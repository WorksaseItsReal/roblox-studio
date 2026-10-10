--[[
	ConveyorController
	==================
	Anime LOCALEMENT toutes les créatures en mouvement (Workspace.Map.Movers) :
	- "Conveyor" : créatures sur le chemin de la Rift (prompt "Acheter")
	- "Walk"     : créatures achetées qui rejoignent leur base

	Position = StartDistance + (heure serveur - StartTime) * Speed, évaluée avec
	PathMath : exactement la formule utilisée par le serveur pour valider un achat.
	Le prompt d'achat est créé côté client et appelle la RemoteFunction
	"BuyCreature" (le serveur revérifie distance, argent, place).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Modules.Format)
local PathMath = require(Shared.Modules.PathMath)
local Net = require(script.Parent.Net)

local ConveyorController = {}

type Tracked = {
	Model: Model,
	Path: PathMath.Path,
	StartTime: number,
	StartDistance: number,
	Speed: number,
	Hip: number,
	Seed: number,
}

local tracked: { [Model]: Tracked } = {}
local mainPath: PathMath.Path? = nil

local function addBuyPrompt(model: Model)
	local root = model.PrimaryPart
	local spawnId = model:GetAttribute("SpawnId")
	local def = Creatures.Get(tostring(model:GetAttribute("CreatureId") or ""))
	if not root or not spawnId or not def then
		return
	end
	local rarity = Rarities.Get(def.Rarity)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Acheter " .. Format.Money(def.Price)
	prompt.ObjectText = def.Name .. (if rarity then " (" .. rarity.Name .. ")" else "")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		Net.Request("BuyCreature", spawnId)
	end)
end

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local moverType = model:GetAttribute("MoverType")
	local path = nil
	if moverType == "Conveyor" then
		path = mainPath
	elseif moverType == "Walk" then
		path = PathMath.ReadInlinePath(model)
	end
	if not path then
		return
	end
	tracked[model] = {
		Model = model,
		Path = path,
		StartTime = model:GetAttribute("StartTime") or workspace:GetServerTimeNow(),
		StartDistance = model:GetAttribute("StartDistance") or 0,
		Speed = model:GetAttribute("Speed") or 7,
		Hip = model:GetAttribute("HipHeight") or 2,
		Seed = math.random() * 10,
	}
	if moverType == "Conveyor" then
		addBuyPrompt(model)
	end
end

local function update()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, info in tracked do
		if model.Parent == nil then
			tracked[model] = nil
			continue
		end
		local distance = info.StartDistance + (now - info.StartTime) * info.Speed
		local position, direction = PathMath.Evaluate(info.Path, distance)
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.01 then
			flat = Vector3.zAxis
		end
		local bob = math.abs(math.sin(clock * 6 + info.Seed)) * 0.4
		local base = position + Vector3.new(0, info.Hip + bob, 0)
		model:PivotTo(CFrame.lookAt(base, base + flat.Unit))
	end
end

function ConveyorController.Start()
	local map = workspace:WaitForChild("Map")
	local pathData = map:WaitForChild("PathData")
	while not mainPath do
		mainPath = PathMath.ReadMainPath(pathData)
		if not mainPath then
			task.wait(0.5)
		end
	end

	local movers = map:WaitForChild("Movers")
	movers.ChildAdded:Connect(function(child)
		-- Laisse les attributs se répliquer avec l'instance
		task.defer(track, child)
	end)
	movers.ChildRemoved:Connect(function(child)
		tracked[child :: any] = nil
	end)
	for _, child in movers:GetChildren() do
		track(child)
	end

	RunService.RenderStepped:Connect(update)
end

return ConveyorController
