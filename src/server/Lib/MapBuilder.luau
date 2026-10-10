--[[
	MapBuilder
	==========
	Génère procéduralement une map jouable si Workspace.Map n'existe pas.
	Vous pouvez remplacer cette map par la vôtre (voir docs/MAP_BUILD.md) : il suffit
	de respecter les NOMS des instances ci-dessous, MapService vérifie le contrat.

	Vue du dessus (Y vers le haut, -Z = "nord") :

	                 [Base 7] [Base 6]
	          [Base 8]                 [Base 5]
	                 .---- anneau ----.
	                |    (  RIFT  )    |      <- chemin circulaire (rayon 70)
	                 '-------||-------'       <- double voie sortie/retour vers la Rift
	          [Base 1]                 [Base 4]
	                 [Base 2] [Base 3]

	Workspace.Map
	  Ground, Plaza, Road (déco)
	  Rift (Model)          : la faille géante (Core, Swirl, RingSegment, Shard)
	  PathData (Configuration): attributs Count, WP1..WPn, RingRadius
	  Plots/Plot1..Plot8    : bases des joueurs
	  Movers                : créatures en mouvement (créées par le serveur)
	  Portals               : portails instables
	  CentralSpawn (SpawnLocation)
]]

local MapBuilder = {}

-- Géométrie (studs)
MapBuilder.RING_RADIUS = 70
MapBuilder.PATH_Y = 0.5
MapBuilder.PLOT_COUNT = 8
MapBuilder.PLOT_RADIUS = 150
MapBuilder.PLOT_WIDTH = 60
MapBuilder.PLOT_DEPTH = 84
MapBuilder.WALL_HEIGHT = 12

local PLOT_COLORS = {
	Color3.fromRGB(235, 87, 87),
	Color3.fromRGB(242, 153, 74),
	Color3.fromRGB(242, 201, 76),
	Color3.fromRGB(111, 207, 151),
	Color3.fromRGB(86, 204, 242),
	Color3.fromRGB(47, 128, 237),
	Color3.fromRGB(155, 81, 224),
	Color3.fromRGB(240, 120, 200),
}

-- Positions des emplacements dans une base (repère local, -Z = entrée)
local SLOT_COLUMNS = { -22, -11, 11, 22 }
local SLOT_ROWS = { -22, -13, -4, 5, 14, 23, 32 }

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function addPrompt(
	parent: Instance,
	name: string,
	action: string,
	objectText: string,
	hold: number,
	key: Enum.KeyCode
)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = key
	prompt.Parent = parent
	return prompt
end

local function addLabel(parent: BasePart, text: string, offset: number, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
end

---------------------------------------------------------------------------
-- Rift
---------------------------------------------------------------------------
local function buildRift(map: Folder)
	local rift = Instance.new("Model")
	rift.Name = "Rift"

	local center = Vector3.new(0, 18, 0)
	local radius = 16
	local segments = 28
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		part({
			Name = "RingSegment",
			Size = Vector3.new(4, 2.6, 3),
			CFrame = CFrame.new(center) * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 90, 20),
			CanCollide = false,
			Parent = rift,
		})
	end

	-- Disque central (le cylindre Roblox est orienté selon X : rotation pour faire face à -Z)
	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, radius * 2 - 2, radius * 2 - 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 120, 40),
		Transparency = 0.25,
		CanCollide = false,
		Parent = rift,
	})
	part({
		Name = "Swirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, radius * 1.2, radius * 1.2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(255, 220, 120),
		CanCollide = false,
		Parent = rift,
	})

	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 3
	light.Color = core.Color
	light.Parent = core

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "RiftParticles"
	particles.Rate = 30
	particles.Lifetime = NumberRange.new(2, 4)
	particles.Speed = NumberRange.new(4, 10)
	particles.SpreadAngle = Vector2.new(25, 25)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = core

	-- Socle
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 40, 40),
		CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(40, 40, 50),
		Parent = rift,
	})

	-- Éclats en orbite (animés côté client)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		part({
			Name = "Shard",
			Size = Vector3.new(1.5, 3, 1.5),
			CFrame = CFrame.new(
				center + Vector3.new(math.cos(angle) * 24, math.sin(angle * 2) * 4, math.sin(angle) * 24)
			),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 60),
			CanCollide = false,
			Parent = rift,
		})
	end

	rift.PrimaryPart = core
	rift.Parent = map
end

