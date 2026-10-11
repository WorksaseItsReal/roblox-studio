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
	-- Vitesse sur le chemin (studs/s). Le tapis droit fait ~385 studs : à 5 studs/s une
	-- créature reste ~77 s visible (comme l'ancien anneau de ~545 studs à 7), soit
	-- ~22 créatures à la fois avec un spawn toutes les 3,5 s (sous MaxActiveSpawns).
	CreatureWalkSpeed = 5,
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
	TeleportCooldown = 5, -- secondes entre deux téléportations rapides (boutons Rift / Ma base)
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
	ClaimQuest = { Rate = 1, Burst = 4 },
	ClaimGift = { Rate = 1, Burst = 4 },
	RedeemCode = { Rate = 0.3, Burst = 3 }, -- strict : empêche de tester des codes en masse
	CompleteTutorial = { Rate = 0.2, Burst = 2 },
	Teleport = { Rate = 0.5, Burst = 2 },
}

---------------------------------------------------------------------------
-- Gains hors ligne : les créatures continuent de produire pendant l'absence
---------------------------------------------------------------------------
GameConfig.Offline = {
	Rate = 0.5, -- 50 % du revenu de base
	MaxHours = 8, -- plafond (incite à revenir au moins une fois par jour)
	MinSeconds = 120, -- en dessous : rien (pas de farm par reconnexion)
}

---------------------------------------------------------------------------
-- Bonus sociaux (moteur de viralité : jouer avec ses amis rapporte plus)
---------------------------------------------------------------------------
GameConfig.Social = {
	FriendBonusPerFriend = 0.10, -- +10 % de revenus par ami présent sur le serveur...
	FriendBonusMax = 0.50, -- ...plafonné à +50 %
	GroupId = 0, -- Id de ton groupe Roblox (0 = désactivé)
	GroupBonus = 0.10, -- +10 % de revenus pour les membres du groupe
}

---------------------------------------------------------------------------
-- Boosts personnels (gagnés via cadeaux, quêtes, codes)
---------------------------------------------------------------------------
GameConfig.Boosts = {
	MoneyMultiplier = 2, -- "Argent x2" temporaire
	MaxStackSeconds = 3600, -- cumul maximum
}

---------------------------------------------------------------------------
-- Tempête de la Rift : événement GLOBAL synchronisé sur l'heure UTC
-- (tous les serveurs en même temps => pics de joueurs, moments à partager)
---------------------------------------------------------------------------
GameConfig.Storm = {
	IntervalMinutes = 60, -- une tempête par heure...
	OffsetMinutes = 30, -- ...à HH:30 UTC
	DurationSeconds = 240,
	WarnSeconds = 300, -- annonce 5 minutes avant
	LuckMultiplier = 3, -- chance x3 (cumulée avec le pack de chance)
	SpawnIntervalMultiplier = 0.45, -- ~2x plus de créatures
	GuaranteedPortal = true, -- un portail doré s'ouvre au début de chaque tempête
}

---------------------------------------------------------------------------
-- Vengeance : après un vol, la victime peut se téléporter gratuitement chez le voleur
---------------------------------------------------------------------------
GameConfig.Revenge = {
	WindowSeconds = 90,
}

---------------------------------------------------------------------------
-- Récompenses (format commun aux cadeaux, quêtes, codes, tutoriel)
--   { Type = "Money", Base = n, IncomeMinutes = m }  -> Base x (1 + rebirths) + m minutes de revenus
--   { Type = "Boost", Seconds = n }                    -> Argent x2 pendant n secondes
--   { Type = "Creature", Rarities = { Rare = 70, Epic = 30 } } ou { Type = "Creature", Id = "..." }
--   { Type = "Bundle", Rewards = { ... } }
---------------------------------------------------------------------------

-- Cadeaux de session : débloqués après X minutes de jeu dans la même session
GameConfig.Playtime = {
	Gifts = {
		{ Minutes = 1, Reward = { Type = "Money", Base = 150, IncomeMinutes = 1 } },
		{ Minutes = 3, Reward = { Type = "Money", Base = 400, IncomeMinutes = 2 } },
		{ Minutes = 6, Reward = { Type = "Boost", Seconds = 300 } },
		{ Minutes = 10, Reward = { Type = "Creature", Rarities = { Rare = 70, Epic = 30 } } },
		{ Minutes = 15, Reward = { Type = "Money", Base = 2500, IncomeMinutes = 5 } },
		{ Minutes = 20, Reward = { Type = "Boost", Seconds = 600 } },
		{ Minutes = 30, Reward = { Type = "Creature", Rarities = { Epic = 80, Legendary = 20 } } },
		{ Minutes = 45, Reward = { Type = "Money", Base = 10000, IncomeMinutes = 12 } },
		{ Minutes = 60, Reward = { Type = "Creature", Rarities = { Legendary = 85, Mythic = 15 } } },
	},
}

-- Tutoriel (premières minutes) : récompense à la fin
GameConfig.Tutorial = {
	Reward = {
		Type = "Bundle",
		Rewards = {
			{ Type = "Money", Base = 400, IncomeMinutes = 0 },
			{ Type = "Boost", Seconds = 300 },
		},
	},
}

---------------------------------------------------------------------------
-- Titres affichés au-dessus des joueurs selon leurs rebirths (statut social)
---------------------------------------------------------------------------
GameConfig.Titles = {
	{ Rebirths = 0, Name = "Novice", Color = Color3.fromRGB(200, 200, 215) },
	{ Rebirths = 1, Name = "Explorateur", Color = Color3.fromRGB(110, 210, 120) },
	{ Rebirths = 2, Name = "Chasseur de failles", Color = Color3.fromRGB(80, 170, 255) },
	{ Rebirths = 4, Name = "Voleur d'élite", Color = Color3.fromRGB(180, 100, 255) },
	{ Rebirths = 7, Name = "Maître des dimensions", Color = Color3.fromRGB(255, 190, 40) },
	{ Rebirths = 12, Name = "Légende de la Rift", Color = Color3.fromRGB(255, 80, 110) },
	{ Rebirths = 20, Name = "Divinité dimensionnelle", Color = Color3.fromRGB(40, 255, 210) },
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
