--[[
	DataService
	===========
	Sauvegarde des joueurs avec VERROU DE SESSION (même principe que ProfileService /
	ProfileStore, sans dépendance externe).

	Enregistrement stocké dans le DataStore :
	  { Data = {...données joueur...}, Lock = { JobId, SessionId, Time } | nil, SavedAt }

	Garanties :
	- Un profil n'est chargé que si aucun AUTRE serveur ne le détient (Lock absent,
	  ou plus vieux que LockStaleSeconds = serveur crashé). Sinon on attend que
	  l'ancien serveur le libère, puis on finit par le forcer (voir loadRecord).
	- Chaque sauvegarde vérifie que le verrou appartient toujours à NOTRE session
	  (SessionId). Si un autre serveur l'a pris, on arrête d'écrire et on expulse :
	  impossible d'écraser une progression plus récente.
	- Le verrou est rafraîchi à chaque autosave et libéré au départ du joueur
	  (et dans BindToClose à l'arrêt du serveur).
	- Les ventes Robux (ProcessReceipt) appellent SaveNow : le reçu n'est validé
	  qu'une fois la sauvegarde réussie.

	Limite connue : un vol modifie 2 profils (victime + voleur) qui sont sauvegardés
	séparément. On déclenche une sauvegarde rapide des deux (SaveSoon), mais un crash
	serveur pile entre les deux écritures pourrait dupliquer la créature. Un DataStore
	n'offre pas de transaction multi-clés ; le risque est accepté (fenêtre de quelques
	secondes, crash nécessaire).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Signal = require(Shared.Modules.Signal)
local MockDataStore = require(script.Parent.Parent.Lib.MockDataStore)

local DataService = {}

local Services

local CONFIG = GameConfig.Data
local SCHEMA_VERSION = 1
local JOB_ID = if game.JobId ~= "" then game.JobId else ("Studio-" .. HttpService:GenerateGUID(false))

export type Profile = {
	Player: Player,
	UserId: number,
	Key: string,
	SessionId: string,
	Data: any,
	Saving: boolean,
	SessionLost: boolean,
	LastSaved: number,
	SaveRequested: boolean,
}

-- Événements utilisés par les autres services
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile) juste avant la sauvegarde finale

local store: any
local usingMock = false
local profiles: { [Player]: Profile } = {}
local releasingUserIds: { [number]: boolean } = {}

---------------------------------------------------------------------------
-- Données par défaut d'un nouveau joueur
---------------------------------------------------------------------------
local function createTemplate()
	return {
		SchemaVersion = SCHEMA_VERSION,
		Money = GameConfig.Economy.StartingMoney,
		TotalEarned = 0,
		Rebirths = 0,
		Creatures = {}, -- { { Uid, Id, Mutation, Slot } }
		NextUid = 1,
		Upgrades = { Slots = 0, Barrier = 0, Alarm = 0 },
		ShortcutUnlocked = false,
		Index = {}, -- [creatureId] = true
		IndexClaimed = {}, -- ["Lava:Complete"] = true
		Daily = { LastDay = -1, Streak = 0 },
		Stats = { Steals = 0, TimesRobbed = 0, Fusions = 0, Bought = 0, Recovered = 0 },
		OwnedPasses = {}, -- cache de possession des gamepasses
		ProcessedReceipts = {}, -- PurchaseId déjà traités (idempotence Robux)
		UnknownCreatures = {}, -- créatures retirées de la config : conservées, jamais supprimées
		FirstJoin = os.time(),
		LastJoin = os.time(),
		LastSeen = 0, -- dernier instant connu en jeu (gains hors ligne)
		LastIncome = 0, -- revenu de base à ce moment-là
		TutorialDone = false,
		Quests = { Day = -1, List = {}, BonusClaimed = false },
		RedeemedCodes = {}, -- [CODE] = true
		Boosts = { MoneyUntil = 0 }, -- fin du boost Argent x2 (os.time)
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- Ajoute les clés manquantes (nouvelles fonctionnalités) sans écraser l'existant
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

-- Nettoie des données potentiellement anciennes ou corrompues
local function sanitize(data: any)
	if type(data.Money) ~= "number" or data.Money ~= data.Money or data.Money < 0 then
		data.Money = 0
	end

	local valid = {}
	local usedSlots = {}
	local usedUids = {}
	local maxUid = 0
	for _, entry in data.Creatures do
		if type(entry) == "table" and Creatures.IsValid(entry.Id) then
			if
				type(entry.Mutation) ~= "string"
				or (entry.Mutation ~= Mutations.None and not Mutations.Get(entry.Mutation))
			then
				entry.Mutation = Mutations.None
			end
			local uidNumber = type(entry.Uid) == "string" and tonumber(entry.Uid:match("^u(%d+)$"))
			if not uidNumber or usedUids[entry.Uid] then
				entry.Uid = nil -- réattribué plus bas
			else
				usedUids[entry.Uid] = true
				maxUid = math.max(maxUid, uidNumber)
			end
			table.insert(valid, entry)
		elseif type(entry) == "table" then
			-- Créature retirée de la config : on la met de côté au lieu de la perdre
			table.insert(data.UnknownCreatures, entry)
		end
	end

	data.NextUid = math.max(tonumber(data.NextUid) or 1, maxUid + 1)
	for _, entry in valid do
		if entry.Uid == nil then
			entry.Uid = "u" .. data.NextUid
			data.NextUid += 1
		end
	end

	-- Emplacements uniques et dans les limites physiques
	local needsSlot = {}
	for _, entry in valid do
		local slot = entry.Slot
		if
			type(slot) ~= "number"
			or slot % 1 ~= 0
			or slot < 1
			or slot > GameConfig.Slots.MaxPhysical
			or usedSlots[slot]
		then
			table.insert(needsSlot, entry)
		else
			usedSlots[slot] = true
		end
	end
	for _, entry in needsSlot do
		entry.Slot = nil
		for slot = 1, GameConfig.Slots.MaxPhysical do
			if not usedSlots[slot] then
				usedSlots[slot] = true
				entry.Slot = slot
				break
			end
		end
	end
	-- S'il n'y a vraiment plus de place physique, la créature part dans UnknownCreatures
	local final = {}
	for _, entry in valid do
		if entry.Slot ~= nil then
			table.insert(final, entry)
		else
			table.insert(data.UnknownCreatures, entry)
		end
	end
	data.Creatures = final
	data.SchemaVersion = SCHEMA_VERSION
end

---------------------------------------------------------------------------
-- DataStore réel ou simulé
---------------------------------------------------------------------------
local function initStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.StoreName)
	end)
	if ok and RunService:IsStudio() then
		-- En Studio sans accès API, la première requête échoue : on teste
		local testOk = pcall(function()
			result:GetAsync("__studio_access_test")
		end)
		ok = testOk
	end
	if ok then
		store = result
	else
		store = MockDataStore.new()
		usingMock = true
		warn(
			"[DataService] DataStore indisponible : données en MÉMOIRE (non sauvegardées). "
				.. "Active 'Enable Studio Access to API Services' pour tester la vraie sauvegarde."
		)
	end
