--[[
	StealService
	============
	Vol de créatures.

	1. Le voleur maintient le prompt "Voler" sur une créature d'une base adverse.
	   Le serveur vérifie : base non protégée par la barrière, distance réelle,
	   voleur vivant, pas déjà en train de porter, place libre chez lui.
	2. La créature est retirée de l'emplacement (mais reste dans les DONNÉES de la
	   victime : un crash ne peut donc pas la dupliquer) et est portée au-dessus de
	   la tête du voleur, qui est ralenti.
	3. Fin du vol, vérifiée 5x/s :
	   - le voleur entre dans SA base           -> transfert des données (réussite)
	   - le propriétaire le touche              -> récupération
	   - le voleur meurt / quitte / délai dépassé -> retour chez la victime
	   - déplacement impossible (téléportation)  -> annulation (anti-triche)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Modules.Economy)
local CreatureVisuals = require(Shared.Modules.CreatureVisuals)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local StealService = {}

local Services
local CONFIG = GameConfig.Steal

type Carry = {
	Thief: Player,
	Victim: Player,
	Uid: string,
	CreatureId: string,
	Mutation: string,
	StartedAt: number,
	LastPosition: Vector3,
	LastTime: number,
	Model: Model?,
}

local carriesByThief: { [Player]: Carry } = {}
local carriesByVictim: { [Player]: { [string]: Carry } } = {}

---------------------------------------------------------------------------
-- Requêtes utilisées par les autres services
---------------------------------------------------------------------------
function StealService.IsBeingCarried(victim: Player, uid: string): boolean
	local list = carriesByVictim[victim]
	return list ~= nil and list[uid] ~= nil
end

function StealService.IsCarrying(player: Player): boolean
	return carriesByThief[player] ~= nil
end

-- Ensemble des Uids de la victime actuellement portés par des voleurs
function StealService.GetCarriedUids(victim: Player): { [string]: boolean }
	local set = {}
	local list = carriesByVictim[victim]
	if list then
		for uid in list do
			set[uid] = true
		end
	end
	return set
end

