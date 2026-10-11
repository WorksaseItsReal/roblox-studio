--[[
	QuestService
	============
	Quêtes quotidiennes (3 par jour UTC, tirées par QuestLogic). Les autres
	services signalent les actions via QuestService.RecordEvent(player, event, n) :
	  Buy, BuyRare, Steal, Fuse, Barrier, Minute, Recover
	La progression est validée côté serveur uniquement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Economy = require(Shared.Modules.Economy)
local QuestLogic = require(Shared.Modules.QuestLogic)
local Guard = require(script.Parent.Parent.Lib.Guard)

local QuestService = {}

local Services

-- Génère les quêtes du jour si besoin (nouveau jour ou données invalides)
local function ensureToday(player: Player, data)
	local today = Economy.GetUtcDay(os.time())
	local quests = data.Quests
	if type(quests) ~= "table" or type(quests.List) ~= "table" or quests.Day ~= today then
		data.Quests = {
			Day = today,
			List = QuestLogic.Generate(player.UserId, today),
			BonusClaimed = false,
		}
		return true
	end
	return false
end

function QuestService.RecordEvent(player: Player, event: string, amount: number?)
	local data = Services.DataService.GetData(player)
	if not data then
		return
	end
	ensureToday(player, data)
	if QuestLogic.Record(data.Quests.List, event, amount or 1) then
		Services.NotificationService.Notify(player, "Quête terminée ! Réclame ta récompense 📜", "Success")
	end
	Services.SyncService.Push(player)
end

local function claim(player: Player, index: number): (boolean, string?)
	local data = Services.DataService.GetData(player)
	ensureToday(player, data)
	local entry = data.Quests.List[index]
	if not entry then
		return false, "Quête introuvable."
	end
	if entry.Claimed then
		return false, "Déjà réclamée."
	end
	if entry.Progress < entry.Goal then
		return false, "Quête pas encore terminée."
	end
	entry.Claimed = true
	local text = Services.RewardService.Grant(player, QuestLogic.GetReward(entry))
	return true, "Quête réussie : " .. text
end

local function claimBonus(player: Player): (boolean, string?)
	local data = Services.DataService.GetData(player)
	ensureToday(player, data)
	if data.Quests.BonusClaimed then
		return false, "Bonus déjà réclamé aujourd'hui."
	end
	if not QuestLogic.AllClaimed(data.Quests.List) then
		return false, "Termine et réclame les 3 quêtes d'abord."
	end
	data.Quests.BonusClaimed = true
	local text = Services.RewardService.Grant(player, Quests.CompletionBonus)
	return true, "Bonus du jour : " .. text
end

function QuestService.GetSnapshot(player: Player)
	local data = Services.DataService.GetData(player)
	if not data then
		return nil
	end
	ensureToday(player, data)
	local list = {}
	for index, entry in data.Quests.List do
		local reward = QuestLogic.GetReward(entry)
		table.insert(list, {
			Index = index,
			Id = entry.Id,
			Text = QuestLogic.Describe(entry),
			Progress = entry.Progress,
			Goal = entry.Goal,
			Claimed = entry.Claimed,
			Tier = entry.Tier,
			RewardText = if reward
				then Services.RewardService.Describe(reward, data.Rebirths, Services.IncomeService.GetIncome(player))
				else "",
		})
	end
	return {
		List = list,
		BonusClaimed = data.Quests.BonusClaimed,
		AllClaimed = QuestLogic.AllClaimed(data.Quests.List),
		ResetsAt = (data.Quests.Day + 1) * 86400,
	}
end

function QuestService.Init(services)
	Services = services
end

function QuestService.Start()
	Guard.BindFunction("ClaimQuest", { Args = { Guard.T.Integer(1, Quests.PerDay) } }, claim)
	Guard.BindFunction("ClaimQuestBonus", {}, claimBonus)

	Services.DataService.ProfileLoaded:Connect(function(player: Player, profile)
		ensureToday(player, profile.Data)
	end)

	-- Quête "Joue X minutes" : une unité par minute passée en jeu
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if Services.DataService.IsLoaded(player) then
					QuestService.RecordEvent(player, "Minute", 1)
				end
			end
		end
	end)
end

return QuestService