end

function DataService.IsUsingMock(): boolean
	return usingMock
end

---------------------------------------------------------------------------
-- Chargement avec verrou de session
---------------------------------------------------------------------------
--[[
	Si un autre serveur détient encore le verrou (le joueur vient de changer de
	serveur), on attend qu'il le libère. À la DERNIÈRE tentative, on le force
	(comme ProfileService/ProfileStore) : c'est sûr car l'ancien serveur vérifie
	le SessionId avant chaque écriture et ne pourra plus rien écraser. Le pire cas
	est la perte de sa progression non sauvegardée (< 1 autosave), jamais une
	duplication.
]]
local function loadRecord(player: Player, key: string, sessionId: string): (boolean, any, string?)
	for attempt = 1, CONFIG.LoadAttempts do
		-- Si CE serveur est encore en train de libérer l'ancienne session du joueur
		-- (il vient de partir et revient aussitôt), on attend la fin de l'écriture.
		local waited = 0
		while releasingUserIds[player.UserId] and waited < 30 do
			waited += task.wait(0.25)
		end

		local force = attempt == CONFIG.LoadAttempts
		local loaded = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				-- Peut être rappelée plusieurs fois par Roblox : on réinitialise l'état
				loaded = nil
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.SessionId ~= nil and not force then
					local age = os.time() - (tonumber(lock.Time) or 0)
					local sameServer = lock.JobId == JOB_ID -- verrou orphelin laissé par CE serveur
					if age < CONFIG.LockStaleSeconds and not sameServer then
						return nil -- annule l'écriture : on réessaiera
					end
				end
				record.Lock = { JobId = JOB_ID, SessionId = sessionId, Time = os.time() }
				loaded = record
				return record
			end)
		end)

		if ok and loaded then
			return true, loaded.Data, nil
		end
		if not ok then
			warn(
				string.format("[DataService] Échec de chargement (%s), tentative %d : %s", key, attempt, tostring(err))
			)
		end
		if player.Parent == nil then
			return false, nil, "left"
		end
		if attempt < CONFIG.LoadAttempts then
			task.wait(CONFIG.LoadRetryDelay)
		end
	end
	return false, nil, "error"
end