-- (porte-t-il quelque chose, niveau d'alarme de la victime)
function StealService.GetCarryInfo(player: Player): (boolean, number?)
	local carry = carriesByThief[player]
	if not carry then
		return false, nil
	end
	local victimData = Services.DataService.GetData(carry.Victim)
	return true, if victimData then victimData.Upgrades.Alarm else 0
end

-- Infos affichables par l'UI du voleur
function StealService.GetCarryPublicInfo(player: Player)
	local carry = carriesByThief[player]
	if not carry then
		return nil
	end
	return {
		CreatureId = carry.CreatureId,
		Mutation = carry.Mutation,
		VictimName = carry.Victim.DisplayName,
		SecondsLeft = math.max(0, carry.StartedAt + CONFIG.MaxCarrySeconds - os.clock()),
	}
end

function StealService.ResetTracking(player: Player)
	local carry = carriesByThief[player]
	local root = Services.CharacterService.GetRootPart(player)
	if carry and root then
		carry.LastPosition = root.Position
		carry.LastTime = os.clock()
	end
end

---------------------------------------------------------------------------
-- Fin de vol
---------------------------------------------------------------------------
local function detach(carry: Carry)
	carriesByThief[carry.Thief] = nil
	local list = carriesByVictim[carry.Victim]
	if list then
		list[carry.Uid] = nil
		if next(list) == nil then
			carriesByVictim[carry.Victim] = nil
		end
	end
	if carry.Model then
		carry.Model:Destroy()
		carry.Model = nil
	end
end

local function refreshBoth(carry: Carry)
	Services.CharacterService.RefreshSpeed(carry.Thief)
	Services.IncomeService.Recalculate(carry.Victim)
	Services.SyncService.Push(carry.Thief)
	Services.SyncService.Push(carry.Victim)
end

-- Le vol échoue : la créature retourne dans la base de la victime
local function fail(carry: Carry, thiefMessage: string, victimMessage: string?)
	detach(carry)
	Services.PlotService.AddCreatureModel(carry.Victim, carry.Uid)
	refreshBoth(carry)
	Services.NotificationService.Notify(carry.Thief, thiefMessage, "Error")
	if victimMessage then
		Services.NotificationService.Notify(carry.Victim, victimMessage, "Success")
	end
end

-- Le voleur est rentré chez lui : transfert des données
local function deliver(carry: Carry)
	local thief, victim = carry.Thief, carry.Victim
	local victimData = Services.DataService.GetData(victim)
	local thiefData = Services.DataService.GetData(thief)
	if not victimData or not thiefData then
		detach(carry)
		refreshBoth(carry)
		return
	end

	local index = nil
	for i, entry in victimData.Creatures do
		if entry.Uid == carry.Uid then
			index = i
			break
		end
	end
	if not index then
		fail(carry, "La créature a disparu en route.")
		return
	end

	local slot = Economy.FindFreeSlot(thiefData, Services.MonetizationService.GetPasses(thief))
	if not slot then
		fail(carry, "Ta base est pleine ! La créature retourne chez " .. victim.DisplayName .. ".")
		return
	end

	detach(carry)
	local stolen = table.remove(victimData.Creatures, index)
	local entry = {
		Uid = Services.DataService.NewUid(thiefData),
		Id = stolen.Id,
		Mutation = stolen.Mutation,
		Slot = slot,
	}
	table.insert(thiefData.Creatures, entry)
	thiefData.Stats.Steals += 1
	victimData.Stats.TimesRobbed += 1

	Services.PlotService.AddCreatureModel(thief, entry.Uid)
	Services.IndexService.Discover(thief, entry.Id)
	Services.IncomeService.Recalculate(thief)
	refreshBoth(carry)
	Services.LeaderboardService.UpdateLeaderstats(thief)
	-- Réduit la fenêtre de risque de duplication en cas de crash (voir DataService)
	Services.DataService.SaveSoon(thief)
	Services.DataService.SaveSoon(victim)

	local def = Creatures.Get(entry.Id)
	local name = if def then def.Name else entry.Id
	Services.NotificationService.Notify(thief, "Vol réussi : " .. name .. " est à toi !", "Success")
	Services.NotificationService.Notify(victim, thief.DisplayName .. " t'a volé " .. name .. " !", "Steal")

	local rarity = def and Rarities.Get(def.Rarity)
	if rarity and rarity.Tier >= CONFIG.AnnounceMinTier then
		Services.NotificationService.Announce(
			"Vol " .. rarity.Name .. " !",
			thief.DisplayName .. " a volé " .. name .. " à " .. victim.DisplayName,
			rarity.Color
		)
	end
end

---------------------------------------------------------------------------
-- Début de vol (ProximityPrompt serveur)
---------------------------------------------------------------------------
local function buildCarryModel(thief: Player, creatureId: string, mutation: string): Model?
	local root = Services.CharacterService.GetRootPart(thief)
	if not root or not thief.Character then
		return nil
	end
	local model = CreatureVisuals.Build(creatureId, mutation, { Anchored = false, Billboard = false })
	model.Name = "CarriedCreature"
	local hip = model:GetAttribute("HipHeight") or 2
	model:PivotTo(root.CFrame * CFrame.new(0, 2.5 + hip, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = thief.Character
	return model
end

function StealService.TryStartSteal(thief: Player, plot, uid: string)
	if not RateLimiter.Check(thief, "StealPrompt") then
		return
	end
	local victim: Player? = plot.Owner
	local notify = Services.NotificationService.Notify
	if not victim or victim == thief then
		return
	end
	local thiefData = Services.DataService.GetData(thief)
	local victimData = Services.DataService.GetData(victim)
	if not thiefData or not victimData or not Services.PlotService.GetPlot(thief) then
		return
	end
	if carriesByThief[thief] then
		notify(thief, "Tu portes déjà une créature !", "Error")
		return
	end
	if Services.BaseDefenseService.IsBarrierActive(plot) then
		notify(thief, "Cette base est protégée par sa barrière.", "Error")
		return
	end

	local entry = nil
	for _, candidate in victimData.Creatures do
		if candidate.Uid == uid then
			entry = candidate
			break
		end
	end
	if not entry or StealService.IsBeingCarried(victim, uid) then
		return
	end

	local root = Services.CharacterService.GetRootPart(thief)
	local creatureModel = Services.PlotService.GetCreatureModel(victim, uid)
	if not root or not creatureModel then
		return
	end
	if (root.Position - creatureModel:GetPivot().Position).Magnitude > CONFIG.MaxStealDistance then
		notify(thief, "Trop loin.", "Error")
		return
	end
	if not Economy.FindFreeSlot(thiefData, Services.MonetizationService.GetPasses(thief)) then
		notify(thief, "Ta base est pleine : libère un emplacement avant de voler.", "Error")
		return
	end

	-- Démarrage
	Services.PlotService.RemoveCreatureModel(victim, uid)
	local carry: Carry = {
		Thief = thief,
		Victim = victim,
		Uid = uid,
		CreatureId = entry.Id,
		Mutation = entry.Mutation or Mutations.None,
		StartedAt = os.clock(),
		LastPosition = root.Position,
		LastTime = os.clock(),
		Model = nil,
	}
	carriesByThief[thief] = carry
	carriesByVictim[victim] = carriesByVictim[victim] or {}
	carriesByVictim[victim][uid] = carry
	carry.Model = buildCarryModel(thief, entry.Id, carry.Mutation)

	refreshBoth(carry)
	local def = Creatures.Get(entry.Id)
	local name = if def then def.Name else entry.Id
	notify(thief, "Tu portes " .. name .. " : ramène-le dans TA base !", "Warning")
	notify(
		victim,
		"ALERTE : " .. thief.DisplayName .. " vole ton " .. name .. " ! Touche-le pour le récupérer.",
		"Steal"
	)
	Services.NotificationService.Effect(victim, "StealAlert", { ThiefUserId = thief.UserId })
end

---------------------------------------------------------------------------
-- Annulations externes
---------------------------------------------------------------------------
-- Rebirth ou départ de la victime : les vols en cours sont annulés sans transfert
function StealService.CancelForVictim(victim: Player, reason: string)
	local list = carriesByVictim[victim]
	if not list then
		return
	end
	for _, carry in table.clone(list) do
		detach(carry)
		Services.CharacterService.RefreshSpeed(carry.Thief)
		Services.SyncService.Push(carry.Thief)
		Services.NotificationService.Notify(carry.Thief, reason, "Error")
	end
end

local function onPlayerGone(player: Player)
	local carry = carriesByThief[player]
	if carry then
		detach(carry)
		Services.PlotService.AddCreatureModel(carry.Victim, carry.Uid)
		Services.IncomeService.Recalculate(carry.Victim)
		Services.SyncService.Push(carry.Victim)
		Services.NotificationService.Notify(
			carry.Victim,
			"Le voleur a quitté le jeu : ta créature est revenue.",
			"Success"
		)
	end
	StealService.CancelForVictim(player, player.DisplayName .. " a quitté le jeu : le vol est annulé.")
end

---------------------------------------------------------------------------
-- Boucle de surveillance
---------------------------------------------------------------------------
local function checkCarry(carry: Carry)
	local thief, victim = carry.Thief, carry.Victim
	local root = Services.CharacterService.GetRootPart(thief)
	if not root then
		fail(
			carry,
			"Tu es tombé : la créature retourne chez son propriétaire.",
			"Le voleur est tombé : ta créature est revenue !"
		)
		return
	end
	local t = os.clock()
	if t - carry.StartedAt > CONFIG.MaxCarrySeconds then
		fail(
			carry,
			"Trop lent ! La créature retourne chez son propriétaire.",
			"Le voleur a été trop lent : ta créature est revenue !"
		)
		return
	end

	-- Le propriétaire touche le voleur
	local victimRoot = Services.CharacterService.GetRootPart(victim)
	if victimRoot and (victimRoot.Position - root.Position).Magnitude <= CONFIG.RecoverDistance then
		fail(carry, victim.DisplayName .. " a récupéré sa créature !", "Créature récupérée !")
		return
	end

	-- Anti-téléportation (distance horizontale uniquement : les chutes sont tolérées)
	local dt = t - carry.LastTime
	if dt > 0 then
		local delta = root.Position - carry.LastPosition
		local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
		local walkSpeed = if humanoid then humanoid.WalkSpeed else GameConfig.Movement.BaseWalkSpeed
		local maxDistance = (walkSpeed * CONFIG.SpeedTolerance + CONFIG.SpeedFlatAllowance) * dt + 2
		if horizontal > maxDistance then
			fail(carry, "Mouvement suspect détecté : vol annulé.")
			return
		end
	end
	carry.LastPosition = root.Position
	carry.LastTime = t

	local thiefPlot = Services.PlotService.GetPlot(thief)
	if thiefPlot and Services.MapService.IsInsidePlot(thiefPlot, root.Position) then
		deliver(carry)
	end
end

function StealService.Init(services)
	Services = services
end

function StealService.Start()
	Services.DataService.ProfileReleasing:Connect(onPlayerGone)
	Players.PlayerRemoving:Connect(function(player: Player)
		RateLimiter.Clear(player)
		if carriesByThief[player] or carriesByVictim[player] then
			onPlayerGone(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, carry in table.clone(carriesByThief) do
				if carriesByThief[carry.Thief] == carry then
					local ok, err = pcall(checkCarry, carry)
					if not ok then
						warn("[StealService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return StealService
