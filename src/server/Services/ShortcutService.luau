--[[
	ShortcutService
	===============
	Portail de raccourci : déblocage unique (argent du jeu), puis chaque
	utilisation coûte max(1000$, 30 s de revenus) avec une recharge de 120 s.
	Le joueur est téléporté DEVANT la base visée (hors barrière) et le
	propriétaire reçoit une alerte. Interdit en portant une créature volée.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)

local ShortcutService = {}

local Services
local readyAt: { [Player]: number } = {}

function ShortcutService.GetReadyAt(player: Player): number
	return readyAt[player] or 0
end

local function unlock(player: Player): (boolean, string?)
	local data = Services.DataService.GetData(player)
	if data.ShortcutUnlocked then
		return false, "Portail de raccourci déjà débloqué."
	end
	local cost = GameConfig.Shortcut.UnlockCost
	if not Services.IncomeService.TrySpend(player, cost) then
		return false, "Il te faut " .. Format.Money(cost) .. "."
	end
	data.ShortcutUnlocked = true
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)
	return true, "Portail de raccourci débloqué !"
end

local function use(player: Player, targetUserId: number): (boolean, string?)
	local data = Services.DataService.GetData(player)
	if not data.ShortcutUnlocked then
		return false, "Débloque d'abord le portail de raccourci."
	end
	local now = workspace:GetServerTimeNow()
	if now < ShortcutService.GetReadyAt(player) then
		return false, "Recharge : " .. Format.Time(ShortcutService.GetReadyAt(player) - now)
	end
	if Services.StealService.IsCarrying(player) then
		return false, "Impossible en portant une créature."
	end
	if not Services.CharacterService.IsAlive(player) then
		return false, "Tu dois être en vie."
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "Cible invalide."
	end
	local plot = Services.PlotService.GetPlot(target)
	if not plot then
		return false, "Ce joueur n'a pas de base."
	end

	local cost = Economy.GetShortcutUseCost(Services.IncomeService.GetIncome(player))
	if not Services.IncomeService.TrySpend(player, cost) then
		return false, "Il te faut " .. Format.Money(cost) .. "."
	end

	readyAt[player] = now + GameConfig.Shortcut.Cooldown
	local landing = plot.ShortcutLanding
	local offset = Vector3.new(math.random(-3, 3), 4, math.random(-3, 3))
	Services.CharacterService.TeleportTo(player, CFrame.new(landing.Position + offset) * landing.CFrame.Rotation)

	Services.NotificationService.Effect(nil, "Teleport", { Position = landing.Position })
	Services.NotificationService.Notify(
		target,
		"Portail ouvert : " .. player.DisplayName .. " arrive devant ta base !",
		"Warning"
	)
	Services.SyncService.Push(player)
	return true, "Téléporté devant la base de " .. target.DisplayName .. " (" .. Format.Money(cost) .. ")"
end

function ShortcutService.Init(services)
	Services = services
end

function ShortcutService.Start()
	Guard.BindFunction("UnlockShortcut", {}, unlock)
	Guard.BindFunction("UseShortcut", { Args = { Guard.T.Integer(1, 2 ^ 53) } }, use)
	Players.PlayerRemoving:Connect(function(player: Player)
		readyAt[player] = nil
	end)
end

return ShortcutService