---------------------------------------------------------------------------
-- Sauvegarde (vérifie la propriété du verrou)
---------------------------------------------------------------------------
local function writeProfile(profile: Profile, release: boolean): boolean
	if profile.SessionLost then
		return false
	end
	-- Une seule écriture à la fois par profil
	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true
	profile.SaveRequested = false

	local snapshot = deepCopy(profile.Data)
	local lost = false
	local ok, err = pcall(function()
		store:UpdateAsync(profile.Key, function(old)
			lost = false
			local lock = if type(old) == "table" then old.Lock else nil
			if type(lock) ~= "table" or lock.SessionId ~= profile.SessionId then
				lost = true
				return nil
			end
			return {
				Data = snapshot,
				Lock = if release then nil else { JobId = JOB_ID, SessionId = profile.SessionId, Time = os.time() },
				SavedAt = os.time(),
			}
		end)
	end)
	profile.Saving = false

	if not ok then
		warn(string.format("[DataService] Échec de sauvegarde (%s) : %s", profile.Key, tostring(err)))
		return false
	end
	if lost then
		profile.SessionLost = true
		warn("[DataService] Session perdue pour " .. profile.Key .. " : un autre serveur a pris le verrou.")
		if profile.Player.Parent then
			profile.Player:Kick("Ta partie a été ouverte sur un autre serveur. Reconnecte-toi.")
		end
		return false
	end
	profile.LastSaved = os.clock()
	return true
end

---------------------------------------------------------------------------
-- Cycle de vie des joueurs
---------------------------------------------------------------------------
local function releaseProfile(player: Player, profile: Profile)
	releasingUserIds[profile.UserId] = true
	-- Les autres services finalisent leurs données (vols en cours, classement...)
	DataService.ProfileReleasing:Fire(player, profile)

	local released = false
	for attempt = 1, 3 do
		if writeProfile(profile, true) or profile.SessionLost then
			released = true
			break
		end
		task.wait(2 * attempt)
	end
	if not released then
		warn("[DataService] Impossible de libérer " .. profile.Key .. " : le verrou expirera seul.")
	end
	releasingUserIds[profile.UserId] = nil
end

local function onPlayerAdded(player: Player)
	local key = CONFIG.KeyPrefix .. player.UserId
	local sessionId = HttpService:GenerateGUID(false)
	local ok, storedData, reason = loadRecord(player, key, sessionId)

	if not ok then
		if reason ~= "left" then
			player:Kick("Impossible de charger ta partie (Roblox DataStore). Réessaie plus tard.")
		end
		return
	end

	local data = if type(storedData) == "table" then storedData else createTemplate()
	reconcile(data, createTemplate())
	sanitize(data)
	data.LastJoin = os.time()

	if
		RunService:IsStudio()
		and GameConfig.Debug.StudioStartingMoney
		and data.Money < GameConfig.Debug.StudioStartingMoney
	then
		data.Money = GameConfig.Debug.StudioStartingMoney
	end

	local profile: Profile = {
		Player = player,
		UserId = player.UserId,
		Key = key,
		SessionId = sessionId,
		Data = data,
		Saving = false,
		SessionLost = false,
		LastSaved = os.clock(),
		SaveRequested = false,
	}

	-- Le joueur est parti pendant le chargement : on libère immédiatement le verrou
	if player.Parent == nil then
		task.spawn(writeProfile, profile, true)
		return
	end

	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	-- Retiré de la table AVANT la sauvegarde : plus aucun service ne peut le modifier
	profiles[player] = nil
	releaseProfile(player, profile)
end

---------------------------------------------------------------------------
-- API publique
---------------------------------------------------------------------------
function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.GetData(player: Player): any
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.GetLoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

-- Génère un identifiant de créature unique pour ce joueur
function DataService.NewUid(data: any): string
	local uid = "u" .. data.NextUid
	data.NextUid += 1
	return uid
end

-- Sauvegarde immédiate (bloquante). Renvoie true si réussie.
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return writeProfile(profile, false)
end

-- Demande une sauvegarde dans les prochaines secondes (regroupée)
function DataService.SaveSoon(player: Player)
	local profile = profiles[player]
	if profile then
		profile.SaveRequested = true
	end
end

function DataService.Init(services)
	Services = services
	initStore()
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave échelonné + sauvegardes "bientôt" (minimum 7 s entre deux écritures :
	-- Roblox limite à 1 écriture / 6 s par clé)
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for _, profile in profiles do
				local elapsed = now - profile.LastSaved
				local due = elapsed >= CONFIG.AutosaveSeconds or (profile.SaveRequested and elapsed >= 7)
				if due and not profile.Saving then
					task.spawn(writeProfile, profile, false)
				end
			end
		end
	end)

	-- Arrêt du serveur : on libère tous les profils (30 s max accordées par Roblox)
	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			profiles[player] = nil
			task.spawn(function()
				releaseProfile(player, profile)
				pending -= 1
			end)
		end
		-- On attend aussi les joueurs partis juste avant l'arrêt (PlayerRemoving en cours)
		local started = os.clock()
		while (pending > 0 or next(releasingUserIds) ~= nil) and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)

	if Services == nil then
		warn("[DataService] Services non injectés")
	end
end

return DataService
