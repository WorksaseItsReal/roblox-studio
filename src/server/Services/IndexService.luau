--[[
	IndexService
	============
	Index de collection : chaque créature obtenue (achat, vol, fusion) est
	découverte. Par dimension, 2 récompenses :
	  Complete : toutes les créatures non secrètes  -> argent + bonus de revenus
	  Perfect  : toutes, Secrète comprise           -> gros bonus
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Dimensions = require(Shared.Config.Dimensions)
local Format = require(Shared.Modules.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)

local IndexService = {}

local Services

local TIERS = { "Complete", "Perfect" }

-- Vrai si le palier est atteint pour cette dimension
function IndexService.IsTierComplete(data, dimensionId: string, tier: string): boolean
	for _, def in Creatures.ByDimension[dimensionId] or {} do
		local required = tier == "Perfect" or def.Rarity ~= "Secret"
		if required and not data.Index[def.Id] then
			return false
		end
	end
	return true
end

function IndexService.Discover(player: Player, creatureId: string)
	local data = Services.DataService.GetData(player)
	if not data or data.Index[creatureId] then
		return
	end
	data.Index[creatureId] = true
	local def = Creatures.Get(creatureId)
	if not def then
		return
	end
	Services.NotificationService.Notify(player, "Nouvelle entrée dans l'index : " .. def.Name, "Info")
	for _, tier in TIERS do
		if
			IndexService.IsTierComplete(data, def.Dimension, tier)
			and not data.IndexClaimed[def.Dimension .. ":" .. tier]
		then
			local dimension = Dimensions.Get(def.Dimension)
			Services.NotificationService.Notify(
				player,
				"Index " .. (if dimension then dimension.Name else def.Dimension) .. " : récompense disponible !",
				"Success"
			)
		end
	end
	Services.SyncService.Push(player)
end

local function claim(player: Player, dimensionId: string, tier: string): (boolean, string?)
	local data = Services.DataService.GetData(player)
	local key = dimensionId .. ":" .. tier
	if data.IndexClaimed[key] then
		return false, "Récompense déjà réclamée."
	end
	if not IndexService.IsTierComplete(data, dimensionId, tier) then
		return false, "Collection incomplète."
	end
	local reward = GameConfig.Index.Rewards[tier]
	data.IndexClaimed[key] = true
	Services.IncomeService.AddMoney(player, reward.Money, true)
	Services.IncomeService.Recalculate(player) -- le bonus de revenus s'applique tout de suite
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)
	return true,
		string.format(
			"+%s et +%d %% de revenus permanents !",
			Format.Money(reward.Money),
			math.round(reward.IncomeBonus * 100)
		)
end

function IndexService.Init(services)
	Services = services
end

function IndexService.Start()
	Guard.BindFunction("ClaimIndexReward", { Args = { Guard.T.OneOf(Dimensions.Order), Guard.T.OneOf(TIERS) } }, claim)
end

return IndexService
