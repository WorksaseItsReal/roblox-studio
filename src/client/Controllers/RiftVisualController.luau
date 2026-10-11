--[[
	RiftVisualController
	====================
	Effets visuels du monde, 100 % côté client (aucun coût serveur ni réseau) :
	- recoloration de la Rift (vortex, cristaux, fissures, liseré de l'estrade) et
	  de la colonne de lumière selon la dimension active ;
	- ambiance (éclairage, atmosphère, teinte, bloom) avec transition douce.
	  Plein jour doux (docs/ART_DIRECTION.md, section 3) : la dimension ne fait que
	  teinter très légèrement l'ambiance, le monde garde ses matériaux ;
	- tourbillons qui tournent, bras de la spirale qui tournent autour de l'axe de la
	  Rift, éclats en orbite, portails instables animés ;
	- flèches peintes du tapis (pièces « Chevron ») : une légère vague d'opacité
	  court dans le sens de marche des créatures (peinture, jamais de néon).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Dimensions = require(ReplicatedStorage.Shared.Config.Dimensions)
local StateController = require(script.Parent.StateController)

local RiftVisualController = {}

-- Pièces recolorées selon la dimension : nom -> "Main" (couleur de la faille), "Deep"
-- (couleur de la faille assombrie : anneau intérieur du vortex) ou "Accent"
local TINTED = {
	RingSegment = "Main",
	Core = "Main",
	RiftDeep = "Deep",
	SwirlArm = "Accent",
	Crack = "Main",
	RiftBeam = "Main",
	RiftTooth = "Accent",
	Shard = "Accent",
	Swirl = "Accent",
	RoadGlow = "Main",
}

-- Tourbillons : vitesse de rotation (radians/s) autour de l'axe du disque
local SPINNERS = { Swirl = 1.2, Swirl2 = -2.4, FusionSwirl = 2, ExitSwirl = -1.5 }
-- Bras de la spirale (pièces « SwirlArm ») : rotation autour de l'axe de la Rift.
-- Sens positif = la spirale se déroule vers l'extérieur : la Rift recrache ses créatures
local ARM_SPEED = 0.7
-- Assombrissement de l'anneau intérieur (même valeur que MapBuilder.DEEP_SHADE)
local DEEP_SHADE = 0.45

-- Réglages de base : plein jour doux (mêmes valeurs que scripts/build-place.luau)
local SKY_HAZE = Color3.fromRGB(205, 224, 250) -- Atmosphere.Color : ciel clair
local SKY_DECAY = Color3.fromRGB(116, 140, 182) -- Atmosphere.Decay
local ATMOSPHERE_DENSITY = 0.28
local ATMOSPHERE_HAZE = 1.2
local SATURATION = 0.08
local CONTRAST = 0.05
local BLOOM_INTENSITY = 0.35
local BLOOM_THRESHOLD = 2.2
-- Part de la couleur de la dimension dans le ciel : nuance à peine perceptible
local SKY_TINT = 0.12
local DECAY_TINT = 0.08

-- Flèches peintes du tapis : une vague d'opacité (gain de 0,2 sur leur transparence
-- de base) parcourt une flèche sur 7, à 1,5 flèche par seconde
local ARROW_WAVE_SPEED = 1.5
local ARROW_WAVE_PERIOD = 7
local ARROW_WAVE_GAIN = 0.2

local tinted: { [string]: { BasePart } } = {}
local spinners: { { Part: BasePart, Base: CFrame, Speed: number } } = {}
local shards: { BasePart } = {}
local chevrons: { { Part: BasePart, Index: number, Base: number } } = {}
local arms: { { Part: BasePart, Offset: CFrame } } = {}
local armSpeed = ARM_SPEED
-- Angle intégré image par image : changer de vitesse (tempête) ne fait pas sauter les bras
local armAngle = 0
local riftAxis = Vector3.zAxis -- remplacé par l'axe du Core de la Rift (son X local)
local riftCenter = Vector3.new(0, 22.5, -195) -- remplacé par la position du Core de la Rift
local shardOrbit = 39 -- rayon de l'orbite des éclats (attribut ShardOrbit du Model Rift)
local currentDimension: string? = nil
local stormOn = false

local colorCorrection: ColorCorrectionEffect
local atmosphere: Atmosphere
local bloom: BloomEffect

local function tween(instance: Instance, props: { [string]: any }, duration: number?)
	TweenService:Create(instance, TweenInfo.new(duration or 2, Enum.EasingStyle.Sine), props):Play()
end

local function getOrCreate(className: string, name: string): any
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local STORM_TINT = Color3.fromRGB(255, 214, 236)

-- Étalonnage (teinte, contraste, saturation) calculé en un seul endroit et appliqué
-- en un seul tween : deux tweens concurrents sur le même effet s'annuleraient
-- (la teinte de la dimension écrasait celle de la tempête).
local function applyGrading(duration: number)
	local dimension = currentDimension and Dimensions.Get(currentDimension)
	local tint = if stormOn then STORM_TINT elseif dimension then dimension.Visual.Tint else Color3.new(1, 1, 1)
	tween(colorCorrection, {
		TintColor = tint,
		Contrast = if stormOn then 0.12 else CONTRAST,
		Saturation = if stormOn then 0.18 else SATURATION,
	}, duration)
end

local function applyDimension(dimensionId: string)
	if dimensionId == currentDimension then
		return
	end
	currentDimension = dimensionId
	local dimension = Dimensions.Get(dimensionId)
	if not dimension then
		return
	end
	local visual = dimension.Visual
	for name, role in TINTED do
		local color = if role == "Main"
			then visual.RiftColor
			elseif role == "Deep" then visual.RiftColor:Lerp(Color3.new(0, 0, 0), DEEP_SHADE)
			else visual.RiftAccent
		for _, part in ipairs(tinted[name] or {}) do
			tween(part, { Color = color })
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				tween(light, { Color = color })
			end
			local particles = part:FindFirstChildOfClass("ParticleEmitter")
			if particles then
				particles.Color = ColorSequence.new(visual.RiftColor, visual.RiftAccent)
			end
		end
	end
	tween(Lighting, { Ambient = visual.Ambient, OutdoorAmbient = visual.Ambient:Lerp(Color3.new(1, 1, 1), 0.35) }, 3)
	applyGrading(3)
	-- Simple nuance du ciel clair : jamais de brume colorée qui délave le monde
	tween(
		atmosphere,
		{ Color = SKY_HAZE:Lerp(visual.FogColor, SKY_TINT), Decay = SKY_DECAY:Lerp(visual.FogColor, DECAY_TINT) },
		3
	)
end

-- Dossiers ignorés : créatures (sur le tapis, dans les bases) et portails instables.
-- Leurs pièces portent parfois les mêmes noms que celles de la Rift (« Core »,
-- « Crack »...) : il ne faut ni les recolorer ni les faire tourner. Les portails
-- instables ont leur propre animation (plus bas).
local function isExcluded(descendant: Instance): boolean
	return descendant:FindFirstAncestor("Movers") ~= nil
		or descendant:FindFirstAncestor("Portals") ~= nil
		or descendant:FindFirstAncestor("Creatures") ~= nil
end

local function collect(map: Instance)
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") and not isExcluded(descendant) then
			local name = descendant.Name
			if TINTED[name] then
				tinted[name] = tinted[name] or {}
				table.insert(tinted[name], descendant)
			end
			if SPINNERS[name] then
				table.insert(spinners, { Part = descendant, Base = descendant.CFrame, Speed = SPINNERS[name] })
			elseif name == "SwirlArm" then
				-- Décalage calculé après la collecte (le Core peut venir plus tard)
				table.insert(arms, { Part = descendant, Offset = descendant.CFrame })
			elseif name == "Shard" then
				table.insert(shards, descendant)
			elseif name == "Chevron" then
				table.insert(chevrons, {
					Part = descendant,
					Index = descendant:GetAttribute("Index") or 0,
					Base = descendant.Transparency,
				})
			elseif name == "Core" and descendant.Parent and descendant.Parent.Name == "Rift" then
				riftCenter = descendant.Position
				riftAxis = descendant.CFrame.RightVector -- axe du disque (cylindre couché)
			end
		end
	end
end

function RiftVisualController.Start()
	colorCorrection = getOrCreate("ColorCorrectionEffect", "RiftColorCorrection")
	colorCorrection.Saturation = SATURATION
	colorCorrection.Contrast = CONTRAST
	-- Atmosphère légère : un voile clair à l'horizon, pas de brume laiteuse
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or getOrCreate("Atmosphere", "Atmosphere")
	atmosphere.Density = ATMOSPHERE_DENSITY
	atmosphere.Haze = ATMOSPHERE_HAZE
	-- Bloom discret : seuil haut, seuls les néons (Rift, globes, lasers) brillent
	bloom = getOrCreate("BloomEffect", "RiftBloom")
	bloom.Intensity = BLOOM_INTENSITY
	bloom.Size = 24
	bloom.Threshold = BLOOM_THRESHOLD

	local map = workspace:WaitForChild("Map")
	map:WaitForChild("Rift")
	map:WaitForChild("Plots")
	task.wait(1) -- laisse la map finir de se répliquer
	collect(map)
	-- Orbite des éclats : attribut ShardOrbit de la Rift, sinon leur distance de départ
	-- au centre (map faite à la main)
	local rift = map:FindFirstChild("Rift")
	local orbit = rift and rift:GetAttribute("ShardOrbit")
	if type(orbit) == "number" and orbit > 0 then
		shardOrbit = orbit
	elseif #shards > 0 then
		local total = 0
		for _, shard in shards do
			total += Vector3.new(shard.Position.X - riftCenter.X, 0, shard.Position.Z - riftCenter.Z).Magnitude
		end
		shardOrbit = total / #shards
	end
	-- Bras de la spirale : position relative au centre de la Rift (repère aligné monde)
	local pivot = CFrame.new(riftCenter)
	for _, arm in arms do
		arm.Offset = pivot:ToObjectSpace(arm.Offset)
	end
	local portals = map:WaitForChild("Portals")

	-- Tempête : ciel plus sombre, teinte magenta, faille et colonne qui s'emballent, éclairs
	local function applyStorm(active: boolean)
		if active == stormOn then
			return
		end
		stormOn = active
		tween(atmosphere, { Density = if active then 0.4 else ATMOSPHERE_DENSITY }, 2)
		tween(bloom, { Intensity = if active then 0.7 else BLOOM_INTENSITY }, 2)
		applyGrading(2)
		for _, beam in ipairs(tinted.RiftBeam or {}) do
			tween(beam, { Transparency = if active then 0.6 else 0.86 }, 2)
		end
		for _, spinner in spinners do
			spinner.Speed *= if active then 3 else 1 / 3
		end
		armSpeed = if active then ARM_SPEED * 3 else ARM_SPEED
	end

	local function refresh()
		local state = StateController.GameState
		-- Dimension d'abord : la tempête (si active) passe ensuite par-dessus
		applyDimension(StateController.GetDimension())
		applyStorm(state ~= nil and state:GetAttribute("StormActive") == true)
	end
	StateController.GameStateChanged:Connect(refresh)
	refresh()

	-- Éclairs pendant la tempête
	task.spawn(function()
		while true do
			task.wait(2 + math.random() * 4)
			if stormOn then
				local brightness = colorCorrection.Brightness
				colorCorrection.Brightness = brightness + 0.45
				tween(colorCorrection, { Brightness = brightness }, 0.35)
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		for _, spinner in spinners do
			spinner.Part.CFrame = spinner.Base * CFrame.Angles(t * spinner.Speed, 0, 0)
		end
		armAngle = (armAngle + dt * armSpeed) % (math.pi * 2)
		local spiral = CFrame.new(riftCenter) * CFrame.fromAxisAngle(riftAxis, armAngle)
		for _, arm in arms do
			arm.Part.CFrame = spiral * arm.Offset
		end
		for i, shard in shards do
			local angle = t * 0.4 + (i / #shards) * math.pi * 2
			local offset = Vector3.new(math.cos(angle) * shardOrbit, math.sin(t + i) * 4, math.sin(angle) * shardOrbit)
			shard.CFrame = CFrame.new(riftCenter + offset) * CFrame.Angles(t, t * 0.7, 0)
		end
		-- Vague d'opacité qui court le long du tapis (flèches peintes, pas de néon)
		local phase = t * ARROW_WAVE_SPEED
		for _, chevron in chevrons do
			local wave = (chevron.Index - phase) % ARROW_WAVE_PERIOD
			local glow = math.max(0, 1 - math.abs(wave - 1))
			chevron.Part.Transparency = math.max(0, chevron.Base - ARROW_WAVE_GAIN * glow)
		end
		for _, portal in portals:GetChildren() do
			local core = portal:FindFirstChild("Core")
			if core and core:IsA("BasePart") then
				local base = core:GetAttribute("BaseCFrame")
				if typeof(base) ~= "CFrame" then
					base = core.CFrame
					core:SetAttribute("BaseCFrame", base)
				end
				core.CFrame = (base :: CFrame) * CFrame.Angles(t * 3, 0, 0)
			end
		end
	end)
end

return RiftVisualController
