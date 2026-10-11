--[[
	PlaytimeService
	===============
	Cadeaux de session : plus le joueur reste, plus il débloque de cadeaux
	(argent, boosts, créatures). Le temps est mesuré par le serveur (pas de
	confiance au client) et repart de zéro à chaque session : c'est voulu, ça
	pousse à de longues sessions, un indicateur clé pour l'algorithme Roblox.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Guard = require(script.Parent.Parent.Lib.Guard)

local PlaytimeService = {}

local Services
local GIFTS = GameConfig.Playtime.Gifts

type Session = { StartedAt: number, Claimed: { [number]: boolean } }
local sessions: { [Player]: Session } = {}

function PlaytimeService.GetSessionSeconds(player: Player): number
	local session = sessions[player]
	return if session then os.clock() - session.StartedAt else 0
end

local function claim(player: Player, index: number): (boolean, string?)
	local session = sessions[player]
	local gift = GIFTS[index]
	if not session or not gift then
		return false, "Cadeau introuvable."
	end
	if session.Claimed[index] then
		return false, "Déjà ouvert."
	end
	if PlaytimeService.GetSessionSeconds(player) < gift.Minutes * 60 then
		return false, "Pas encore disponible."
	end
	session.Claimed[index] = true
	local text = Services.RewardService.Grant(player, gift.Reward)
	return true, "🎁 Cadeau : " .. text
end

function PlaytimeService.GetSnapshot(player: Player)
	local session = sessions[player]
	if not session then
		return nil
	end
	local claimed = {}
	for index in session.Claimed do
		table.insert(claimed, index)
	end
	local data = Services.DataService.GetData(player)
	local income = Services.IncomeService.GetIncome(player)
	local previews = {}
	for index, gift in GIFTS do
		previews[index] = Services.RewardService.Describe(gift.Reward, if data then data.Rebirths else 0, income)
	end
	return {
		SessionSeconds = PlaytimeService.GetSessionSeconds(player),
		Claimed = claimed,
		Previews = previews,
	}
end

function PlaytimeService.Init(services)
	Services = services
end

function PlaytimeService.Start()
	Guard.BindFunction("ClaimGift", { Args = { Guard.T.Integer(1, #GIFTS) } }, claim)

	local function start(player: Player)
		sessions[player] = { StartedAt = os.clock(), Claimed = {} }
	end
	Players.PlayerAdded:Connect(start)
	for _, player in Players:GetPlayers() do
		start(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)

	-- Prévient le joueur quand un cadeau se débloque
	task.spawn(function()
		local announced: { [Player]: { [number]: boolean } } = {}
		while true do
			task.wait(5)
			for player, session in sessions do
				local seconds = os.clock() - session.StartedAt
				announced[player] = announced[player] or {}
				for index, gift in GIFTS do
					if seconds >= gift.Minutes * 60 and not session.Claimed[index] and not announced[player][index] then
						announced[player][index] = true
						Services.NotificationService.Notify(player, "🎁 Un cadeau de session est prêt !", "Success")
						Services.SyncService.Push(player)
					end
				end
			end
			for player in announced do
				if not sessions[player] then
					announced[player] = nil
				end
			end
		end
	end)
end

return PlaytimeService
