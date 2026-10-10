--[[
	GameConfig
	==========
	Tous les réglages d'équilibrage et de gameplay de "Steal a Rift" au même endroit.
	Ce module est partagé (ReplicatedStorage) : le client l'utilise pour AFFICHER des
	valeurs (coûts, timers...), mais seul le serveur les applique. Modifier ce fichier
	côté client (exploit) ne change donc rien au jeu réel.

	Toutes les durées sont en secondes, toutes les distances en studs.
]]

local GameConfig = {}

-- Nom affiché dans l'UI
GameConfig.GameName = "Steal a Rift"

---------------------------------------------------------------------------
-- Économie
---------------------------------------------------------------------------
GameConfig.Economy = {
	StartingMoney = 100, -- argent de départ (et après un rebirth)
	IncomeTickSeconds = 1, -- fréquence de versement des revenus
	SellRefundRatio = 0.5, -- revente = 50 % du prix d'achat x multiplicateur de mutation
}

---------------------------------------------------------------------------
-- Emplacements de base
---------------------------------------------------------------------------
GameConfig.Slots = {
	Base = 8, -- emplacements de départ
	MaxPhysical = 28, -- nombre d'emplacements construits physiquement dans chaque base
	VipBonus = 3, -- bonus du gamepass "Emplacements VIP"
}

---------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------
GameConfig.Rebirth = {
	BaseCost = 1_000_000, -- coût du 1er rebirth
	CostGrowth = 4, -- chaque rebirth coûte x4 le précédent
	MultiplierPerLevel = 0.5, -- +50 % de revenus permanents par rebirth
	SlotPerLevel = 1, -- +1 emplacement par rebirth...
	SlotBonusCap = 5, -- ...plafonné à +5
}

---------------------------------------------------------------------------
-- La Rift (spawns sur le chemin + cycle de dimensions)
---------------------------------------------------------------------------
GameConfig.Rift = {
	DimensionDurationSeconds = 300, -- changement de dimension toutes les 5 min
	FirstDimension = "Lava",
	SpawnIntervalSeconds = 3.5, -- intervalle moyen entre deux créatures
	MaxActiveSpawns = 24, -- plafond de créatures simultanées sur le chemin
	CreatureWalkSpeed = 7, -- vitesse sur le chemin (studs/s)
	CrossDimensionChance = 0.15, -- 15 % de "fuites" : créature d'une autre dimension
	WalkToBaseSpeed = 16, -- vitesse de la créature achetée qui rejoint la base
}

---------------------------------------------------------------------------
-- Portails instables (créatures Secrètes)
---------------------------------------------------------------------------
GameConfig.UnstablePortal = {
	CheckIntervalSeconds = 30, -- on tente l'apparition toutes les 30 s...
	ChancePerCheck = 0.04, -- ...avec 4 % de chance
	MinGapSeconds = 240, -- au moins 4 min entre deux portails instables
	PortalLifetime = 10, -- durée de vie du portail doré
	SecretWalkSpeedMultiplier = 0.6, -- la Secrète marche plus lentement : course pour l'atteindre
}

---------------------------------------------------------------------------
-- Achat
---------------------------------------------------------------------------
GameConfig.Purchase = {
	MaxBuyDistance = 18, -- distance max joueur <-> créature pour acheter
	LatencyAllowanceSeconds = 0.6, -- tolérance réseau (la créature bouge pendant le ping)
}

---------------------------------------------------------------------------
-- Vol
---------------------------------------------------------------------------
GameConfig.Steal = {
	HoldDuration = 1.5, -- temps d'appui sur le prompt "Voler"
	MaxStealDistance = 14, -- distance max pour commencer un vol
	CarrySpeedMultiplier = 0.7, -- le voleur est ralenti quand il porte une créature
	AlarmCarryMultiplier = 0.85, -- ralentissement supplémentaire (alarme niveau 3 de la victime)
	MaxCarrySeconds = 90, -- au-delà, la créature retourne chez son propriétaire
	RecoverDistance = 7, -- le propriétaire touche le voleur => récupération
	SpeedTolerance = 1.75, -- tolérance anti-téléportation (x vitesse de marche)
	SpeedFlatAllowance = 12, -- studs/s supplémentaires tolérés (poussées physiques, lag)
	AnnounceMinTier = 4, -- annonce globale à partir de Légendaire (Tier 4)
}

---------------------------------------------------------------------------
-- Barrière (verrou de base)
---------------------------------------------------------------------------
GameConfig.Barrier = {
	BaseDuration = 60,
	DurationPerUpgrade = 10,
	PassBonus = 30, -- gamepass "Barrière longue"
	Cooldown = 90, -- recharge APRÈS la fin de la barrière
}

