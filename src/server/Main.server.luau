--[[
	Steal a Rift — point d'entrée serveur
	=====================================
	1. Crée les Remotes.
	2. Init() de chaque service (références croisées, aucune boucle lancée).
	3. Start() de chaque service (connexions, boucles).

	Les services se référencent via la table "Services" injectée dans Init : pas
	de require circulaires.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Guard = require(script.Parent.Lib.Guard)

Remotes.SetupServer()

local ServicesFolder = script.Parent.Services

-- Ordre d'initialisation : MapService et DataService d'abord
local ORDER = {
	"MapService",
	"DataService",
	"NotificationService",
	"MonetizationService",
	"PlotService",
	"CharacterService",
	"IncomeService",
	"SyncService",
	"RiftService",
	"ShopService",
	"StealService",
	"BaseDefenseService",
	"FusionService",
	"ShortcutService",
	"UpgradeService",
	"RebirthService",
	"IndexService",
	"DailyRewardService",
	"LeaderboardService",
}

local Services = {}
for _, name in ORDER do
	Services[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	Services[name].Init(Services)
end

Guard.IsReady = Services.DataService.IsLoaded

-- DataService démarre EN DERNIER : tous les services sont alors abonnés à
-- ProfileLoaded avant que le premier profil ne soit chargé.
for _, name in ORDER do
	if name ~= "DataService" then
		Services[name].Start()
	end
end
Services.DataService.Start()

print("[Steal a Rift] Serveur prêt")
