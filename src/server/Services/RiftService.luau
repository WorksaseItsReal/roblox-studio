--[[
	RiftService
	===========
	Cœur du twist "portails" :
	- Cycle des dimensions (toutes les 5 min) + annonce globale.
	- Apparition des créatures sur le chemin (tirage Odds).
	- Chance serveur (pack de chance Robux).
	- Portails instables dorés qui libèrent une créature Secrète.

	Les créatures du chemin sont des modèles créés par le serveur avec des
	attributs (StartTime, StartDistance, Speed). Le serveur ne les déplace JAMAIS :
	chaque client les anime localement avec PathMath (mouvement fluide, zéro coût
	réseau). Le serveur recalcule la position exacte avec la même formule quand un
	joueur veut acheter.

	État global répliqué : attributs de ReplicatedStorage.GameState
	  Dimension, DimensionEndsAt, LuckMultiplier, LuckEndsAt
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Dimensions = require(Shared.Config.Dimensions)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Odds = require(Shared.Modules.Odds)
local PathMath = require(Shared.Modules.PathMath)
local Format = require(Shared.Modules.Format)
local CreatureVisuals = require(Shared.Modules.CreatureVisuals)

local RiftService = {}

local Services

export type Spawn = {
	Id: string,
	CreatureId: string,
	Price: number,
	StartTime: number,
	StartDistance: number,
	Speed: number,
	IsSecret: boolean,
	Model: Model,
}

local rng = Random.new()
local stateFolder: Folder
local spawns: { [string]: Spawn } = {}
local spawnCount = 0
local nextSpawnSerial = 0

local currentDimension = GameConfig.Rift.FirstDimension
local dimensionEndsAt = 0
local luckMultiplier = 1
local luckEndsAt = 0
local lastPortalAt = -math.huge

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publishState()
	stateFolder:SetAttribute("Dimension", currentDimension)
	stateFolder:SetAttribute("DimensionEndsAt", dimensionEndsAt)
	stateFolder:SetAttribute("LuckMultiplier", luckMultiplier)
	stateFolder:SetAttribute("LuckEndsAt", luckEndsAt)
end

function RiftService.GetDimension(): string
	return currentDimension
end

function RiftService.GetLuck(): number
	return if now() < luckEndsAt then luckMultiplier else 1
end

---------------------------------------------------------------------------
-- Dimensions
---------------------------------------------------------------------------
local function setDimension(dimensionId: string, forcedBy: Player?)
	local dimension = Dimensions.Get(dimensionId)
	if not dimension then
		return
	end
	currentDimension = dimensionId
	dimensionEndsAt = now() + GameConfig.Rift.DimensionDurationSeconds
	publishState()

	local subtitle = dimension.Description
	if forcedBy then
		subtitle = forcedBy.DisplayName .. " a forcé l'ouverture ! " .. subtitle
	end
	Services.NotificationService.Announce(
		"La Rift bascule : " .. dimension.Name .. " !",
		subtitle,
		dimension.Visual.RiftColor
	)
end

-- Produit développeur "Forcer une dimension"
function RiftService.ForceDimension(dimensionId: string?, player: Player?)
	local target = dimensionId
	if not target or not Dimensions.IsValid(target) or target == currentDimension then
		target = Dimensions.Next(currentDimension)
	end
	setDimension(target :: string, player)
end

-- Produit développeur "Pack de chance" (cumulable en durée)
function RiftService.AddLuck(seconds: number, multiplier: number, maxStack: number, player: Player?)
	local t = now()
	luckMultiplier = math.max(multiplier, if t < luckEndsAt then luckMultiplier else 1)
	luckEndsAt = math.min(math.max(t, luckEndsAt) + seconds, t + maxStack)
	publishState()
	local by = if player then player.DisplayName .. " offre " else ""
	Services.NotificationService.Announce(
		"Chance x" .. luckMultiplier .. " !",
		by .. "une chance boostée à tout le serveur pendant " .. Format.Time(luckEndsAt - t),
		Color3.fromRGB(110, 255, 120)
	)
end

---------------------------------------------------------------------------
-- Apparitions sur le chemin
---------------------------------------------------------------------------
function RiftService.GetSpawn(spawnId: string): Spawn?
	return spawns[spawnId]
end

function RiftService.GetSpawnDistance(spawn: Spawn, atTime: number?): number
	return spawn.StartDistance + ((atTime or now()) - spawn.StartTime) * spawn.Speed
end

function RiftService.GetSpawnPosition(spawn: Spawn, atTime: number?): Vector3
	local position = PathMath.Evaluate(Services.MapService.GetPath(), RiftService.GetSpawnDistance(spawn, atTime))
	return position
end

local function removeSpawn(spawnId: string)
	local spawn = spawns[spawnId]
	if spawn then
		spawns[spawnId] = nil
		spawnCount -= 1
		spawn.Model:Destroy()
	end
end

-- Retire une créature du chemin (achat). Aucune attente : atomique côté serveur.
function RiftService.ConsumeSpawn(spawnId: string): Spawn?
	local spawn = spawns[spawnId]
	if not spawn then
		return nil
	end
	removeSpawn(spawnId)
	return spawn
end

local function createSpawn(creatureId: string, startDistance: number, speed: number, isSecret: boolean)
	local def = Creatures.Get(creatureId)
	if not def then
		return
	end
	nextSpawnSerial += 1
	local spawnId = "s" .. nextSpawnSerial

	local model = CreatureVisuals.Build(creatureId, Mutations.None, {
		Anchored = true,
		Billboard = true,
		PriceText = Format.Money(def.Price),
	})
	model.Name = spawnId
	model:SetAttribute("MoverType", "Conveyor")
	model:SetAttribute("SpawnId", spawnId)
	model:SetAttribute("Price", def.Price)
	model:SetAttribute("IsSecret", isSecret)
	model:SetAttribute("StartDistance", startDistance)
	model:SetAttribute("Speed", speed)
	-- Toujours répliqué, même avec StreamingEnabled (le client le déplace localement)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local startTime = now()
	model:SetAttribute("StartTime", startTime)
	local position, direction = PathMath.Evaluate(Services.MapService.GetPath(), startDistance)
	local hip = model:GetAttribute("HipHeight") or 2
	model:PivotTo(CFrame.lookAt(position, position + direction) + Vector3.new(0, hip, 0))
	model.Parent = Services.MapService.GetMoversFolder()

	spawns[spawnId] = {
		Id = spawnId,
		CreatureId = creatureId,
		Price = def.Price,
		StartTime = startTime,
		StartDistance = startDistance,
		Speed = speed,
		IsSecret = isSecret,
		Model = model,
	}
	spawnCount += 1
end

local function spawnRandom()
	local rarityId = Odds.RollRarity(currentDimension, RiftService.GetLuck(), rng)
	local def = Odds.PickCreature(currentDimension, rarityId, rng)
	if not def then
		return
	end
	local dimension = Dimensions.Get(currentDimension)
	local speed = GameConfig.Rift.CreatureWalkSpeed * (if dimension then dimension.WalkSpeedMultiplier else 1)
	createSpawn(def.Id, 0, speed, false)

	local rarity = Rarities.Get(def.Rarity)
	if rarity and rarity.Tier >= 5 then
		Services.NotificationService.Announce(
			rarity.Name .. " repéré !",
			def.Name .. " sort de la Rift (" .. Format.Money(def.Price) .. ")",
			rarity.Color
		)
	end
end

---------------------------------------------------------------------------
-- Portails instables
---------------------------------------------------------------------------
local function buildGoldenPortal(position: Vector3, direction: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "UnstablePortal"
	local center = position + Vector3.new(0, 7, 0)
	local facing = CFrame.lookAt(center, center + direction)
	local radius = 6
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local segment = Instance.new("Part")
		segment.Name = "RingSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(255, 200, 50)
		segment.Size = Vector3.new(2.6, 1.2, 1.2)
		segment.CFrame = facing * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0)
		segment.Parent = model
	end
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Cylinder
	core.Anchored = true
	core.CanCollide = false
	core.Material = Enum.Material.ForceField
	core.Color = Color3.fromRGB(255, 230, 120)
	core.Size = Vector3.new(0.5, radius * 2, radius * 2)
	core.CFrame = facing * CFrame.Angles(0, math.rad(90), 0)
	core.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 80)
	light.Range = 30
	light.Brightness = 4
	light.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
	sparks.LightEmission = 1
	sparks.Rate = 40
	sparks.Speed = NumberRange.new(3, 8)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = core
	model.PrimaryPart = core
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return model
end

function RiftService.OpenUnstablePortal()
	local path = Services.MapService.GetPath()
	local distance = rng:NextNumber(path.Length * 0.2, path.Length * 0.65)
	local position, direction = PathMath.Evaluate(path, distance)
	lastPortalAt = now()

	local portal = buildGoldenPortal(position, direction)
	portal.Parent = Services.MapService.GetPortalsFolder()

	-- La Secrète de la dimension active (ou n'importe laquelle à défaut)
	local pool = Creatures.ByDimensionAndRarity[currentDimension]
	local secrets = (pool and pool.Secret) or Creatures.ByRarity.Secret
	local def = secrets[rng:NextInteger(1, #secrets)]

	Services.NotificationService.Announce(
		"Un portail instable s'ouvre !",
		"Une créature SECRÈTE en sort : " .. def.Name .. ". Premier arrivé, premier servi !",
		Color3.fromRGB(255, 210, 60)
	)

	task.delay(1.5, function()
		local speed = GameConfig.Rift.CreatureWalkSpeed * GameConfig.UnstablePortal.SecretWalkSpeedMultiplier
		createSpawn(def.Id, distance, speed, true)
	end)
	task.delay(GameConfig.UnstablePortal.PortalLifetime, function()
		portal:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Boucle principale
---------------------------------------------------------------------------
function RiftService.Init(services)
	Services = services
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "GameState"
	stateFolder.Parent = ReplicatedStorage
end

function RiftService.Start()
	dimensionEndsAt = now() + GameConfig.Rift.DimensionDurationSeconds
	publishState()

	local portalConfig = GameConfig.UnstablePortal
	local fastPortals = RunService:IsStudio() and GameConfig.Debug.FastUnstablePortals
	local nextSpawnAt = now()
	local nextPortalCheck = now() + (if fastPortals then 10 else portalConfig.CheckIntervalSeconds)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()

			if t >= dimensionEndsAt then
				setDimension(Dimensions.Next(currentDimension), nil)
			end
			if luckMultiplier ~= 1 and t >= luckEndsAt then
				luckMultiplier = 1
				publishState()
			end

			-- Créatures arrivées au bout du chemin : elles retournent dans la Rift
			local pathLength = Services.MapService.GetPath().Length
			for spawnId, spawn in spawns do
				if RiftService.GetSpawnDistance(spawn, t) >= pathLength then
					removeSpawn(spawnId)
				end
			end

			if t >= nextSpawnAt then
				local dimension = Dimensions.Get(currentDimension)
				local interval = GameConfig.Rift.SpawnIntervalSeconds
					* (if dimension then dimension.SpawnIntervalMultiplier else 1)
				nextSpawnAt = t + interval * rng:NextNumber(0.8, 1.2)
				if spawnCount < GameConfig.Rift.MaxActiveSpawns then
					spawnRandom()
				end
			end

			if t >= nextPortalCheck then
				nextPortalCheck = t + (if fastPortals then 40 else portalConfig.CheckIntervalSeconds)
				local gapOk = fastPortals or (t - lastPortalAt >= portalConfig.MinGapSeconds)
				if gapOk and (fastPortals or rng:NextNumber() < portalConfig.ChancePerCheck) then
					RiftService.OpenUnstablePortal()
				end
			end
		end
	end)
end

return RiftService
