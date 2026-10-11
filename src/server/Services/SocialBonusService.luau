--[[
	SocialBonusService
	==================
	Bonus de revenus quand on joue avec ses amis (+10 % par ami présent, max
	+50 %) et pour les membres du groupe Roblox du jeu. C'est un des moteurs de
	viralité les plus efficaces : inviter ses amis devient rentable.

	Les vérifications d'amitié (IsFriendsWithAsync) sont des appels web : elles sont
	faites une seule fois par paire de joueurs et mises en cache.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local SocialBonusService = {}

local Services

local friendCache: { [string]: boolean } = {}
local friendCount: { [Player]: number } = {}
local inGroup: { [Player]: boolean } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a.UserId, b.UserId)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId)
	local value = ok and result == true
	if ok then
		friendCache[key] = value
	end
	return value
end

-- "leaving" : joueur en train de partir (encore listé par Players pendant PlayerRemoving)
local function recount(leaving: Player?)
	for _, player in Players:GetPlayers() do
		if player == leaving then
			continue
		end
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and other ~= leaving and areFriends(player, other) then
				count += 1
			end
		end
		if friendCount[player] ~= count then
			friendCount[player] = count
			player:SetAttribute("FriendCount", count)
			if Services.DataService.IsLoaded(player) then
				Services.IncomeService.Recalculate(player)
				Services.SyncService.Push(player)
			end
		end
	end
end

function SocialBonusService.GetBonus(player: Player)
	return {
		Friends = friendCount[player] or 0,
		InGroup = inGroup[player] == true,
	}
end

function SocialBonusService.Init(services)
	Services = services
end

function SocialBonusService.Start()
	local groupId = GameConfig.Social.GroupId

	local function checkGroup(player: Player)
		if groupId ~= 0 then
			local ok, result = pcall(player.IsInGroupAsync, player, groupId)
			inGroup[player] = ok and result == true
			player:SetAttribute("InGroup", inGroup[player])
		end
	end
	Players.PlayerAdded:Connect(function(player: Player)
		checkGroup(player)
		recount(nil)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkGroup, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		friendCount[player] = nil
		inGroup[player] = nil
		task.spawn(recount, player)
	end)
	task.spawn(recount, nil)
end

return SocialBonusService
