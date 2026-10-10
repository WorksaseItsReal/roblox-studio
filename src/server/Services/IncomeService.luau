--[[
	IncomeService
	=============
	Seul endroit qui modifie l'argent des joueurs.
	- Boucle de revenus : toutes les secondes, chaque joueur reçoit son revenu/s.
	- Revenu mis en cache, recalculé uniquement quand quelque chose change
	  (achat, vol, fusion, rebirth, gamepass, index...).
	- AddMoney / TrySpend : utilisés par tous les autres services.

	L'argent est répliqué au client via l'attribut "Money" du Player (léger,
	automatique) ; le reste des données passe par SyncService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)

local IncomeService = {}

local Services

local incomeCache: { [Player]: number } = {}

local function publish(player: Player, data)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("TotalEarned", data.TotalEarned)
	Services.LeaderboardService.UpdateLeaderstats(player)
end

function IncomeService.Recalculate(player: Player): number
	local data = Services.DataService.GetData(player)
	if not data then
		incomeCache[player] = nil
		return 0
	end
	local passes = Services.MonetizationService.GetPasses(player)
	local excluded = Services.StealService.GetCarriedUids(player)
	local income = Economy.GetIncomePerSecond(data, passes, excluded)
	incomeCache[player] = income
	player:SetAttribute("IncomePerSecond", income)
	return income
end

function IncomeService.GetIncome(player: Player): number
	return incomeCache[player] or IncomeService.Recalculate(player)
end

-- countsAsEarned : true pour l'argent "gagné" (classement), false pour un remboursement
function IncomeService.AddMoney(player: Player, amount: number, countsAsEarned: boolean?)
	local data = Services.DataService.GetData(player)
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.Money += amount
	if countsAsEarned ~= false then
		data.TotalEarned += amount
	end
	publish(player, data)
end

-- Débite si le joueur a assez d'argent. Renvoie true si le paiement a eu lieu.
function IncomeService.TrySpend(player: Player, amount: number): boolean
	local data = Services.DataService.GetData(player)
	if not data or amount ~= amount or amount < 0 then
		return false
	end
	if data.Money < amount then
		return false
	end
	data.Money -= amount
	publish(player, data)
	return true
end

-- Réinitialisation (rebirth)
function IncomeService.SetMoney(player: Player, amount: number)
	local data = Services.DataService.GetData(player)
	if not data then
		return
	end
	data.Money = amount
	publish(player, data)
end

function IncomeService.Init(services)
	Services = services
end

function IncomeService.Start()
	Services.DataService.ProfileLoaded:Connect(function(player: Player, profile)
		IncomeService.Recalculate(player)
		publish(player, profile.Data)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		incomeCache[player] = nil
	end)

	task.spawn(function()
		local tick = GameConfig.Economy.IncomeTickSeconds
		while true do
			local elapsed = task.wait(tick)
			-- On paie le temps réellement écoulé (si le serveur ralentit, rien n'est perdu)
			local dt = math.min(elapsed, tick * 3)
			for _, player in Services.DataService.GetLoadedPlayers() do
				local income = IncomeService.GetIncome(player)
				if income > 0 then
					IncomeService.AddMoney(player, income * dt, true)
				end
			end
		end
	end)
end

return IncomeService