---------------------------------------------------------------------------
-- Alarme anti-vol (niveaux d'amélioration)
---------------------------------------------------------------------------
GameConfig.Alarm = {
	ScanIntervalSeconds = 0.5,
	-- Niveau 1 : notification quand un intrus entre
	-- Niveau 2 : + l'intrus est surligné pour le propriétaire
	-- Niveau 3 : + le voleur est encore plus ralenti
	HighlightSeconds = 8,
}

---------------------------------------------------------------------------
-- Portail de raccourci
---------------------------------------------------------------------------
GameConfig.Shortcut = {
	UnlockCost = 25_000, -- achat unique (argent du jeu)
	UseCostBase = 1_000, -- coût minimum par utilisation
	UseCostIncomeSeconds = 30, -- ...ou 30 s de revenus si c'est plus cher
	Cooldown = 120,
}

---------------------------------------------------------------------------
-- Fusion
---------------------------------------------------------------------------
GameConfig.Fusion = {
	MaxDistance = 18, -- le joueur doit être au portail de fusion de SA base
}

---------------------------------------------------------------------------
-- Récompenses quotidiennes (cycle de 7 jours, jour UTC)
---------------------------------------------------------------------------
GameConfig.Daily = {
	-- Récompense = Base x (1 + rebirths) + revenu/s x IncomeMinutes x 60
	Rewards = {
		{ Base = 250, IncomeMinutes = 1 },
		{ Base = 500, IncomeMinutes = 2 },
		{ Base = 1_000, IncomeMinutes = 3 },
		{ Base = 2_500, IncomeMinutes = 5 },
		{ Base = 5_000, IncomeMinutes = 7 },
		{ Base = 10_000, IncomeMinutes = 10 },
		{ Base = 25_000, IncomeMinutes = 15 },
	},
}

---------------------------------------------------------------------------
-- Index (collection)
---------------------------------------------------------------------------
GameConfig.Index = {
	-- "Complete" = toutes les créatures NON secrètes d'une dimension
	-- "Perfect"  = toutes, Secrète comprise
	Rewards = {
		Complete = { Money = 25_000, IncomeBonus = 0.05 },
		Perfect = { Money = 1_000_000, IncomeBonus = 0.10 },
	},
}

---------------------------------------------------------------------------
-- Déplacements
---------------------------------------------------------------------------
GameConfig.Movement = {
	BaseWalkSpeed = 16,
	SpeedPassMultiplier = 1.5,
}

---------------------------------------------------------------------------
-- Classement global
---------------------------------------------------------------------------
GameConfig.Leaderboard = {
	MoneyStoreName = "StealARift_TotalEarned_v1",
	StealsStoreName = "StealARift_Steals_v1",
	RefreshSeconds = 120, -- relecture du top
	PushSeconds = 300, -- écriture du score de chaque joueur
	Size = 25,
}

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------
GameConfig.Data = {
	StoreName = "StealARift_PlayerData_v1",
	KeyPrefix = "Player_",
	AutosaveSeconds = 60,
	LockStaleSeconds = 600, -- un verrou de session plus vieux est considéré comme orphelin (crash)
	LoadAttempts = 6, -- tentatives si la session est encore ouverte sur un autre serveur
	LoadRetryDelay = 4,
	MaxReceiptHistory = 50,
}

---------------------------------------------------------------------------
-- Limites de requêtes (token bucket : Rate jetons/s, Burst = capacité)
---------------------------------------------------------------------------
GameConfig.RateLimits = {
	Default = { Rate = 2, Burst = 5 },
	BuyCreature = { Rate = 3, Burst = 6 },
	SellCreature = { Rate = 3, Burst = 6 },
	FuseCreatures = { Rate = 1, Burst = 3 },
	ActivateBarrier = { Rate = 0.5, Burst = 2 },
	BuyUpgrade = { Rate = 2, Burst = 4 },
	Rebirth = { Rate = 0.2, Burst = 1 },
	ClaimDaily = { Rate = 0.5, Burst = 2 },
	ClaimIndexReward = { Rate = 1, Burst = 3 },
	UnlockShortcut = { Rate = 0.5, Burst = 2 },
	UseShortcut = { Rate = 0.5, Burst = 2 },
	SetDimensionChoice = { Rate = 1, Burst = 3 },
	GetLeaderboard = { Rate = 0.5, Burst = 3 },
	RequestSync = { Rate = 1, Burst = 3 },
	StealPrompt = { Rate = 1, Burst = 3 },
}

---------------------------------------------------------------------------
-- Debug (Studio uniquement, ignoré en jeu publié)
---------------------------------------------------------------------------
GameConfig.Debug = {
	GrantAllPassesInStudio = false, -- simule la possession de tous les gamepasses
	FastUnstablePortals = false, -- portail instable toutes les ~40 s en Studio
	StudioStartingMoney = nil, -- ex: 1e7 pour tester rapidement (nil = désactivé)
}

return GameConfig
