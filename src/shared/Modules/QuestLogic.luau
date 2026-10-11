--[[
	QuestLogic
	==========
	Génération DÉTERMINISTE des quêtes du jour : même joueur + même jour UTC =
	mêmes quêtes, quel que soit le serveur (un joueur ne peut pas "relancer"
	ses quêtes en changeant de serveur). Fonctions pures, testables hors Roblox.
]]

local Shared = script.Parent.Parent
local Quests = require(Shared.Config.Quests)

local QuestLogic = {}

export type QuestEntry = {
	Id: string,
	Tier: number,
	Goal: number,
	Progress: number,
	Claimed: boolean,
}

-- Petit générateur pseudo-aléatoire déterministe (LCG)
local function makeRandom(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

function QuestLogic.Generate(userId: number, day: number): { QuestEntry }
	local random = makeRandom(userId * 7919 + day * 104729 + 17)
	local pool = table.clone(Quests.Pool)
	local result = {}
	for _ = 1, math.min(Quests.PerDay, #pool) do
		local total = 0
		for _, quest in pool do
			total += quest.Weight
		end
		local roll = random() * total
		local index = #pool
		for i, quest in pool do
			roll -= quest.Weight
			if roll <= 0 then
				index = i
				break
			end
		end
		local quest = table.remove(pool, index)
		local tier = math.clamp(math.floor(random() * 3) + 1, 1, #quest.Goals)
		table.insert(result, {
			Id = quest.Id,
			Tier = tier,
			Goal = quest.Goals[tier],
			Progress = 0,
			Claimed = false,
		})
	end
	return result
end

-- Fait progresser les quêtes concernées par un événement. Renvoie true si une
-- quête vient d'être terminée.
function QuestLogic.Record(list: { QuestEntry }, event: string, amount: number): boolean
	local completedOne = false
	for _, entry in list do
		local quest = Quests.Get(entry.Id)
		if quest and quest.Event == event and entry.Progress < entry.Goal then
			entry.Progress = math.min(entry.Goal, entry.Progress + amount)
			if entry.Progress >= entry.Goal then
				completedOne = true
			end
		end
	end
	return completedOne
end

function QuestLogic.AllClaimed(list: { QuestEntry }): boolean
	if #list == 0 then
		return false
	end
	for _, entry in list do
		if not entry.Claimed then
			return false
		end
	end
	return true
end

-- Récompense d'une quête : la difficulté multiplie la base et les minutes de revenus
function QuestLogic.GetReward(entry: QuestEntry)
	local quest = Quests.Get(entry.Id)
	if not quest then
		return nil
	end
	local reward = table.clone(quest.Reward)
	reward.Base = (reward.Base or 0) * entry.Tier
	reward.IncomeMinutes = (reward.IncomeMinutes or 0) * entry.Tier
	return reward
end

function QuestLogic.Describe(entry: QuestEntry): string
	local quest = Quests.Get(entry.Id)
	if not quest then
		return "?"
	end
	return string.format(quest.Text, entry.Goal)
end

return QuestLogic
