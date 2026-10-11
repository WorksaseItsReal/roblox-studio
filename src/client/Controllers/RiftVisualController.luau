--[[
	RiftVisualController
	====================
	Effets visuels du monde, 100 % côté client (aucun coût serveur ni réseau) :
	- recoloration de la Rift, des fissures, des néons de la route, des
	  lampadaires et de la colonne de lumière selon la dimension active ;
	- ambiance (éclairage, brouillard, teinte, bloom) avec transition douce ;
	- tourbillons qui tournent, éclats en orbite, portails instables animés ;
	- chevrons du tapis roulant qui "défilent" (lumière qui court dans le sens
	  de marche des créatures).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Dimensions = require(ReplicatedStorage.Shared.Config.Dimensions)
local StateController = require(script.Parent.StateController)

local RiftVisualController = {}

-- Pièces recolorées selon la dimension : nom -> "Main" (couleur de la faille) ou "Accent"
local TINTED = {
	RingSegment = "Main",
	Core = "Main",
	Crack = "Main",
	RiftBeam = "Main",
	RiftTooth = "Accent",
	Shard = "Accent",
	Swirl = "Accent",
	RoadGlow = "Main",
	Chevron = "Main",
	Lamp = "Accent",
}

local tinted: { [string]: { BasePart } } = {}
local spinners: { { Part: BasePart, Base: CFrame, Speed: number } } = {}
local shards: { BasePart } = {}
local chevrons: { { Part: BasePart, Index: number } } = {}
local riftCenter = Vector3.new(0, 17, 0)
local currentDimension: string? = nil

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
		local color = if role == "Main" then visual.RiftColor else visual.RiftAccent
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
	tween(colorCorrection, { TintColor = visual.Tint }, 3)
	tween(atmosphere, { Color = visual.FogColor:Lerp(Color3.new(1, 1, 1), 0.5), Decay = visual.FogColor }, 3)
end

local function collect(map: Instance)
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = descendant.Name
			if TINTED[name] then
				tinted[name] = tinted[name] or {}
				table.insert(tinted[name], descendant)
			end
			if name == "Swirl" or name == "Swirl2" or name == "FusionSwirl" then
				local speed = if name == "Swirl" then 1.2 elseif name == "Swirl2" then -2.4 else 2
				table.insert(spinners, { Part = descendant, Base = descendant.CFrame, Speed = speed })
			elseif name == "Shard" then
				table.insert(shards, descendant)
			elseif name == "Chevron" then
				table.insert(chevrons, { Part = descendant, Index = descendant:GetAttribute("Index") or 0 })
			elseif name == "Core" and descendant.Parent and descendant.Parent.Name == "Rift" then
				riftCenter = descendant.Position
			end
		end
	end
end

function RiftVisualController.Start()
	colorCorrection = getOrCreate("ColorCorrectionEffect", "RiftColorCorrection")
	colorCorrection.Saturation = 0.12
	colorCorrection.Contrast = 0.05
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or getOrCreate("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	bloom = getOrCreate("BloomEffect", "RiftBloom")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.6

	local map = workspace:WaitForChild("Map")
	map:WaitForChild("Rift")
	map:WaitForChild("Plots")
	task.wait(1) -- laisse la map finir de se répliquer
	collect(map)
	local portals = map:WaitForChild("Portals")

	-- Tempête : ciel plus sombre, teinte magenta, faille et colonne qui s'emballent, éclairs
	local stormOn = false
	local function applyStorm(active: boolean)
		if active == stormOn then
			return
		end
		stormOn = active
		tween(atmosphere, { Density = if active then 0.45 else 0.28 }, 2)
		tween(bloom, { Intensity = if active then 1.2 else 0.7 }, 2)
		if active then
			tween(colorCorrection, { TintColor = Color3.fromRGB(255, 200, 235), Contrast = 0.15, Saturation = 0.3 }, 2)
		else
			tween(colorCorrection, { Contrast = 0.05, Saturation = 0.12 }, 2)
			currentDimension = nil -- forcera la teinte de la dimension à être réappliquée
		end
		for _, beam in ipairs(tinted.RiftBeam or {}) do
			tween(beam, { Transparency = if active then 0.6 else 0.86 }, 2)
		end
		for _, spinner in spinners do
			spinner.Speed *= if active then 3 else 1 / 3
		end
	end

	local function refresh()
		local state = StateController.GameState
		applyStorm(state ~= nil and state:GetAttribute("StormActive") == true)
		applyDimension(StateController.GetDimension())
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

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, spinner in spinners do
			spinner.Part.CFrame = spinner.Base * CFrame.Angles(t * spinner.Speed, 0, 0)
		end
		for i, shard in shards do
			local angle = t * 0.4 + (i / #shards) * math.pi * 2
			local offset = Vector3.new(math.cos(angle) * 24, math.sin(t + i) * 4, math.sin(angle) * 24)
			shard.CFrame = CFrame.new(riftCenter + offset) * CFrame.Angles(t, t * 0.7, 0)
		end
		-- Lumière qui court le long du tapis (groupes de 6 chevrons)
		local phase = t * 6
		for _, chevron in chevrons do
			local wave = (chevron.Index - phase) % 6
			chevron.Part.Transparency = if wave < 1.5 then 0 else 0.65
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
