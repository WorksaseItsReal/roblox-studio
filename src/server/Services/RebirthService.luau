--[[
	RebirthService
	==============
	Rebirth : remet l'argent au départ et vide les créatures, en échange d'un
	multiplicateur permanent (+50 % / rebirth) et d'emplacements bonus (+1, max +5).
	Conservés : améliorations, index, récompenses d'index, raccourci, gamepasses, stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)

local RebirthService = {}

local Services

local function rebirth(player: Player): (boolean, string?)
	local data = Services.DataService.GetData(player)
	local cost = Economy.GetRebirthCost(data.Rebirths)
	if data.Money < cost then
		return false, "Il te faut " .. Format.Money(cost) .. " pour renaître."
	end
	if Services.StealService.IsCarrying(player) then
		return false, "Dépose d'abord la créature que tu portes."
	end

	-- Les vols en cours sur ses créatures sont annulés (elles vont disparaître)
	Services.StealService.CancelForVictim(player, player.DisplayName .. " a fait un rebirth : le vol est annulé.")

	data.Rebirths += 1
	data.Creatures = {}
	Services.IncomeService.SetMoney(player, GameConfig.Economy.StartingMoney)

	Services.PlotService.RenderAll(player)
	Services.IncomeService.Recalculate(player)
	Services.CharacterService.RefreshSpeed(player)
	Services.SyncService.Push(player)
	Services.LeaderboardService.UpdateLeaderstats(player)
	Services.DataService.SaveSoon(player)

	Services.NotificationService.Announce(
		player.DisplayName .. " renaît !",
		string.format("Rebirth %d : revenus x%.1f", data.Rebirths, Economy.GetRebirthMultiplier(data.Rebirths)),
		Color3.fromRGB(255, 120, 255)
	)
	return true, "Rebirth réussi !"
end

function RebirthService.Init(services)
	Services = services
end

function RebirthService.Start()
	Guard.BindFunction("Rebirth", {}, rebirth)
end

return RebirthService
