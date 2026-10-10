--[[
	EffectsController
	=================
	Effets visuels déclenchés par le serveur (RemoteEvent "Effect") :
	Fusion, Teleport, HighlightIntruder, StealAlert.
	Tout est local et éphémère : aucun impact sur le gameplay.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local EffectsController = {}

local function burst(position: Vector3, color: Color3, size: number)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = color
	sphere.Size = Vector3.one
	sphere.CFrame = CFrame.new(position)
	sphere.Transparency = 0.2
	sphere.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Speed = NumberRange.new(10, 25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 0
	emitter.Parent = sphere
	emitter:Emit(60)

	TweenService:Create(sphere, TweenInfo.new(0.6), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(sphere, 1.5)
end

local function highlightPlayer(userId: number, color: Color3, duration: number)
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	Debris:AddItem(highlight, duration)
end

local handlers = {
	Fusion = function(payload)
		if typeof(payload.Position) == "Vector3" then
			burst(
				payload.Position,
				if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 1, 1),
				18
			)
		end
	end,
	Teleport = function(payload)
		if typeof(payload.Position) == "Vector3" then
			burst(payload.Position + Vector3.new(0, 3, 0), Color3.fromRGB(150, 120, 255), 12)
		end
	end,
	HighlightIntruder = function(payload)
		if type(payload.UserId) == "number" then
			highlightPlayer(payload.UserId, Color3.fromRGB(255, 60, 60), tonumber(payload.Duration) or 8)
		end
	end,
	StealAlert = function(payload)
		if type(payload.ThiefUserId) == "number" then
			highlightPlayer(payload.ThiefUserId, Color3.fromRGB(255, 40, 40), 10)
		end
	end,
}

function EffectsController.Start()
	Remotes.GetEvent("Effect").OnClientEvent:Connect(function(effectType, payload)
		local handler = handlers[effectType]
		if handler and type(payload) == "table" then
			handler(payload)
		end
	end)
end

return EffectsController
