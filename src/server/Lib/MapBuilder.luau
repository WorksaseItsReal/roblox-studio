--[[
	MapBuilder
	==========
	Génère procéduralement une map jouable et décorée si Workspace.Map n'existe pas.
	Vous pouvez remplacer cette map par la vôtre (voir docs/MAP_BUILD.md) : il suffit
	de respecter les NOMS des instances de jeu, MapService vérifie le contrat.

	Thème : une île flottante au-dessus du vide. Au centre, la Rift (anneau de
	cristal entre deux piliers de roche) ; autour, un tapis roulant circulaire ;
	sur le pourtour, 8 bases ouvertes vers la Rift.

	Vue du dessus (Y vers le haut, -Z = "nord") :

	                 [Base 7] [Base 6]
	          [Base 8]                 [Base 5]
	                 .---- anneau ----.
	                |    (  RIFT  )    |      <- tapis roulant circulaire (rayon 70)
	                 '-------||-------'       <- double voie sortie/retour vers la Rift
	          [Base 1]                 [Base 4]
	                 [Base 2] [Base 3]

	Noms utilisés par le client pour les effets (recolorés selon la dimension) :
	  RingSegment, RiftTooth, Core, Swirl, Swirl2, Shard, RiftBeam, Crack,
	  RoadGlow, Chevron (attribut Index), Lamp
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
MapBuilder.ISLAND_RADIUS = 300

local RIFT_CENTER = Vector3.new(0, 17, 0)
local RIFT_RADIUS = 14
local ROAD_WIDTH = 14

local PLOT_COLORS = {
	Color3.fromRGB(255, 92, 92),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(90, 220, 130),
	Color3.fromRGB(70, 210, 255),
	Color3.fromRGB(80, 130, 255),
	Color3.fromRGB(170, 100, 255),
	Color3.fromRGB(255, 110, 200),
}

-- Couleurs d'ambiance
local C = {
	Grass = Color3.fromRGB(96, 178, 104),
	GrassDark = Color3.fromRGB(70, 140, 82),
	Cliff = Color3.fromRGB(128, 104, 92),
	CliffDark = Color3.fromRGB(88, 70, 66),
	Stone = Color3.fromRGB(110, 100, 128),
	StoneDark = Color3.fromRGB(70, 62, 88),
	Plaza = Color3.fromRGB(226, 222, 238),
	Road = Color3.fromRGB(44, 42, 60),
	Curb = Color3.fromRGB(215, 212, 230),
	Glow = Color3.fromRGB(150, 110, 255),
	Metal = Color3.fromRGB(60, 58, 76),
	Pedestal = Color3.fromRGB(232, 230, 242),
	Wood = Color3.fromRGB(120, 80, 56),
}

-- Emplacements dans une base (repère local, -Z = entrée)
local SLOT_COLUMNS = { -22, -11, 11, 22 }
local SLOT_ROWS = { -22, -13, -4, 5, 14, 23, 32 }

---------------------------------------------------------------------------
-- Aides de construction
---------------------------------------------------------------------------
local function make(
	className: string,
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	props: { [string]: any }?
): BasePart
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	for key, value in pairs(props or {}) do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function block(parent, name, size, cf, color, material, props)
	return make("Part", parent, name, size, cf, color, material, props)
end

-- Cylindre DEBOUT (le cylindre Roblox est orienté selon X : rotation de 90°)
local function cylinder(parent, name, height: number, diameter: number, center: CFrame, color, material, props)
	local p = make(
		"Part",
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		center * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		props
	);
	(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

-- Cylindre couché le long de Z (disques "face à -Z")
local function disc(parent, name, thickness: number, diameter: number, center: CFrame, color, material, props)
	local p = make(
		"Part",
		parent,
		name,
		Vector3.new(thickness, diameter, diameter),
		center * CFrame.Angles(0, math.rad(90), 0),
		color,
		material,
		props
	);
	(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, diameter: number, cf: CFrame, color, material, props)
	local p = make("Part", parent, name, Vector3.one * diameter, cf, color, material, props);
	(p :: Part).Shape = Enum.PartType.Ball
	return p
end

-- Ellipsoïde : bloc + SpecialMesh "Sphere" (aucun asset requis)
local function ellipsoid(parent, name, size: Vector3, cf: CFrame, color, material, props)
	local p = make("Part", parent, name, size, cf, color, material, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function noCollide()
	return { CanCollide = false, CanQuery = false, CanTouch = false }
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

-- Étiquette flottante stylée (icône + texte avec contour)
local function addLabel(parent: BasePart, text: string, offset: number, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(190, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(24, 20, 40)
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = frame
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(20, 14, 36)
	textStroke.Thickness = 2
	textStroke.Parent = label
	gui.Parent = parent
end

local function pointLight(parent: Instance, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

local function sparkle(parent: Instance, color: Color3, rate: number, size: number, speed: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

-- Générateur pseudo-aléatoire déterministe (la map est identique à chaque build)
local seed = 1337
local function rand(a: number, b: number): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return a + (seed / 2147483648) * (b - a)
end

---------------------------------------------------------------------------
-- Île
---------------------------------------------------------------------------
local function buildIsland(map: Folder)
	local island = Instance.new("Model")
	island.Name = "Island"
	local R = MapBuilder.ISLAND_RADIUS

	cylinder(island, "Ground", 6, R * 2, CFrame.new(0, -3, 0), C.Grass, Enum.Material.Grass)
	cylinder(island, "Cliff", 22, R * 2 - 6, CFrame.new(0, -16, 0), C.Cliff, Enum.Material.Rock)
	cylinder(island, "CliffLow", 30, R * 2 - 70, CFrame.new(0, -40, 0), C.CliffDark, Enum.Material.Rock)
	cylinder(island, "CliffBottom", 30, R * 2 - 220, CFrame.new(0, -66, 0), C.CliffDark, Enum.Material.Rock)

	-- Rochers suspendus sous l'île
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + rand(-0.15, 0.15)
		local radius = rand(R * 0.35, R * 0.8)
		local size = Vector3.new(rand(20, 40), rand(18, 36), rand(20, 40))
		block(
			island,
			"UnderRock",
			size,
			CFrame.new(math.cos(angle) * radius, -70 - rand(0, 30), math.sin(angle) * radius)
				* CFrame.Angles(rand(-0.4, 0.4), rand(0, 3), rand(-0.4, 0.4)),
			C.CliffDark,
			Enum.Material.Rock
		)
	end

	-- Bordure rocheuse continue (empêche de tomber dans le vide)
	local rimCount = 56
	for i = 1, rimCount do
		local angle = (i / rimCount) * math.pi * 2
		local chord = 2 * math.pi * (R - 4) / rimCount
		block(
			island,
			"Rim",
			Vector3.new(chord * 1.35, rand(5, 9), rand(5, 8)),
			CFrame.new(math.cos(angle) * (R - 4), 1.5, math.sin(angle) * (R - 4))
				* CFrame.Angles(0, -angle + math.pi / 2, 0)
				* CFrame.Angles(rand(-0.15, 0.15), 0, rand(-0.1, 0.1)),
			if i % 2 == 0 then C.Cliff else C.Stone,
			Enum.Material.Rock
		)
	end

	-- Esplanade centrale
	cylinder(island, "PlazaRim", 0.3, 124, CFrame.new(0, 0.15, 0), C.Glow, Enum.Material.Neon, { Name = "RoadGlow" })
	cylinder(island, "Plaza", 0.4, 120, CFrame.new(0, 0.2, 0), C.Plaza, Enum.Material.Marble)
	cylinder(island, "PlazaInner", 0.3, 64, CFrame.new(0, 0.3, 0), Color3.fromRGB(200, 196, 220), Enum.Material.Marble)

	island.Parent = map
end

---------------------------------------------------------------------------
-- Rift
---------------------------------------------------------------------------
local function buildRift(map: Folder)
	local rift = Instance.new("Model")
	rift.Name = "Rift"
	local center = RIFT_CENTER

	-- Estrade
	cylinder(rift, "Dais", 1.2, 26, CFrame.new(0, 0.6, 0), C.StoneDark, Enum.Material.Slate)
	cylinder(rift, "DaisGlow", 0.4, 22.6, CFrame.new(0, 1.3, 0), C.Glow, Enum.Material.Neon, { Name = "Crack" })
	cylinder(rift, "DaisTop", 1, 22, CFrame.new(0, 1.5, 0), C.Stone, Enum.Material.Slate)

	-- Piliers de roche qui encadrent la faille
	for _, side in { -1, 1 } do
		local x = side * (RIFT_RADIUS + 6)
		local y = 0
		for level = 1, 5 do
			local height = rand(6, 9)
			block(
				rift,
				"Pillar",
				Vector3.new(rand(5, 7), height, rand(5, 7)),
				CFrame.new(x + side * rand(-0.5, 0.8), y + height / 2, rand(-0.6, 0.6))
					* CFrame.Angles(rand(-0.08, 0.08), rand(0, 1.5), side * -0.06 * level),
				if level % 2 == 0 then C.Stone else C.StoneDark,
				Enum.Material.Rock
			)
			y += height * 0.85
		end
		-- Rochers flottants au sommet
		for i = 1, 3 do
			block(
				rift,
				"FloatingRock",
				Vector3.new(rand(2, 4), rand(2, 4), rand(2, 4)),
				CFrame.new(x + rand(-3, 3), y + 3 + i * 3, rand(-3, 3))
					* CFrame.Angles(rand(0, 3), rand(0, 3), rand(0, 3)),
				C.Stone,
				Enum.Material.Rock,
				noCollide()
			)
		end
		-- Cristaux incrustés dans le pilier
		for i = 1, 3 do
			block(
				rift,
				"RiftTooth",
				Vector3.new(1.2, rand(3, 5), 1.2),
				CFrame.new(x - side * 2.8, 6 + i * 7, rand(-1.5, 1.5)) * CFrame.Angles(0, 0, side * rand(0.5, 0.9)),
				Color3.fromRGB(255, 200, 80),
				Enum.Material.Neon,
				noCollide()
			)
		end
	end

	-- Anneau de la faille
	local segments = 36
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		block(
			rift,
			"RingSegment",
			Vector3.new(2.9, 2.6, 3.2),
			CFrame.new(center) * CFrame.Angles(0, 0, angle) * CFrame.new(0, RIFT_RADIUS, 0),
			Color3.fromRGB(255, 90, 20),
			Enum.Material.Neon,
			noCollide()
		)
		-- Bord sombre extérieur (donne de l'épaisseur)
		block(
			rift,
			"RingBack",
			Vector3.new(3, 1.6, 4.2),
			CFrame.new(center) * CFrame.Angles(0, 0, angle) * CFrame.new(0, RIFT_RADIUS + 1.8, 0),
			C.StoneDark,
			Enum.Material.Slate,
			noCollide()
		)
	end
	-- Dents de cristal : la faille a l'air "déchirée"
	for i = 1, 20 do
		local angle = (i / 20) * math.pi * 2 + rand(-0.08, 0.08)
		local length = rand(3, 8)
		block(
			rift,
			"RiftTooth",
			Vector3.new(1.4, length, 1.4),
			CFrame.new(center)
				* CFrame.Angles(0, 0, angle)
				* CFrame.new(0, RIFT_RADIUS + 2.4 + length / 2, 0)
				* CFrame.Angles(rand(-0.3, 0.3), rand(0, 1), rand(-0.25, 0.25)),
			Color3.fromRGB(255, 200, 80),
			Enum.Material.Neon,
			noCollide()
		)
	end

	-- Vortex en couches (face à -Z, côté chemin)
	local core = disc(
		rift,
		"Core",
		0.6,
		RIFT_RADIUS * 2 - 1,
		CFrame.new(center),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon,
		noCollide()
	)
	core.Transparency = 0.05
	disc(
		rift,
		"Swirl",
		1.0,
		RIFT_RADIUS * 1.6,
		CFrame.new(center),
		Color3.fromRGB(255, 220, 120),
		Enum.Material.ForceField,
		noCollide()
	)
	disc(
		rift,
		"Abyss",
		0.9,
		RIFT_RADIUS * 1.05,
		CFrame.new(center),
		Color3.fromRGB(16, 8, 30),
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	disc(
		rift,
		"Swirl2",
		1.3,
		RIFT_RADIUS * 0.9,
		CFrame.new(center),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.ForceField,
		noCollide()
	)
	ball(rift, "Eye", 2.4, CFrame.new(center), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, noCollide())

	pointLight(core, core.Color, 70, 4)
	local particles = sparkle(core, Color3.fromRGB(255, 160, 60), 40, 1.4, 12)
	particles.Name = "RiftParticles"
	particles.SpreadAngle = Vector2.new(35, 35)

	-- Colonne de lumière visible de toute l'île
	cylinder(rift, "RiftBeam", 400, 9, CFrame.new(0, 34 + 200, 0), Color3.fromRGB(255, 140, 60), Enum.Material.Neon, {
		Transparency = 0.86,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})

	-- Fissures lumineuses au sol
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2 + rand(-0.12, 0.12)
		local r0, r1 = 13, rand(24, 34)
		local mid = (r0 + r1) / 2
		local bend = rand(-0.18, 0.18)
		for s = 0, 1 do
			local a = angle + bend * s
			local from = (if s == 0 then r0 else mid)
			local to = (if s == 0 then mid else r1)
			local p0 = Vector3.new(math.cos(a) * from, 0.42, math.sin(a) * from)
			local p1 = Vector3.new(math.cos(a) * to, 0.42, math.sin(a) * to)
			block(
				rift,
				"Crack",
				Vector3.new(0.7 - s * 0.25, 0.1, (p1 - p0).Magnitude + 0.5),
				CFrame.lookAt((p0 + p1) / 2, p1),
				Color3.fromRGB(255, 120, 40),
				Enum.Material.Neon,
				noCollide()
			)
		end
	end

	-- Éclats en orbite (animés côté client)
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		block(
			rift,
			"Shard",
			Vector3.new(1.4, 3.2, 1.4),
			CFrame.new(center + Vector3.new(math.cos(angle) * 24, 0, math.sin(angle) * 24)),
			Color3.fromRGB(255, 200, 60),
			Enum.Material.Neon,
			noCollide()
		)
	end

	rift.PrimaryPart = core
	rift.Parent = map
end

---------------------------------------------------------------------------
-- Chemin (tapis roulant)
---------------------------------------------------------------------------
-- Renvoie la liste ordonnée des waypoints du chemin principal
function MapBuilder.ComputePathPoints(): { Vector3 }
	local R = MapBuilder.RING_RADIUS
	local y = MapBuilder.PATH_Y
	local points = {
		Vector3.new(-3, y, -14), -- sortie de la Rift
		Vector3.new(-3, y, -R),
	}
	-- Tour complet de l'anneau (angles décroissants)
	local steps = 32
	for k = 1, steps - 1 do
		local theta = -math.pi / 2 - k * (2 * math.pi / steps)
		table.insert(points, Vector3.new(R * math.cos(theta), y, R * math.sin(theta)))
	end
	table.insert(points, Vector3.new(3, y, -R))
	table.insert(points, Vector3.new(3, y, -14)) -- retour dans la Rift
	return points
end

-- Chevron lumineux "flèche" posé sur la route, pointant dans "direction"
local function chevron(parent: Instance, position: Vector3, direction: Vector3, index: number)
	local base = CFrame.lookAt(position, position + direction)
	for _, side in { -1, 1 } do
		local arm = block(
			parent,
			"Chevron",
			Vector3.new(0.6, 0.08, 3.4),
			base * CFrame.new(side * 1.05, 0, 0.6) * CFrame.Angles(0, side * math.rad(-38), 0),
			C.Glow,
			Enum.Material.Neon,
			noCollide()
		)
		arm:SetAttribute("Index", index)
	end
end

local function buildRoad(map: Folder)
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = map

	local R = MapBuilder.RING_RADIUS
	local y = MapBuilder.PATH_Y
	local segments = 48
	local segmentLength = 2 * math.pi * R / segments
	for i = 1, segments do
		local theta = (i / segments) * math.pi * 2
		local position = Vector3.new(R * math.cos(theta), 0, R * math.sin(theta))
		local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta))
		local cf = CFrame.lookAt(position, position + tangent)
		block(
			road,
			"RoadSegment",
			Vector3.new(ROAD_WIDTH, y, segmentLength * 1.07),
			cf * CFrame.new(0, y / 2, 0),
			C.Road,
			Enum.Material.SmoothPlastic
		)
		for _, side in { -1, 1 } do
			local edge = side * (ROAD_WIDTH / 2 + 0.6)
			block(
				road,
				"Curb",
				Vector3.new(1.2, 0.9, segmentLength * 1.12),
				cf * CFrame.new(edge, 0.45, 0),
				C.Curb,
				Enum.Material.SmoothPlastic
			)
			block(
				road,
				"RoadGlow",
				Vector3.new(0.35, 0.06, segmentLength * 1.07),
				cf * CFrame.new(side * (ROAD_WIDTH / 2 - 0.6), y + 0.03, 0),
				C.Glow,
				Enum.Material.Neon,
				noCollide()
			)
		end
		-- Sens de marche : angles décroissants => -tangente
		local index = (segments - i) % segments
		chevron(road, position + Vector3.new(0, y + 0.05, 0), -tangent, index)
	end

	-- Double voie Rift <-> anneau
	local spokeLength = R - 14
	local spokeCenter = CFrame.new(0, 0, -(R + 14) / 2)
	block(
		road,
		"Spoke",
		Vector3.new(ROAD_WIDTH, y, spokeLength),
		spokeCenter * CFrame.new(0, y / 2, 0),
		C.Road,
		Enum.Material.SmoothPlastic
	)
	block(
		road,
		"RoadGlow",
		Vector3.new(0.4, 0.06, spokeLength),
		spokeCenter * CFrame.new(0, y + 0.03, 0),
		C.Glow,
		Enum.Material.Neon,
		noCollide()
	)
	for _, side in { -1, 1 } do
		block(
			road,
			"Curb",
			Vector3.new(1.2, 0.9, spokeLength),
			spokeCenter * CFrame.new(side * (ROAD_WIDTH / 2 + 0.6), 0.45, 0),
			C.Curb,
			Enum.Material.SmoothPlastic
		)
	end
	local count = 6
	for k = 0, count - 1 do
		local z = -16 - k * (spokeLength - 4) / (count - 1)
		chevron(road, Vector3.new(-3, y + 0.05, z), -Vector3.zAxis, k) -- sortie
		chevron(road, Vector3.new(3, y + 0.05, z), Vector3.zAxis, count - k) -- retour
	end

	-- Lampadaires
	for i = 0, 15 do
		local angle = math.rad(11.25 + i * 22.5)
		local base =
			Vector3.new(math.cos(angle) * (R + ROAD_WIDTH / 2 + 4.5), 0, math.sin(angle) * (R + ROAD_WIDTH / 2 + 4.5))
		cylinder(road, "LampPost", 11, 0.8, CFrame.new(base + Vector3.new(0, 5.5, 0)), C.Metal, Enum.Material.Metal)
		cylinder(road, "LampBase", 1, 2.2, CFrame.new(base + Vector3.new(0, 0.5, 0)), C.Metal, Enum.Material.Metal)
		local lamp =
			ball(road, "Lamp", 2.2, CFrame.new(base + Vector3.new(0, 11.6, 0)), C.Glow, Enum.Material.Neon, noCollide())
		pointLight(lamp, C.Glow, 20, 1.5)
	end
end

---------------------------------------------------------------------------
-- Décor
---------------------------------------------------------------------------
local TREE_COLORS = {
	Color3.fromRGB(110, 200, 110),
	Color3.fromRGB(90, 180, 120),
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(160, 120, 255),
}

local function tree(parent: Instance, position: Vector3, scale: number)
	local height = 9 * scale
	cylinder(
		parent,
		"Trunk",
		height,
		1.6 * scale,
		CFrame.new(position + Vector3.new(0, height / 2, 0)),
		C.Wood,
		Enum.Material.Wood
	)
	local color = TREE_COLORS[math.floor(rand(1, #TREE_COLORS + 0.999))]
	for i = 1, 3 do
		local size = Vector3.new(rand(7, 9), rand(5, 6.5), rand(7, 9)) * scale
		ellipsoid(
			parent,
			"Leaves",
			size,
			CFrame.new(
				position + Vector3.new(rand(-1.5, 1.5) * scale, height + (i - 1) * 2.6 * scale, rand(-1.5, 1.5) * scale)
			),
			color:Lerp(Color3.new(1, 1, 1), (i - 1) * 0.08),
			Enum.Material.SmoothPlastic
		)
	end
end

local function crystalCluster(parent: Instance, position: Vector3, color: Color3, scale: number)
	for i = 1, 5 do
		local height = rand(4, 9) * scale
		block(
			parent,
			"Crystal",
			Vector3.new(1.6, height, 1.6) * Vector3.new(scale, 1, scale),
			CFrame.new(position + Vector3.new(rand(-2, 2) * scale, height / 2 - 0.5, rand(-2, 2) * scale))
				* CFrame.Angles(rand(-0.35, 0.35), rand(0, 3), rand(-0.35, 0.35)),
			color,
			if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Glass,
			{ Transparency = if i % 2 == 0 then 0 else 0.2 }
		)
	end
	block(
		parent,
		"CrystalRock",
		Vector3.new(5, 2, 5) * scale,
		CFrame.new(position) * CFrame.Angles(0, rand(0, 3), 0),
		C.Stone,
		Enum.Material.Rock
	)
end

local function floatingIsland(parent: Instance, position: Vector3, radius: number)
	cylinder(parent, "IslandTop", 3, radius * 2, CFrame.new(position), C.Grass, Enum.Material.Grass)
	cylinder(
		parent,
		"IslandRock",
		8,
		radius * 1.7,
		CFrame.new(position - Vector3.new(0, 5, 0)),
		C.Cliff,
		Enum.Material.Rock
	)
	cylinder(
		parent,
		"IslandRock",
		8,
		radius * 1.1,
		CFrame.new(position - Vector3.new(0, 11, 0)),
		C.CliffDark,
		Enum.Material.Rock
	)
	tree(parent, position + Vector3.new(0, 1.5, 0), radius / 12)
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 220, 90),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(170, 140, 255),
}

-- Vrai si la position tombe dans une base (marge comprise)
local function insideAnyPlot(position: Vector3): boolean
	for index = 1, MapBuilder.PLOT_COUNT do
		local angle = math.rad((index - 1) * (360 / MapBuilder.PLOT_COUNT) + 22.5)
		local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MapBuilder.PLOT_RADIUS
		local localPos = CFrame.lookAt(center, Vector3.zero):PointToObjectSpace(position)
		if
			math.abs(localPos.X) < MapBuilder.PLOT_WIDTH / 2 + 5
			and math.abs(localPos.Z) < MapBuilder.PLOT_DEPTH / 2 + 16
		then
			return true
		end
	end
	return false
end

local function buildDecor(map: Folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map

	-- Allées pavées de la route jusqu'à chaque base
	local R = MapBuilder.RING_RADIUS
	local fromRadius = R + ROAD_WIDTH / 2 + 1.2
	local toRadius = MapBuilder.PLOT_RADIUS - MapBuilder.PLOT_DEPTH / 2
	for index = 1, MapBuilder.PLOT_COUNT do
		local angle = math.rad((index - 1) * (360 / MapBuilder.PLOT_COUNT) + 22.5)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = toRadius - fromRadius
		local mid = dir * (fromRadius + length / 2)
		local cf = CFrame.lookAt(mid, mid + dir)
		block(
			decor,
			"Walkway",
			Vector3.new(12, 0.1, length),
			cf * CFrame.new(0, 0.05, 0),
			Color3.fromRGB(200, 192, 214),
			Enum.Material.Pavement
		)
		for _, side in { -1, 1 } do
			block(
				decor,
				"WalkwayEdge",
				Vector3.new(0.8, 0.3, length),
				cf * CFrame.new(side * 6.2, 0.15, 0),
				C.StoneDark,
				Enum.Material.Slate
			)
		end
	end

	-- Nuances de gazon
	for _ = 1, 16 do
		local angle = rand(0, math.pi * 2)
		local radius = rand(120, 270)
		local size = rand(18, 40)
		cylinder(
			decor,
			"GrassPatch",
			0.06,
			size,
			CFrame.new(math.cos(angle) * radius, 0.02, math.sin(angle) * radius),
			C.GrassDark,
			Enum.Material.Grass,
			noCollide()
		)
	end

	-- Fleurs
	local placed = 0
	while placed < 70 do
		local angle = rand(0, math.pi * 2)
		local radius = rand(92, 285)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not insideAnyPlot(position) then
			placed += 1
			local color = FLOWER_COLORS[math.floor(rand(1, #FLOWER_COLORS + 0.999))]
			for _ = 1, 3 do
				local offset = Vector3.new(rand(-1.4, 1.4), 0, rand(-1.4, 1.4))
				cylinder(
					decor,
					"Stem",
					0.9,
					0.18,
					CFrame.new(position + offset + Vector3.new(0, 0.45, 0)),
					C.GrassDark,
					Enum.Material.SmoothPlastic,
					noCollide()
				)
				ball(
					decor,
					"Flower",
					0.75,
					CFrame.new(position + offset + Vector3.new(0, 1.0, 0)),
					color,
					Enum.Material.SmoothPlastic,
					noCollide()
				)
			end
		end
	end

	-- Arbres entre les bases
	for k = 0, 7 do
		local angle = math.rad(k * 45)
		for _, radius in { 205, 250 } do
			local jitter = rand(-0.05, 0.05)
			tree(
				decor,
				Vector3.new(math.cos(angle + jitter) * radius, 0, math.sin(angle + jitter) * radius),
				rand(0.9, 1.4)
			)
		end
	end
	-- Cristaux entre la route et les bases (hors des trajets des créatures)
	for k = 0, 7 do
		local angle = math.rad(k * 45)
		crystalCluster(decor, Vector3.new(math.cos(angle) * 100, 0, math.sin(angle) * 100), PLOT_COLORS[k + 1], 1)
	end
	-- Îlots flottants à l'horizon
	for k = 0, 5 do
		local angle = math.rad(k * 60 + 15)
		floatingIsland(decor, Vector3.new(math.cos(angle) * 390, rand(10, 60), math.sin(angle) * 390), rand(14, 22))
	end
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
	local dark = color:Lerp(Color3.fromRGB(30, 28, 44), 0.55)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.45)
	local W, D, H = MapBuilder.PLOT_WIDTH, MapBuilder.PLOT_DEPTH, MapBuilder.WALL_HEIGHT

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotId", index)
	model:SetAttribute("PlotColor", color)

	local function at(x: number, y: number, z: number): CFrame
		return plotCFrame * CFrame.new(x, y, z)
	end

	-- Sol : dalle + tapis intérieur + allée centrale
	local floor = block(model, "Floor", Vector3.new(W, 1, D), plotCFrame, dark, Enum.Material.SmoothPlastic)
	model.PrimaryPart = floor
	block(
		model,
		"FloorInset",
		Vector3.new(W - 4, 0.1, D - 4),
		at(0, 0.55, 0),
		dark:Lerp(Color3.new(1, 1, 1), 0.12),
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	block(
		model,
		"Aisle",
		Vector3.new(10, 0.12, D - 6),
		at(0, 0.58, 1),
		color:Lerp(Color3.fromRGB(30, 28, 44), 0.25),
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	for _, side in { -1, 1 } do
		block(
			model,
			"AisleGlow",
			Vector3.new(0.4, 0.14, D - 6),
			at(side * 5.2, 0.58, 1),
			color,
			Enum.Material.Neon,
			noCollide()
		)
	end

	-- Murs : muret plein + vitre + main courante + poteaux à lampe
	local function wall(cf: CFrame, length: number)
		block(
			model,
			"Wall",
			Vector3.new(length, 4, 1.2),
			cf * CFrame.new(0, 2.5, 0),
			color,
			Enum.Material.SmoothPlastic
		)
		block(
			model,
			"WallGlass",
			Vector3.new(length, H - 4, 0.4),
			cf * CFrame.new(0, 4.5 + (H - 4) / 2, 0),
			light,
			Enum.Material.Glass,
			{ Transparency = 0.55 }
		)
		block(
			model,
			"WallCap",
			Vector3.new(length + 0.4, 0.8, 1.6),
			cf * CFrame.new(0, H + 0.9, 0),
			light,
			Enum.Material.SmoothPlastic
		)
		block(
			model,
			"WallTrim",
			Vector3.new(length, 0.3, 1.4),
			cf * CFrame.new(0, 4.6, 0),
			color,
			Enum.Material.Neon,
			noCollide()
		)
		local posts = math.max(2, math.floor(length / 14) + 1)
		for p = 0, posts - 1 do
			local x = -length / 2 + p * (length / (posts - 1))
			block(
				model,
				"Post",
				Vector3.new(2, H + 1.6, 2),
				cf * CFrame.new(x, (H + 1.6) / 2 + 0.5, 0),
				dark,
				Enum.Material.SmoothPlastic
			)
			ball(model, "PostLamp", 1.6, cf * CFrame.new(x, H + 2.6, 0), color, Enum.Material.Neon, noCollide())
		end
	end
	wall(at(0, 0, D / 2), W)
	wall(at(-W / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), D)
	wall(at(W / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), D)

	-- Arche d'entrée
	for _, side in { -1, 1 } do
		block(
			model,
			"ArchPillar",
			Vector3.new(3.4, H + 8, 3.4),
			at(side * (W / 2), (H + 8) / 2 + 0.5, -D / 2),
			light,
			Enum.Material.SmoothPlastic
		)
		block(
			model,
			"ArchTrim",
			Vector3.new(3.6, 0.5, 3.6),
			at(side * (W / 2), 5, -D / 2),
			color,
			Enum.Material.Neon,
			noCollide()
		)
		block(
			model,
			"ArchTrim",
			Vector3.new(3.6, 0.5, 3.6),
			at(side * (W / 2), H + 4, -D / 2),
			color,
			Enum.Material.Neon,
			noCollide()
		)
		ball(model, "ArchLamp", 3, at(side * (W / 2), H + 9.6, -D / 2), color, Enum.Material.Neon, noCollide())
	end
	block(model, "ArchBeam", Vector3.new(W + 3.4, 3, 3.4), at(0, H + 7, -D / 2), light, Enum.Material.SmoothPlastic)

	-- Barrière (désactivée par défaut : invisible et traversable)
	block(
		model,
		"Barrier",
		Vector3.new(W - 3.4, H + 5, 1),
		at(0, (H + 5) / 2 + 0.5, -D / 2),
		color,
		Enum.Material.ForceField,
		{
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}
	)

	-- Panneau du propriétaire, fixé sous la poutre de l'arche
	local sign = block(
		model,
		"Sign",
		Vector3.new(34, 5, 0.6),
		at(0, H + 7, -D / 2 - 1.9),
		Color3.fromRGB(24, 20, 40),
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 24
	surface.LightInfluence = 0
	local signFrame = Instance.new("Frame")
	signFrame.Size = UDim2.new(1, -16, 1, -16)
	signFrame.Position = UDim2.fromOffset(8, 8)
	signFrame.BackgroundColor3 = Color3.fromRGB(32, 26, 56)
	signFrame.Parent = surface
	local signCorner = Instance.new("UICorner")
	signCorner.CornerRadius = UDim.new(0, 24)
	signCorner.Parent = signFrame
	local signStroke = Instance.new("UIStroke")
	signStroke.Color = color
	signStroke.Thickness = 8
	signStroke.Parent = signFrame
	local signGradient = Instance.new("UIGradient")
	signGradient.Color = ColorSequence.new(Color3.fromRGB(70, 60, 110), Color3.fromRGB(30, 24, 52))
	signGradient.Rotation = 90
	signGradient.Parent = signFrame
	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "Text"
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.new(1, -40, 1, -20)
	signLabel.Position = UDim2.fromOffset(20, 10)
	signLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.Text = "Base libre"
	signLabel.Parent = signFrame
	local signTextStroke = Instance.new("UIStroke")
	signTextStroke.Color = Color3.fromRGB(16, 12, 30)
	signTextStroke.Thickness = 4
	signTextStroke.Parent = signLabel
	surface.Parent = sign

	-- Point d'apparition du propriétaire (cercle lumineux)
	cylinder(
		model,
		"Spawn",
		0.2,
		7,
		at(0, 0.62, -30),
		color,
		Enum.Material.Neon,
		{ Transparency = 0.35, CanCollide = false }
	)
	cylinder(model, "SpawnInner", 0.22, 5.4, at(0, 0.63, -30), dark, Enum.Material.SmoothPlastic, noCollide())

	-- Arrivée du portail de raccourci (DEVANT la base, hors barrière) : rune au sol
	cylinder(
		model,
		"ShortcutLanding",
		0.15,
		7,
		at(0, 0.14, -D / 2 - 10),
		Color3.fromRGB(150, 130, 255),
		Enum.Material.Neon,
		{
			Transparency = 0.55,
			CanCollide = false,
		}
	)

	-- Point de passage des créatures qui rentrent à la base
	block(
		model,
		"Entrance",
		Vector3.new(2, 0.2, 2),
		at(0, 0.6, -D / 2 - 5),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		{
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}
	)

	-- Bouton de barrière : socle + gros bouton rouge
	local lockButton = block(
		model,
		"LockButton",
		Vector3.new(4.4, 2.6, 4.4),
		at(-W / 2 + 8, 1.8, -D / 2 + 8),
		C.Metal,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"LockTrim",
		Vector3.new(4.6, 0.4, 4.6),
		at(-W / 2 + 8, 0.8, -D / 2 + 8),
		color,
		Enum.Material.Neon,
		noCollide()
	)
	cylinder(
		model,
		"LockButtonTop",
		0.9,
		3.2,
		at(-W / 2 + 8, 3.5, -D / 2 + 8),
		Color3.fromRGB(255, 60, 70),
		Enum.Material.Neon,
		noCollide()
	)
	addPrompt(lockButton, "LockPrompt", "Activer la barrière", "Base", 0.4, Enum.KeyCode.E)
	addLabel(lockButton, "🛡️ Barrière", 4.5, Color3.fromRGB(255, 90, 100))

	-- Portail de fusion : marches + anneau + vortex
	local fx, fz = W / 2 - 9, -D / 2 + 9
	cylinder(model, "FusionStep", 0.8, 10, at(fx, 0.9, fz), C.Metal, Enum.Material.SmoothPlastic)
	cylinder(model, "FusionStep", 0.8, 7.6, at(fx, 1.7, fz), dark, Enum.Material.SmoothPlastic)
	local portalCenter = at(fx, 6.6, fz)
	local fusionColor = Color3.fromRGB(190, 110, 255)
	for i = 1, 20 do
		local a = (i / 20) * math.pi * 2
		block(
			model,
			"FusionRing",
			Vector3.new(1.6, 1.1, 1.4),
			portalCenter * CFrame.Angles(0, 0, a) * CFrame.new(0, 4.2, 0),
			fusionColor,
			Enum.Material.Neon,
			noCollide()
		)
	end
	local fusion = disc(
		model,
		"FusionPortal",
		0.5,
		7.6,
		portalCenter,
		Color3.fromRGB(120, 60, 220),
		Enum.Material.Neon,
		{ CanCollide = false, Transparency = 0.15 }
	)
	disc(
		model,
		"FusionSwirl",
		0.7,
		5.6,
		portalCenter,
		Color3.fromRGB(255, 220, 255),
		Enum.Material.ForceField,
		noCollide()
	)
	addPrompt(fusion, "FusionPrompt", "Fusionner", "Portail de fusion", 0, Enum.KeyCode.E)
	addLabel(fusion, "🌀 Fusion", 6.5, fusionColor)
	sparkle(fusion, fusionColor, 10, 0.4, 2)
	pointLight(fusion, fusionColor, 16, 2)

	-- Cristaux décoratifs dans les coins du fond
	crystalCluster(model, (at(-W / 2 + 5, 0.5, D / 2 - 5)).Position, color, 0.8)
	crystalCluster(model, (at(W / 2 - 5, 0.5, D / 2 - 5)).Position, color, 0.8)

	-- Emplacements : socles ronds avec anneau lumineux
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	local slotIndex = 0
	for _, z in SLOT_ROWS do
		for _, x in SLOT_COLUMNS do
			slotIndex += 1
			local slot = cylinder(
				slots,
				"Slot" .. slotIndex,
				0.7,
				6.4,
				at(x, 0.95, z),
				C.Pedestal,
				Enum.Material.SmoothPlastic,
				{
					CanCollide = true,
				}
			)
			slot:SetAttribute("SlotIndex", slotIndex)
			local ring = cylinder(slot, "SlotRing", 0.5, 7.2, at(x, 0.85, z), color, Enum.Material.Neon, noCollide())
			ring.Transparency = 1
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
	seed = 1337
	local map = Instance.new("Folder")
	map.Name = "Map"

	buildIsland(map)
	buildRift(map)
	buildRoad(map)
	buildDecor(map)

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
	spawn.Shape = Enum.PartType.Cylinder
	spawn.Size = Vector3.new(0.6, 10, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 42) * CFrame.Angles(0, 0, math.rad(90))
	spawn.Material = Enum.Material.Neon
	spawn.Color = C.Glow
	spawn.Transparency = 0.3
	spawn.Duration = 0 -- pas de ForceField à l'apparition
	spawn.Parent = map

	map.Parent = parent
	return map
end

return MapBuilder
