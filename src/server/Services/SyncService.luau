--[[
	SyncService
	===========
	Envoie au client un INSTANTANÉ de ses données (créatures, améliorations,
	index...) quand elles changent. Les envois sont regroupés (au plus un toutes les
	0.15 s par joueur) pour éviter de saturer le réseau.

	Le client n'utilise ces données que pour l'AFFICHAGE : aucune décision n'est
	prise à partir de ce qu'il renvoie.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Modules.Economy)
local Remotes = require(Shared.Modules.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)

local SyncService = {}

local Services
local syncEvent: RemoteEvent
local pending: { [Player]: boolean } = {}

function SyncService.BuildSnapshot(player: Player)
	local data = Services.DataService.GetData(player)
	if not data then
		return nil
	end
	local passes = Services.MonetizationService.GetPasses(player)
	local carrying = Services.StealService.GetCarryPublicInfo(player)
	local carried = Services.StealService.GetCarriedUids(player)
	local carriedList = {}
	for uid in carried do
		table.insert(carriedList, uid)
	end

	return {
		Money = data.Money,
		TotalEarned = data.TotalEarned,
		Rebirths = data.Rebirths,
		Creatures = table.clone(data.Creatures),
		Upgrades = table.clone(data.Upgrades),
		ShortcutUnlocked = data.ShortcutUnlocked,
		Index = table.clone(data.Index),
		IndexClaimed = table.clone(data.IndexClaimed),
		Daily = table.clone(data.Daily),
		Stats = table.clone(data.Stats),
		Passes = passes,
		MaxSlots = Economy.GetMaxSlots(data, passes),
		IncomePerSecond = Services.IncomeService.GetIncome(player),
		BeingStolen = carriedList, -- mes créatures actuellement portées par un voleur
		Carrying = carrying, -- ce que JE porte (nil si rien)
		ShortcutReadyAt = Services.ShortcutService.GetReadyAt(player),
		ServerUtcDay = Economy.GetUtcDay(os.time()),
		ServerUnixTime = os.time(),
	}
end

-- Planifie un envoi (regroupé)
function SyncService.Push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.15, function()
		pending[player] = nil
		if player.Parent then
			local snapshot = SyncService.BuildSnapshot(player)
			if snapshot then
				syncEvent:FireClient(player, snapshot)
			end
		end
	end)
end

function SyncService.Init(services)
	Services = services
	syncEvent = Remotes.GetEvent("ProfileSync")
end

function SyncService.Start()
	Services.DataService.ProfileLoaded:Connect(function(player: Player)
		SyncService.Push(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
	end)

	-- Le client demande un instantané au démarrage (évite toute course au chargement)
	Guard.BindFunction("RequestSync", {}, function(player: Player)
		return true, nil, SyncService.BuildSnapshot(player)
	end)
end

return SyncService
