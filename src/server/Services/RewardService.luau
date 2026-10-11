--[[
	RewardService
	=============
	Point unique d'attribution des récompenses (cadeaux de session, quêtes,
	codes, tutoriel). Format commun décrit dans GameConfig (section Récompenses) :
	  Money    : argent (base x (1 + rebirths) + minutes de revenus)
	  Boost    : Argent x2 temporaire (cumulable, plafonné)
	  Creature : créature tirée selon des poids de rareté (ou un Id précis),
	             posée directement dans la base ; base pleine = convertie en argent
	  Bundle   : plusieurs récompenses

	Grant renvoie un texte lisible ("+$12K, Argent x2 5:00...") pour l'UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)

local RewardService = {}

local Services
local rng = Random.new()

-- Tirage d'une rareté selon des poids { Rare = 70, Epic = 30 }
local function rollRarity(weights: { [string]: number }): string?
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	-- Ordre stable : on parcourt les raretés dans l'ordre officiel
	local last = nil
	for _, rarity in Rarities.List do
		local weight = weights[rarity.Id]
		if weight then
			last = rarity.Id
			roll -= weight
			if roll <= 0 then
				return rarity.Id
			end
		end
	end
	return last
end

local function pickCreature(reward): any
	if reward.Id then
		return Creatures.Get(reward.Id)
	end
	local rarityId = rollRarity(reward.Rarities or { Common = 1 })
	local pool = rarityId and Creatures.ByRarity[rarityId]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- Ajoute directement une créature dans la base du joueur. Renvoie un texte.
function RewardService.GiveCreature(player: Player, def, mutation: string?): string
	local data = Services.DataService.GetData(player)
	local slot = Economy.FindFreeSlot(data, Services.MonetizationService.GetPasses(player))
	if not slot then
		local value = def.Price
		Services.IncomeService.AddMoney(player, value, true)
		return string.format("%s (base pleine : convertie en %s)", def.Name, Format.Money(value))
	end
	local entry = {
		Uid = Services.DataService.NewUid(data),
		Id = def.Id,
		Mutation = mutation or Mutations.None,
		Slot = slot,
	}
	table.insert(data.Creatures, entry)
	Services.PlotService.AddCreatureModel(player, entry.Uid)
	Services.IndexService.Discover(player, def.Id)
	Services.IncomeService.Recalculate(player)

	local rarity = Rarities.Get(def.Rarity)
	Services.NotificationService.Effect(player, "Celebrate", {
		Color = if rarity then rarity.Color else Color3.new(1, 1, 1),
		Text = def.Name,
	})
	if rarity and rarity.Tier >= 4 then
		Services.NotificationService.Feed(
			string.format("%s a obtenu %s (%s) !", player.DisplayName, def.Name, rarity.Name),
			rarity.Color,
			"🎁"
		)
	end
	return def.Name .. (if rarity then " (" .. rarity.Name .. ")" else "")
end

function RewardService.AddBoost(player: Player, seconds: number)
	local data = Services.DataService.GetData(player)
	local now = os.time()
	local current = math.max(now, data.Boosts.MoneyUntil or 0)
	data.Boosts.MoneyUntil = math.min(current + seconds, now + GameConfig.Boosts.MaxStackSeconds)
	Services.IncomeService.Recalculate(player)
end

-- Attribue une récompense. Renvoie le texte du gain.
function RewardService.Grant(player: Player, reward): string
	local data = Services.DataService.GetData(player)
	if not data or type(reward) ~= "table" then
		return ""
	end
	local text = ""
	if reward.Type == "Money" then
		local amount = Economy.GetRewardMoney(reward, data.Rebirths, Services.IncomeService.GetIncome(player))
		Services.IncomeService.AddMoney(player, amount, true)
		text = "+" .. Format.Money(amount)
	elseif reward.Type == "Boost" then
		RewardService.AddBoost(player, reward.Seconds or 300)
		text = string.format(
			"Argent x%d pendant %s",
			GameConfig.Boosts.MoneyMultiplier,
			Format.Time(reward.Seconds or 300)
		)
	elseif reward.Type == "Creature" then
		local def = pickCreature(reward)
		if def then
			text = RewardService.GiveCreature(player, def, reward.Mutation)
		end
	elseif reward.Type == "Bundle" then
		local parts = {}
		for _, inner in reward.Rewards or {} do
			local innerText = RewardService.Grant(player, inner)
			if innerText ~= "" then
				table.insert(parts, innerText)
			end
		end
		text = table.concat(parts, " • ")
	end
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)
	return text
end

-- Texte d'aperçu (sans rien attribuer) pour l'UI côté serveur si besoin
function RewardService.Describe(reward, rebirths: number, income: number): string
	if reward.Type == "Money" then
		return "+" .. Format.Money(Economy.GetRewardMoney(reward, rebirths, income))
	elseif reward.Type == "Boost" then
		return string.format("Argent x%d %s", GameConfig.Boosts.MoneyMultiplier, Format.Time(reward.Seconds or 300))
	elseif reward.Type == "Creature" then
		return "Créature mystère"
	elseif reward.Type == "Bundle" then
		local parts = {}
		for _, inner in reward.Rewards or {} do
			table.insert(parts, RewardService.Describe(inner, rebirths, income))
		end
		return table.concat(parts, " + ")
	end
	return ""
end

function RewardService.Init(services)
	Services = services
end

function RewardService.Start() end

return RewardService
