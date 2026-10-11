--[[
	Economy
	=======
	Fonctions PURES de calcul économique (aucun effet de bord).
	Partagées pour que l'UI affiche exactement les mêmes chiffres que ceux que le
	serveur applique. Le serveur reste la seule source de vérité : il appelle ces
	fonctions avec SES données, jamais avec des valeurs envoyées par le client.

	"passes" = ensemble des gamepasses effectifs du joueur : { DoubleMoney = true, ... }
]]

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Dimensions = require(Shared.Config.Dimensions)

local Economy = {}

export type CreatureEntry = {
	Uid: string,
	Id: string,
	Mutation: string,
	Slot: number,
}

export type Passes = { [string]: boolean }

-- Revenu d'UNE créature (base x mutation), sans les multiplicateurs du joueur
function Economy.GetCreatureIncome(entry: CreatureEntry): number
	local def = Creatures.Get(entry.Id)
	if not def then
		return 0
	end
	return def.Income * Mutations.GetMultiplier(entry.Mutation)
end

function Economy.GetSellValue(entry: CreatureEntry): number
	local def = Creatures.Get(entry.Id)
	if not def then
		return 0
	end
	return math.floor(def.Price * GameConfig.Economy.SellRefundRatio * Mutations.GetMultiplier(entry.Mutation))
end

function Economy.GetRebirthMultiplier(rebirths: number): number
	return 1 + rebirths * GameConfig.Rebirth.MultiplierPerLevel
end

function Economy.GetRebirthCost(rebirths: number): number
	return math.floor(GameConfig.Rebirth.BaseCost * GameConfig.Rebirth.CostGrowth ^ rebirths)
end

-- Bonus permanent cumulé des récompenses d'index réclamées (ex : 0.15 = +15 %)
function Economy.GetIndexBonus(data): number
	local bonus = 0
	local rewards = GameConfig.Index.Rewards
	for _, dimensionId in Dimensions.Order do
		for tier, reward in rewards do
			if data.IndexClaimed[dimensionId .. ":" .. tier] then
				bonus += reward.IncomeBonus
			end
		end
	end
	return bonus
end

-- Bonus temporaires / sociaux calculés par le serveur
export type Bonus = {
	Friends: number?, -- nombre d'amis présents sur le serveur
	InGroup: boolean?, -- membre du groupe Roblox du jeu
	Boost: boolean?, -- boost "Argent x2" actif
}

function Economy.GetFriendBonus(friends: number): number
	local social = GameConfig.Social
	return math.min(friends * social.FriendBonusPerFriend, social.FriendBonusMax)
end

-- Multiplicateur global appliqué à tous les revenus du joueur
function Economy.GetGlobalMultiplier(data, passes: Passes, bonus: Bonus?): number
	local multiplier = Economy.GetRebirthMultiplier(data.Rebirths)
	multiplier *= 1 + Economy.GetIndexBonus(data)
	if passes.DoubleMoney then
		multiplier *= 2
	end
	if bonus then
		multiplier *= 1 + Economy.GetFriendBonus(bonus.Friends or 0)
		if bonus.InGroup then
			multiplier *= 1 + GameConfig.Social.GroupBonus
		end
		if bonus.Boost then
			multiplier *= GameConfig.Boosts.MoneyMultiplier
		end
	end
	return multiplier
end

-- Revenu de base (créatures seules, sans aucun multiplicateur)
function Economy.GetBaseIncome(data, excluded: { [string]: boolean }?): number
	local base = 0
	for _, entry in data.Creatures do
		if not (excluded and excluded[entry.Uid]) then
			base += Economy.GetCreatureIncome(entry)
		end
	end
	return base
end

-- Revenu total par seconde. "excluded" = Uids actuellement portés par un voleur
-- (une créature en cours de vol ne produit rien).
function Economy.GetIncomePerSecond(data, passes: Passes, excluded: { [string]: boolean }?, bonus: Bonus?): number
	return Economy.GetBaseIncome(data, excluded) * Economy.GetGlobalMultiplier(data, passes, bonus)
end

-- Argent gagné pendant une absence (revenu "de base" du joueur au moment de son départ)
function Economy.GetOfflineEarnings(incomePerSecond: number, secondsAway: number): number
	local config = GameConfig.Offline
	if secondsAway < config.MinSeconds or incomePerSecond <= 0 then
		return 0
	end
	local seconds = math.min(secondsAway, config.MaxHours * 3600)
	return math.floor(incomePerSecond * seconds * config.Rate)
end

-- Montant d'une récompense de type "Money" (format commun, voir GameConfig)
function Economy.GetRewardMoney(reward, rebirths: number, incomePerSecond: number): number
	local base = (reward.Base or 0) * (1 + rebirths)
	return math.floor(base + incomePerSecond * (reward.IncomeMinutes or 0) * 60)
end

-- Titre affiché au-dessus du joueur
function Economy.GetTitle(rebirths: number)
	local best = GameConfig.Titles[1]
	for _, title in GameConfig.Titles do
		if rebirths >= title.Rebirths then
			best = title
		end
	end
	return best
end

function Economy.GetMaxSlots(data, passes: Passes): number
	local slots = GameConfig.Slots.Base + data.Upgrades.Slots
	slots += math.min(data.Rebirths * GameConfig.Rebirth.SlotPerLevel, GameConfig.Rebirth.SlotBonusCap)
	if passes.VipSlots then
		slots += GameConfig.Slots.VipBonus
	end
	return math.min(slots, GameConfig.Slots.MaxPhysical)
end

-- Premier emplacement libre (1..MaxSlots) ou nil si la base est pleine
function Economy.FindFreeSlot(data, passes: Passes): number?
	local used = {}
	for _, entry in data.Creatures do
		used[entry.Slot] = true
	end
	for slot = 1, Economy.GetMaxSlots(data, passes) do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

function Economy.GetBarrierDuration(data, passes: Passes): number
	local config = GameConfig.Barrier
	local duration = config.BaseDuration + data.Upgrades.Barrier * config.DurationPerUpgrade
	if passes.LongBarrier then
		duration += config.PassBonus
	end
	return duration
end

function Economy.GetShortcutUseCost(incomePerSecond: number): number
	local config = GameConfig.Shortcut
	return math.floor(math.max(config.UseCostBase, incomePerSecond * config.UseCostIncomeSeconds))
end

-- day = jour du cycle (1..7)
function Economy.GetDailyReward(day: number, rebirths: number, incomePerSecond: number): number
	local rewards = GameConfig.Daily.Rewards
	local reward = rewards[((day - 1) % #rewards) + 1]
	return math.floor(reward.Base * (1 + rebirths) + incomePerSecond * reward.IncomeMinutes * 60)
end

function Economy.GetWalkSpeed(passes: Passes, carrying: boolean, victimAlarmLevel: number?): number
	local speed = GameConfig.Movement.BaseWalkSpeed
	if passes.Speed then
		speed *= GameConfig.Movement.SpeedPassMultiplier
	end
	if carrying then
		speed *= GameConfig.Steal.CarrySpeedMultiplier
		if victimAlarmLevel and victimAlarmLevel >= 3 then
			speed *= GameConfig.Steal.AlarmCarryMultiplier
		end
	end
	return speed
end

-- Jour UTC courant (entier) : base des récompenses quotidiennes
function Economy.GetUtcDay(unixTime: number): number
	return unixTime // 86400
end

return Economy
