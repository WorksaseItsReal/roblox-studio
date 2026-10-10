--[[
	DailyRewardService
	==================
	Récompense quotidienne (jour UTC, horloge SERVEUR uniquement : changer l'heure
	de son PC ne sert à rien). Série de 7 jours ; un jour manqué remet la série à 1.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)

local DailyRewardService = {}

local Services

local function claim(player: Player): (boolean, string?)
	local data = Services.DataService.GetData(player)
	local today = Economy.GetUtcDay(os.time())
	if data.Daily.LastDay == today then
		local secondsLeft = (today + 1) * 86400 - os.time()
		return false, "Reviens dans " .. Format.Time(secondsLeft) .. "."
	end

	local streak = if data.Daily.LastDay == today - 1 then data.Daily.Streak + 1 else 1
	local reward = Economy.GetDailyReward(streak, data.Rebirths, Services.IncomeService.GetIncome(player))
	data.Daily.LastDay = today
	data.Daily.Streak = streak
	Services.IncomeService.AddMoney(player, reward, true)
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)
	return true, string.format("Jour %d : +%s !", streak, Format.Money(reward))
end

function DailyRewardService.Init(services)
	Services = services
end

function DailyRewardService.Start()
	Guard.BindFunction("ClaimDaily", {}, claim)
	Services.DataService.ProfileLoaded:Connect(function(player: Player, profile)
		if profile.Data.Daily.LastDay ~= Economy.GetUtcDay(os.time()) then
			task.delay(4, function()
				if player.Parent then
					Services.NotificationService.Notify(
						player,
						"Ta récompense quotidienne est disponible !",
						"Success"
					)
				end
			end)
		end
	end)
end

return DailyRewardService