---------------------------------------------------------------------------
-- Chemin
---------------------------------------------------------------------------
-- Renvoie la liste ordonnée des waypoints du chemin principal
function MapBuilder.ComputePathPoints(): { Vector3 }
	local R = MapBuilder.RING_RADIUS
	local y = MapBuilder.PATH_Y
	local points = {
		Vector3.new(-3, y, -14), -- sortie de la Rift
		Vector3.new(-3, y, -R),
	}
	-- Tour complet de l'anneau, sens anti-horaire vu du dessus (angles décroissants)
	local steps = 32
	for k = 1, steps - 1 do
		local theta = -math.pi / 2 - k * (2 * math.pi / steps)
		table.insert(points, Vector3.new(R * math.cos(theta), y, R * math.sin(theta)))
	end
	table.insert(points, Vector3.new(3, y, -R))
	table.insert(points, Vector3.new(3, y, -14)) -- retour dans la Rift
	return points
end

local function buildRoad(map: Folder)
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = map

	local R = MapBuilder.RING_RADIUS
	local segments = 48
	local segmentLength = 2 * math.pi * R / segments * 1.08
	for i = 1, segments do
		local theta = (i / segments) * math.pi * 2
		local position = Vector3.new(R * math.cos(theta), 0.2, R * math.sin(theta))
		-- Tangente au cercle
		local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta))
		local cf = CFrame.lookAt(position, position + tangent)
		part({
			Name = "RoadSegment",
			Size = Vector3.new(12, 0.6, segmentLength),
			CFrame = cf,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(35, 35, 45),
			Parent = road,
		})
		for _, side in { -1, 1 } do
			part({
				Name = "RoadEdge",
				Size = Vector3.new(0.5, 0.7, segmentLength),
				CFrame = cf * CFrame.new(side * 6, 0.05, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(120, 90, 255),
				CanCollide = false,
				Parent = road,
			})
		end
	end

	-- Double voie Rift <-> anneau
	part({
		Name = "Spoke",
		Size = Vector3.new(12, 0.6, R - 14),
		CFrame = CFrame.new(0, 0.2, -(R + 14) / 2),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(35, 35, 45),
		Parent = road,
	})
	part({
		Name = "SpokeDivider",
		Size = Vector3.new(0.4, 0.7, R - 14),
		CFrame = CFrame.new(0, 0.25, -(R + 14) / 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 90, 255),
		CanCollide = false,
		Parent = road,
	})
end

---------------------------------------------------------------------------
-- Bases
---------------------------------------------------------------------------
local function buildPlot(plots: Folder, index: number)
	local angle = math.rad((index - 1) * (360 / MapBuilder.PLOT_COUNT) + 22.5)
	local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MapBuilder.PLOT_RADIUS
	-- -Z local de la base pointe vers le centre de la map (l'entrée fait face à la Rift)
	local plotCFrame = CFrame.lookAt(center, Vector3.zero)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local W, D, H = MapBuilder.PLOT_WIDTH, MapBuilder.PLOT_DEPTH, MapBuilder.WALL_HEIGHT

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotId", index)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(W, 1, D),
		CFrame = plotCFrame,
		Material = Enum.Material.Concrete,
		Color = color:Lerp(Color3.new(0.15, 0.15, 0.18), 0.65),
		Parent = model,
	})
	model.PrimaryPart = floor

	local function at(x: number, y: number, z: number): CFrame
		return plotCFrame * CFrame.new(x, y, z)
	end

	-- Murs (fond + côtés). L'avant est ouvert : c'est là que se trouve la barrière.
	part({
		Name = "Wall",
		Size = Vector3.new(W, H, 1),
		CFrame = at(0, H / 2 + 0.5, D / 2),
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Wall",
			Size = Vector3.new(1, H, D),
			CFrame = at(side * W / 2, H / 2 + 0.5, 0),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			Parent = model,
		})
		part({
			Name = "Pillar",
			Size = Vector3.new(2, H + 4, 2),
			CFrame = at(side * W / 2, (H + 4) / 2 + 0.5, -D / 2),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end

	-- Barrière (désactivée par défaut : invisible et traversable)
	part({
		Name = "Barrier",
		Size = Vector3.new(W - 2, H + 4, 1),
		CFrame = at(0, (H + 4) / 2 + 0.5, -D / 2),
		Material = Enum.Material.ForceField,
		Color = color,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Panneau du propriétaire au-dessus de l'entrée
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(W - 2, 4, 0.6),
		CFrame = at(0, H + 6.5, -D / 2),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(25, 25, 32),
		CanCollide = false,
		Parent = model,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 20
	surface.LightInfluence = 0
	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "Text"
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.Text = "Base libre"
	signLabel.Parent = surface
	surface.Parent = sign

	-- Point d'apparition du propriétaire
	part({
		Name = "Spawn",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = at(0, 0.6, -30),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.5,
		CanCollide = false,
		Parent = model,
	})

	-- Point d'arrivée du portail de raccourci (DEVANT la base, hors barrière)
	part({
		Name = "ShortcutLanding",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = at(0, 0.6, -D / 2 - 10),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.7,
		CanCollide = false,
		Parent = model,
	})

	-- Point de passage des créatures qui rentrent à la base
	part({
		Name = "Entrance",
		Size = Vector3.new(2, 0.2, 2),
		CFrame = at(0, 0.6, -D / 2 - 5),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Bouton de barrière
	local lockButton = part({
		Name = "LockButton",
		Size = Vector3.new(4, 2, 4),
		CFrame = at(-W / 2 + 8, 1.5, -D / 2 + 8),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 70, 70),
		Parent = model,
	})
	addPrompt(lockButton, "LockPrompt", "Activer la barrière", "Base", 0.4, Enum.KeyCode.E)
	addLabel(lockButton, "Barrière", 3, Color3.fromRGB(255, 120, 120))

	-- Portail de fusion
	local fusionBase = part({
		Name = "FusionPedestal",
		Size = Vector3.new(8, 1, 4),
		CFrame = at(W / 2 - 8, 1, -D / 2 + 8),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(45, 30, 70),
		Parent = model,
	})
	local fusion = part({
		Name = "FusionPortal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 7, 7),
		CFrame = fusionBase.CFrame * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(170, 90, 255),
		Transparency = 0.2,
		CanCollide = false,
		Parent = model,
	})
	addPrompt(fusion, "FusionPrompt", "Fusionner", "Portail de fusion", 0, Enum.KeyCode.E)
	addLabel(fusion, "Portail de fusion", 5, Color3.fromRGB(200, 150, 255))
	local fusionParticles = Instance.new("ParticleEmitter")
	fusionParticles.Rate = 12
	fusionParticles.LightEmission = 1
	fusionParticles.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255))
	fusionParticles.Speed = NumberRange.new(1, 2)
	fusionParticles.Parent = fusion

	-- Emplacements
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	local slotIndex = 0
	for _, z in SLOT_ROWS do
		for _, x in SLOT_COLUMNS do
			slotIndex += 1
			local slot = part({
				Name = "Slot" .. slotIndex,
				Size = Vector3.new(7, 0.4, 7),
				CFrame = at(x, 0.7, z),
				Material = Enum.Material.SmoothPlastic,
				Color = Color3.fromRGB(60, 60, 70),
				Transparency = 0.6,
				CanCollide = false,
				Parent = slots,
			})
			slot:SetAttribute("SlotIndex", slotIndex)
		end
	end

	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = model

	model.Parent = plots
end

---------------------------------------------------------------------------
-- Construction complète
---------------------------------------------------------------------------
-- parent : Workspace en jeu (ou le Workspace d'un fichier .rbxl lors du build hors Studio)
function MapBuilder.Build(parent: Instance): Folder
	local map = Instance.new("Folder")
	map.Name = "Map"

	part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 600, 600),
		CFrame = CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(55, 55, 65),
		Parent = map,
	})
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 120, 120),
		CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(80, 80, 95),
		Parent = map,
	})

	buildRift(map)
	buildRoad(map)

	local pathData = Instance.new("Configuration")
	pathData.Name = "PathData"
	pathData:SetAttribute("RingRadius", MapBuilder.RING_RADIUS)
	pathData:SetAttribute("RingCenter", Vector3.new(0, MapBuilder.PATH_Y, 0))
	pathData.Parent = map
	local points = MapBuilder.ComputePathPoints()
	pathData:SetAttribute("Count", #points)
	for i, point in points do
		pathData:SetAttribute("WP" .. i, point)
	end

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	for index = 1, MapBuilder.PLOT_COUNT do
		buildPlot(plots, index)
	end

	for _, name in { "Movers", "Portals" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = map
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CentralSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.6, 40)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(120, 90, 255)
	spawn.Transparency = 0.4
	spawn.Duration = 0 -- pas de ForceField à l'apparition
	spawn.Parent = map

	map.Parent = parent
	return map
end

return MapBuilder
