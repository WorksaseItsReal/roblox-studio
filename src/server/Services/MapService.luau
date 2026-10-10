--[[
	MapService
	==========
	- Construit la map procédurale si Workspace.Map est absent (MapBuilder).
	- Sinon, vérifie que la map faite à la main respecte le contrat de noms
	  (docs/MAP_BUILD.md) et convertit d'éventuels waypoints "pièces" en attributs.
	- Expose les bases (PlotRecord) et le chemin aux autres services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local PathMath = require(Shared.Modules.PathMath)
local MapBuilder = require(script.Parent.Parent.Lib.MapBuilder)

local MapService = {}

export type PlotRecord = {
	Id: number,
	Model: Model,
	Floor: BasePart,
	Barrier: BasePart,
	Spawn: BasePart,
	ShortcutLanding: BasePart,
	Entrance: BasePart,
	LockButton: BasePart,
	FusionPortal: BasePart,
	Sign: BasePart?,
	Slots: { [number]: BasePart },
	CreaturesFolder: Folder,
	Owner: Player?,
}

local map: Folder
local path: PathMath.Path
local plots: { PlotRecord } = {}
local ringRadius: number? = nil
local ringCenter: Vector3 = Vector3.zero

local REQUIRED_PLOT_PARTS = { "Floor", "Barrier", "Spawn", "ShortcutLanding", "Entrance", "LockButton", "FusionPortal" }

local function fail(message: string)
	error("[MapService] Map invalide : " .. message .. " (voir docs/MAP_BUILD.md)", 0)
end

-- Map manuelle : waypoints posés comme pièces Map.PathWaypoints.WP1..WPn
local function convertWaypointParts(): boolean
	local folder = map:FindFirstChild("PathWaypoints")
	if not folder then
		return false
	end
	local points = {}
	local index = 1
	while true do
		local waypoint = folder:FindFirstChild("WP" .. index)
		if not waypoint or not waypoint:IsA("BasePart") then
			break
		end
		table.insert(points, waypoint.Position)
		waypoint.Transparency = 1
		waypoint.CanCollide = false
		index += 1
	end
	if #points < 2 then
		fail("PathWaypoints doit contenir WP1, WP2, ... (au moins 2)")
	end
	local pathData = map:FindFirstChild("PathData") or Instance.new("Configuration")
	pathData.Name = "PathData"
	PathMath.WriteMainPath(pathData, points)
	pathData.Parent = map
	return true
end

local function buildPlotRecord(model: Instance): PlotRecord
	if not model:IsA("Model") then
		fail(model:GetFullName() .. " doit être un Model")
	end
	for _, name in REQUIRED_PLOT_PARTS do
		local child = model:FindFirstChild(name)
		if not child or not child:IsA("BasePart") then
			fail(model.Name .. "." .. name .. " manquant (BasePart attendu)")
		end
	end
	local slotsFolder = model:FindFirstChild("Slots")
	if not slotsFolder then
		fail(model.Name .. ".Slots manquant")
	end

	local slots = {}
	for index = 1, GameConfig.Slots.MaxPhysical do
		local slot = slotsFolder:FindFirstChild("Slot" .. index)
		if not slot or not slot:IsA("BasePart") then
			fail(
				model.Name .. ".Slots.Slot" .. index .. " manquant (il en faut " .. GameConfig.Slots.MaxPhysical .. ")"
			)
		end
		slots[index] = slot
	end

	local creatures = model:FindFirstChild("Creatures")
	if not creatures then
		creatures = Instance.new("Folder")
		creatures.Name = "Creatures"
		creatures.Parent = model
	end

	local id = model:GetAttribute("PlotId")
	if type(id) ~= "number" then
		id = tonumber(model.Name:match("%d+"))
		if not id then
			fail(model.Name .. " : attribut PlotId (nombre) manquant")
		end
		model:SetAttribute("PlotId", id)
	end

	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("BarrierActive", false)
	model:SetAttribute("BarrierEndsAt", 0)
	model:SetAttribute("BarrierCooldownEndsAt", 0)

	local m = model :: Model
	return {
		Id = id,
		Model = m,
		Floor = m:FindFirstChild("Floor") :: BasePart,
		Barrier = m:FindFirstChild("Barrier") :: BasePart,
		Spawn = m:FindFirstChild("Spawn") :: BasePart,
		ShortcutLanding = m:FindFirstChild("ShortcutLanding") :: BasePart,
		Entrance = m:FindFirstChild("Entrance") :: BasePart,
		LockButton = m:FindFirstChild("LockButton") :: BasePart,
		FusionPortal = m:FindFirstChild("FusionPortal") :: BasePart,
		Sign = m:FindFirstChild("Sign") :: BasePart?,
		Slots = slots,
		CreaturesFolder = creatures :: Folder,
		Owner = nil,
	}
end

function MapService.Init(_services)
	local existing = workspace:FindFirstChild("Map")
	if existing then
		map = existing :: Folder
		print("[MapService] Map existante détectée : vérification du contrat")
	else
		map = MapBuilder.Build(workspace)
		print("[MapService] Map procédurale générée")
	end

	-- Chemin
	if not map:FindFirstChild("PathData") then
		convertWaypointParts()
	end
	local pathData = map:FindFirstChild("PathData")
	if not pathData then
		fail("Map.PathData (attributs WP1..WPn) ou Map.PathWaypoints (pièces WP1..WPn) requis")
	end
	local readPath = PathMath.ReadMainPath(pathData)
	if not readPath then
		fail("PathData : attributs Count / WP1..WPn invalides")
	end
	path = readPath :: PathMath.Path
	local radius = pathData:GetAttribute("RingRadius")
	ringRadius = if type(radius) == "number" then radius else nil
	local center = pathData:GetAttribute("RingCenter")
	ringCenter = if typeof(center) == "Vector3" then center else Vector3.new(0, path.Points[1].Y, 0)

	-- Dossiers runtime
	for _, name in { "Movers", "Portals" } do
		if not map:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = map
		end
	end

	-- Bases
	local plotsFolder = map:FindFirstChild("Plots")
	if not plotsFolder then
		fail("Map.Plots manquant")
	end
	for _, model in plotsFolder:GetChildren() do
		table.insert(plots, buildPlotRecord(model))
	end
	table.sort(plots, function(a, b)
		return a.Id < b.Id
	end)
	if #plots == 0 then
		fail("aucune base dans Map.Plots")
	end
	print(string.format("[MapService] %d bases, chemin de %.0f studs", #plots, path.Length))
end

function MapService.Start() end

function MapService.GetMap(): Folder
	return map
end

function MapService.GetPath(): PathMath.Path
	return path
end

-- Anneau central (rayon nil si la map manuelle n'est pas circulaire) : sert à faire
-- contourner la Rift aux créatures qui rejoignent une base
function MapService.GetRing(): (Vector3, number?)
	return ringCenter, ringRadius
end

function MapService.GetPlots(): { PlotRecord }
	return plots
end

function MapService.GetMoversFolder(): Folder
	return map:FindFirstChild("Movers") :: Folder
end

function MapService.GetPortalsFolder(): Folder
	return map:FindFirstChild("Portals") :: Folder
end

-- Vrai si la position est à l'intérieur de la base (volume du sol, sur 30 studs de haut)
function MapService.IsInsidePlot(plot: PlotRecord, position: Vector3): boolean
	local localPos = plot.Floor.CFrame:PointToObjectSpace(position)
	local size = plot.Floor.Size
	return math.abs(localPos.X) <= size.X / 2
		and math.abs(localPos.Z) <= size.Z / 2
		and localPos.Y >= -2
		and localPos.Y <= 30
end

return MapService
