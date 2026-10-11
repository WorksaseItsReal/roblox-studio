--[[
	MapBuilder
	==========
	Génère procéduralement une map jouable et décorée si Workspace.Map n'existe pas.
	Vous pouvez remplacer cette map par la vôtre (voir docs/MAP_BUILD.md) : il suffit
	de respecter les NOMS des instances de jeu, MapService vérifie le contrat.

	Direction artistique v3 « propre » (docs/ART_DIRECTION.md, section 3) : une île
	flottante en herbe, un long tapis rouge en tissu bordé d'or où défilent les
	créatures, et 4 bases de chaque côté dont l'entrée fait face au tapis.
	Peu d'éléments, de vrais matériaux Roblox (Grass, Fabric, Concrete, WoodPlanks,
	Brick, Slate), et du néon UNIQUEMENT pour la Rift, les globes des lampadaires et
	(en jeu) les lasers d'une base verrouillée.

	Vue du dessus (Y vers le haut, -Z = "nord") :

	                   [  RIFT  ]        <- portail géant face à +Z, Z = -195 (rayon 22)
	      [Classement] [Boutique] | | [Index] [Classement]   <- esplanade de la Rift
	                       |  |
	      [Base 1] ◄────   |  |   ────► [Base 2]     Z = -105
	      [Base 3]         |  |         [Base 4]     Z =  -35
	      [Base 5]         |  |         [Base 6]     Z =  +35
	      [Base 7]         |  |         [Base 8]     Z = +105
	                       |  |
	                   [ sortie ]        <- petit portail sombre, Z = +195

	Tapis rouge (X = 0, largeur 14) bordé d'or, trottoirs en béton de X = ±8 à ±18,
	bases centrées en X = ±66. Les créatures marchent vers +Z.

	Noms utilisés par le client pour les effets :
	  RingSegment, RiftTooth, Core, RiftDeep, Swirl, Swirl2, SwirlArm (tournent autour
	  de l'axe de la Rift), Shard (orbite de rayon Rift.ShardOrbit), RiftBeam, Crack,
	  RoadGlow (recolorés selon la dimension) ; Chevron (attribut Index : flèches
	  peintes du tapis, légère vague d'opacité) ; ExitSwirl, FusionSwirl (rotation).
	Stands du marché (Map.Stands) : leur ProximityPrompt porte l'attribut Panel
	("Shop", "Index") : StandController ouvre la fenêtre correspondante.
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
-- Murs bas (on voit l'intérieur par-dessus) : corps de 7 + chaperon de 1 = 8,6 studs
-- au-dessus de l'herbe. Ils ne sont PAS infranchissables (un saut depuis le seuil de
-- l'entrée, ou une pyramide de joueurs, peut passer) : c'est le serveur qui fait
-- respecter la barrière (BaseDefenseService expulse les intrus, StealService refuse
-- les vols tant qu'elle est active)
MapBuilder.WALL_HEIGHT = 7
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
local SHARD_ORBIT = RIFT_RADIUS + 17 -- orbite des éclats : au-delà des piliers (~36 studs), avant les tableaux
-- Anneau sombre du vortex : couleur de la faille assombrie (même valeur côté client)
local DEEP_SHADE = 0.45
local EXIT_RADIUS = 9
local EXIT_CENTER = Vector3.new(0, PATH_Y + EXIT_RADIUS, MapBuilder.EXIT_Z)
local PLAZA_RADIUS = 58

-- Couleurs d'équipe (une par base, dans l'ordre des PlotId) : franches mais
-- maîtrisées. Elles n'apparaissent que sur le chaperon des murs, l'arche et le panneau
local PLOT_COLORS = {
	Color3.fromRGB(236, 72, 72), -- rouge
	Color3.fromRGB(245, 146, 50), -- orange
	Color3.fromRGB(240, 192, 46), -- jaune
	Color3.fromRGB(68, 186, 96), -- vert
	Color3.fromRGB(44, 178, 226), -- cyan
	Color3.fromRGB(70, 118, 236), -- bleu
	Color3.fromRGB(150, 96, 234), -- violet
	Color3.fromRGB(234, 96, 170), -- rose
}

-- Palette du monde (docs/ART_DIRECTION.md, section 3)
local C = {
	-- Sols et chemins
	Grass = Color3.fromRGB(93, 181, 71),
	Carpet = Color3.fromRGB(200, 32, 47),
	Gold = Color3.fromRGB(242, 182, 50),
	Sidewalk = Color3.fromRGB(207, 207, 214),
	Curb = Color3.fromRGB(233, 233, 238),
	Joint = Color3.fromRGB(186, 186, 196),
	-- Bases
	BaseFloor = Color3.fromRGB(231, 201, 160),
	BaseWall = Color3.fromRGB(240, 237, 230),
	Pad = Color3.fromRGB(248, 248, 250),
	-- Nature
	Leaves = Color3.fromRGB(62, 148, 64),
	LeavesLight = Color3.fromRGB(78, 164, 70),
	Bush = Color3.fromRGB(82, 170, 70),
	BushLight = Color3.fromRGB(106, 190, 82),
	Trunk = Color3.fromRGB(120, 84, 58),
	Rock = Color3.fromRGB(150, 153, 164),
	RockDark = Color3.fromRGB(120, 123, 136),
	Dirt = Color3.fromRGB(164, 112, 70),
	Cliff = Color3.fromRGB(138, 96, 66),
	CliffDark = Color3.fromRGB(100, 72, 58),
	-- Bois des stands
	WoodLight = Color3.fromRGB(222, 178, 126),
	Wood = Color3.fromRGB(186, 134, 88),
	WoodDark = Color3.fromRGB(128, 86, 54),
	-- Rift : pierre sombre + vortex (couleurs de départ, dimension Lave)
	RiftStone = Color3.fromRGB(66, 58, 92),
	RiftStoneLight = Color3.fromRGB(88, 80, 118),
	Rift = Color3.fromRGB(255, 90, 20),
	RiftAccent = Color3.fromRGB(255, 200, 60),
	Exit = Color3.fromRGB(150, 60, 255),
	ExitStone = Color3.fromRGB(52, 44, 74),
	-- Divers
	Ink = Color3.fromRGB(28, 31, 58), -- encre bleu nuit : tous les contours (jamais de noir pur)
	White = Color3.fromRGB(255, 255, 255),
	Metal = Color3.fromRGB(46, 50, 66),
	Steel = Color3.fromRGB(150, 156, 170),
	LampGlow = Color3.fromRGB(255, 216, 150), -- globe chaud des lampadaires
	Laser = Color3.fromRGB(255, 40, 52),
	LensOff = Color3.fromRGB(90, 24, 30), -- lentille éteinte (BaseDefenseService l'allume)
	Danger = Color3.fromRGB(230, 60, 68),
	Magic = Color3.fromRGB(122, 92, 255),
	Marble = Color3.fromRGB(236, 233, 246),
	MagicDeep = Color3.fromRGB(96, 62, 214),
	Shop = Color3.fromRGB(61, 139, 255),
	Index = Color3.fromRGB(240, 70, 74),
	Money = Color3.fromRGB(47, 203, 85),
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
-- sur X puis tourné) le coucherait.
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
-- Textes (docs/ART_DIRECTION.md) : Fredoka One en casse normale, blanc à contour
-- encre bleu nuit
---------------------------------------------------------------------------
local FREDOKA = Font.fromEnum(Enum.Font.FredokaOne)

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
	label.FontFace = FREDOKA
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	if strokeThickness > 0 then
		addStroke(label, strokeThickness)
	end
	return label
end

-- Étiquette flottante : texte seul, blanc à contour encre (mise à jour par PlotController)
local function addLabel(parent: BasePart, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(210, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	addText(gui, "Text", text, C.White, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2.5)
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
-- Île : gazon (Grass), falaises rocheuses, bordure de pierres
---------------------------------------------------------------------------
local function buildIsland(map: Folder)
	local island = Instance.new("Model")
	island.Name = "Island"
	local R = MapBuilder.ISLAND_RADIUS

	cylinder(island, "Ground", 6, R * 2, CFrame.new(0, -3, 0), C.Grass, Enum.Material.Grass)
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

	-- Bordure de pierres continue (empêche de tomber dans le vide)
	local rimCount = 56
	for i = 1, rimCount do
		local angle = (i / rimCount) * math.pi * 2
		local chord = 2 * math.pi * (R - 4) / rimCount
		block(
			island,
			"Rim",
			Vector3.new(chord * 1.35, rand(5, 7), rand(5, 7)),
			CFrame.new(math.cos(angle) * (R - 4), 1.5, math.sin(angle) * (R - 4))
				* CFrame.Angles(0, -angle + math.pi / 2, 0)
				* CFrame.Angles(rand(-0.12, 0.12), 0, rand(-0.08, 0.08)),
			if i % 2 == 0 then C.Rock else C.RockDark,
			Enum.Material.Slate
		)
	end

	island.Parent = map
end

---------------------------------------------------------------------------
-- Rift (nord) : portail géant d'où sortent les créatures, face au tapis (+Z).
-- Anneau de pierre sombre (Slate) + vortex néon : le seul grand élément lumineux
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

local function buildRift(map: Folder)
	local rift = Instance.new("Model")
	rift.Name = "Rift"
	-- Rayon de l'orbite des éclats (lu par RiftVisualController)
	rift:SetAttribute("ShardOrbit", SHARD_ORBIT)
	local R = RIFT_RADIUS
	local center = RIFT_CENTER
	local frame = CFrame.new(center) -- plan du portail : XY, face à ±Z
	local floor = Vector3.new(0, 0, center.Z)

	-- Estrade de pierre sombre au ras du tapis, fin liseré lumineux (recoloré selon la
	-- dimension)
	cylinder(
		rift,
		"RoadGlow",
		0.42,
		R * 2 + 18.6,
		CFrame.new(floor + Vector3.new(0, 0.21, 0)),
		C.Rift,
		Enum.Material.Neon,
		noCollide({ CastShadow = false })
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

	-- Quelques fissures lumineuses sur l'estrade, jamais en travers du tapis
	for _, degrees in { 28, 152, 64, 116, -30, -150 } do
		local angle = math.rad(degrees)
		local bend = if degrees > 90 or degrees < -90 then -0.14 else 0.14
		local r0, r1 = R - 2, R + 7.5
		local mid = (r0 + r1) / 2
		for s = 0, 1 do
			local a = angle + bend * s
			local from = (if s == 0 then r0 else mid)
			local to = (if s == 0 then mid else r1)
			local p0 = floor + Vector3.new(math.cos(a) * from, 0.47, math.sin(a) * from)
			local p1 = floor + Vector3.new(math.cos(a) * to, 0.47, math.sin(a) * to)
			block(
				rift,
				"Crack",
				Vector3.new(0.75 - s * 0.3, 0.06, (p1 - p0).Magnitude + 0.4),
				lookAt((p0 + p1) / 2, p1),
				C.Rift,
				Enum.Material.Neon,
				noCollide({ CastShadow = false })
			)
		end
	end

	-- Deux pylônes de pierre taillée qui encadrent la faille : socle, fût en trois
	-- tronçons légèrement effilés séparés par des bandeaux clairs, chapiteau, cristaux
	for _, side in { -1, 1 } do
		local x = side * (R + 8)
		local function stone(name: string, size: Vector3, y: number, color: Color3)
			block(rift, name, size, CFrame.new(x, y + size.Y / 2, center.Z), color, Enum.Material.Slate)
		end
		stone("PillarBase", Vector3.new(10, 2, 10), 0, C.RiftStoneLight)
		local y = 2
		for level, width in { 7.8, 7.1, 6.4 } do
			stone("Pillar", Vector3.new(width, 9.4, width), y, C.RiftStone)
			y += 9.4
			if level < 3 then
				stone("PillarBand", Vector3.new(width + 0.5, 0.7, width + 0.5), y - 0.35, C.RiftStoneLight)
			end
		end
		stone("PillarCap", Vector3.new(7.8, 1.3, 7.8), y, C.RiftStoneLight)
		y += 1.3
		-- Trois cristaux : un grand droit, deux plus courts en éventail
		local top = CFrame.new(x, y, center.Z) * CFrame.Angles(0.08, 0, side * -0.2)
		for i, spec in { { 0, 9.5, 2.6 }, { 0.5, 6, 1.9 }, { -0.5, 6.5, 2 } } do
			local fan = spec[1]
			crystal(
				rift,
				"RiftTooth",
				spec[2],
				spec[3],
				top * CFrame.new(fan * 2.2, -0.4, if i == 1 then 0 else 0.4) * CFrame.Angles(0, 0, -fan),
				C.RiftAccent
			)
		end
	end

	-- Anneau : lèvre néon intérieure + épais bord de pierre sombre
	local segments = 32
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local around = frame * CFrame.Angles(0, 0, angle)
		block(
			rift,
			"RingSegment",
			Vector3.new(2 * math.pi * R / segments * 1.12, 3, 3.4),
			around * CFrame.new(0, R, 0),
			C.Rift,
			Enum.Material.Neon,
			noCollide()
		)
		block(
			rift,
			"RingBack",
			Vector3.new(2 * math.pi * (R + 3) / segments * 1.12, 3.2, 5.2),
			around * CFrame.new(0, R + 3, 0),
			C.RiftStone,
			Enum.Material.Slate,
			noCollide()
		)
	end
	-- Couronne de cinq cristaux symétriques sur le haut de l'anneau
	for k, spec in { { -50, 7.5, 2 }, { -25, 10, 2.3 }, { 0, 13.5, 2.7 }, { 25, 10, 2.3 }, { 50, 7.5, 2 } } do
		crystal(
			rift,
			"RiftTooth",
			spec[2],
			spec[3],
			frame * CFrame.Angles(0, 0, math.rad(spec[1])) * CFrame.new(0, R + 4, if k % 2 == 0 then 0.6 else -0.6),
			C.RiftAccent
		)
	end

	-- Vortex en couches, du bord lumineux au centre sombre (effet de profondeur)
	local core = disc(rift, "Core", 0.6, R * 2 - 1, frame, C.Rift, Enum.Material.Neon, noCollide())
	disc(
		rift,
		"RiftDeep",
		0.8,
		R * 1.5,
		frame,
		C.Rift:Lerp(Color3.new(0, 0, 0), DEEP_SHADE),
		Enum.Material.Neon,
		noCollide()
	)
	disc(rift, "Swirl", 1.0, R * 1.62, frame, Color3.fromRGB(255, 220, 120), Enum.Material.ForceField, noCollide())
	disc(rift, "Abyss", 1.2, R * 0.98, frame, Color3.fromRGB(26, 12, 44), Enum.Material.SmoothPlastic, noCollide())
	-- Petit tourbillon blanc autour de l'œil : la lumière au bout du tunnel
	disc(rift, "Swirl2", 1.3, R * 0.42, frame, C.White, Enum.Material.ForceField, noCollide())
	ball(rift, "Eye", 3.4, frame, C.White, Enum.Material.Neon, noCollide())

	-- Bras de la spirale, devant le vortex : ils tournent autour de l'axe de la
	-- Rift (RiftVisualController) et s'affinent vers le centre
	local arms, steps = 3, 6
	local winding = 2.4 -- radians d'enroulement du bord au centre
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
				Vector3.new((p1 - p0).Magnitude + 0.6, 1.7 - 1.1 * s / steps, 0.25),
				frame * CFrame.fromMatrix(mid, along, up, Vector3.zAxis),
				C.RiftAccent,
				Enum.Material.Neon,
				noCollide({ CastShadow = false })
			)
		end
	end

	pointLight(core, core.Color, 60, 2.5)
	local particles = sparkle(core, Color3.fromRGB(255, 160, 60), 30, 1.5, 14)
	particles.Name = "RiftParticles"
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.EmissionDirection = Enum.NormalId.Left -- -X local du disque = +Z monde : vers le tapis

	-- Colonne de lumière visible de toute l'île
	cylinder(
		rift,
		"RiftBeam",
		400,
		10,
		CFrame.new(center.X, center.Y + R + 4 + 200, center.Z),
		Color3.fromRGB(255, 140, 60),
		Enum.Material.Neon,
		noCollide({ Transparency = 0.86, CastShadow = false })
	)

	-- Éclats en orbite horizontale autour de la faille, au-delà des piliers (animés
	-- côté client)
	for i = 1, 8 do
		-- Décalés d'un demi-pas : aucun éclat pile devant l'œil en mode édition
		local angle = ((i - 0.5) / 8) * math.pi * 2
		block(
			rift,
			"Shard",
			Vector3.new(1.5, 3.4, 1.5),
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
-- Esplanade en béton autour de la Rift : les tableaux de classement, les stands
-- du marché et l'apparition neutre y sont posés, les trottoirs y débouchent
---------------------------------------------------------------------------
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
		C.Curb,
		Enum.Material.Concrete
	)
	cylinder(
		plaza,
		"PlazaFloor",
		0.38,
		PLAZA_RADIUS * 2,
		CFrame.new(floor + Vector3.new(0, 0.19, 0)),
		C.Sidewalk,
		Enum.Material.Concrete
	)
	-- Joints rayonnants (grandes dalles en éventail autour de l'estrade)
	for k = 0, 15 do
		local angle = math.rad(k * 22.5 + 11.25)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local r0, r1 = 31.5, PLAZA_RADIUS - 0.5
		local mid = floor + direction * (r0 + r1) / 2 + Vector3.new(0, 0.385, 0)
		block(
			plaza,
			"PlazaJoint",
			Vector3.new(0.22, 0.03, r1 - r0),
			lookAt(mid, mid + direction),
			C.Joint,
			Enum.Material.SmoothPlastic,
			noCollide({ CastShadow = false })
		)
	end
end

---------------------------------------------------------------------------
-- Stands du marché (façon Grow a Garden) : étal en bois, toile rayée, enseigne.
-- Le ProximityPrompt du comptoir porte l'attribut Panel : StandController ouvre
-- la fenêtre correspondante côté client.
---------------------------------------------------------------------------
type StandDef = {
	Name: string,
	Title: string,
	Panel: string,
	Stripe: Color3,
	Position: Vector3,
	Facing: Vector3,
	Side: number, -- -1 = ouest, 1 = est (tonneaux et caisses côté extérieur)
}

local STANDS: { StandDef } = {
	{
		Name = "ShopStand",
		Title = "🛒 Boutique",
		Panel = "Shop",
		Stripe = C.Shop,
		Position = Vector3.new(-31, 0, -161),
		Facing = Vector3.new(0, 0, -128),
		Side = -1,
	},
	{
		Name = "IndexStand",
		Title = "📖 Index",
		Panel = "Index",
		Stripe = C.Index,
		Position = Vector3.new(31, 0, -161),
		Facing = Vector3.new(0, 0, -128),
		Side = 1,
	},
}

local STAND_WIDTH = 13
local STAND_DEPTH = 7

local function buildStandSign(sign: BasePart, title: string, color: Color3)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = if face == Enum.NormalId.Front then "StandGui" else "StandGuiBack"
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 24
		surface.LightInfluence = 0
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.Position = UDim2.fromOffset(6, 6)
		panel.Size = UDim2.new(1, -12, 1, -12)
		panel.BackgroundColor3 = Color3.new(1, 1, 1)
		panel.Parent = surface
		addCorner(panel, UDim.new(0, 12))
		addStroke(panel, 3)
		addGradient(panel, color:Lerp(C.White, 0.12), color:Lerp(C.Ink, 0.1))
		addText(panel, "Text", title, C.White, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8), 3)
		surface.Parent = sign
	end
end

local function buildStand(parent: Instance, def: StandDef)
	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("Panel", def.Panel)
	local cf = lookAt(def.Position, Vector3.new(def.Facing.X, def.Position.Y, def.Facing.Z))
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local SW, SD = STAND_WIDTH, STAND_DEPTH
	local deckTop = 0.8
	local counterHeight = 3.2
	local counterZ = -SD / 2 + 1.1 -- comptoir à l'avant (-Z local = côté client)
	local yFront, yBack = 8.2, 10.4 -- bords de la toile (pente vers l'avant)
	local signHeight = 2.8

	-- Plancher, comptoir en planches et plateau en bois sombre
	block(
		model,
		"StandDeck",
		Vector3.new(SW + 1.2, 0.5, SD + 1.2),
		at(0, deckTop - 0.25, 0),
		C.Wood,
		Enum.Material.WoodPlanks
	)
	local counter = block(
		model,
		"Counter",
		Vector3.new(SW - 0.6, counterHeight, 2),
		at(0, deckTop + counterHeight / 2, counterZ),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	block(
		model,
		"CounterTop",
		Vector3.new(SW + 0.2, 0.36, 2.7),
		at(0, deckTop + counterHeight + 0.18, counterZ - 0.05),
		C.WoodDark,
		Enum.Material.Wood
	)
	-- Poteaux d'angle : ceux du fond montent jusqu'en haut de l'enseigne
	for _, sx in { -1, 1 } do
		local x = sx * (SW / 2 - 0.35)
		block(
			model,
			"StandPost",
			Vector3.new(0.7, yFront - deckTop, 0.7),
			at(x, (yFront + deckTop) / 2, -SD / 2 + 0.35),
			C.WoodDark,
			Enum.Material.Wood
		)
		local backTop = yBack + signHeight + 0.4
		block(
			model,
			"StandPost",
			Vector3.new(0.7, backTop - deckTop, 0.7),
			at(x, (backTop + deckTop) / 2, SD / 2 - 0.35),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
	-- Fond de l'étal
	block(
		model,
		"StandBack",
		Vector3.new(SW - 0.7, yBack - deckTop - 0.3, 0.35),
		at(0, (yBack - 0.3 + deckTop) / 2, SD / 2 - 0.35),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)

	-- Toile rayée en pente (haut à l'arrière, bas à l'avant) et lambrequin à festons
	local stripes = 8
	local zBack, zFront = SD / 2 + 0.4, -SD / 2 - 0.9
	local run, rise = zBack - zFront, yBack - yFront
	local slope = math.atan2(rise, run)
	local length = math.sqrt(run * run + rise * rise)
	local spanX = SW + 0.8
	local stripeWidth = spanX / stripes
	for i = 1, stripes do
		local x = -spanX / 2 + (i - 0.5) * stripeWidth
		local color = if i % 2 == 1 then def.Stripe else C.White
		block(
			model,
			"Awning",
			Vector3.new(stripeWidth + 0.02, 0.24, length),
			at(x, (yBack + yFront) / 2, (zBack + zFront) / 2) * CFrame.Angles(-slope, 0, 0),
			color,
			Enum.Material.Fabric,
			noCollide()
		)
		-- Bande verticale devant, demi-disques derrière elle : seuls les festons dépassent
		block(
			model,
			"Valance",
			Vector3.new(stripeWidth + 0.02, 1, 0.16),
			at(x, yFront - 0.5, zFront - 0.06),
			color,
			Enum.Material.Fabric,
			noCollide({ CastShadow = false })
		)
		disc(
			model,
			"Valance",
			0.14,
			stripeWidth,
			at(x, yFront - 1, zFront + 0.04),
			color,
			Enum.Material.Fabric,
			noCollide({ CastShadow = false })
		)
	end

	-- Enseigne entre les poteaux du fond, au-dessus de la toile
	local sign = block(
		model,
		"StandSign",
		Vector3.new(SW - 1.1, signHeight, 0.4),
		at(0, yBack + 0.2 + signHeight / 2, SD / 2 - 0.35),
		C.White,
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	buildStandSign(sign, def.Title, def.Stripe)

	-- Marchandises sur le comptoir
	local top = deckTop + counterHeight + 0.36
	if def.Panel == "Shop" then
		-- Paquets cadeaux (ruban blanc) et pile de pièces d'or
		local gifts = { { X = -4, Size = 1.5, Color = C.Index }, { X = -2.2, Size = 1.2, Color = C.Money } }
		for k, gift in gifts do
			local size = gift.Size
			local giftCF = at(gift.X, top + size / 2, counterZ) * CFrame.Angles(0, 0.25 * k, 0)
			block(model, "Gift", Vector3.one * size, giftCF, gift.Color, Enum.Material.SmoothPlastic)
			block(
				model,
				"Ribbon",
				Vector3.new(size + 0.06, size + 0.06, 0.3),
				giftCF,
				C.White,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
			block(
				model,
				"Ribbon",
				Vector3.new(0.3, size + 0.06, size + 0.06),
				giftCF,
				C.White,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
		for k = 0, 2 do
			cylinder(
				model,
				"Coin",
				0.3,
				1.2,
				at(3.4 + (k % 2) * 0.15, top + 0.15 + k * 0.32, counterZ),
				C.Gold,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
	else
		-- Grand livre ouvert (l'Index des créatures) et pile de livres
		local bookCF = at(-2.4, top, counterZ) * CFrame.Angles(0, 0.1, 0)
		block(
			model,
			"BookCover",
			Vector3.new(4.4, 0.2, 2.6),
			bookCF * CFrame.new(0, 0.1, 0),
			C.Index,
			Enum.Material.SmoothPlastic
		)
		for _, sx in { -1, 1 } do
			block(
				model,
				"BookPage",
				Vector3.new(2, 0.24, 2.3),
				bookCF * CFrame.new(sx * 1.02, 0.32, 0) * CFrame.Angles(0, 0, sx * 0.1),
				C.White,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
		local books =
			{ { Color = C.Shop, Turn = 0.2 }, { Color = C.Money, Turn = -0.15 }, { Color = C.Gold, Turn = 0.1 } }
		for k, book in books do
			block(
				model,
				"Book",
				Vector3.new(1.9 - k * 0.15, 0.42, 2.4 - k * 0.15),
				at(3.4, top + 0.21 + (k - 1) * 0.42, counterZ) * CFrame.Angles(0, book.Turn, 0),
				book.Color,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Tonneaux et caisses groupés contre le flanc extérieur de l'étal
	local outer = -def.Side -- X local du flanc extérieur (le repère suit l'orientation)
	for k, spot in { { 0.4, -1.6 }, { 0.6, 1.2 } } do
		local barrelCF = at(outer * (SW / 2 + 1.9 + spot[1]), 0, spot[2])
		cylinder(model, "Barrel", 3, 2.4, barrelCF * CFrame.new(0, 1.5, 0), C.Wood, Enum.Material.Wood)
		for _, y in { 0.7, 2.3 } do
			cylinder(
				model,
				"BarrelBand",
				0.25,
				2.5,
				barrelCF * CFrame.new(0, y, 0),
				C.Metal,
				Enum.Material.Metal,
				noCollide()
			)
		end
		if k == 2 then
			-- Caisses empilées à côté du second tonneau
			local crateCF = barrelCF * CFrame.new(outer * 0.4, 0, 2.9) * CFrame.Angles(0, 0.2, 0)
			block(
				model,
				"Crate",
				Vector3.one * 2.3,
				crateCF * CFrame.new(0, 1.15, 0),
				C.WoodLight,
				Enum.Material.WoodPlanks
			)
			block(
				model,
				"Crate",
				Vector3.one * 1.8,
				crateCF * CFrame.new(0.1, 3.2, 0.1) * CFrame.Angles(0, -0.35, 0),
				C.WoodLight,
				Enum.Material.WoodPlanks
			)
		end
	end

	-- Prompt du comptoir : StandController ouvre la fenêtre « Panel »
	local prompt = addPrompt(counter, "StandPrompt", "Ouvrir", def.Title, 0, Enum.KeyCode.E)
	prompt.MaxActivationDistance = 12
	prompt:SetAttribute("Panel", def.Panel)

	model.PrimaryPart = counter
	model.Parent = parent
end

local function buildStands(map: Folder)
	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = map
	for _, def in STANDS do
		buildStand(stands, def)
	end
end

-- Arbre « nuage » : tronc + une grosse boule de feuillage et deux plus petites
-- (style unique de tous les arbres de la map)
local function tree(parent: Instance, position: Vector3, scale: number, light: boolean?)
	local height = 7 * scale
	cylinder(
		parent,
		"Trunk",
		height + 1.5 * scale,
		1.5 * scale,
		CFrame.new(position + Vector3.new(0, (height + 1.5 * scale) / 2, 0)),
		C.Trunk,
		Enum.Material.Wood
	)
	local leaves = if light then C.LeavesLight else C.Leaves
	local crown = position + Vector3.new(0, height + 3 * scale, 0)
	ellipsoid(
		parent,
		"Leaves",
		Vector3.new(10.5, 8.8, 10.5) * scale,
		CFrame.new(crown),
		leaves,
		Enum.Material.Grass,
		{ CanCollide = false }
	)
	local turn = rand(0, math.pi * 2)
	for i = 1, 2 do
		local a = turn + i * math.pi * 0.85
		ellipsoid(
			parent,
			"Leaves",
			Vector3.new(6.6, 5.8, 6.6) * scale,
			CFrame.new(crown + Vector3.new(math.cos(a) * 4.2, -1.2 + i * 1.6, math.sin(a) * 4.2) * scale),
			leaves:Lerp(C.LeavesLight, 0.4),
			Enum.Material.Grass,
			{ CanCollide = false }
		)
	end
end

-- Deux jardinières rondes avec un arbre, derrière les piliers de la Rift : elles
-- encadrent le portail et habillent le fond de l'esplanade
local function buildPlanters(map: Folder)
	local plaza = map:FindFirstChild("Plaza") :: Folder
	for _, side in { -1, 1 } do
		local center = Vector3.new(side * 46, 0, MapBuilder.RIFT_Z - 17)
		cylinder(plaza, "Planter", 1.2, 11, CFrame.new(center + Vector3.new(0, 0.6, 0)), C.Curb, Enum.Material.Concrete)
		cylinder(
			plaza,
			"PlanterSoil",
			1.24,
			9.8,
			CFrame.new(center + Vector3.new(0, 0.62, 0)),
			C.Grass,
			Enum.Material.Grass
		)
		tree(plaza, center + Vector3.new(0, 1.2, 0), 1.15)
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

	-- Petite place en béton au bout du tapis (même dalle que les trottoirs)
	cylinder(exit, "ExitRim", 0.36, 32, CFrame.new(floor + Vector3.new(0, 0.18, 0)), C.Curb, Enum.Material.Concrete)
	cylinder(exit, "ExitDais", 0.4, 30, CFrame.new(floor + Vector3.new(0, 0.2, 0)), C.Sidewalk, Enum.Material.Concrete)

	local segments = 20
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local rotation = frame * CFrame.Angles(0, 0, angle)
		block(
			exit,
			"ExitRing",
			Vector3.new(2 * math.pi * (EXIT_RADIUS + 1) / segments * 1.12, 2.4, 2.6),
			rotation * CFrame.new(0, EXIT_RADIUS + 1, 0),
			if i % 2 == 0 then C.RiftStoneLight else C.RiftStone,
			Enum.Material.Slate,
			noCollide()
		)
	end
	-- Fin cercle violet (sans néon : réservé à la Rift) : un disque à peine plus
	-- grand que le cœur sombre
	disc(exit, "ExitGlow", 0.3, EXIT_RADIUS * 2 - 0.2, frame, C.Exit, Enum.Material.SmoothPlastic, noCollide())
	disc(
		exit,
		"ExitCore",
		0.6,
		EXIT_RADIUS * 2 - 2.2,
		frame,
		Color3.fromRGB(26, 12, 44),
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
	ball(exit, "ExitEye", 1.4, frame, Color3.fromRGB(226, 204, 255), Enum.Material.SmoothPlastic, noCollide())
	exit.Parent = map
end

---------------------------------------------------------------------------
-- Chemin : tapis rouge en tissu, bordures or, trottoirs en béton, lampadaires
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

-- Flèche peinte sur le tapis : chevron blanc semi-transparent (pas de néon) qui
-- pointe vers +Z. Deux bras à 45° + un carré sur la pointe qui comble exactement
-- l'encoche entre eux : aucune pièce ne se recouvre, la transparence reste uniforme.
local CHEVRON_ARM = 3.6 -- longueur d'un bras
local CHEVRON_WIDTH = 1 -- largeur de la bande peinte
local function chevron(parent: Instance, apex: Vector3, index: number)
	local props = noCollide({ Transparency = 0.35, CastShadow = false })
	local s45 = math.sqrt(0.5)
	local w, length = CHEVRON_WIDTH, CHEVRON_ARM
	-- Coin intérieur de la pointe (sur l'axe) : la pointe extérieure est w·√2 plus loin
	local tip = apex - Vector3.new(0, 0, w * math.sqrt(2))
	for _, side in { -1, 1 } do
		local along = Vector3.new(side * s45, 0, -s45) -- vers l'arrière et l'extérieur
		local across = Vector3.new(side * s45, 0, s45) -- largeur de la bande
		local arm = block(
			parent,
			"Chevron",
			Vector3.new(w, 0.05, length),
			CFrame.fromMatrix(
				tip + along * (length / 2) + across * (w / 2),
				across,
				Vector3.yAxis,
				across:Cross(Vector3.yAxis)
			),
			C.White,
			Enum.Material.SmoothPlastic,
			props
		)
		arm:SetAttribute("Index", index)
	end
	local cap = block(
		parent,
		"Chevron",
		Vector3.new(w, 0.05, w),
		CFrame.new(tip + Vector3.new(0, 0, w * s45)) * CFrame.Angles(0, math.rad(45), 0),
		C.White,
		Enum.Material.SmoothPlastic,
		props
	)
	cap:SetAttribute("Index", index)
end

-- Lampadaire : pied et fût en métal sombre, globe chaud (néon : un des trois seuls
-- usages autorisés avec la Rift et les lasers)
local function lamp(parent: Instance, base: Vector3)
	cylinder(parent, "LampBase", 0.8, 1.7, CFrame.new(base + Vector3.new(0, 0.4, 0)), C.Metal, Enum.Material.Metal)
	cylinder(parent, "LampPost", 10.6, 0.6, CFrame.new(base + Vector3.new(0, 5.6, 0)), C.Metal, Enum.Material.Metal)
	cylinder(parent, "LampCollar", 0.45, 1.4, CFrame.new(base + Vector3.new(0, 10.9, 0)), C.Gold, Enum.Material.Metal)
	local globe = ball(
		parent,
		"Lamp",
		2.3,
		CFrame.new(base + Vector3.new(0, 12.2, 0)),
		C.LampGlow,
		Enum.Material.Neon,
		noCollide()
	)
	cylinder(parent, "LampCap", 0.4, 1.3, CFrame.new(base + Vector3.new(0, 13.45, 0)), C.Metal, Enum.Material.Metal)
	pointLight(globe, C.LampGlow, 18, 0.7)
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
	local inner, outer = MapBuilder.SIDEWALK_INNER, MapBuilder.SIDEWALK_OUTER

	-- Le tapis rouge (tissu) sort du vortex de la Rift et entre dans le portail de sortie
	local carpetStart, carpetEnd = MapBuilder.RIFT_Z + 2, MapBuilder.EXIT_Z - 2
	block(
		road,
		"Carpet",
		Vector3.new(MapBuilder.CARPET_WIDTH, y, carpetEnd - carpetStart),
		CFrame.new(0, y / 2, (carpetStart + carpetEnd) / 2),
		C.Carpet,
		Enum.Material.Fabric
	)

	-- Ouvertures de la bordure blanche devant chaque entrée de base (le trottoir
	-- continue sans marche jusqu'au seuil)
	local gaps = {}
	for _, z in MapBuilder.PLOT_ROWS_Z do
		table.insert(gaps, { z - (OPENING / 2 + 2), z + (OPENING / 2 + 2) })
	end
	table.sort(gaps, function(a, b)
		return a[1] < b[1]
	end)

	for _, side in { -1, 1 } do
		-- Bordure or légèrement surélevée entre le tapis et le trottoir
		block(
			road,
			"CarpetBorder",
			Vector3.new(1, 0.8, length),
			CFrame.new(side * (half + 0.5), 0.4, mid),
			C.Gold,
			Enum.Material.SmoothPlastic
		)
		-- Trottoir en béton
		local width = outer - inner
		block(
			road,
			"Sidewalk",
			Vector3.new(width, FLOOR_TOP, length),
			CFrame.new(side * (inner + width / 2), FLOOR_TOP / 2, mid),
			C.Sidewalk,
			Enum.Material.Concrete
		)
		-- Bordure claire côté herbe, interrompue devant les entrées
		local from = z0 - 0.45
		local segments = {}
		for _, gap in gaps do
			table.insert(segments, { from, gap[1] })
			from = gap[2]
		end
		table.insert(segments, { from, z1 + 0.45 })
		for _, segment in segments do
			local a, b = segment[1], segment[2]
			block(
				road,
				"Curb",
				Vector3.new(0.9, FLOOR_TOP + 0.35, b - a),
				CFrame.new(side * (outer - 0.45), (FLOOR_TOP + 0.35) / 2, (a + b) / 2),
				C.Curb,
				Enum.Material.Concrete
			)
		end
		-- Joints de dalles (une dalle de 10 x 11,7 studs : 3 entre deux lampadaires)
		local slab = 35 / 3
		local count = math.floor(length / slab)
		for k = 1, count do
			local z = z0 + k * slab
			if z < z1 - 1 then
				block(
					road,
					"SidewalkJoint",
					Vector3.new(width - 0.9, 0.03, 0.2),
					CFrame.new(side * (inner + (width - 0.9) / 2), FLOOR_TOP + 0.01, z),
					C.Joint,
					Enum.Material.SmoothPlastic,
					noCollide({ CastShadow = false })
				)
			end
		end
	end
	-- Embouts arrondis des bordures or
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

	-- Flèches peintes (Index croissant dans le sens de marche : RiftVisualController
	-- y fait courir une légère vague d'opacité vers la sortie)
	local index = 0
	local z = z0 + 7
	while z <= z1 - 3 do
		chevron(road, Vector3.new(0, y + 0.025, z), index)
		index += 1
		z += 18
	end

	-- Lampadaires tous les 35 studs, de part et d'autre de chaque entrée
	for k = 0, 9 do
		local lampZ = -157.5 + k * 35
		for _, side in { -1, 1 } do
			lamp(road, Vector3.new(side * (outer - 0.45), FLOOR_TOP + 0.35, lampZ))
		end
	end
end

---------------------------------------------------------------------------
-- Décor groupé : bosquets d'arbres d'un seul style sur le pourtour, quelques
-- rochers, buissons le long des murs des bases (traversables), îlots à l'horizon
---------------------------------------------------------------------------
local function bush(parent: Instance, position: Vector3, scale: number)
	ellipsoid(
		parent,
		"Bush",
		Vector3.new(4.6, 3.6, 4.2) * scale,
		CFrame.new(position + Vector3.new(0, 1.2 * scale, 0)),
		C.Bush,
		Enum.Material.Grass,
		-- Décor traversable : un buisson collé à un mur servirait de marchepied
		noCollide()
	)
	ellipsoid(
		parent,
		"Bush",
		Vector3.new(3.4, 2.8, 3.2) * scale,
		CFrame.new(position + Vector3.new(1.7 * scale, 0.9 * scale, 0.5 * scale)),
		C.BushLight,
		Enum.Material.Grass,
		noCollide()
	)
end

-- Rocher : galets de Slate arrondis, à moitié enterrés
local function rock(parent: Instance, position: Vector3, scale: number)
	for i = 1, 3 do
		local size = Vector3.new(rand(5, 7), rand(3, 4.5), rand(4.5, 6)) * scale * (if i == 1 then 1 else 0.55)
		local offset = if i == 1 then Vector3.zero else Vector3.new(rand(-3.5, 3.5), 0, rand(-3.5, 3.5)) * scale
		ellipsoid(
			parent,
			"Rock",
			size,
			CFrame.new(position + offset + Vector3.new(0, size.Y * 0.28, 0)) * CFrame.Angles(0, rand(0, 3), 0),
			if i == 1 then C.Rock else C.RockDark,
			Enum.Material.Slate
		)
	end
end

local function floatingIsland(parent: Instance, position: Vector3, radius: number)
	cylinder(parent, "IslandTop", 3, radius * 2, CFrame.new(position), C.Grass, Enum.Material.Grass)
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
	tree(parent, position + Vector3.new(0, 1.5, 0), radius / 13)
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

-- Emplacement libre pour un décor : sur l'île, hors du tapis et des trottoirs,
-- hors des bases, de l'esplanade de la Rift et du portail de sortie
local function isFree(position: Vector3, margin: number): boolean
	local x, z = position.X, position.Z
	if math.sqrt(x * x + z * z) > MapBuilder.ISLAND_RADIUS - 18 - margin then
		return false
	end
	if math.abs(x) < MapBuilder.SIDEWALK_OUTER + 6 + margin then
		return false
	end
	local fromRift = Vector3.new(x, 0, z - MapBuilder.RIFT_Z).Magnitude
	if fromRift < PLAZA_RADIUS + 4 + margin then
		return false
	end
	if z > MapBuilder.EXIT_Z - 40 - margin and math.abs(x) < 32 + margin then
		return false
	end
	return not insideAnyPlot(position, margin)
end

-- Bosquets (centre, nombre d'arbres, rayon) : sur le pourtour, jamais sur les
-- passages ni devant les bases. Placés à la main pour encadrer la Rift et la sortie
local GROVES = {
	{ Center = Vector3.new(-168, 0, -52), Count = 6, Spread = 15 },
	{ Center = Vector3.new(-172, 0, 78), Count = 6, Spread = 15 },
	{ Center = Vector3.new(-236, 0, 8), Count = 5, Spread = 13 },
	{ Center = Vector3.new(170, 0, -34), Count = 6, Spread = 15 },
	{ Center = Vector3.new(176, 0, 92), Count = 5, Spread = 14 },
	{ Center = Vector3.new(238, 0, -6), Count = 5, Spread = 13 },
	{ Center = Vector3.new(-108, 0, -214), Count = 6, Spread = 14 },
	{ Center = Vector3.new(112, 0, -210), Count = 6, Spread = 14 },
	{ Center = Vector3.new(-48, 0, -268), Count = 4, Spread = 10 },
	{ Center = Vector3.new(52, 0, -266), Count = 4, Spread = 10 },
	{ Center = Vector3.new(-104, 0, 206), Count = 5, Spread = 14 },
	{ Center = Vector3.new(110, 0, 200), Count = 5, Spread = 14 },
	{ Center = Vector3.new(-46, 0, 252), Count = 4, Spread = 11 },
	{ Center = Vector3.new(50, 0, 254), Count = 4, Spread = 11 },
	{ Center = Vector3.new(-212, 0, -150), Count = 4, Spread = 12 },
	{ Center = Vector3.new(214, 0, 146), Count = 4, Spread = 12 },
	{ Center = Vector3.new(-204, 0, 162), Count = 4, Spread = 12 },
	{ Center = Vector3.new(210, 0, -150), Count = 4, Spread = 12 },
	-- Ceinture d'arbres le long de la bordure (entre les bosquets ci-dessus)
	{ Center = Vector3.new(262, 0, 56), Count = 5, Spread = 13 },
	{ Center = Vector3.new(178, 0, 200), Count = 5, Spread = 13 },
	{ Center = Vector3.new(-178, 0, 200), Count = 5, Spread = 13 },
	{ Center = Vector3.new(-262, 0, 56), Count = 5, Spread = 13 },
	{ Center = Vector3.new(-262, 0, -56), Count = 5, Spread = 13 },
	{ Center = Vector3.new(-170, 0, -206), Count = 5, Spread = 13 },
	{ Center = Vector3.new(170, 0, -206), Count = 5, Spread = 13 },
	{ Center = Vector3.new(262, 0, -56), Count = 5, Spread = 13 },
}

-- Rochers : près des bosquets, pas au milieu des pelouses
local ROCKS = {
	{ Position = Vector3.new(-150, 0, -32), Scale = 1.2 },
	{ Position = Vector3.new(-222, 0, 30), Scale = 1 },
	{ Position = Vector3.new(154, 0, -60), Scale = 1.3 },
	{ Position = Vector3.new(222, 0, 20), Scale = 0.9 },
	{ Position = Vector3.new(-86, 0, -232), Scale = 1.1 },
	{ Position = Vector3.new(88, 0, 222), Scale = 1.2 },
	{ Position = Vector3.new(-150, 0, 104), Scale = 1 },
	{ Position = Vector3.new(160, 0, 118), Scale = 1.1 },
}

local function buildDecor(map: Folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map

	for g, grove in GROVES do
		local planted, attempts = 0, 0
		while planted < grove.Count and attempts < 40 do
			attempts += 1
			-- Premier arbre (le plus grand) au centre, les autres en couronne irrégulière
			local angle = attempts * 2.4 + g
			local offset = if attempts == 1
				then Vector3.zero
				else Vector3.new(math.cos(angle), 0, math.sin(angle)) * rand(grove.Spread * 0.55, grove.Spread)
			local position = grove.Center + offset
			if isFree(position, 6) then
				planted += 1
				tree(decor, position, if attempts == 1 then rand(1.25, 1.4) else rand(0.85, 1.2), planted % 3 == 0)
			end
		end
	end

	for _, spec in ROCKS do
		if isFree(spec.Position, 3) then
			rock(decor, spec.Position, spec.Scale)
		end
	end

	-- Buissons le long des murs extérieurs des bases : devant la façade (de part et
	-- d'autre du seuil) et derrière le mur du fond
	for index = 1, MapBuilder.PLOT_COUNT do
		local plotCFrame = MapBuilder.GetPlotCFrame(index)
		local front = -MapBuilder.PLOT_DEPTH / 2
		for _, x in { -27.5, -21.5, 21.5, 27.5 } do
			bush(decor, plotCFrame:PointToWorldSpace(Vector3.new(x, 0, front - 2.1)), 0.8)
		end
		for _, x in { -21, -7, 7, 21 } do
			bush(decor, plotCFrame:PointToWorldSpace(Vector3.new(x, 0, MapBuilder.PLOT_DEPTH / 2 + 2.6)), 1.05)
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

-- Fenêtre blanche à en-tête coloré (jetons de l'interface, docs/ART_DIRECTION.md)
local function buildBoardGui(panel: BasePart, title: string, color: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = BOARD_PPS
	surface.LightInfluence = 0
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Position = UDim2.fromOffset(10, 10)
	background.Size = UDim2.new(1, -20, 1, -20)
	background.BackgroundColor3 = Color3.new(1, 1, 1)
	background.Parent = surface
	addCorner(background, UDim.new(0, 24))
	addStroke(background, 6)
	addGradient(background, C.White, Color3.fromRGB(241, 244, 250))
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(0, 0)
	header.Size = UDim2.new(1, 0, 0, 92)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.Parent = background
	addCorner(header, UDim.new(0, 24))
	addGradient(header, color:Lerp(C.White, 0.1), color:Lerp(C.Ink, 0.12))
	addText(header, "Title", title, C.White, UDim2.fromOffset(20, 10), UDim2.new(1, -40, 1, -20), 3.5)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(22, 108)
	rows.Size = UDim2.new(1, -44, 1, -124)
	rows.Parent = background
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	surface.Parent = panel
end

local function buildBoards(map: Folder)
	local boards = Instance.new("Folder")
	boards.Name = "Boards"
	boards.Parent = map
	local definitions = {
		{ Name = "MoneyBoard", Side = -1, Title = "💰 Les plus riches", Color = Color3.fromRGB(47, 190, 80) },
		{ Name = "StealsBoard", Side = 1, Title = "🦹 Maîtres voleurs", Color = Color3.fromRGB(240, 70, 74) },
	}
	local plinthTop = 1
	-- Panneaux surélevés (façon enseigne) : lisibles de loin, au-dessus des stands
	local bottom = 12.5
	local centerY = bottom + BOARD_SIZE.Y / 2
	local top = bottom + BOARD_SIZE.Y
	for _, def in definitions do
		-- Hors de l'emprise des piliers de la Rift (X = ±30), en bord d'esplanade
		local base = Vector3.new(def.Side * 54, 0, MapBuilder.RIFT_Z + 16)
		-- Légèrement tourné vers le centre du tapis
		local facing = lookAt(base, Vector3.new(0, 0, MapBuilder.RIFT_Z + 95))
		local cf = facing * CFrame.new(0, centerY, 0)
		local panel =
			block(boards, def.Name, Vector3.new(BOARD_SIZE.X, BOARD_SIZE.Y, 1), cf, C.Ink, Enum.Material.SmoothPlastic)
		-- Deux poteaux en bois sombre sur socles de béton, traverse sous le panneau,
		-- petit toit au-dessus
		for _, side in { -1, 1 } do
			local x = side * (BOARD_SIZE.X / 2 + 0.9)
			block(
				boards,
				"BoardPlinth",
				Vector3.new(3.4, plinthTop, 3.4),
				facing * CFrame.new(x, plinthTop / 2, 0.2),
				C.Curb,
				Enum.Material.Concrete
			)
			block(
				boards,
				"BoardPost",
				Vector3.new(1.8, top + 1 - plinthTop, 1.8),
				facing * CFrame.new(x, (top + 1 + plinthTop) / 2, 0.2),
				C.WoodDark,
				Enum.Material.Wood
			)
		end
		block(
			boards,
			"BoardBeam",
			Vector3.new(BOARD_SIZE.X + 1.2, 1, 1.4),
			facing * CFrame.new(0, bottom - 0.5, 0.2),
			C.WoodDark,
			Enum.Material.Wood
		)
		block(
			boards,
			"BoardRoof",
			Vector3.new(BOARD_SIZE.X + 4.6, 0.8, 2.8),
			facing * CFrame.new(0, top + 1.4, 0.2),
			C.WoodDark,
			Enum.Material.Wood
		)
		buildBoardGui(panel, def.Title, def.Color)
	end
end

---------------------------------------------------------------------------
-- Bases : sol en planches, murs bas en brique blanc cassé. La couleur d'équipe
-- n'apparaît que sur le chaperon des murs, l'arche et le panneau.
---------------------------------------------------------------------------
-- Panneau « Base de {nom} » sur l'arche (texte écrit par PlotController)
local SIGN_SIZE = Vector2.new(30, 6.4)
local SIGN_PPS = 20

local function buildSignGui(sign: BasePart, color: Color3, face: Enum.NormalId, name: string)
	local surface = Instance.new("SurfaceGui")
	surface.Name = name
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = SIGN_PPS
	surface.LightInfluence = 0
	-- Cadre blanc (la pièce), panneau couleur d'équipe à contour encre
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(8, 8)
	panel.Size = UDim2.new(1, -16, 1, -16)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.Parent = surface
	addCorner(panel, UDim.new(0, 14))
	addStroke(panel, 3)
	addGradient(panel, color:Lerp(C.White, 0.1), color:Lerp(C.Ink, 0.1))
	addText(panel, "Text", "Base libre", C.White, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.92, 0.76), 3.5)
	-- Ligne d'état dans une pastille encre (lisible sur toutes les couleurs d'équipe) :
	-- cachée tant qu'elle est vide (PlotController)
	local pill = Instance.new("Frame")
	pill.Name = "StatusPill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.6)
	pill.Size = UDim2.fromScale(0.46, 0.32)
	pill.BackgroundColor3 = C.Ink
	pill.BackgroundTransparency = 0.08
	pill.Visible = false
	pill.Parent = panel
	addCorner(pill, UDim.new(0.5, 0))
	addText(pill, "Status", "", C.White, UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.88, 0.8), 0)
	surface.Parent = sign
end

local function buildPlot(plots: Folder, index: number)
	local plotCFrame = MapBuilder.GetPlotCFrame(index)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
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

	-- Sol en planches claires
	local floor =
		block(model, "Floor", Vector3.new(W, 1.2, D), at(0, FT - 0.6, 0), C.BaseFloor, Enum.Material.WoodPlanks)
	model.PrimaryPart = floor

	-- Murs bas en brique blanc cassé, chaperon couleur d'équipe
	local thickness = 1.8
	local capHeight = 1
	local function wall(length: number, cf: CFrame)
		block(
			model,
			"Wall",
			Vector3.new(length, H, thickness),
			cf * CFrame.new(0, FT + H / 2, 0),
			C.BaseWall,
			Enum.Material.Brick
		)
		block(
			model,
			"WallCap",
			Vector3.new(length + 0.4, capHeight, thickness + 0.5),
			cf * CFrame.new(0, FT + H + capHeight / 2, 0),
			color,
			Enum.Material.SmoothPlastic
		)
	end
	local sideCF = CFrame.Angles(0, math.rad(90), 0)
	local pillarWidth = 3.6 -- piliers de l'arche
	wall(W, at(0, 0, D / 2 - thickness / 2))
	wall(D, at(-W / 2 + thickness / 2, 0, 0) * sideCF)
	wall(D, at(W / 2 - thickness / 2, 0, 0) * sideCF)
	local frontStart = OPENING / 2 + pillarWidth
	local frontLength = W / 2 - frontStart
	for _, side in { -1, 1 } do
		wall(frontLength, at(side * (frontStart + frontLength / 2), 0, front + thickness / 2))
	end
	-- Piliers d'angle (et au milieu des longs murs) un peu plus hauts que les murs
	local postSize = 3.2
	local postHeight = H + 1.8
	local postSpots = {
		{ -W / 2 + postSize / 2 - 0.2, front + postSize / 2 - 0.2 },
		{ W / 2 - postSize / 2 + 0.2, front + postSize / 2 - 0.2 },
		{ -W / 2 + postSize / 2 - 0.2, D / 2 - postSize / 2 + 0.2 },
		{ W / 2 - postSize / 2 + 0.2, D / 2 - postSize / 2 + 0.2 },
		{ -W / 2 + postSize / 2 - 0.2, 0 },
		{ W / 2 - postSize / 2 + 0.2, 0 },
	}
	for _, spot in postSpots do
		block(
			model,
			"Post",
			Vector3.new(postSize, postHeight, postSize),
			at(spot[1], FT + postHeight / 2, spot[2]),
			C.BaseWall,
			Enum.Material.Brick
		)
		block(
			model,
			"PostCap",
			Vector3.new(postSize + 0.6, capHeight, postSize + 0.6),
			at(spot[1], FT + postHeight + capHeight / 2, spot[2]),
			color,
			Enum.Material.SmoothPlastic
		)
	end

	-- Arche d'entrée : piliers en brique, linteau couleur d'équipe, panneau dessus
	local pillarX = OPENING / 2 + pillarWidth / 2
	for _, side in { -1, 1 } do
		block(
			model,
			"ArchPillar",
			Vector3.new(pillarWidth, ARCH_CLEAR, 3.8),
			at(side * pillarX, FT + ARCH_CLEAR / 2, front + 1),
			C.BaseWall,
			Enum.Material.Brick
		)
		-- Émetteur laser (face intérieure du pilier) : bande de métal gris clair
		block(
			model,
			"LaserEmitter",
			Vector3.new(0.5, ARCH_CLEAR - 1, 1.4),
			at(side * (OPENING / 2 - 0.2), FT + ARCH_CLEAR / 2, front + 1),
			C.Steel,
			Enum.Material.Metal
		)
	end
	local beamHeight = 1.8
	block(
		model,
		"ArchBeam",
		Vector3.new(OPENING + pillarWidth * 2 + 0.8, beamHeight, 4.4),
		at(0, FT + ARCH_CLEAR + beamHeight / 2, front + 1),
		color,
		Enum.Material.SmoothPlastic
	)
	local sign = block(
		model,
		"Sign",
		Vector3.new(SIGN_SIZE.X, SIGN_SIZE.Y, 0.8),
		at(0, FT + ARCH_CLEAR + beamHeight + 0.15 + SIGN_SIZE.Y / 2, front + 1),
		C.White,
		Enum.Material.SmoothPlastic,
		noCollide()
	)
	buildSignGui(sign, color, Enum.NormalId.Front, "SignGui")
	-- Même panneau au dos : lisible depuis l'intérieur de la base et l'esplanade
	buildSignGui(sign, color, Enum.NormalId.Back, "SignGuiBack")

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
	-- Lasers cachés (BaseDefenseService les montre, en néon, base verrouillée)
	local lasers = Instance.new("Folder")
	lasers.Name = "Lasers"
	lasers.Parent = model
	for i = 1, 5 do
		local y = FT + 1.6 + (i - 1) * 2.35
		rod(
			lasers,
			"Laser",
			OPENING,
			0.4,
			at(0, y, front + 1),
			C.Laser,
			Enum.Material.SmoothPlastic,
			noCollide({ Transparency = 1, CastShadow = false })
		)
		for _, side in { -1, 1 } do
			-- Lentille éteinte : BaseDefenseService l'allume en rouge quand la base est
			-- verrouillée (rouge = danger, jamais sur une base ouverte)
			block(
				model,
				"LaserLens",
				Vector3.new(0.3, 0.55, 0.55),
				at(side * (OPENING / 2 - 0.5), y, front + 1),
				C.LensOff,
				Enum.Material.SmoothPlastic,
				noCollide()
			)
		end
	end

	-- Seuil en béton entre le trottoir et l'entrée (même dalle que le trottoir)
	local outside = MapBuilder.PLOT_X - D / 2 - MapBuilder.SIDEWALK_OUTER -- herbe entre trottoir et façade
	block(
		model,
		"Doorstep",
		Vector3.new(OPENING + 4, FT, outside + 0.9),
		at(0, FT / 2, front - (outside + 0.9) / 2),
		C.Sidewalk,
		Enum.Material.Concrete
	)

	-- Point d'apparition du propriétaire (face au tapis) : repère invisible
	marker(model, "Spawn", Vector3.new(7, 0.2, 7), at(0, FT + 0.1, -30))

	-- Arrivée du portail de raccourci : sur le trottoir DEVANT la base (hors barrière),
	-- tournée vers l'entrée. Repère invisible : ShortcutService joue déjà l'effet de
	-- téléportation à l'arrivée
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

	-- Bouton de verrouillage : gros bouton rouge (danger) sur un socle clair, juste
	-- après l'entrée (visible depuis le trottoir à travers l'ouverture)
	local lockAt = at(-11, 0, front + 10)
	cylinder(model, "LockPlate", 0.4, 7.6, lockAt * CFrame.new(0, FT + 0.2, 0), C.Curb, Enum.Material.Concrete)
	cylinder(model, "LockRing", 0.5, 6.2, lockAt * CFrame.new(0, FT + 0.25, 0), C.Ink, Enum.Material.SmoothPlastic)
	local lockButton = cylinder(
		model,
		"LockButton",
		0.9,
		5.4,
		lockAt * CFrame.new(0, FT + 0.85, 0),
		C.Danger,
		Enum.Material.SmoothPlastic
	)
	addPrompt(lockButton, "LockPrompt", "Verrouiller", "Base", 0.4, Enum.KeyCode.E)
	addLabel(lockButton, "🔒 Verrouiller", 4)

	-- Portail de fusion (violet = magique) : anneau de marbre clair, disque violet et
	-- voile scintillant (ForceField), aucun néon
	local fx, fz = 19, front + 9
	cylinder(model, "FusionStep", 0.5, 9.6, at(fx, FT + 0.25, fz), C.Curb, Enum.Material.Concrete)
	cylinder(model, "FusionStep", 0.5, 7.6, at(fx, FT + 0.75, fz), C.Marble, Enum.Material.Marble)
	local portalCenter = at(fx, FT + 6.2, fz)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		block(
			model,
			"FusionRing",
			Vector3.new(2.1, 1.3, 1.5),
			portalCenter * CFrame.Angles(0, 0, a) * CFrame.new(0, 4.3, 0),
			C.Marble,
			Enum.Material.Marble,
			noCollide()
		)
	end
	local fusion = disc(
		model,
		"FusionPortal",
		0.5,
		7.4,
		portalCenter,
		C.MagicDeep,
		Enum.Material.SmoothPlastic,
		{ CanCollide = false }
	)
	disc(
		model,
		"FusionSwirl",
		0.7,
		5.8,
		portalCenter,
		Color3.fromRGB(214, 196, 255),
		Enum.Material.ForceField,
		noCollide()
	)
	addPrompt(fusion, "FusionPrompt", "Fusionner", "Portail de fusion", 0, Enum.KeyCode.E)
	addLabel(fusion, "🌀 Fusion", 6.5)
	sparkle(fusion, C.Magic, 6, 0.35, 2)
	pointLight(fusion, C.Magic, 14, 1.2)

	-- Emplacements : socles ronds blancs, anneau fin couleur d'équipe. Construits
	-- « verrouillés » (INVISIBLES et traversables) comme au démarrage du serveur :
	-- PlotService montre ceux que le propriétaire a débloqués
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
				0.8,
				6.4,
				at(x, FT + 0.4, z),
				C.Pad,
				Enum.Material.Plastic,
				{ Transparency = 1, CanCollide = false, CanQuery = false }
			)
			slot:SetAttribute("SlotIndex", slotIndex)
			cylinder(
				slot,
				"SlotRing",
				0.36,
				7,
				at(x, FT + 0.18, z),
				color,
				Enum.Material.SmoothPlastic,
				noCollide({ Transparency = 1 })
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
	buildStands(map)
	buildPlanters(map)
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

	-- Apparition neutre avant l'attribution de la base : devant la Rift, entre son
	-- pilier ouest et la Boutique, face au tapis (dalle invisible)
	local spawnAt = Vector3.new(-20, 0.5, MapBuilder.RIFT_Z + 17)
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

	map.Parent = parent
	return map
end

return MapBuilder
