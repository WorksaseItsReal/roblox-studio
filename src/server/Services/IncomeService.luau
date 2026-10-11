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

	Le revenu est recalculé à chaque versement (calcul très léger) : les bonus
	temporaires (boost x2, amis présents) s'appliquent et expirent sans aucune
	invalidation de cache à gérer.

	Gains hors ligne : à chaque versement on mémorise LastSeen / LastIncome
	(revenu de base, sans bonus temporaires) ; à la connexion suivante le joueur
	touche Offline.Rate x ce revenu pendant son absence (plafonnée).
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

-- Bonus temporaires et sociaux du joueur (amis, groupe, boost x2)
function IncomeService.GetBonus(player: Player, data)
	local bonus = Services.SocialBonusService.GetBonus(player)
	bonus.Boost = (data.Boosts.MoneyUntil or 0) > os.time()
	return bonus
end

function IncomeService.Recalculate(player: Player): number
	local data = Services.DataService.GetData(player)
	if not data then
		incomeCache[player] = nil
		return 0
	end
	local passes = Services.MonetizationService.GetPasses(player)
	local excluded = Services.StealService.GetCarriedUids(player)
	local income = Economy.GetIncomePerSecond(data, passes, excluded, IncomeService.GetBonus(player, data))
	if incomeCache[player] ~= income then
		player:SetAttribute("IncomePerSecond", income)
	end
	incomeCache[player] = income
	return income
end

-- Revenu "de base" (sans bonus temporaires) : sert aux gains hors ligne
local function getBaseIncome(player: Player, data): number
	return Economy.GetIncomePerSecond(data, Services.MonetizationService.GetPasses(player))
end

local function grantOfflineEarnings(player: Player, data)
	local lastSeen = tonumber(data.LastSeen) or 0
	if lastSeen <= 0 then
		return
	end
	local away = os.time() - lastSeen
	local amount = Economy.GetOfflineEarnings(tonumber(data.LastIncome) or 0, away)
	if amount <= 0 then
		return
	end
	IncomeService.AddMoney(player, amount, true)
	-- Laisse le temps au client de charger son interface avant la fenêtre de bienvenue
	task.delay(3, function()
		if player.Parent then
			Services.NotificationService.Effect(player, "OfflineEarnings", {
				Amount = amount,
				Seconds = math.min(away, GameConfig.Offline.MaxHours * 3600),
			})
		end
	end)
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
		-- Avant tout versement : LastSeen est encore celui de la session précédente
		grantOfflineEarnings(player, profile.Data)
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
			local now = os.time()
			for _, player in Services.DataService.GetLoadedPlayers() do
				local data = Services.DataService.GetData(player)
				if data then
					local income = IncomeService.Recalculate(player)
					if income > 0 then
						IncomeService.AddMoney(player, income * dt, true)
					end
					data.LastSeen = now
					data.LastIncome = getBaseIncome(player, data)
				end
			end
		end
	end)
end

return IncomeService
