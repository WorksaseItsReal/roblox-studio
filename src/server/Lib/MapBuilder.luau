--[[
	MapBuilder
	==========
	Génère procéduralement une map jouable et décorée si Workspace.Map n'existe pas.
	Vous pouvez remplacer cette map par la vôtre (voir docs/MAP_BUILD.md) : il suffit
	de respecter les NOMS des instances de jeu, MapService vérifie le contrat.

	Style « Steal a … » (docs/ART_DIRECTION.md) : une île flottante, un long tapis
	rouge en ligne droite où défilent les créatures, et 4 bases de chaque côté dont
	l'entrée fait face au tapis.

	Vue du dessus (Y vers le haut, -Z = "nord") :

	                   [  RIFT  ]        <- portail géant face à +Z, Z = -195 (rayon 22)
	         [Classement]  |  |  [Classement]
	                       |  |
	      [Base 1] ◄────   |  |   ────► [Base 2]     Z = -105
	      [Base 3]         |  |         [Base 4]     Z =  -35
	      [Base 5]         |  |         [Base 6]     Z =  +35
	      [Base 7]         |  |         [Base 8]     Z = +105
	                       |  |
	                   [ sortie ]        <- petit portail sombre, Z = +195

	Tapis rouge (X = 0, largeur 14) bordé d'or, trottoirs gris clair de X = ±8 à ±18,
	bases centrées en X = ±66. Les créatures marchent vers +Z.

	Noms utilisés par le client pour les effets (recolorés selon la dimension) :
	  RingSegment, RiftTooth, Core, RiftDeep, Swirl, Swirl2, SwirlArm (tournent autour
	  de l'axe de la Rift), Shard (orbite de rayon Rift.ShardOrbit), RiftBeam, Crack,
	  RoadGlow, Chevron (attribut Index), Lamp, ExitSwirl (rotation seulement)
]]

local MapBuilder = {}

-- Géométrie (studs)
MapBuilder.PATH_Y = 0.5 -- dessus du tapis : les créatures marchent à cette hauteur
MapBuilder.CARPET_WIDTH = 14
MapBuilder.CARPET_START_Z = -185
MapBuilder.CARPET_END_Z = 185
MapBuilder.RIFT_Z = -195
MapBuilder.EXIT_Z = 195
MapBuilder.SIDEWALK_INNER = 8
MapBuilder.SIDEWALK_OUTER = 18
MapBuilder.PLOT_COUNT = 8
MapBuilder.PLOT_X = 66 -- distance entre l'axe du tapis et le centre des bases
MapBuilder.PLOT_ROWS_Z = { -105, -35, 35, 105 }
MapBuilder.PLOT_WIDTH = 60 -- le long du tapis
MapBuilder.PLOT_DEPTH = 84 -- de l'entrée au mur du fond
MapBuilder.WALL_HEIGHT = 8
MapBuilder.ISLAND_RADIUS = 300

local PATH_Y = MapBuilder.PATH_Y
local FLOOR_TOP = 0.6 -- dessus du sol des bases et des trottoirs
local OPENING = 24 -- largeur de l'entrée des bases
local ARCH_CLEAR = 12 -- hauteur libre sous l'arche (= hauteur de la barrière)
-- Rayon 22 (la spec parle d'un centre vers Y = 17) : la Rift, emblème du jeu, doit se
-- lire depuis l'autre bout du tapis (370 studs) et dominer les tableaux de classement
local RIFT_RADIUS = 22
-- Le bas de l'anneau affleure le tapis : les créatures sortent du vortex
local RIFT_CENTER = Vector3.new(0, PATH_Y + RIFT_RADIUS, MapBuilder.RIFT_Z)
local SHARD_ORBIT = RIFT_RADIUS + 17 -- orbite des éclats : au-delà des piliers (~37 studs), avant les tableaux
-- Anneau sombre du vortex : couleur de la faille assombrie (même valeur côté client)
local DEEP_SHADE = 0.45
local EXIT_RADIUS = 9
local EXIT_CENTER = Vector3.new(0, PATH_Y + EXIT_RADIUS, MapBuilder.EXIT_Z)

-- Couleurs d'équipe (une par base, dans l'ordre des PlotId)
local PLOT_COLORS = {
	Color3.fromRGB(255, 64, 64), -- rouge
	Color3.fromRGB(255, 140, 30), -- orange
	Color3.fromRGB(255, 210, 40), -- jaune
	Color3.fromRGB(60, 210, 90), -- vert
	Color3.fromRGB(30, 200, 255), -- cyan
	Color3.fromRGB(50, 110, 255), -- bleu
	Color3.fromRGB(160, 80, 255), -- violet
	Color3.fromRGB(255, 80, 190), -- rose
}

-- Palette du monde (docs/ART_DIRECTION.md) : couleurs franches, aucun pastel
local C = {
	Grass = Color3.fromRGB(86, 196, 70),
	GrassDark = Color3.fromRGB(66, 168, 58),
	Leaves = Color3.fromRGB(52, 172, 62),
	Dirt = Color3.fromRGB(176, 116, 66),
	Cliff = Color3.fromRGB(146, 98, 64),
	CliffDark = Color3.fromRGB(104, 72, 56),
	Stone = Color3.fromRGB(160, 162, 176),
	StoneDark = Color3.fromRGB(74, 68, 96),
	RiftStone = Color3.fromRGB(52, 30, 100),
	RiftStoneLight = Color3.fromRGB(84, 52, 156),
	Carpet = Color3.fromRGB(215, 38, 52),
	CarpetDark = Color3.fromRGB(176, 24, 40),
	Gold = Color3.fromRGB(255, 200, 60),
	Sidewalk = Color3.fromRGB(232, 232, 240),
	SidewalkJoint = Color3.fromRGB(206, 206, 220),
	White = Color3.fromRGB(255, 255, 255),
	Floor = Color3.fromRGB(245, 245, 250),
	Ink = Color3.fromRGB(0, 0, 0),
	Metal = Color3.fromRGB(46, 48, 60),
	-- Anthracite des poutres et plinthes : un mélange couleur d'équipe + noir donnerait
	-- des olive / marron ternes sous les panneaux jaunes et orange
	Trim = Color3.fromRGB(30, 30, 38),
	Wood = Color3.fromRGB(128, 82, 48),
	Laser = Color3.fromRGB(255, 28, 40),
	LensOff = Color3.fromRGB(90, 24, 30), -- lentille éteinte (BaseDefenseService l'allume)
	SlotLocked = Color3.fromRGB(217, 219, 230), -- socle verrouillé (mêmes valeurs que PlotService)
	SlotRingLocked = Color3.fromRGB(78, 80, 94),
	LockRed = Color3.fromRGB(255, 36, 48),
	Rift = Color3.fromRGB(255, 90, 20), -- dimension de départ (Lave), recolorée par le client
	RiftAccent = Color3.fromRGB(255, 200, 60),
	Magic = Color3.fromRGB(160, 80, 255),
	Navigation = Color3.fromRGB(50, 150, 255),
	Exit = Color3.fromRGB(150, 60, 255),
	ExitStone = Color3.fromRGB(48, 36, 70),
}

-- Emplacements dans une base (repère local, -Z = entrée)
local SLOT_COLUMNS = { -22, -11, 11, 22 }
local SLOT_ROWS = { -22, -13, -4, 5, 14, 23, 32 }

---------------------------------------------------------------------------
-- Aides de construction
---------------------------------------------------------------------------

-- Équivalent de CFrame.lookAt construit avec CFrame.fromMatrix.
-- La map est « cuite » hors de Roblox par Lune (scripts/build-place.luau), dont
-- CFrame.lookAt renvoie une orientation en miroir : ce helper donne le même
-- résultat que Roblox dans les deux environnements. Ne pas le remplacer.
local function lookAt(position: Vector3, target: Vector3): CFrame
	local look = (target - position).Unit
	local right = look:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-6 then
		right = Vector3.xAxis
	end
	right = right.Unit
	local up = right:Cross(look)
	return CFrame.fromMatrix(position, right, up, -look)
end

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

-- Repère LOGIQUE invisible et debout (rotation sans roulis) : pour Spawn et
-- ShortcutLanding, le personnage téléporté prend sa rotation. Un cylindre (couché
-- sur X puis tourné) le coucherait : le disque visible est une pièce séparée.
local function marker(parent, name, size: Vector3, cf: CFrame)
	return make("Part", parent, name, size, cf, C.White, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

-- Cylindre couché le long de Z (disques "face à ±Z")
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

-- Barreau le long de l'axe X local (faisceaux laser)
local function rod(parent, name, length: number, diameter: number, cf: CFrame, color, material, props)
	local p = make("Part", parent, name, Vector3.new(length, diameter, diameter), cf, color, material, props);
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

local function noCollide(extra: { [string]: any }?)
	local props: { [string]: any } = { CanCollide = false, CanQuery = false, CanTouch = false }
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return props
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

---------------------------------------------------------------------------
-- Textes (style du genre : Luckiest Guy / Fredoka One, contours noirs épais)
---------------------------------------------------------------------------
local LUCKIEST = Font.fromEnum(Enum.Font.LuckiestGuy)

local function addStroke(parent: Instance, thickness: number, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or C.Ink
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

local function addCorner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

-- Dégradé vertical (haut -> bas)
local function addGradient(parent: Instance, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = parent
end

local function addText(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	position: UDim2,
	size: UDim2,
	strokeThickness: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.FontFace = LUCKIEST
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	addStroke(label, strokeThickness)
	return label
end

-- Étiquette flottante : texte seul, blanc à contour noir (mis à jour par PlotController)
local function addLabel(parent: BasePart, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(230, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	addText(gui, "Text", text, C.White, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 3)
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

local function pick<T>(list: { T }): T
	return list[math.clamp(math.floor(rand(1, #list + 1)), 1, #list)]
end

---------------------------------------------------------------------------
-- Positions des bases
---------------------------------------------------------------------------
-- Numérotation alternée ouest/est en partant de la Rift : Plot1 = ouest Z=-105,
-- Plot2 = est Z=-105, Plot3 = ouest Z=-35... Les premiers joueurs arrivés ont les
-- bases les plus proches de la Rift. Le -Z local de chaque base pointe vers le tapis.
function MapBuilder.GetPlotCFrame(index: number): CFrame
	local row = math.ceil(index / 2)
	local side = if index % 2 == 1 then -1 else 1
	local z = MapBuilder.PLOT_ROWS_Z[row]
	local center = Vector3.new(side * MapBuilder.PLOT_X, 0, z)
	return lookAt(center, Vector3.new(0, 0, z))
end

---------------------------------------------------------------------------
-- Île
---------------------------------------------------------------------------
local function buildIsland(map: Folder)
	local island = Instance.new("Model")
	island.Name = "Island"
	local R = MapBuilder.ISLAND_RADIUS

	cylinder(island, "Ground", 6, R * 2, CFrame.new(0, -3, 0), C.Grass, Enum.Material.Plastic)
	cylinder(island, "Cliff", 22, R * 2 - 6, CFrame.new(0, -16, 0), C.Dirt, Enum.Material.Rock)
	cylinder(island, "CliffLow", 30, R * 2 - 70, CFrame.new(0, -40, 0), C.Cliff, Enum.Material.Rock)
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
			if i % 2 == 0 then C.Cliff else C.CliffDark,
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
			Vector3.new(chord * 1.35, rand(5, 8), rand(5, 8)),
			CFrame.new(math.cos(angle) * (R - 4), 1.5, math.sin(angle) * (R - 4))
				* CFrame.Angles(0, -angle + math.pi / 2, 0)
				* CFrame.Angles(rand(-0.15, 0.15), 0, rand(-0.1, 0.1)),
			if i % 2 == 0 then C.Stone else C.Stone:Lerp(C.StoneDark, 0.25),
			Enum.Material.Slate
		)
	end

	island.Parent = map
end

---------------------------------------------------------------------------
-- Rift (nord) : portail géant d'où sortent les créatures, face au tapis (+Z)
---------------------------------------------------------------------------
-- Cristal néon : prisme carré tourné de 45° (section en losange) terminé par une
-- pointe : un cube posé sur un sommet (diagonale verticale) à moitié enfoncé dans le
-- haut du prisme. cf = base du cristal, +Y local = direction de pousse
-- Cube sur un sommet : rotation de -45° autour de Y puis de -atan(√2) autour de X (la
-- diagonale (1, 1, 1) devient verticale)
local TIP_TILT = CFrame.Angles(-math.atan(math.sqrt(2)), -math.pi / 4, 0)
local function crystal(parent: Instance, name: string, length: number, width: number, cf: CFrame, color: Color3)
	local body = length - width * 0.6
	block(
		parent,
		name,
		Vector3.new(width, body, width),
		cf * CFrame.new(0, body / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
		color,
		Enum.Material.Neon,
		noCollide()
	)
	block(
		parent,
		name,
		Vector3.one * (width * 0.86),
		cf * CFrame.new(0, body, 0) * TIP_TILT,
		color,
		Enum.Material.Neon,
		noCollide()
	)
end

-- Amas irrégulier de cristaux qui jaillissent d'un même point (+Y local de cf) :
-- un grand presque droit, les autres plus courts et inclinés
local function crystalCluster(
	parent: Instance,
	name: string,
	cf: CFrame,
	count: number,
	minLength: number,
	maxLength: number,
	color: Color3
)
	for i = 1, count do
		local length = rand(minLength, maxLength) * (if i == 1 then 1 else rand(0.45, 0.7))
		-- Le premier presque droit, les autres en éventail autour (alternés gauche/droite)
		local fan = if i == 1 then 0 else (if i % 2 == 0 then 1 else -1) * rand(0.35, 0.6)
		local tilt = CFrame.Angles(rand(-0.25, 0.25), 0, fan) * CFrame.Angles(0, rand(0, math.pi), 0)
		local width = math.clamp(length * 0.26, 1.3, 2.8)
		crystal(parent, name, length, width, cf * CFrame.new(fan * 1.6, -0.8, rand(-0.6, 0.6)) * tilt, color)
	end
end

local function buildRift(map: Folder)
	local rift = Instance.new("Model")
	rift.Name = "Rift"
	-- Rayon de l'orbite des éclats (lu par RiftVisualController)
	rift:SetAttribute("ShardOrbit", SHARD_ORBIT)
	local R = RIFT_RADIUS
	local center = RIFT_CENTER
	local frame = CFrame.new(center) -- plan du portail : XY, face à ±Z
	local floor = Vector3.new(0, 0, center.Z)

	-- Estrade au ras du tapis, liseré lumineux recoloré selon la dimension
	cylinder(
		rift,
		"DaisGlow",
		0.42,
		R * 2 + 19,
		CFrame.new(floor + Vector3.new(0, 0.21, 0)),
		C.Rift,
		Enum.Material.Neon,
		{
			Name = "RoadGlow",
		}
	)
	cylinder(
		rift,
		"Dais",
		0.44,
		R * 2 + 17,
		CFrame.new(floor + Vector3.new(0, 0.22, 0)),
		C.RiftStone,
		Enum.Material.Slate
	)

	-- Fissures lumineuses sur l'estrade et dans le dallage autour
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2 + rand(-0.12, 0.12)
		local r0, r1 = R - 1, rand(R + 10, R + 20)
		local mid = (r0 + r1) / 2
		local bend = rand(-0.18, 0.18)
		-- Aucune fissure en travers du tapis (elle dépasserait de 0,01 et couperait les
		-- chevrons) : on saute celles qui partent vers +Z dans l'axe du tapis
		local overCarpet = math.sin(angle) > 0 and math.abs(math.cos(angle)) < 0.42
		for s = 0, if overCarpet then -1 else 1 do
			local a = angle + bend * s
			local from = (if s == 0 then r0 else mid)
			local to = (if s == 0 then mid else r1)
			local p0 = floor + Vector3.new(math.cos(a) * from, 0.47, math.sin(a) * from)
			local p1 = floor + Vector3.new(math.cos(a) * to, 0.47, math.sin(a) * to)
			block(
				rift,
				"Crack",
				Vector3.new(0.9 - s * 0.35, 0.08, (p1 - p0).Magnitude + 0.5),
				lookAt((p0 + p1) / 2, p1),
				C.Rift,
				Enum.Material.Neon,
				noCollide()
			)
		end
	end

	-- Piliers de roche qui encadrent la faille, couronnés de cristaux
	for _, side in { -1, 1 } do
		local x = side * (R + 8)
		local y = 0
		for level = 1, 6 do
			local height = rand(6.5, 9)
			local width = 9 - level * 0.45
			block(
				rift,
				"Pillar",
				Vector3.new(width + rand(-0.6, 0.6), height, width + rand(-0.6, 0.6)),
				CFrame.new(x + side * rand(-0.3, 0.8), y + height / 2, center.Z + rand(-0.6, 0.6))
					* CFrame.Angles(rand(-0.06, 0.06), rand(0, 1.5), side * -0.035 * level),
				if level % 2 == 0 then C.RiftStoneLight else C.RiftStone,
				Enum.Material.Slate
			)
			y += height * 0.85
		end
		-- Couronne de cristaux au sommet (penchés vers l'extérieur et vers le tapis)
		crystalCluster(
			rift,
			"RiftTooth",
			CFrame.new(x, y + 0.6, center.Z) * CFrame.Angles(0.25, 0, side * -0.45),
			3,
			5,
			9,
			C.RiftAccent
		)
		-- Rochers flottants au-dessus
		for i = 1, 3 do
			block(
				rift,
				"FloatingRock",
				Vector3.new(rand(1.6, 3.2), rand(1.6, 3.2), rand(1.6, 3.2)),
				CFrame.new(x + side * rand(-1, 4), y + 7 + i * 3.4, center.Z + rand(-3, 3))
					* CFrame.Angles(rand(0, 3), rand(0, 3), rand(0, 3)),
				C.RiftStoneLight,
				Enum.Material.Slate,
				noCollide()
			)
		end
		-- Amas de cristaux au pied du pilier, côté tapis
		crystalCluster(
			rift,
			"RiftTooth",
			CFrame.new(x - side * 1.5, 0.3, center.Z + 6.5) * CFrame.Angles(0.35, 0, side * 0.3),
			4,
			3.5,
			7.5,
			C.RiftAccent
		)
		-- Éboulis sombres au pied
		for i = 1, 3 do
			local size = rand(2.2, 3.8)
			block(
				rift,
				"RiftRubble",
				Vector3.new(size, size * 0.7, size),
				CFrame.new(x + side * rand(2, 6), size * 0.3, center.Z + rand(-6, 7))
					* CFrame.Angles(rand(-0.4, 0.4), rand(0, 3), rand(-0.4, 0.4)),
				if i == 2 then C.RiftStoneLight else C.RiftStone,
				Enum.Material.Slate
			)
		end
	end

	-- Anneau de la faille : néon intérieur + épais bord de pierre sombre
	local segments = 48
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local around = frame * CFrame.Angles(0, 0, angle)
		block(
			rift,
			"RingSegment",
			Vector3.new(3.4, 3.2, 3.6),
			around * CFrame.new(0, R, 0),
			C.Rift,
			Enum.Material.Neon,
			noCollide()
		)
		block(
			rift,
			"RingBack",
			Vector3.new(3.7, 3, 5.4),
			around * CFrame.new(0, R + 2.9, 0),
			C.RiftStone,
			Enum.Material.Slate,
			noCollide()
		)
	end
	-- Amas de cristaux irréguliers sur le haut de l'anneau (la faille a l'air
	-- « déchirée ») : jamais sur les côtés, où se tiennent les piliers
	for k, base in { -0.8, -0.28, 0.2, 0.74 } do
		local angle = base + rand(-0.08, 0.08)
		crystalCluster(
			rift,
			"RiftTooth",
			frame * CFrame.Angles(0, 0, angle) * CFrame.new(0, R + 3.6, 1.4) * CFrame.Angles(0.4, 0, 0),
			3 + (k % 2),
			6.5,
			if k == 2 then 14 else 10.5,
			C.RiftAccent
		)
	end

	-- Vortex en couches, du bord lumineux au centre sombre (effet de profondeur)
	local core = disc(rift, "Core", 0.6, R * 2 - 1, frame, C.Rift, Enum.Material.Neon, noCollide())
	disc(rift, "RiftDeep", 0.8, R * 1.5, frame, C.Rift:Lerp(C.Ink, DEEP_SHADE), Enum.Material.Neon, noCollide())
	disc(rift, "Swirl", 1.0, R * 1.62, frame, Color3.fromRGB(255, 220, 120), Enum.Material.ForceField, noCollide())
	disc(rift, "Abyss", 1.2, R * 0.98, frame, Color3.fromRGB(26, 8, 44), Enum.Material.SmoothPlastic, noCollide())
	-- Petit tourbillon blanc autour de l'œil : la lumière au bout du tunnel
	disc(rift, "Swirl2", 1.3, R * 0.42, frame, C.White, Enum.Material.ForceField, noCollide())
	ball(rift, "Eye", 3.6, frame, C.White, Enum.Material.Neon, noCollide())

	-- Bras de la spirale, devant le vortex : ils tournent autour de l'axe de la
	-- Rift (RiftVisualController) et s'affinent vers le centre
	local arms, steps = 3, 8
	local winding = 2.6 -- radians d'enroulement du bord au centre
	local function spiralPoint(arm: number, f: number): Vector3
		local radius = R * (0.9 - 0.6 * f)
		local angle = (arm / arms) * math.pi * 2 + f * winding
		return Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
	end
	for arm = 1, arms do
		for s = 0, steps - 1 do
			local p0 = spiralPoint(arm, s / steps)
			local p1 = spiralPoint(arm, (s + 1) / steps)
			local along = (p1 - p0).Unit
			local up = Vector3.zAxis:Cross(along)
			local mid = (p0 + p1) / 2 + Vector3.new(0, 0, 0.85)
			block(
				rift,
				"SwirlArm",
				Vector3.new((p1 - p0).Magnitude + 0.6, 1.9 - 1.2 * s / steps, 0.25),
				frame * CFrame.fromMatrix(mid, along, up, Vector3.zAxis),
				C.RiftAccent,
				Enum.Material.Neon,
				noCollide({ CastShadow = false })
			)
		end
	end

	pointLight(core, core.Color, 60, 4)
	local particles = sparkle(core, Color3.fromRGB(255, 160, 60), 50, 1.8, 14)
	particles.Name = "RiftParticles"
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.EmissionDirection = Enum.NormalId.Left -- -X local du disque = +Z monde : vers le tapis

	-- Colonne de lumière visible de toute l'île
	cylinder(
		rift,
		"RiftBeam",
		400,
		11,
		CFrame.new(center.X, center.Y + R + 4 + 200, center.Z),
		Color3.fromRGB(255, 140, 60),
		Enum.Material.Neon,
		noCollide({ Transparency = 0.86, CastShadow = false })
	)

	-- Éclats en orbite horizontale autour de la faille, au-delà des piliers (animés
	-- côté client)
	for i = 1, 12 do
		-- Décalés d'un demi-pas : aucun éclat pile devant l'œil en mode édition
		local angle = ((i - 0.5) / 12) * math.pi * 2
		block(
			rift,
			"Shard",
			Vector3.new(1.6, 3.6, 1.6),
			CFrame.new(center + Vector3.new(math.cos(angle) * SHARD_ORBIT, 0, math.sin(angle) * SHARD_ORBIT))
				* CFrame.Angles(rand(0, 3), rand(0, 3), rand(0, 3)),
			C.RiftAccent,
			Enum.Material.Neon,
			noCollide()
		)
	end

	rift.PrimaryPart = core
	rift.Parent = map
end

---------------------------------------------------------------------------
-- Esplanade pavée autour de la Rift : les tableaux de classement et l'apparition
-- neutre y sont posés, les trottoirs y débouchent
---------------------------------------------------------------------------
local PLAZA_RADIUS = 58

local function buildPlaza(map: Folder)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = map
	local floor = Vector3.new(0, 0, MapBuilder.RIFT_Z)
	cylinder(
		plaza,
		"PlazaRim",
		0.36,
		PLAZA_RADIUS * 2 + 2,
		CFrame.new(floor + Vector3.new(0, 0.18, 0)),
		C.White,
		Enum.Material.SmoothPlastic
	)
	cylinder(
		plaza,
		"PlazaFloor",
		0.38,
		PLAZA_RADIUS * 2,
		CFrame.new(floor + Vector3.new(0, 0.19, 0)),
		C.Sidewalk,
		Enum.Material.SmoothPlastic
	)
	-- Joints rayonnants (dalles en éventail autour de la Rift)
	for k = 0, 23 do
		local angle = math.rad(k * 15 + 7.5)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local r0, r1 = 27, PLAZA_RADIUS - 1
		local mid = floor + direction * (r0 + r1) / 2 + Vector3.new(0, 0.39, 0)
		block(
			plaza,
			"PlazaJoint",
			Vector3.new(0.3, 0.03, r1 - r0),
			lookAt(mid, mid + direction),
			C.SidewalkJoint,
			Enum.Material.SmoothPlastic,
			noCollide({ CastShadow = false })
		)
	end
end

---------------------------------------------------------------------------
-- Portail de sortie (sud) : plus petit et sombre, les créatures non achetées
-- y disparaissent
---------------------------------------------------------------------------
local function buildExit(map: Folder)
	local exit = Instance.new("Model")
	exit.Name = "ExitPortal"
	local center = EXIT_CENTER
	local frame = CFrame.new(center)
	local floor = Vector3.new(0, 0, center.Z)

	cylinder(exit, "ExitDaisGlow", 0.36, 31, CFrame.new(floor + Vector3.new(0, 0.18, 0)), C.Exit, Enum.Material.Neon)
	cylinder(exit, "ExitDais", 0.44, 29, CFrame.new(floor + Vector3.new(0, 0.22, 0)), C.StoneDark, Enum.Material.Slate)

	local segments = 28
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local rotation = frame * CFrame.Angles(0, 0, angle)
		block(
			exit,
			"ExitRing",
			Vector3.new(2.6, 2.8, 3.4),
			rotation * CFrame.new(0, EXIT_RADIUS + 0.6, 0),
			C.ExitStone,
			Enum.Material.Slate,
			noCollide()
		)
		block(
			exit,
			"ExitRim",
			Vector3.new(2.3, 0.7, 3.6),
			rotation * CFrame.new(0, EXIT_RADIUS - 0.9, 0),
			C.Exit,
			Enum.Material.Neon,
			noCollide()
		)
		-- Éclats de pierre sombre sur le pourtour (silhouette brisée)
		if i % 3 == 0 and math.cos(angle) > -0.4 then
			local length = rand(1.6, 2.8)
			block(
				exit,
				"ExitSpike",
				Vector3.new(2, length, 2),
				rotation
					* CFrame.new(0, EXIT_RADIUS + 1.8 + length / 2, 0)
					* CFrame.Angles(rand(-0.4, 0.4), rand(0, 1), rand(-0.3, 0.3)),
				C.ExitStone,
				Enum.Material.Slate,
				noCollide()
			)
		end
	end
	disc(
		exit,
		"ExitCore",
		0.5,
		EXIT_RADIUS * 2 - 1.5,
		frame,
		Color3.fromRGB(26, 10, 44),
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	disc(
		exit,
		"ExitSwirl",
		0.8,
		EXIT_RADIUS * 1.5,
		frame,
		Color3.fromRGB(170, 90, 255),
		Enum.Material.ForceField,
		noCollide()
	)
	ball(exit, "ExitEye", 1.6, frame, Color3.fromRGB(200, 150, 255), Enum.Material.Neon, noCollide())
	exit.Parent = map
end

---------------------------------------------------------------------------
-- Chemin (tapis rouge en ligne droite)
---------------------------------------------------------------------------
-- Renvoie la liste ordonnée des waypoints du chemin principal : de la sortie de la
-- Rift jusqu'au portail de sortie, en ligne droite le long du tapis (sens +Z).
function MapBuilder.ComputePathPoints(): { Vector3 }
	local y = MapBuilder.PATH_Y
	local startZ = MapBuilder.RIFT_Z + 3 -- juste devant le vortex
	local endZ = MapBuilder.EXIT_Z - 2 -- dans le portail de sortie
	local points = { Vector3.new(0, y, startZ) }
	-- Un point tous les 35 studs (utile pour éditer la map à la main)
	local z = MapBuilder.CARPET_START_Z + 10
	while z < endZ - 5 do
		table.insert(points, Vector3.new(0, y, z))
		z += 35
	end
	table.insert(points, Vector3.new(0, y, endZ))
	return points
end

-- Chevron lumineux "flèche" posé sur le tapis, pointant dans "direction"
local function chevron(parent: Instance, position: Vector3, direction: Vector3, index: number)
	local base = lookAt(position, position + direction)
	for _, side in { -1, 1 } do
		local arm = block(
			parent,
			"Chevron",
			Vector3.new(1, 0.06, 4.6),
			-- Les deux bras se rejoignent à l'avant (-Z local) : la pointe indique le sens de marche
			base * CFrame.new(side * 1.45, 0, -0.9) * CFrame.Angles(0, side * math.rad(40), 0),
			C.RiftAccent,
			Enum.Material.Neon,
			noCollide()
		)
		arm:SetAttribute("Index", index)
	end
end

-- Lampadaire : pied sombre, globe lumineux recoloré selon la dimension
local function lamp(parent: Instance, base: Vector3)
	cylinder(parent, "LampBase", 1, 1.8, CFrame.new(base + Vector3.new(0, 0.5, 0)), C.Metal, Enum.Material.Metal)
	cylinder(parent, "LampPost", 11, 0.7, CFrame.new(base + Vector3.new(0, 5.5, 0)), C.Metal, Enum.Material.Metal)
	cylinder(parent, "LampCollar", 0.5, 1.6, CFrame.new(base + Vector3.new(0, 10.9, 0)), C.Gold, Enum.Material.Metal)
	local globe = ball(
		parent,
		"Lamp",
		2.4,
		CFrame.new(base + Vector3.new(0, 12.2, 0)),
		C.RiftAccent,
		Enum.Material.Neon,
		noCollide()
	)
	cylinder(parent, "LampCap", 0.4, 1.2, CFrame.new(base + Vector3.new(0, 13.5, 0)), C.Metal, Enum.Material.Metal)
	pointLight(globe, C.RiftAccent, 22, 1.2)
end

local function buildRoad(map: Folder)
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = map

	local y = MapBuilder.PATH_Y
	local z0, z1 = MapBuilder.CARPET_START_Z, MapBuilder.CARPET_END_Z
	local length = z1 - z0
	local mid = (z0 + z1) / 2
	local half = MapBuilder.CARPET_WIDTH / 2

	-- Le tapis rouge sort du vortex de la Rift et entre dans le portail de sortie
	local carpetStart, carpetEnd = MapBuilder.RIFT_Z + 2, MapBuilder.EXIT_Z - 2
	block(
		road,
		"Carpet",
		Vector3.new(MapBuilder.CARPET_WIDTH, y, carpetEnd - carpetStart),
		CFrame.new(0, y / 2, (carpetStart + carpetEnd) / 2),
		C.Carpet,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		-- Liseré rouge foncé le long des bordures (donne du relief)
		block(
			road,
			"CarpetTrim",
			Vector3.new(0.9, 0.04, carpetEnd - carpetStart),
			CFrame.new(side * (half - 1.2), y + 0.02, (carpetStart + carpetEnd) / 2),
			C.CarpetDark,
			Enum.Material.SmoothPlastic,
			noCollide()
		)
		-- Bordure or
		block(
			road,
			"CarpetBorder",
			Vector3.new(1, 0.8, length),
			CFrame.new(side * (half + 0.5), 0.4, mid),
			C.Gold,
			Enum.Material.SmoothPlastic
		)
		-- Trottoir + bordure blanche côté herbe
		local inner, outer = MapBuilder.SIDEWALK_INNER, MapBuilder.SIDEWALK_OUTER
		local width = outer - inner
		block(
			road,
			"Sidewalk",
			Vector3.new(width, FLOOR_TOP, length),
			CFrame.new(side * (inner + width / 2), FLOOR_TOP / 2, mid),
			C.Sidewalk,
			Enum.Material.SmoothPlastic
		)
		block(
			road,
			"Curb",
			Vector3.new(0.9, FLOOR_TOP + 0.35, length + 0.9),
			CFrame.new(side * (outer - 0.45), (FLOOR_TOP + 0.35) / 2, mid),
			C.White,
			Enum.Material.SmoothPlastic
		)
		-- Joints de dalles
		local joints = math.floor(length / 7)
		for k = 1, joints - 1 do
			block(
				road,
				"SidewalkJoint",
				Vector3.new(width - 0.9, 0.04, 0.3),
				CFrame.new(side * (inner + (width - 0.9) / 2), FLOOR_TOP + 0.01, z0 + k * (length / joints)),
				C.SidewalkJoint,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
	end
	-- Bouts des bordures (embouts arrondis or)
	for _, z in { z0, z1 } do
		for _, side in { -1, 1 } do
			cylinder(
				road,
				"CarpetBorderEnd",
				0.9,
				1.6,
				CFrame.new(side * (half + 0.5), 0.45, z),
				C.Gold,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Chevrons (Index croissant dans le sens de marche : la lumière court vers la sortie)
	local index = 0
	local z = z0 + 4
	while z <= z1 - 4 do
		chevron(road, Vector3.new(0, y + 0.04, z), Vector3.zAxis, index)
		index += 1
		z += 8
	end

	-- Lampadaires tous les 35 studs, entre les entrées des bases
	for k = 0, 9 do
		local lampZ = -157.5 + k * 35
		for _, side in { -1, 1 } do
			lamp(road, Vector3.new(side * (MapBuilder.SIDEWALK_OUTER - 0.45), FLOOR_TOP + 0.35, lampZ))
		end
	end
end

---------------------------------------------------------------------------
-- Décor
---------------------------------------------------------------------------
local LEAF_COLORS = {
	Color3.fromRGB(52, 172, 62),
	Color3.fromRGB(36, 150, 70),
	Color3.fromRGB(96, 200, 56),
	Color3.fromRGB(28, 138, 84),
}
-- Fruits : touches de couleur vive sur certains arbres (au lieu de feuillages pastel)
local FRUIT_COLORS = {
	Color3.fromRGB(235, 36, 48),
	Color3.fromRGB(255, 140, 20),
	Color3.fromRGB(255, 214, 30),
}

local function tree(parent: Instance, position: Vector3, scale: number, color: Color3?)
	local height = 8 * scale
	cylinder(
		parent,
		"Trunk",
		height + 2,
		1.8 * scale,
		CFrame.new(position + Vector3.new(0, (height + 2) / 2, 0)),
		C.Wood,
		Enum.Material.Wood
	)
	local leaves = color or pick(LEAF_COLORS)
	-- Feuillage en « nuage » : une grosse boule + trois plus petites
	ellipsoid(
		parent,
		"Leaves",
		Vector3.new(11, 9, 11) * scale,
		CFrame.new(position + Vector3.new(0, height + 3 * scale, 0)),
		leaves,
		Enum.Material.SmoothPlastic
	)
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + rand(0, 1)
		local size = rand(5.5, 7) * scale
		ellipsoid(
			parent,
			"Leaves",
			Vector3.new(size, size * 0.85, size),
			CFrame.new(
				position
					+ Vector3.new(math.cos(a) * 4 * scale, height + rand(4.5, 6.5) * scale, math.sin(a) * 4 * scale)
			),
			leaves:Lerp(C.White, 0.12),
			Enum.Material.SmoothPlastic
		)
	end
	-- Un arbre sur trois porte des fruits, posés sur la grosse boule de feuillage
	if color == nil and rand(0, 1) < 0.35 then
		local fruit = pick(FRUIT_COLORS)
		local center = position + Vector3.new(0, height + 3 * scale, 0)
		for _ = 1, 7 do
			local a = rand(0, math.pi * 2)
			local e = rand(-0.35, 0.55)
			local direction =
				Vector3.new(math.cos(a) * math.cos(e) * 5.4, math.sin(e) * 4.4, math.sin(a) * math.cos(e) * 5.4)
			ball(
				parent,
				"Fruit",
				1.15 * scale,
				CFrame.new(center + direction * scale),
				fruit,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
	end
end

local function bush(parent: Instance, position: Vector3, scale: number)
	for i = 1, 3 do
		local size = rand(3.5, 5) * scale
		ellipsoid(
			parent,
			"Bush",
			Vector3.new(size, size * 0.8, size),
			CFrame.new(position + Vector3.new(rand(-1.8, 1.8) * scale, size * 0.3, rand(-1.8, 1.8) * scale)),
			if i == 2 then C.Leaves:Lerp(C.White, 0.1) else C.Leaves,
			Enum.Material.SmoothPlastic,
			-- Décor traversable : un buisson collé à un mur servirait de marchepied
			noCollide()
		)
	end
end

local function rock(parent: Instance, position: Vector3, scale: number)
	for i = 1, 3 do
		local size = Vector3.new(rand(4, 7), rand(2.5, 4.5), rand(4, 6)) * scale * (if i == 1 then 1 else 0.6)
		ellipsoid(
			parent,
			"Rock",
			size,
			CFrame.new(position + Vector3.new(rand(-2.5, 2.5) * scale, size.Y * 0.3, rand(-2.5, 2.5) * scale))
				* CFrame.Angles(0, rand(0, 3), rand(-0.2, 0.2)),
			if i == 1 then C.Stone else C.Stone:Lerp(C.White, 0.15),
			Enum.Material.SmoothPlastic
		)
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 60, 80),
	Color3.fromRGB(255, 220, 40),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 90, 190),
	Color3.fromRGB(70, 150, 255),
}

local function flowers(parent: Instance, position: Vector3)
	local color = pick(FLOWER_COLORS)
	for _ = 1, 3 do
		local offset = Vector3.new(rand(-1.4, 1.4), 0, rand(-1.4, 1.4))
		cylinder(
			parent,
			"Stem",
			1,
			0.2,
			CFrame.new(position + offset + Vector3.new(0, 0.5, 0)),
			C.GrassDark,
			Enum.Material.SmoothPlastic,
			noCollide()
		)
		ball(
			parent,
			"Flower",
			0.85,
			CFrame.new(position + offset + Vector3.new(0, 1.1, 0)),
			color,
			Enum.Material.SmoothPlastic,
			noCollide()
		)
	end
end

-- Touffe d'herbe plus foncée (trois brins inclinés)
local function tuft(parent: Instance, position: Vector3)
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + rand(0, 1)
		local h = rand(1.2, 2)
		block(
			parent,
			"Tuft",
			Vector3.new(0.35, h, 0.35),
			CFrame.new(position + Vector3.new(math.cos(a) * 0.3, h / 2 - 0.1, math.sin(a) * 0.3))
				* CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35),
			C.GrassDark,
			Enum.Material.SmoothPlastic,
			noCollide({ CastShadow = false })
		)
	end
end

local function floatingIsland(parent: Instance, position: Vector3, radius: number)
	cylinder(parent, "IslandTop", 3, radius * 2, CFrame.new(position), C.Grass, Enum.Material.Plastic)
	cylinder(
		parent,
		"IslandRock",
		8,
		radius * 1.7,
		CFrame.new(position - Vector3.new(0, 5, 0)),
		C.Dirt,
		Enum.Material.Rock
	)
	cylinder(
		parent,
		"IslandRock",
		8,
		radius * 1.1,
		CFrame.new(position - Vector3.new(0, 11, 0)),
		C.Cliff,
		Enum.Material.Rock
	)
	tree(parent, position + Vector3.new(0, 1.5, 0), radius / 12, C.Leaves)
end

-- Vrai si la position tombe dans une base ou devant son entrée (marge comprise)
local function insideAnyPlot(position: Vector3, margin: number): boolean
	for index = 1, MapBuilder.PLOT_COUNT do
		local localPos = MapBuilder.GetPlotCFrame(index):PointToObjectSpace(position)
		if
			math.abs(localPos.X) < MapBuilder.PLOT_WIDTH / 2 + margin
			and localPos.Z > -MapBuilder.PLOT_DEPTH / 2 - 8 - margin
			and localPos.Z < MapBuilder.PLOT_DEPTH / 2 + margin
		then
			return true
		end
	end
	return false
end

-- Emplacement libre pour un décor : sur l'île, hors du tapis et de ses bouts,
-- hors des bases, de l'esplanade de la Rift et du portail de sortie
local function isFree(position: Vector3, margin: number): boolean
	local x, z = position.X, position.Z
	if math.sqrt(x * x + z * z) > MapBuilder.ISLAND_RADIUS - 14 - margin then
		return false
	end
	if math.abs(x) < MapBuilder.SIDEWALK_OUTER + 6 + margin then
		return false
	end
	if z < MapBuilder.RIFT_Z + 52 + margin and z > MapBuilder.RIFT_Z - 30 - margin and math.abs(x) < 66 + margin then
		return false
	end
	if z > MapBuilder.EXIT_Z - 40 - margin and math.abs(x) < 32 + margin then
		return false
	end
	return not insideAnyPlot(position, margin)
end

local function randomFreePosition(minRadius: number, maxRadius: number, margin: number): Vector3?
	for _ = 1, 60 do
		local angle = rand(0, math.pi * 2)
		local radius = rand(minRadius, maxRadius)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if isFree(position, margin) then
			return position
		end
	end
	return nil
end

local function buildDecor(map: Folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map

	-- Nuances de gazon
	for _ = 1, 22 do
		local position = randomFreePosition(40, 270, 6)
		if position then
			cylinder(
				decor,
				"GrassPatch",
				0.06,
				rand(14, 30),
				CFrame.new(position + Vector3.new(0, 0.02, 0)),
				C.GrassDark,
				Enum.Material.Plastic,
				noCollide({ CastShadow = false })
			)
		end
	end
	for _ = 1, 70 do
		local position = randomFreePosition(30, 280, 1)
		if position then
			tuft(decor, position)
		end
	end
	for _ = 1, 55 do
		local position = randomFreePosition(30, 280, 2)
		if position then
			flowers(decor, position)
		end
	end

	-- Bosquets sur le pourtour de l'île
	local planted = 0
	local attempts = 0
	while planted < 46 and attempts < 600 do
		attempts += 1
		local position = randomFreePosition(120, 278, 7)
		if position then
			planted += 1
			tree(decor, position, rand(0.85, 1.35))
		end
	end
	-- Arbres qui encadrent la Rift et le portail de sortie (derrière, hors de l'axe)
	for _, side in { -1, 1 } do
		tree(decor, Vector3.new(side * 86, 0, MapBuilder.RIFT_Z - 6), 1.5, C.Leaves)
		tree(decor, Vector3.new(side * 104, 0, MapBuilder.RIFT_Z + 26), 1.2)
		tree(decor, Vector3.new(side * 44, 0, MapBuilder.EXIT_Z + 12), 1.2, C.Leaves)
		tree(decor, Vector3.new(side * 60, 0, MapBuilder.EXIT_Z - 18), 1)
	end
	-- Rochers
	for _ = 1, 22 do
		local position = randomFreePosition(60, 280, 5)
		if position then
			rock(decor, position, rand(0.8, 1.6))
		end
	end
	-- Buissons dans les espaces entre les bases, côté trottoir
	for _, z in { -70, 0, 70 } do
		for _, side in { -1, 1 } do
			bush(decor, Vector3.new(side * 27, 0, z), 1)
			bush(decor, Vector3.new(side * 52, 0, z + rand(-1, 1)), 0.9)
			bush(decor, Vector3.new(side * 80, 0, z + rand(-1, 1)), 0.9)
		end
	end

	-- Îlots flottants à l'horizon
	for k = 0, 5 do
		local angle = math.rad(k * 60 + 15)
		floatingIsland(decor, Vector3.new(math.cos(angle) * 390, rand(10, 60), math.sin(angle) * 390), rand(14, 22))
	end
end

-- Mer de nuages sous l'île : renforce l'impression d'île flottante.
-- Des cumulus en grappes (base aplatie + bosses), répartis en anneau autour de
-- l'île : c'est la zone visible depuis le bord et dans les vues aériennes.
local function buildCloudSea(map: Folder)
	local clouds = Instance.new("Folder")
	clouds.Name = "CloudSea"
	clouds.Parent = map
	local props = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	local white = Color3.fromRGB(255, 255, 255)
	local shade = Color3.fromRGB(232, 240, 255)
	local count = 44
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rand(-0.06, 0.06)
		local radius = if i % 2 == 0 then rand(330, 470) else rand(520, 760)
		local center = Vector3.new(math.cos(angle) * radius, -105 - rand(0, 20), math.sin(angle) * radius)
		local scale = rand(0.9, 1.5)
		ellipsoid(
			clouds,
			"Cloud",
			Vector3.new(150, 30, 110) * scale,
			CFrame.new(center) * CFrame.Angles(0, rand(0, math.pi), 0),
			shade,
			Enum.Material.SmoothPlastic,
			props
		)
		for _ = 1, 3 do
			local offset = Vector3.new(rand(-45, 45), rand(8, 18), rand(-30, 30)) * scale
			local diameter = rand(45, 75) * scale
			ellipsoid(
				clouds,
				"Cloud",
				Vector3.new(diameter, diameter * 0.75, diameter),
				CFrame.new(center + offset),
				white,
				Enum.Material.SmoothPlastic,
				props
			)
		end
	end
end

---------------------------------------------------------------------------
-- Tableaux de classement (remplis par le client : BoardController)
-- De part et d'autre de la Rift, tournés vers le tapis : lisibles depuis les
-- trottoirs sans jamais masquer le portail.
---------------------------------------------------------------------------
local BOARD_SIZE = Vector2.new(26, 19)
local BOARD_PPS = 30

local function buildBoardGui(panel: BasePart, title: string, color: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = BOARD_PPS
	surface.LightInfluence = 0
	-- Fenêtre bleu vif à contour noir (jetons « Fenêtre » de l'interface)
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Position = UDim2.fromOffset(12, 12)
	background.Size = UDim2.new(1, -24, 1, -24)
	background.BackgroundColor3 = Color3.new(1, 1, 1)
	background.Parent = surface
	addCorner(background, UDim.new(0, 26))
	addStroke(background, 8)
	addGradient(background, Color3.fromRGB(66, 160, 255), Color3.fromRGB(30, 92, 220))
	-- En-tête coloré (vert = argent, rouge = vols)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(14, 12)
	header.Size = UDim2.new(1, -28, 0, 84)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.Parent = background
	addCorner(header, UDim.new(0, 20))
	addStroke(header, 5)
	addGradient(header, color:Lerp(C.White, 0.2), color:Lerp(C.Ink, 0.15))
	addText(header, "Title", title, C.White, UDim2.fromOffset(16, 6), UDim2.new(1, -32, 1, -12), 5)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(22, 112)
	rows.Size = UDim2.new(1, -44, 1, -128)
	rows.Parent = background
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	surface.Parent = panel
end

local function buildBoards(map: Folder)
	local boards = Instance.new("Folder")
	boards.Name = "Boards"
	boards.Parent = map
	local definitions = {
		{ Name = "MoneyBoard", Side = -1, Title = "💰 LES PLUS RICHES", Color = Color3.fromRGB(40, 200, 70) },
		{ Name = "StealsBoard", Side = 1, Title = "🦹 MAÎTRES VOLEURS", Color = Color3.fromRGB(255, 60, 60) },
	}
	local plinthTop = 1.2
	local centerY = plinthTop + 0.6 + BOARD_SIZE.Y / 2
	for _, def in definitions do
		-- Hors de l'emprise des piliers de la Rift (X = ±30), en bord d'esplanade
		local base = Vector3.new(def.Side * 54, 0, MapBuilder.RIFT_Z + 16)
		-- Légèrement tourné vers le centre du tapis
		local facing = lookAt(base, Vector3.new(0, 0, MapBuilder.RIFT_Z + 95))
		block(
			boards,
			"BoardPlinth",
			Vector3.new(BOARD_SIZE.X + 7, plinthTop, 7),
			facing * CFrame.new(0, plinthTop / 2, 0.4),
			C.White,
			Enum.Material.SmoothPlastic
		)
		block(
			boards,
			"BoardPlinthTrim",
			Vector3.new(BOARD_SIZE.X + 7.4, 0.4, 7.4),
			facing * CFrame.new(0, 0.2, 0.4),
			def.Color,
			Enum.Material.SmoothPlastic
		)
		local cf = facing * CFrame.new(0, centerY, 0)
		local panel = block(
			boards,
			def.Name,
			Vector3.new(BOARD_SIZE.X, BOARD_SIZE.Y, 0.8),
			cf,
			C.Ink,
			Enum.Material.SmoothPlastic
		)
		-- Dos coloré (vu depuis l'arrière) et poteaux blancs
		block(
			boards,
			"BoardBack",
			Vector3.new(BOARD_SIZE.X + 1.2, BOARD_SIZE.Y + 1.2, 0.6),
			cf * CFrame.new(0, 0, 0.65),
			def.Color,
			Enum.Material.SmoothPlastic
		)
		for _, side in { -1, 1 } do
			block(
				boards,
				"BoardPost",
				Vector3.new(2, centerY + BOARD_SIZE.Y / 2 + 1.4 - plinthTop, 2),
				facing
					* CFrame.new(
						side * (BOARD_SIZE.X / 2 + 1.6),
						(centerY + BOARD_SIZE.Y / 2 + 1.4 + plinthTop) / 2,
						0.4
					),
				C.White,
				Enum.Material.SmoothPlastic
			)
			ball(
				boards,
				"BoardLamp",
				2.6,
				facing * CFrame.new(side * (BOARD_SIZE.X / 2 + 1.6), centerY + BOARD_SIZE.Y / 2 + 2.6, 0.4),
				def.Color,
				Enum.Material.Neon,
				noCollide()
			)
		end
		pointLight(panel, def.Color, 24, 1)
		buildBoardGui(panel, def.Title, def.Color)
	end
end

---------------------------------------------------------------------------
-- Bases
---------------------------------------------------------------------------
-- Grand panneau « BASE DE {Nom} » au-dessus de l'arche (texte écrit par PlotController)
local SIGN_SIZE = Vector2.new(46, 9)
local SIGN_PPS = 16

local function buildSign(model: Model, cf: CFrame, color: Color3): BasePart
	-- Pièce noire : sa bordure forme le contour épais du panneau
	local sign = block(
		model,
		"Sign",
		Vector3.new(SIGN_SIZE.X, SIGN_SIZE.Y, 1),
		cf,
		C.Ink,
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = SIGN_PPS
	surface.LightInfluence = 0
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(9, 9)
	panel.Size = UDim2.new(1, -18, 1, -18)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.Parent = surface
	addCorner(panel, UDim.new(0, 16))
	addStroke(panel, 4)
	addGradient(panel, color:Lerp(C.White, 0.22), color:Lerp(C.Ink, 0.12))
	addText(panel, "Text", "BASE LIBRE", C.White, UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.84), 5)
	addText(panel, "Status", "", C.White, UDim2.fromScale(0.1, 0.64), UDim2.fromScale(0.8, 0.32), 3)
	surface.Parent = sign
	-- Même panneau au dos : lisible depuis l'intérieur de la base et l'esplanade
	local back = surface:Clone()
	back.Name = "SignGuiBack"
	back.Face = Enum.NormalId.Back
	back.Parent = sign
	return sign
end

local function buildPlot(plots: Folder, index: number)
	local plotCFrame = MapBuilder.GetPlotCFrame(index)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local light = color:Lerp(C.White, 0.62)
	local W, D, H = MapBuilder.PLOT_WIDTH, MapBuilder.PLOT_DEPTH, MapBuilder.WALL_HEIGHT
	local FT = FLOOR_TOP
	local front = -D / 2 -- façade côté tapis (Z local)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotId", index)
	model:SetAttribute("PlotColor", color)

	local function at(x: number, y: number, z: number): CFrame
		return plotCFrame * CFrame.new(x, y, z)
	end

	-- Sol blanc cassé, quadrillage léger couleur d'équipe, allée centrale colorée
	local floor =
		block(model, "Floor", Vector3.new(W, 1.2, D), at(0, FT - 0.6, 0), C.Floor, Enum.Material.SmoothPlastic)
	model.PrimaryPart = floor
	local aisle = 11
	block(
		model,
		"Aisle",
		Vector3.new(aisle, 0.1, D - 4),
		at(0, FT + 0.05, 0),
		color,
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	for _, side in { -1, 1 } do
		block(
			model,
			"AisleEdge",
			Vector3.new(0.6, 0.12, D - 4),
			at(side * (aisle / 2), FT + 0.06, 0),
			C.White,
			Enum.Material.SmoothPlastic,
			noCollide()
		)
		for _, x in { 16.5, 27.5 } do
			block(
				model,
				"FloorGrid",
				Vector3.new(0.35, 0.05, D - 4),
				at(side * x, FT + 0.025, 0),
				light,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
		for _, z in { -26.5, -17.5, -8.5, 0.5, 9.5, 18.5, 27.5, 36.5 } do
			local x0, x1 = aisle / 2, W / 2 - 2
			block(
				model,
				"FloorGrid",
				Vector3.new(x1 - x0, 0.05, 0.35),
				at(side * (x0 + x1) / 2, FT + 0.025, z),
				light,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
	end

	-- Murs pleins couleur d'équipe, plinthe anthracite, bandeau blanc en haut
	local thickness = 2
	local function wall(length: number, cf: CFrame)
		block(
			model,
			"Wall",
			Vector3.new(length, H, thickness),
			cf * CFrame.new(0, FT + H / 2, 0),
			color,
			Enum.Material.SmoothPlastic
		)
		block(
			model,
			"WallBase",
			Vector3.new(length, 1, thickness + 0.3),
			cf * CFrame.new(0, FT + 0.5, 0),
			C.Trim,
			Enum.Material.SmoothPlastic
		)
		block(
			model,
			"WallCap",
			Vector3.new(length + 0.3, 1.2, thickness + 0.7),
			cf * CFrame.new(0, FT + H + 0.6, 0),
			C.White,
			Enum.Material.SmoothPlastic
		)
	end
	local sideCF = CFrame.Angles(0, math.rad(90), 0)
	wall(W, at(0, 0, D / 2 - thickness / 2))
	wall(D, at(-W / 2 + thickness / 2, 0, 0) * sideCF)
	wall(D, at(W / 2 - thickness / 2, 0, 0) * sideCF)
	local frontLength = W / 2 - OPENING / 2
	for _, side in { -1, 1 } do
		wall(frontLength, at(side * (OPENING / 2 + frontLength / 2), 0, front + thickness / 2))
	end
	-- Montants blancs aux coins et au milieu des longs murs
	local postHeight = H + 2.6
	local postSpots = {
		{ -W / 2 + 1, front + 1 },
		{ W / 2 - 1, front + 1 },
		{ -W / 2 + 1, D / 2 - 1 },
		{ W / 2 - 1, D / 2 - 1 },
		{ -W / 2 + 1, 0 },
		{ W / 2 - 1, 0 },
		{ 0, D / 2 - 1 },
	}
	for _, spot in postSpots do
		block(
			model,
			"Post",
			Vector3.new(3.4, postHeight, 3.4),
			at(spot[1], FT + postHeight / 2, spot[2]),
			C.White,
			Enum.Material.SmoothPlastic
		)
		block(
			model,
			"PostCap",
			Vector3.new(4, 1, 4),
			at(spot[1], FT + postHeight + 0.5, spot[2]),
			color,
			Enum.Material.SmoothPlastic
		)
	end

	-- Arche d'entrée : piliers blancs, poutre anthracite, grand panneau
	local pillarX = OPENING / 2 + 1.8
	for _, side in { -1, 1 } do
		block(
			model,
			"ArchPillar",
			Vector3.new(3.6, ARCH_CLEAR, 3.8),
			at(side * pillarX, FT + ARCH_CLEAR / 2, front + 1),
			C.White,
			Enum.Material.SmoothPlastic
		)
		-- Émetteur laser (face intérieure du pilier) avec ses lentilles
		block(
			model,
			"LaserEmitter",
			Vector3.new(0.8, ARCH_CLEAR - 1, 1.6),
			at(side * (OPENING / 2 - 0.1), FT + ARCH_CLEAR / 2, front + 1),
			C.Metal,
			Enum.Material.SmoothPlastic
		)
	end
	block(
		model,
		"ArchBeam",
		Vector3.new(SIGN_SIZE.X, 2.6, 4.2),
		at(0, FT + ARCH_CLEAR + 1.3, front + 1),
		C.Trim,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"ArchTrim",
		Vector3.new(SIGN_SIZE.X + 0.4, 0.6, 4.6),
		at(0, FT + ARCH_CLEAR + 0.3, front + 1),
		C.White,
		Enum.Material.SmoothPlastic
	)
	buildSign(model, at(0, FT + ARCH_CLEAR + 2.6 + SIGN_SIZE.Y / 2, front - 0.4), color)

	-- Barrière : mur LOGIQUE de l'entrée, toujours invisible. Ce sont les lasers qui
	-- la montrent (BaseDefenseService). Traversable tant qu'elle est inactive.
	block(
		model,
		"Barrier",
		Vector3.new(OPENING, ARCH_CLEAR, 1),
		at(0, FT + ARCH_CLEAR / 2, front + 1),
		C.Laser,
		Enum.Material.ForceField,
		{
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}
	)
	local lasers = Instance.new("Folder")
	lasers.Name = "Lasers"
	lasers.Parent = model
	for i = 1, 6 do
		local y = FT + 1.2 + (i - 1) * 1.95
		rod(
			lasers,
			"Laser",
			OPENING,
			0.45,
			at(0, y, front + 1),
			C.Laser,
			Enum.Material.Neon,
			noCollide({ Transparency = 1, CastShadow = false })
		)
		for _, side in { -1, 1 } do
			-- Lentille éteinte : BaseDefenseService l'allume en rouge quand la base est
			-- verrouillée (rouge = danger, jamais sur une base ouverte)
			block(
				model,
				"LaserLens",
				Vector3.new(0.3, 0.6, 0.6),
				at(side * (OPENING / 2 - 0.55), y, front + 1),
				C.LensOff,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
	end

	-- Paillasson couleur d'équipe entre le trottoir et l'entrée
	local outside = MapBuilder.PLOT_X - D / 2 - MapBuilder.SIDEWALK_OUTER -- herbe entre trottoir et façade
	block(
		model,
		"Doorstep",
		Vector3.new(OPENING + 4, FT, outside + 0.4),
		at(0, FT / 2, front - outside / 2),
		C.Sidewalk,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Doormat",
		Vector3.new(OPENING - 2, 0.1, outside + 2),
		at(0, FT + 0.05, front - outside / 2 + 1),
		color,
		Enum.Material.SmoothPlastic,
		noCollide()
	)

	-- Point d'apparition du propriétaire (face au tapis) + cercle lumineux
	marker(model, "Spawn", Vector3.new(7, 0.2, 7), at(0, FT + 0.1, -30))
	cylinder(
		model,
		"SpawnDisc",
		0.2,
		7,
		at(0, FT + 0.12, -30),
		color,
		Enum.Material.Neon,
		noCollide({
			Transparency = 0.15,
		})
	)
	cylinder(model, "SpawnInner", 0.22, 5.2, at(0, FT + 0.13, -30), C.White, Enum.Material.SmoothPlastic, noCollide())

	-- Arrivée du portail de raccourci : sur le trottoir DEVANT la base (hors barrière),
	-- tournée vers l'entrée. Repère invisible : ShortcutService joue déjà l'effet de
	-- téléportation à l'arrivée (un disque ici ressemblait à une flaque d'eau)
	marker(
		model,
		"ShortcutLanding",
		Vector3.new(7, 0.15, 7),
		at(0, FT + 0.1, front - 10) * CFrame.Angles(0, math.pi, 0)
	)

	-- Point de passage des créatures qui rentrent à la base
	block(model, "Entrance", Vector3.new(2, 0.2, 2), at(0, FT, front - 5), C.White, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	-- Bouton de verrouillage : gros bouton rouge rond au sol, juste après l'entrée (visible
	-- depuis le trottoir à travers l'ouverture)
	local lockAt = at(-11, 0, front + 10)
	cylinder(model, "LockOutline", 0.4, 8.6, lockAt * CFrame.new(0, FT + 0.2, 0), C.Ink, Enum.Material.SmoothPlastic)
	cylinder(model, "LockRing", 0.7, 8, lockAt * CFrame.new(0, FT + 0.35, 0), C.White, Enum.Material.SmoothPlastic)
	local lockButton =
		cylinder(model, "LockButton", 0.9, 6, lockAt * CFrame.new(0, FT + 1.1, 0), C.LockRed, Enum.Material.Neon)
	cylinder(
		model,
		"LockShine",
		0.12,
		2.2,
		lockAt * CFrame.new(-1, FT + 1.6, -1),
		Color3.fromRGB(255, 170, 170),
		Enum.Material.Neon,
		noCollide()
	)
	addPrompt(lockButton, "LockPrompt", "Verrouiller", "Base", 0.4, Enum.KeyCode.E)
	addLabel(lockButton, "🔒 VERROUILLER", 4.2)

	-- Portail de fusion (violet = magique) : marches + anneau + vortex
	local fx, fz = 19, front + 9
	cylinder(model, "FusionStep", 0.8, 10, at(fx, FT + 0.4, fz), C.White, Enum.Material.SmoothPlastic)
	cylinder(model, "FusionStep", 0.8, 7.6, at(fx, FT + 1.2, fz), C.Magic, Enum.Material.SmoothPlastic)
	local portalCenter = at(fx, FT + 6.4, fz)
	for i = 1, 20 do
		local a = (i / 20) * math.pi * 2
		block(
			model,
			"FusionRing",
			Vector3.new(1.7, 1.2, 1.5),
			portalCenter * CFrame.Angles(0, 0, a) * CFrame.new(0, 4.2, 0),
			C.Magic,
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
		Color3.fromRGB(110, 30, 230),
		Enum.Material.Neon,
		{ CanCollide = false, Transparency = 0.1 }
	)
	disc(
		model,
		"FusionSwirl",
		0.7,
		5.6,
		portalCenter,
		Color3.fromRGB(255, 200, 255),
		Enum.Material.ForceField,
		noCollide()
	)
	addPrompt(fusion, "FusionPrompt", "Fusionner", "Portail de fusion", 0, Enum.KeyCode.E)
	addLabel(fusion, "🌀 FUSION", 6.5)
	sparkle(fusion, C.Magic, 10, 0.4, 2)
	pointLight(fusion, C.Magic, 16, 2)

	-- Emplacements : socles ronds. Construits avec l'aspect « verrouillé » (socle gris
	-- perle, anneau gris foncé mat) comme au démarrage du serveur ; PlotService passe
	-- les emplacements débloqués en blanc avec un anneau néon couleur d'équipe
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
				1,
				6.4,
				at(x, FT + 0.5, z),
				C.SlotLocked,
				Enum.Material.SmoothPlastic,
				{ CanCollide = true }
			)
			slot:SetAttribute("SlotIndex", slotIndex)
			cylinder(
				slot,
				"SlotRing",
				0.5,
				7.4,
				at(x, FT + 0.25, z),
				C.SlotRingLocked,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
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
	buildPlaza(map)
	buildRift(map)
	buildExit(map)
	buildRoad(map)
	buildDecor(map)
	buildCloudSea(map)
	buildBoards(map)

	-- Chemin en ligne droite : pas d'anneau (pas d'attribut RingRadius)
	local pathData = Instance.new("Configuration")
	pathData.Name = "PathData"
	pathData.Parent = map
	-- Les créatures achetées rejoignent leur base par le milieu du trottoir
	pathData:SetAttribute("LaneOffset", (MapBuilder.SIDEWALK_INNER + MapBuilder.SIDEWALK_OUTER) / 2)
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

	-- Apparition neutre avant l'attribution de la base : sur l'esplanade de la Rift,
	-- face au tapis (dalle invisible + disque lumineux)
	local spawnAt = Vector3.new(-30, 0.3, MapBuilder.RIFT_Z + 40)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CentralSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = lookAt(spawnAt, Vector3.new(0, spawnAt.Y, spawnAt.Z))
	spawn.Transparency = 1
	spawn.Duration = 0 -- pas de ForceField à l'apparition
	spawn.Parent = map
	-- Même dessin que l'apparition des bases : anneau néon bleu (navigation) + disque blanc
	cylinder(map, "CentralSpawnPad", 0.3, 10, CFrame.new(spawnAt), C.Navigation, Enum.Material.Neon, noCollide())
	cylinder(
		map,
		"CentralSpawnInner",
		0.32,
		8.4,
		CFrame.new(spawnAt + Vector3.new(0, 0.02, 0)),
		C.White,
		Enum.Material.SmoothPlastic,
		noCollide()
	)

	map.Parent = parent
	return map
end

return MapBuilder
