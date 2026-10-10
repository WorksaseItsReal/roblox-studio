--[[
	LeaderboardService
	==================
	- leaderstats (liste des joueurs Roblox) : Argent, Vols, Rebirths.
	- Classement GLOBAL via 2 OrderedDataStores : argent total gagné et vols réussis.
	  Écriture périodique (toutes les 5 min) + au départ du joueur, lecture du top
	  toutes les 2 min, diffusion aux clients.
	  L'argent est encodé en log (LeaderboardCodec) car les OrderedDataStores
	  n'acceptent que des entiers < 2^63.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Modules.Format)
local LeaderboardCodec = require(Shared.Modules.LeaderboardCodec)
local Remotes = require(Shared.Modules.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)

local LeaderboardService = {}

local Services
local CONFIG = GameConfig.Leaderboard

local moneyStore: OrderedDataStore?
local stealsStore: OrderedDataStore?
local cached = { Money = {}, Steals = {}, UpdatedAt = 0 }
local nameCache: { [number]: string } = {}
local updatedEvent: RemoteEvent

---------------------------------------------------------------------------
-- leaderstats
---------------------------------------------------------------------------
local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local money = Instance.new("StringValue")
	money.Name = "Argent"
	money.Parent = folder
	local steals = Instance.new("IntValue")
	steals.Name = "Vols"
	steals.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
end

function LeaderboardService.UpdateLeaderstats(player: Player)
	local data = Services.DataService.GetData(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local money = folder:FindFirstChild("Argent") :: StringValue?
	local steals = folder:FindFirstChild("Vols") :: IntValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if money then
		money.Value = Format.Money(data.Money)
	end
	if steals then
		steals.Value = data.Stats.Steals
	end
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	player:SetAttribute("Steals", data.Stats.Steals)
	player:SetAttribute("Rebirths", data.Rebirths)
end

---------------------------------------------------------------------------
-- Classement global
---------------------------------------------------------------------------
local function pushScores(userId: number, data)
	if not moneyStore or not stealsStore then
		return
	end
	local key = tostring(userId)
	local ok, err = pcall(function()
		moneyStore:SetAsync(key, LeaderboardCodec.Encode(data.TotalEarned))
		stealsStore:SetAsync(key, math.floor(data.Stats.Steals))
	end)
	if not ok then
		warn("[LeaderboardService] Écriture impossible : " .. tostring(err))
	end
end

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and name then name else ("#" .. userId)
	nameCache[userId] = result
	return result
end

local function readTop(store: OrderedDataStore, decode: boolean)
	local entries = {}
	local ok, pages = pcall(store.GetSortedAsync, store, false, CONFIG.Size)
	if not ok then
		return nil
	end
	for rank, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key) or 0
		table.insert(entries, {
			Rank = rank,
			UserId = userId,
			Name = getName(userId),
			Value = if decode then LeaderboardCodec.Decode(item.value) else item.value,
		})
	end
	return entries
end

-- Repli (Studio sans API) : classement des joueurs présents
local function localTop()
	local money, steals = {}, {}
	for _, player in Services.DataService.GetLoadedPlayers() do
		local data = Services.DataService.GetData(player)
		if data then
			table.insert(money, { UserId = player.UserId, Name = player.Name, Value = data.TotalEarned })
			table.insert(steals, { UserId = player.UserId, Name = player.Name, Value = data.Stats.Steals })
		end
	end
	for _, list in { money, steals } do
		table.sort(list, function(a, b)
			return a.Value > b.Value
		end)
		for rank, entry in list do
			entry.Rank = rank
		end
	end
	return money, steals
end

local function refresh()
	local money, steals
	if moneyStore and stealsStore then
		money = readTop(moneyStore, true)
		steals = readTop(stealsStore, false)
	end
	if not money or not steals then
		money, steals = localTop()
	end
	cached = { Money = money, Steals = steals, UpdatedAt = os.time() }
	updatedEvent:FireAllClients(cached)
end

function LeaderboardService.Init(services)
	Services = services
	updatedEvent = Remotes.GetEvent("LeaderboardUpdated")
	if not Services.DataService.IsUsingMock() then
		local ok1, store1 = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, CONFIG.MoneyStoreName)
		local ok2, store2 = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, CONFIG.StealsStoreName)
		if ok1 and ok2 then
			moneyStore = store1
			stealsStore = store2
		end
	end
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(createLeaderstats)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			createLeaderstats(player)
		end
	end

	Services.DataService.ProfileLoaded:Connect(function(player: Player)
		LeaderboardService.UpdateLeaderstats(player)
	end)
	Services.DataService.ProfileReleasing:Connect(function(player: Player, profile)
		pushScores(player.UserId, profile.Data)
	end)

	Guard.BindFunction("GetLeaderboard", {}, function()
		return true, nil, cached
	end)

	-- Écriture périodique
	task.spawn(function()
		while true do
			task.wait(CONFIG.PushSeconds)
			for _, player in Services.DataService.GetLoadedPlayers() do
				local data = Services.DataService.GetData(player)
				if data then
					task.spawn(pushScores, player.UserId, data)
				end
				task.wait(1) -- étale les requêtes
			end
		end
	end)

	-- Lecture périodique
	task.spawn(function()
		task.wait(10)
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[LeaderboardService] " .. tostring(err))
			end
			task.wait(CONFIG.RefreshSeconds)
		end
	end)
end

return LeaderboardService
