--[[
	UpgradeService
	==============
	Améliorations de base (emplacements, barrière, alarme), payées en argent du
	jeu. Coûts dans Config/Upgrades. Conservées après un rebirth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Format = require(Shared.Modules.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)

local UpgradeService = {}

local Services

local UPGRADE_IDS = {}
for _, upgrade in Upgrades.List do
	table.insert(UPGRADE_IDS, upgrade.Id)
end

local function buyUpgrade(player: Player, upgradeId: string): (boolean, string?)
	local data = Services.DataService.GetData(player)
	local upgrade = Upgrades.Get(upgradeId)
	if not upgrade then
		return false, "Amélioration inconnue."
	end
	local level = data.Upgrades[upgradeId] or 0
	local cost = Upgrades.GetCost(upgradeId, level)
	if not cost then
		return false, "Niveau maximum atteint."
	end
	if not Services.IncomeService.TrySpend(player, cost) then
		return false, "Il te faut " .. Format.Money(cost) .. "."
	end

	data.Upgrades[upgradeId] = level + 1
	if upgradeId == "Slots" then
		Services.PlotService.RefreshSlotPads(player)
	end
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)
	return true, string.format("%s : niveau %d !", upgrade.Name, level + 1)
end

function UpgradeService.Init(services)
	Services = services
end

function UpgradeService.Start()
	Guard.BindFunction("BuyUpgrade", { Args = { Guard.T.OneOf(UPGRADE_IDS) } }, buyUpgrade)
end

return UpgradeService
