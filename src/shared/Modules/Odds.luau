--[[
	Odds
	====
	Calcul des probabilités d'apparition sur le chemin de la Rift.
	Partagé : le serveur l'utilise pour TIRER les créatures, le client pour AFFICHER
	les chances exactes (index, boutique). Afficher les probabilités est requis par
	les règles Roblox dès qu'un achat Robux (pack de chance) influence un tirage.

	Tirage en 2 étapes :
	 1. Rareté : poids de base x multiplicateur de dimension x chance (Épique et +)
	 2. Créature : 85 % parmi la dimension active, 15 % "fuite" parmi toutes les
	    dimensions (GameConfig.Rift.CrossDimensionChance)
]]

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Dimensions = require(Shared.Config.Dimensions)
local Creatures = require(Shared.Config.Creatures)

local Odds = {}

-- Poids (non normalisés) par rareté pour une dimension et un multiplicateur de chance
function Odds.GetRarityWeights(dimensionId: string, luck: number): { [string]: number }
	local dimension = Dimensions.Get(dimensionId)
	local multipliers = if dimension then dimension.RarityMultipliers else {}
	local weights = {}
	for _, rarity in Rarities.List do
		local weight = rarity.Weight * (multipliers[rarity.Id] or 1)
		if rarity.LuckAffected then
			weight *= luck
		end
		-- Une rareté sans aucune créature disponible ne peut pas sortir
		if weight > 0 and Creatures.ByRarity[rarity.Id] and #Creatures.ByRarity[rarity.Id] > 0 then
			weights[rarity.Id] = weight
		end
	end
	return weights
end

-- Liste ordonnée { {Rarity, Chance} } (Chance entre 0 et 1) pour l'affichage
function Odds.GetRarityChances(dimensionId: string, luck: number): { { Rarity: any, Chance: number } }
	local weights = Odds.GetRarityWeights(dimensionId, luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local result = {}
	for _, rarity in Rarities.List do
		local weight = weights[rarity.Id]
		if weight then
			table.insert(result, { Rarity = rarity, Chance = weight / total })
		end
	end
	return result
end

function Odds.RollRarity(dimensionId: string, luck: number, rng: Random): string
	local weights = Odds.GetRarityWeights(dimensionId, luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	-- Parcours dans l'ordre de Rarities.List pour un résultat déterministe
	local last = "Common"
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

-- Pools utilisés à l'étape 2
local function getPools(dimensionId: string, rarityId: string)
	local byDim = Creatures.ByDimensionAndRarity[dimensionId]
	local local_ = (byDim and byDim[rarityId]) or {}
	local global = Creatures.ByRarity[rarityId] or {}
	return local_, global
end

function Odds.PickCreature(dimensionId: string, rarityId: string, rng: Random)
	local localPool, globalPool = getPools(dimensionId, rarityId)
	local useGlobal = #localPool == 0 or rng:NextNumber() < GameConfig.Rift.CrossDimensionChance
	local pool = if useGlobal then globalPool else localPool
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- Chance qu'une apparition donnée soit cette créature précise (pour l'index)
function Odds.GetCreatureChance(dimensionId: string, luck: number, creatureId: string): number
	local def = Creatures.Get(creatureId)
	if not def then
		return 0
	end
	local weights = Odds.GetRarityWeights(dimensionId, luck)
	local weight = weights[def.Rarity]
	if not weight then
		return 0
	end
	local total = 0
	for _, w in weights do
		total += w
	end
	local rarityChance = weight / total

	local localPool, globalPool = getPools(dimensionId, def.Rarity)
	local cross = if #localPool == 0 then 1 else GameConfig.Rift.CrossDimensionChance
	local chance = rarityChance * cross / #globalPool
	if table.find(localPool, def) then
		chance += rarityChance * (1 - cross) / #localPool
	end
	return chance
end

return Odds
