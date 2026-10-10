--[[
	RiftVisualController
	====================
	Effets visuels de la Rift, 100 % côté client :
	- couleurs de la faille et ambiance (éclairage, brouillard, teinte) selon la
	  dimension active, avec transition douce ;
	- rotation du tourbillon, éclats en orbite, portails instables qui tournent.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Dimensions = require(ReplicatedStorage.Shared.Config.Dimensions)
local StateController = require(script.Parent.StateController)

local RiftVisualController = {}

local rift: Model? = nil
local ringParts: { BasePart } = {}
local shards: { BasePart } = {}
local swirl: BasePart? = nil
local core: BasePart? = nil
local swirlBase: CFrame? = nil
local riftCenter = Vector3.new(0, 18, 0)
local currentDimension: string? = nil

local colorCorrection: ColorCorrectionEffect
local atmosphere: Atmosphere

local function tween(instance: Instance, props: { [string]: any }, duration: number?)
	TweenService:Create(instance, TweenInfo.new(duration or 2, Enum.EasingStyle.Sine), props):Play()
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
	for _, part in ringParts do
		tween(part, { Color = visual.RiftColor })
	end
	for _, part in shards do
		tween(part, { Color = visual.RiftAccent })
	end
	if core then
		tween(core, { Color = visual.RiftColor })
		local light = core:FindFirstChildOfClass("PointLight")
		if light then
			tween(light, { Color = visual.RiftColor })
		end
		local particles = core:FindFirstChildOfClass("ParticleEmitter")
		if particles then
			particles.Color = ColorSequence.new(visual.RiftColor, visual.RiftAccent)
		end
	end
	if swirl then
		tween(swirl, { Color = visual.RiftAccent })
	end
	tween(Lighting, { Ambient = visual.Ambient, OutdoorAmbient = visual.Ambient, FogColor = visual.FogColor }, 3)
	tween(colorCorrection, { TintColor = visual.Tint }, 3)
	tween(atmosphere, { Color = visual.FogColor, Decay = visual.Ambient }, 3)
end

local function collectRift()
	local map = workspace:WaitForChild("Map")
	rift = map:WaitForChild("Rift") :: Model
	for _, child in (rift :: Model):GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "RingSegment" then
				table.insert(ringParts, child)
			elseif child.Name == "Shard" then
				table.insert(shards, child)
			elseif child.Name == "Swirl" then
				swirl = child
				swirlBase = child.CFrame
			elseif child.Name == "Core" then
				core = child
				riftCenter = child.Position
			end
		end
	end
end

function RiftVisualController.Start()
	local existingCC = Lighting:FindFirstChild("RiftColorCorrection")
	if existingCC and existingCC:IsA("ColorCorrectionEffect") then
		colorCorrection = existingCC
	else
		local created = Instance.new("ColorCorrectionEffect")
		created.Name = "RiftColorCorrection"
		created.Saturation = 0.1
		created.Parent = Lighting
		colorCorrection = created
	end
	local existingAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmosphere then
		atmosphere = existingAtmosphere
	else
		local created = Instance.new("Atmosphere")
		created.Density = 0.3
		created.Haze = 1
		created.Parent = Lighting
		atmosphere = created
	end

	collectRift()
	local portals = workspace.Map:WaitForChild("Portals")

	local function refresh()
		applyDimension(StateController.GetDimension())
	end
	StateController.GameStateChanged:Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if swirl and swirlBase then
			swirl.CFrame = swirlBase * CFrame.Angles(t * 1.5, 0, 0)
		end
		for i, shard in shards do
			local angle = t * 0.4 + (i / #shards) * math.pi * 2
			local offset = Vector3.new(math.cos(angle) * 24, math.sin(t + i) * 4, math.sin(angle) * 24)
			shard.CFrame = CFrame.new(riftCenter + offset) * CFrame.Angles(t, t * 0.7, 0)
		end
		for _, portal in portals:GetChildren() do
			local portalCore = portal:FindFirstChild("Core")
			if portalCore and portalCore:IsA("BasePart") then
				local base = portalCore:GetAttribute("BaseCFrame")
				if typeof(base) ~= "CFrame" then
					base = portalCore.CFrame
					portalCore:SetAttribute("BaseCFrame", base)
				end
				portalCore.CFrame = (base :: CFrame) * CFrame.Angles(t * 3, 0, 0)
			end
		end
	end)
end

return RiftVisualController
