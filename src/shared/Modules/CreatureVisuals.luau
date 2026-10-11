--[[
	CreatureVisuals
	===============
	Fabrique de modèles de créatures, style « jouet » des jeux Steal a ... :
	couleurs franches, grosses têtes rondes, gros yeux brillants, joues roses,
	silhouettes lisibles de loin.

	1. Si un modèle nommé def.Model (ou def.Id) existe dans
	   ReplicatedStorage.Assets.Creatures, il est cloné (vos vrais modèles 3D).
	2. Sinon, un modèle procédural est construit :
	   - corps en ellipsoïdes lisses (SpecialMesh Sphere : aucun asset requis)
	   - archétypes : Blob, Spiky, Tall, Crystal, Wisp, Beast, Serpent, Golem
	   - traits propres à chaque créature (TRAITS : oreilles, cornes, ailes, bec,
	     trompe, tentacules, hélices...) : les 40 créatures ont leur silhouette
	   - accessoire de dimension : Lave (flamme), Néant (antennes + 3e œil),
	     Glace (neige + cristaux), Bonbon (chantilly + cerise), Cyber (antenne)
	   - rareté : taille, disque néon au sol (dès Rare), couronne et étincelles
	     dès Légendaire, lumière dès Mythique, aura arc-en-ciel pour Secret
	   - mutation : couleurs de la mutation + effet propre (voir Mutations.luau)
	   - étiquette (CreateBillboard) : texte seul façon « Steal a ... »
	   - chaque créature tient dans la case de son socle de base (10 x 8,8 studs) :
	     trop grande, elle est reconstruite un peu plus petite (fitFactor)

	Structure du modèle renvoyé :
	  Model (attributs CreatureId, Mutation, HipHeight, Floating si elle plane)
	    Root (PrimaryPart, invisible, centre du corps)  <- les ProximityPrompts vont ici
	    ...pièces visuelles soudées à Root
	    Info (BillboardGui, optionnel ; lignes "Mutation", "Name", "Rarity", "Income", "Price")

	Repères pour CreatureAnimator (client) : pièces "Eye" / "Pupil" (écrasées au
	clignement) et "Shine" (reflets masqués), pièces "Orbit" (tournent autour de Root),
	attribut "Rainbow" (teinte animée ; valeur = teinte de départ entre 0 et 1), lignes
	"Name" et "Mutation" de l'étiquette (masquées de loin dans les bases).

	HipHeight = distance entre le centre de Root et le sol : pour poser la créature
	au point P, on fait model:PivotTo(CFrame.new(P + Vector3.yAxis * HipHeight)).

	Toutes les cotes ci-dessous sont en « unités créature » (taille Commune),
	multipliées par l'échelle de rareté au moment de créer les pièces. Le devant
	de la créature est -Z (comme le LookVector d'un CFrame).

	On évite volontairement l'instance Highlight : Roblox n'en affiche que 31
	simultanément par client, ce qui casserait l'effet dans une base pleine.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Modules.Format)

local CreatureVisuals = {}

export type BuildOptions = {
	Anchored: boolean?, -- true (défaut) : pièces ancrées. false : soudées, sans masse (portée par un joueur)
	Billboard: boolean?, -- afficher le nom / la rareté / le revenu
	PriceText: string?, -- ligne de prix (créatures sur le chemin)
}

local rgb = Color3.fromRGB
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

local WHITE = rgb(255, 255, 255)
local INK = rgb(0, 0, 0)
local MOUTH = rgb(96, 18, 42)
local TONGUE = rgb(255, 104, 136)
local BLUSH = rgb(255, 86, 146)
local INNER_EAR = rgb(255, 138, 186)
local BEAK = rgb(255, 168, 24)
local HORN = rgb(255, 240, 210)
local GOLD = rgb(255, 198, 26)
local GOLD_LIGHT = rgb(255, 232, 110)
local STEEL = rgb(64, 70, 88)

-- Emplacement d'une base (studs) : colonnes espacées de 11, rangées de 9, socle de 6,4 de
-- diamètre. Chaque créature tient dans une case de 10 x 8,8 centrée sur son socle (les
-- voisines ne se touchent jamais) ; disque de rareté et orbites restent dans la case.
local SLOT_HALF_WIDTH = 5.0
local SLOT_HALF_DEPTH = 4.4
local SLOT_RADIUS = 3.1 -- rayon max du disque de rareté (le socle fait 3,2)
local ORBIT_REACH = 4.3 -- distance max au centre des pièces en orbite (perles, éclats)
local MIN_FIT = 0.78 -- réduction maximale pour faire tenir une créature dans sa case

-- Dégradé régulier à partir d'une liste de couleurs (configs : données pures)
local function sequence(colors: { Color3 }): ColorSequence
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), color))
	end
	return ColorSequence.new(keypoints)
end

---------------------------------------------------------------------------
-- Styles par dimension (palette « jouet » saturée, voir docs/ART_DIRECTION.md)
---------------------------------------------------------------------------
type Style = {
	Body: Color3,
	Belly: Color3,
	Limb: Color3,
	Accent: Color3,
	Accent2: Color3,
	Pupil: Color3,
	Glow: boolean, -- accents en néon (sinon plastique brillant)
	Robot: boolean?, -- semelles et voyant néon (Cyber)
	Topper: string, -- accessoire de tête par défaut
	Blush: boolean,
	Eyes: string?, -- style d'yeux par défaut
	ThirdEye: { [string]: boolean }?, -- archétypes qui reçoivent un 3e œil
}

local STYLES: { [string]: Style } = {
	Lava = {
		Body = rgb(255, 104, 26),
		Belly = rgb(255, 214, 70),
		Limb = rgb(228, 42, 30),
		Accent = rgb(255, 222, 40),
		Accent2 = rgb(255, 128, 0),
		Pupil = rgb(48, 14, 8),
		Glow = true,
		Topper = "Flame",
		Blush = true,
	},
	Void = {
		Body = rgb(124, 48, 238),
		Belly = rgb(214, 102, 255),
		Limb = rgb(74, 24, 170),
		Accent = rgb(255, 58, 214),
		Accent2 = rgb(64, 222, 255),
		Pupil = rgb(30, 8, 58),
		Glow = true,
		Topper = "Antennae",
		Blush = true,
		ThirdEye = { Blob = true, Tall = true, Beast = true },
	},
	Ice = {
		Body = rgb(44, 174, 255),
		Belly = rgb(236, 250, 255),
		Limb = rgb(24, 106, 228),
		Accent = rgb(150, 248, 255),
		Accent2 = rgb(255, 255, 255),
		Pupil = rgb(12, 30, 78),
		Glow = false,
		Topper = "Snow",
		Blush = true,
	},
	Candy = {
		Body = rgb(255, 94, 186),
		Belly = rgb(255, 244, 250),
		Limb = rgb(236, 42, 140),
		Accent = rgb(56, 230, 196),
		Accent2 = rgb(255, 214, 46),
		Pupil = rgb(66, 12, 46),
		Glow = false,
		Topper = "Cream",
		Blush = true,
	},
	Cyber = {
		-- Gris métal soutenu : un gris clair disparaîtrait sur les socles blancs
		Body = rgb(146, 158, 184),
		Belly = rgb(38, 44, 60),
		Limb = rgb(50, 56, 76),
		Accent = rgb(40, 255, 110),
		Accent2 = rgb(0, 214, 255),
		Pupil = rgb(10, 12, 18),
		Glow = true,
		Topper = "Antenna",
		Blush = false,
		Eyes = "Visor",
		Robot = true,
	},
}

---------------------------------------------------------------------------
-- Traits propres à chaque créature (silhouettes reconnaissables)
---------------------------------------------------------------------------
type Traits = { [string]: any }

local TRAITS: { [string]: Traits } = {
	-- Lave
	Lava_Braisillon = { Topper = "BigFlame", Tail = "Flame" },
	Lava_CrapaudMagma = { Eyes = "Frog", Spots = true, Mouth = "Wide" },
	Lava_Salamandre = { Frills = true, Spots = true },
	Lava_GolemScories = {
		-- Roche de lave charbon + fissures néon orange : fort contraste, lisible de loin
		Palette = {
			Body = rgb(62, 42, 48),
			Belly = rgb(44, 30, 34),
			Limb = rgb(52, 36, 40),
			Accent = rgb(255, 120, 20),
		},
		Cracks = true,
		Brows = "Angry",
	},
	Lava_PhenixFele = { Wings = "Bird", Beak = true, Topper = "Crest", Tail = "Feathers", Mouth = "None" },
	Lava_WyrmVolcanique = { Horns = "Dragon", Spines = true, Wings = "Bat" },
	Lava_TitanNoyau = { Core = true, Horns = "Dragon", Cracks = true, Brows = "Angry" },
	Lava_IgnisPrimordial = { Palette = { Body = rgb(255, 138, 20), Accent2 = rgb(255, 70, 20) } },
	-- Néant
	Void_Ombrelin = { Horns = "Imp", Tail = "Devil", Topper = "None" },
	Void_OeilErrant = { Eyes = "Cyclops", Wings = "Bat", Mouth = "None" },
	Void_SpectreCreux = { Ghost = true, Mouth = "O", Topper = "None" },
	Void_MeduseVide = { Tentacles = true },
	Void_DevoreurEchos = { Mouth = "Fangs", Ears = "Bat", Topper = "None" },
	Void_ArchonteSilencieux = { Hood = true, Cape = rgb(92, 30, 196), GlowEyes = true, Topper = "None" },
	Void_LeviathanAbyssal = { Fins = true, Horns = "Dragon", Spots = true },
	Void_CeluiQuiNestPas = { Eyes = "Many", Palette = { Body = rgb(88, 30, 186), Limb = rgb(58, 16, 132) } },
	-- Glace
	Ice_FloconGrognon = { Snowflake = true, Brows = "Grumpy", Mouth = "Flat", Topper = "None" },
	Ice_PingouinGivre = {
		Palette = { Body = rgb(30, 92, 214), Limb = rgb(255, 156, 26) },
		Beak = true,
		Flippers = true,
		Scarf = rgb(255, 54, 84),
		Mouth = "None",
	},
	Ice_LynxCristallin = { Ears = "Lynx", Tail = "Short", Shards = true, Topper = "None" },
	Ice_YetiMiniature = {
		-- Corps bleu glacier, fourrure blanche par-dessus (un yéti blanc disparaît sur le socle)
		Palette = { Body = rgb(110, 196, 255), Belly = rgb(240, 250, 255), Limb = rgb(64, 146, 236) },
		Fur = true,
		Horns = "Ram",
		Topper = "None",
	},
	Ice_SentinelleGivre = { Helmet = true, Staff = "Spear", Topper = "None" },
	Ice_MammouthBoreal = { Trunk = true, Ears = "Elephant", Fur = true },
	Ice_ReineBlizzard = { Staff = "Wand", Cape = rgb(170, 236, 255) },
	Ice_ZeroAbsolu = { Palette = { Body = rgb(150, 228, 255), Limb = rgb(60, 176, 255) }, OrbitCrystals = true },
	-- Bonbon
	Candy_Gommy = { Ears = "Bear", Topper = "None" },
	Candy_Marshmallo = {
		-- Corps rose, tête blanche (Belly) : le blanc se détache sur le ciel, pas sur le socle
		Palette = { Body = rgb(255, 138, 198), Belly = rgb(255, 250, 252), Limb = rgb(255, 186, 222) },
		Marshmallow = true,
	},
	Candy_LicorneReglisse = {
		Palette = { Body = rgb(104, 54, 168), Belly = rgb(255, 128, 206), Limb = rgb(72, 36, 120) },
		Horns = "Unicorn",
		Mane = true,
		Topper = "None",
	},
	Candy_GolemPraline = {
		Palette = { Body = rgb(156, 84, 44), Belly = rgb(255, 210, 150), Limb = rgb(116, 60, 30) },
		Sprinkles = true,
	},
	Candy_DragonBarbeAPapa = { Clouds = true, Wings = "Fairy", Horns = "Nub", Topper = "None" },
	Candy_RoiCaramel = {
		Palette = { Body = rgb(255, 168, 52), Belly = rgb(255, 232, 168), Limb = rgb(218, 116, 26) },
		Cape = rgb(226, 30, 64),
		Staff = "Scepter",
	},
	Candy_HydreSucreOrge = { Heads = true },
	Candy_SucreneaInfinie = { Sprinkles = true, Wings = "Fairy", Staff = "Lollipop" },
	-- Cyber
	Cyber_BitBot = {},
	Cyber_DronePixel = { Eyes = "Lens", Propellers = true, Topper = "None" },
	Cyber_Glitchat = { Ears = "Cat", Tail = "Cat", Glitch = true, Topper = "None" },
	Cyber_SerpentBinaire = { Spines = true },
	Cyber_MechaLoup = { Ears = "Wolf", Tail = "Wolf", Topper = "None" },
	Cyber_IARebelle = { Eyes = "Cyclops", Ring = true },
	Cyber_KernelOmega = { Core = true },
	Cyber_SingulariteExe = {
		Palette = { Body = rgb(70, 76, 112), Limb = rgb(40, 44, 66) },
		Ring = true,
		Glitch = true,
	},
}

local NO_TRAITS: Traits = {}

---------------------------------------------------------------------------
-- Contexte de construction
---------------------------------------------------------------------------
type Palette = {
	Body: Color3,
	Belly: Color3,
	Limb: Color3,
	Accent: Color3,
	Accent2: Color3,
	Pupil: Color3,
	Sclera: Color3,
	PupilMaterial: Enum.Material,
	Material: Enum.Material,
	AccentMaterial: Enum.Material,
}

type Ctx = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	P: Palette,
	Style: Style,
	Traits: Traits,
	Accents: { BasePart },
	RainbowAccents: boolean, -- accents arc-en-ciel (mutation Prismatique)
	Blush: boolean,
	Crowned: boolean, -- couronne sur la tête (Légendaire et plus)
	SkinOf: { [BasePart]: BasePart }, -- pièce de masque (lèvre) -> pièce dont elle prend la couleur
	Freckles: Color3?, -- taches lumineuses à la place des joues roses (Abyssal)
	Track: { BasePart }?, -- pièces créées pendant une mesure (sommet de la couronne...)
}

-- Ellipsoïde (ou boîte si Box) servant de repère : centre C, demi-axes R
type Head = { C: Vector3, R: Vector3, Box: boolean? }

-- Infos renvoyées par un archétype (unités avant mise à l'échelle)
type Shape = {
	Hip: number, -- distance centre -> sol
	Head: Head, -- tête (visage, oreilles, cornes, accessoire)
	Body: Head, -- corps (ailes, queue, taches)
	Eye: { U: number, V: number, Size: number }, -- yeux sur Head (U, V : direction)
	Mouth: number?, -- V de la bouche (nil : pas de bouche)
	MouthOn: Head?, -- support de la bouche s'il diffère de Head (museau)
	HeadPart: BasePart?, -- pièce de la tête (couleur des joues, des sourcils)
	Skin: BasePart?, -- pièce qui porte la bouche si ce n'est pas la tête (museau)
	Top: number?, -- sommet de la tête s'il diffère de Head (capuche, casque, cristaux...)
	HatTop: number?, -- sommet de la couronne ou de l'accessoire de tête (auréole au-dessus)
	Floating: boolean?,
}

---------------------------------------------------------------------------
-- Pièces de base
---------------------------------------------------------------------------
-- Détails sans ombre portée (moins coûteux, rien de visible perdu)
local NO_SHADOW = { Eye = true, Pupil = true, Shine = true, Blush = true, Mouth = true, Lip = true, Brow = true }

-- Luminance perçue (0..1) : choisit les détails clairs sur les peaux sombres
local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function newPart(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * ctx.Scale
	part.CFrame = CFrame.new(cf.Position * ctx.Scale) * cf.Rotation
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	if NO_SHADOW[name] or material == NEON or math.max(size.X, size.Y, size.Z) < 0.7 then
		part.CastShadow = false
	end
	part.Parent = ctx.Model
	if ctx.Track then
		table.insert(ctx.Track, part)
	end
	return part
end

local function ellipsoid(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = newPart(ctx, name, size, cf, color, material or ctx.P.Material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function box(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return newPart(ctx, name, size, cf, color, material or ctx.P.Material)
end

local function ball(ctx: Ctx, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(ctx, name, Vector3.one * diameter, cf, color, material or ctx.P.Material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Cylindre debout (axe Y)
local function cylinder(
	ctx: Ctx,
	name: string,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = newPart(
		ctx,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material or ctx.P.Material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Demi-étendue d'une pièce le long d'un axe du monde (exacte pour les ellipsoïdes et les
-- boules, boîte englobante sinon)
local function halfExtent(part: BasePart, axis: Vector3): number
	local cf, half = part.CFrame, part.Size / 2
	local x = cf.RightVector:Dot(axis) * half.X
	local y = cf.UpVector:Dot(axis) * half.Y
	local z = cf.LookVector:Dot(axis) * half.Z
	if part:FindFirstChildOfClass("SpecialMesh") or (part:IsA("Part") and part.Shape == Enum.PartType.Ball) then
		return math.sqrt(x * x + y * y + z * z)
	end
	return math.abs(x) + math.abs(y) + math.abs(z)
end

-- Couleur arc-en-ciel + attribut "Rainbow" (CreatureAnimator fait tourner la teinte)
local function rainbow(part: BasePart, phase: number)
	local hue = phase % 1
	part.Color = Color3.fromHSV(hue, 0.78, 1)
	part:SetAttribute("Rainbow", hue)
end

local function accent(ctx: Ctx, part: BasePart): BasePart
	table.insert(ctx.Accents, part)
	if ctx.RainbowAccents then
		rainbow(part, #ctx.Accents * 0.137)
	end
	return part
end

-- Rayon d'orbite (unités) : celui voulu, borné pour que la pièce (demi-taille "halfSize")
-- reste dans la case de la créature quand elle tourne
local function orbitRadius(ctx: Ctx, wanted: number, halfSize: number): number
	return math.min(wanted, ORBIT_REACH / ctx.Scale - halfSize)
end

-- Hauteur d'une orbite : à hauteur du ventre, sous le visage (une perle qui passe devant
-- les yeux gâche le visage), en alternant un peu au-dessus et en dessous
local function orbitHeight(body: Head, index: number, spread: number): number
	return body.C.Y - body.R.Y * 0.62 + (if index % 2 == 0 then spread else -spread)
end

-- Équivalent de CFrame.lookAt via fromMatrix (résultat identique dans Roblox) :
-- les aperçus hors Roblox passent par Lune, dont CFrame.lookAt est en miroir.
local function lookAt(position: Vector3, target: Vector3): CFrame
	local look = (target - position).Unit
	local right = look:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-6 then
		right = Vector3.xAxis
	end
	right = right.Unit
	return CFrame.fromMatrix(position, right, right:Cross(look), -look)
end

-- Repère dont le +Y local suit "up" et dont le devant (-Z local) regarde au mieux vers
-- "forward" (par défaut -Z, le devant de la créature)
local function upright(position: Vector3, up: Vector3, forward: Vector3?): CFrame
	local u = up.Unit
	local front = forward or -Vector3.zAxis
	local look = front - u * front:Dot(u)
	if look.Magnitude < 1e-4 then
		look = Vector3.xAxis:Cross(u)
	end
	look = look.Unit
	return CFrame.fromMatrix(position, look:Cross(u), u, -look)
end

-- Point de la surface de "head" dans la direction "dir" (depuis son centre) et normale sortante
local function surface(head: Head, dir: Vector3): (Vector3, Vector3)
	local d = dir.Unit
	local r = head.R
	if head.Box then
		local tx = if math.abs(d.X) > 1e-6 then r.X / math.abs(d.X) else math.huge
		local ty = if math.abs(d.Y) > 1e-6 then r.Y / math.abs(d.Y) else math.huge
		local tz = if math.abs(d.Z) > 1e-6 then r.Z / math.abs(d.Z) else math.huge
		local t = math.min(tx, ty, tz)
		local normal = if t == tz
			then Vector3.new(0, 0, math.sign(d.Z))
			elseif t == tx then Vector3.new(math.sign(d.X), 0, 0)
			else Vector3.new(0, math.sign(d.Y), 0)
		return head.C + d * t, normal
	end
	local t = 1 / math.sqrt((d.X / r.X) ^ 2 + (d.Y / r.Y) ^ 2 + (d.Z / r.Z) ^ 2)
	local q = d * t
	local normal = Vector3.new(q.X / (r.X * r.X), q.Y / (r.Y * r.Y), q.Z / (r.Z * r.Z)).Unit
	return head.C + q, normal
end

-- Repère posé sur la surface (le -Z local sort de la surface), enfoncé de "sink"
local function onSurface(head: Head, dir: Vector3, sink: number): CFrame
	local p, n = surface(head, dir)
	return lookAt(p, p + n) * CFrame.new(0, 0, sink)
end

-- Même chose à partir d'un point déjà proche de la surface
local function onSurfaceAt(head: Head, point: Vector3, sink: number): CFrame
	return onSurface(head, point - head.C, sink)
end

---------------------------------------------------------------------------
-- Visage
---------------------------------------------------------------------------
-- Gros œil brillant : blanc, grosse pupille, deux reflets. Renvoie le centre de l'œil.
local function addEye(ctx: Ctx, head: Head, u: number, v: number, size: number, simple: boolean?): Vector3
	local depth = size * 0.55
	local cf = onSurface(head, Vector3.new(u, v, -1), depth * 0.22)
	ellipsoid(ctx, "Eye", Vector3.new(size, size * 1.2, depth), cf, ctx.P.Sclera, SMOOTH)
	local side = if u > 0.01 then 1 elseif u < -0.01 then -1 else 0
	local pupilDepth = depth * 0.36
	ellipsoid(
		ctx,
		"Pupil",
		Vector3.new(size * 0.74, size * 0.9, pupilDepth),
		cf * CFrame.new(-side * size * 0.06, -size * 0.07, -depth * 0.5 + pupilDepth * 0.4),
		ctx.P.Pupil,
		ctx.P.PupilMaterial
	)
	ball(ctx, "Shine", size * 0.3, cf * CFrame.new(size * 0.15, size * 0.22, -depth * 0.52), WHITE, NEON)
	if not simple then
		ball(ctx, "Shine", size * 0.14, cf * CFrame.new(-size * 0.16, -size * 0.24, -depth * 0.5), WHITE, NEON)
	end
	return cf.Position
end

-- Visière de robot : écran noir brillant + deux yeux néon
local function addVisor(ctx: Ctx, head: Head, v: number, size: number)
	local width = math.min(head.R.X * 1.55, size * 2.9)
	local height = size * 1.15
	local depth = 0.5
	local cf = onSurface(head, Vector3.new(0, v, -1), depth * 0.32)
	if head.Box then
		box(ctx, "Visor", Vector3.new(width, height, depth), cf, rgb(16, 18, 26), SMOOTH)
	else
		ellipsoid(ctx, "Visor", Vector3.new(width, height, depth), cf, rgb(16, 18, 26), SMOOTH)
	end
	local front = if head.Box then depth * 0.5 else depth * 0.42
	for _, side in { -1, 1 } do
		local eye = ellipsoid(
			ctx,
			"Eye",
			Vector3.new(size * 0.46, size * 0.66, 0.16),
			cf * CFrame.new(side * width * 0.21, size * 0.03, -front),
			ctx.P.Accent,
			NEON
		)
		accent(ctx, eye)
	end
end

-- Objectif d'appareil photo (drone) : bague sombre + iris néon + reflet
local function addLens(ctx: Ctx, head: Head, v: number, size: number)
	local cf = onSurface(head, Vector3.new(0, v, -1), size * 0.2)
	ellipsoid(ctx, "Eye", Vector3.new(size * 1.5, size * 1.5, size * 0.7), cf, rgb(28, 30, 40), SMOOTH)
	accent(
		ctx,
		ellipsoid(
			ctx,
			"Pupil",
			Vector3.new(size * 0.95, size * 0.95, size * 0.4),
			cf * CFrame.new(0, 0, -size * 0.25),
			ctx.P.Accent,
			NEON
		)
	)
	ball(ctx, "Shine", size * 0.32, cf * CFrame.new(size * 0.22, size * 0.24, -size * 0.42), WHITE, NEON)
end

-- Bouche. "skin" : pièce qui porte la bouche (la lèvre en prend la couleur)
local function addMouth(ctx: Ctx, head: Head, v: number, size: number, kind: string, skin: BasePart?)
	local cf = onSurface(head, Vector3.new(0, v, -1), size * 0.12)
	if (kind == "Smile" or kind == "Wide") and skin then
		-- Grand sourire en « D » : ovale sombre dont le haut est caché par une lèvre couleur
		-- de peau (un ovale entier donne un air étonné), langue au fond
		local width = if kind == "Wide" then 1.36 else 0.95
		ellipsoid(ctx, "Mouth", Vector3.new(size * width, size * 0.46, size * 0.3), cf, MOUTH, SMOOTH)
		ellipsoid(
			ctx,
			"Mouth",
			Vector3.new(size * width * 0.56, size * 0.18, size * 0.2),
			cf * CFrame.new(0, -size * 0.15, -size * 0.08),
			TONGUE,
			SMOOTH
		)
		local lip = ellipsoid(
			ctx,
			"Lip",
			Vector3.new(size * (width + 0.14), size * 0.3, size * 0.32),
			cf * CFrame.new(0, size * 0.17, -0.02),
			skin.Color,
			skin.Material
		)
		ctx.SkinOf[lip] = skin
	elseif kind == "Smile" or kind == "Wide" or kind == "Fangs" then
		local width = if kind == "Wide" then 1.3 elseif kind == "Fangs" then 1.0 else 0.62
		ellipsoid(ctx, "Mouth", Vector3.new(size * width, size * 0.42, size * 0.3), cf, MOUTH, SMOOTH)
		ellipsoid(
			ctx,
			"Mouth",
			Vector3.new(size * width * 0.58, size * 0.2, size * 0.2),
			cf * CFrame.new(0, -size * 0.1, -size * 0.08),
			TONGUE,
			SMOOTH
		)
		if kind == "Fangs" then
			for _, side in { -1, 1 } do
				ellipsoid(
					ctx,
					"Mouth",
					Vector3.new(size * 0.18, size * 0.32, size * 0.14),
					cf * CFrame.new(side * size * 0.26, size * 0.05, -size * 0.13),
					WHITE,
					SMOOTH
				)
			end
		end
	elseif kind == "O" then
		ellipsoid(ctx, "Mouth", Vector3.new(size * 0.34, size * 0.44, size * 0.3), cf, MOUTH, SMOOTH)
	elseif kind == "Flat" then
		ellipsoid(
			ctx,
			"Mouth",
			Vector3.new(size * 0.55, size * 0.14, size * 0.28),
			cf * CFrame.Angles(0, 0, 0.12),
			MOUTH,
			SMOOTH
		)
	end
end

local function addFace(ctx: Ctx, shape: Shape)
	local traits = ctx.Traits
	local head, e = shape.Head, shape.Eye
	local kind = traits.Eyes or ctx.Style.Eyes or "Normal"
	local eyeCenters = {}
	if kind == "Visor" then
		addVisor(ctx, head, e.V, e.Size)
	elseif kind == "Lens" then
		addLens(ctx, head, e.V, e.Size)
	elseif kind == "Cyclops" then
		table.insert(eyeCenters, addEye(ctx, head, 0, e.V + 0.04, e.Size * 1.65))
	elseif kind == "Many" then
		for _, spot in
			{
				{ 0, 0.08, 1.15 },
				{ -0.62, 0.42, 0.62 },
				{ 0.6, 0.46, 0.58 },
				{ -0.58, -0.3, 0.5 },
				{ 0.56, -0.26, 0.48 },
				{ 0, 0.66, 0.5 },
			}
		do
			addEye(ctx, head, spot[1], spot[2], e.Size * spot[3], spot[3] < 1)
		end
	elseif kind == "Frog" then
		-- Yeux perchés sur deux bosses (crapaud)
		for _, side in { -1, 1 } do
			local p, n = surface(head, Vector3.new(side * 0.5, 1.1, -0.5))
			local socket: Head = { C = p + n * 0.12, R = Vector3.new(0.8, 0.74, 0.74) * e.Size }
			ellipsoid(ctx, "Body", socket.R * 2, CFrame.new(socket.C), ctx.P.Body)
			table.insert(eyeCenters, addEye(ctx, socket, side * 0.1, 0.18, e.Size * 0.88))
		end
	else
		for _, side in { -1, 1 } do
			table.insert(eyeCenters, addEye(ctx, head, side * e.U, e.V, e.Size))
		end
	end

	-- 3e œil (Néant)
	local third = ctx.Style.ThirdEye
	if kind == "Normal" and third and third[traits.Archetype] then
		addEye(ctx, head, 0, e.V + 0.62, e.Size * 0.52, true)
	end

	-- Sourcils froncés (au-dessus de chaque œil, inclinés vers le centre) ; lumineux sur
	-- une peau sombre (golem de scories), où des sourcils noirs disparaîtraient
	local skinColor = if shape.HeadPart then shape.HeadPart.Color else ctx.P.Body
	if traits.Brows and #eyeCenters == 2 then
		local dark = luminance(skinColor) < 0.32
		for i, center in eyeCenters do
			local side = if i == 1 then -1 else 1
			local point = center + Vector3.new(-side * e.Size * 0.05, e.Size * 0.78, 0)
			local thickness = if traits.Brows == "Angry" then 0.24 else 0.18
			local brow = box(
				ctx,
				"Brow",
				Vector3.new(e.Size * 0.78, e.Size * thickness, e.Size * 0.3),
				onSurfaceAt(head, point, e.Size * 0.06) * CFrame.Angles(0, 0, side * 0.42),
				if dark then ctx.P.Accent else rgb(36, 20, 30),
				if dark then ctx.P.AccentMaterial else SMOOTH
			)
			if dark then
				accent(ctx, brow)
			end
		end
	end

	-- Bouche (sur le museau s'il y en a un)
	local robot = kind == "Visor" or kind == "Lens"
	local mouthKind = traits.Mouth or (if robot then "None" else "Smile")
	if shape.Mouth and mouthKind ~= "None" then
		local v = shape.Mouth - (if kind == "Cyclops" then 0.12 else 0)
		addMouth(ctx, shape.MouthOn or head, v, e.Size, mouthKind, shape.Skin or shape.HeadPart)
	end

	-- Taches bioluminescentes sous les yeux (Abyssal) : la mutation se lit aussi de face
	if ctx.Freckles and not robot and #eyeCenters == 2 then
		for i, center in eyeCenters do
			local side = if i == 1 then -1 else 1
			local point = center + Vector3.new(side * e.Size * 0.5, -e.Size * 0.66, 0)
			ball(ctx, "Spot", e.Size * 0.24, onSurfaceAt(head, point, 0), ctx.Freckles, NEON)
		end
	end

	-- Joues roses (opaques : pas de tri de transparence à chaque image)
	if ctx.Blush and not robot and #eyeCenters == 2 then
		for i, center in eyeCenters do
			local side = if i == 1 then -1 else 1
			local point = center + Vector3.new(side * e.Size * 0.48, -e.Size * 0.66, 0)
			ellipsoid(
				ctx,
				"Blush",
				Vector3.new(e.Size * 0.56, e.Size * 0.3, e.Size * 0.16),
				onSurfaceAt(head, point, e.Size * 0.05),
				BLUSH:Lerp(skinColor, 0.15),
				SMOOTH
			)
		end
	end
end

---------------------------------------------------------------------------
-- Archétypes : construisent le corps, renvoient les repères (Shape)
---------------------------------------------------------------------------
local Archetypes = {}

local function feet(ctx: Ctx, y: number, spacing: number, width: number)
	for _, side in { -1, 1 } do
		local foot = ellipsoid(
			ctx,
			"Foot",
			Vector3.new(width, width * 0.58, width * 1.25),
			CFrame.new(side * spacing, y, -0.28),
			if ctx.Style.Robot then ctx.P.Accent else ctx.P.Limb,
			if ctx.Style.Robot then NEON else nil
		)
		if ctx.Style.Robot then
			accent(ctx, foot)
		end
	end
end

-- Ventre plus clair, légèrement bombé sur la surface du corps
local function belly(ctx: Ctx, body: Head, dir: Vector3, size: Vector3)
	ellipsoid(ctx, "Belly", size, onSurface(body, dir, size.Z * 0.5 - 0.08), ctx.P.Belly)
end

-- Petits bras posés sur les flancs, pointés vers l'extérieur
local function arms(ctx: Ctx, body: Head, v: number, size: Vector3, tilt: number)
	for _, side in { -1, 1 } do
		local p, n = surface(body, Vector3.new(side, v, -0.15))
		ellipsoid(
			ctx,
			"Arm",
			size,
			CFrame.new(p + n * size.X * 0.12) * CFrame.Angles(0, 0, side * tilt),
			if ctx.Traits.Flippers then ctx.P.Body else ctx.P.Limb
		)
	end
end

function Archetypes.Blob(ctx: Ctx): Shape
	local body: Head = { C = Vector3.zero, R = Vector3.new(1.72, 1.5, 1.6) }
	local main = ellipsoid(ctx, "Body", body.R * 2, CFrame.new(), ctx.P.Body)
	belly(ctx, body, Vector3.new(0, -0.95, -1), Vector3.new(2.0, 1.2, 0.9))
	if ctx.Traits.Flippers then
		arms(ctx, body, -0.05, Vector3.new(0.4, 1.35, 0.8), 0.75)
	else
		arms(ctx, body, -0.1, Vector3.new(0.72, 1.1, 0.72), 0.65)
	end
	feet(ctx, -1.4, 0.78, 1.0)
	return {
		Hip = 1.69,
		Head = body,
		Body = body,
		HeadPart = main,
		Eye = { U = 0.38, V = 0.2, Size = 1.0 },
		Mouth = -0.2,
	}
end

function Archetypes.Spiky(ctx: Ctx): Shape
	local body: Head = { C = Vector3.zero, R = Vector3.new(1.62, 1.52, 1.56) }
	local main = ellipsoid(ctx, "Body", body.R * 2, CFrame.new(), ctx.P.Body)
	belly(ctx, body, Vector3.new(0, -1.0, -1), Vector3.new(1.75, 1.05, 0.85))
	-- Piques sur le dos et le dessus (jamais sur le visage) : longues vers le haut, plus
	-- courtes sur les côtés et à l'arrière (la créature tient dans sa case de base)
	local spikes = {
		{ Vector3.new(0, 1, 0.15), 2.0 },
		{ Vector3.new(0.62, 0.78, 0.3), 1.85 },
		{ Vector3.new(-0.62, 0.78, 0.3), 1.85 },
		{ Vector3.new(0, 0.62, 0.85), 1.55 },
		{ Vector3.new(0.88, 0.36, 0.55), 1.4 },
		{ Vector3.new(-0.88, 0.36, 0.55), 1.4 },
		{ Vector3.new(0.5, 0.0, 0.95), 1.3 },
		{ Vector3.new(-0.5, 0.0, 0.95), 1.3 },
		{ Vector3.new(0.38, 0.92, -0.42), 1.6 },
		{ Vector3.new(-0.38, 0.92, -0.42), 1.6 },
		{ Vector3.new(0.92, 0.55, -0.12), 1.4 },
		{ Vector3.new(-0.92, 0.55, -0.12), 1.4 },
	}
	for i, spike in spikes do
		local dir, length = spike[1].Unit, spike[2]
		if ctx.Crowned and dir.Y > 0.7 then
			-- Sous une couronne, les piques du dessus basculent vers l'arrière (raccourcies)
			dir = (dir + Vector3.new(0, -0.1, 0.62)).Unit
			length *= 0.8
		end
		local p = surface(body, dir)
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Spike",
				Vector3.new(0.78, 0.78, length),
				lookAt(p, p + dir) * CFrame.new(0, 0, -length * 0.2),
				if i % 2 == 0 then ctx.P.Accent2 else ctx.P.Accent,
				ctx.P.AccentMaterial
			)
		)
	end
	arms(ctx, body, -0.15, Vector3.new(0.66, 1.0, 0.66), 0.65)
	feet(ctx, -1.4, 0.75, 0.95)
	return {
		Hip = 1.68,
		Head = body,
		Body = body,
		HeadPart = main,
		Eye = { U = 0.38, V = 0.14, Size = 0.98 },
		Mouth = -0.26,
	}
end

function Archetypes.Tall(ctx: Ctx): Shape
	local traits = ctx.Traits
	local body: Head = { C = Vector3.new(0, -0.25, 0), R = Vector3.new(1.12, 1.28, 1.02) }
	local head: Head = { C = Vector3.new(0, 2.15, 0), R = Vector3.new(1.5, 1.36, 1.36) }
	ellipsoid(ctx, "Body", body.R * 2, CFrame.new(body.C), ctx.P.Body)
	local headPart = ellipsoid(ctx, "Body", head.R * 2, CFrame.new(head.C), ctx.P.Body)
	belly(ctx, body, Vector3.new(0, -0.1, -1), Vector3.new(1.45, 1.75, 0.8))
	arms(ctx, body, 0.1, Vector3.new(0.6, 1.55, 0.6), 0.32)
	local hip = 1.95
	if traits.Ghost then
		-- Robe de fantôme à l'ourlet ondulé, pas de pieds : il flotte
		ellipsoid(ctx, "Body", Vector3.new(2.6, 1.5, 2.3), CFrame.new(0, -1.15, 0.05), ctx.P.Body)
		for i = 1, 4 do
			local x = -1.0 + (i - 1) * 0.66
			local inner = i == 2 or i == 3
			ball(ctx, "Body", 0.7, CFrame.new(x, -1.78, if inner then -0.25 else -0.1), ctx.P.Body)
		end
		hip = 2.7
	else
		feet(ctx, -1.62, 0.52, 0.98)
	end
	return {
		Hip = hip,
		Head = head,
		Body = body,
		HeadPart = headPart,
		Eye = { U = 0.37, V = 0.08, Size = 0.98 },
		Mouth = -0.32,
	}
end

-- Cube posé sur un sommet (pointe de gemme vers le bas)
local function gemCFrame(position: Vector3): CFrame
	return CFrame.fromMatrix(
		position,
		Vector3.new(0.8165, -0.5774, 0),
		Vector3.new(-0.4082, -0.5774, -0.7071),
		Vector3.new(-0.4082, -0.5774, 0.7071)
	)
end

function Archetypes.Crystal(ctx: Ctx): Shape
	local traits = ctx.Traits
	local body: Head = { C = Vector3.new(0, 0.2, 0), R = Vector3.new(1.42, 1.3, 1.32) }
	local main = ellipsoid(ctx, "Body", body.R * 2, CFrame.new(body.C), ctx.P.Body)
	if traits.Snowflake then
		-- Six branches de flocon derrière le corps, dans le plan du visage
		for i = 0, 5 do
			local a = i * math.pi / 3 + math.pi / 2
			local dir = Vector3.new(math.cos(a), math.sin(a), 0)
			local cf = CFrame.new(body.C + dir * 1.55 + Vector3.new(0, 0, 0.35)) * CFrame.Angles(0, 0, a - math.pi / 2)
			accent(ctx, box(ctx, "Spike", Vector3.new(0.5, 1.9, 0.36), cf, ctx.P.Accent, ctx.P.AccentMaterial))
			accent(
				ctx,
				box(
					ctx,
					"Spike",
					Vector3.new(0.62, 0.62, 0.36),
					cf * CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(45)),
					ctx.P.Accent2,
					ctx.P.AccentMaterial
				)
			)
		end
	else
		-- Pointe de gemme sous le corps
		accent(ctx, box(ctx, "Spike", Vector3.one * 1.1, gemCFrame(Vector3.new(0, -0.9, 0)), ctx.P.Accent, GLASS))
		-- Couronne de cristaux sur la tête (derrière la couronne dorée s'il y en a une)
		local back = if ctx.Crowned then 0.75 else 0
		for i, data in { { 0, 1.75, 0, 0.62 }, { -0.62, 1.25, 0.25, 0.48 }, { 0.62, 1.3, -0.1, 0.48 } } do
			local x, height, z, width = data[1], data[2], data[3] + back, data[4]
			local top = body.C.Y + body.R.Y * (if i == 1 then 0.92 else 0.72) - back * 0.3
			accent(
				ctx,
				box(
					ctx,
					"Spike",
					Vector3.new(width, height, width),
					CFrame.new(x, top + height * 0.3, z) * CFrame.Angles(0, math.rad(45), -x * 0.55),
					if i == 1 then ctx.P.Accent else ctx.P.Accent2,
					ctx.P.AccentMaterial
				)
			)
		end
	end
	return {
		Hip = if traits.Snowflake then 2.9 else 2.75,
		Head = body,
		Body = body,
		HeadPart = main,
		Eye = { U = 0.4, V = 0.12, Size = 0.92 },
		Mouth = -0.3,
		-- Sommet des cristaux (sous une couronne, ils sont repoussés derrière elle)
		Top = if traits.Snowflake or ctx.Crowned then nil else body.C.Y + body.R.Y + 0.35,
		Floating = true,
	}
end

function Archetypes.Wisp(ctx: Ctx): Shape
	local traits = ctx.Traits
	local body: Head = { C = Vector3.zero, R = Vector3.new(1.45, 1.36, 1.4) }
	local main = ellipsoid(ctx, "Body", body.R * 2, CFrame.new(), ctx.P.Body)
	if not (traits.Tentacles or traits.Propellers or traits.Tail) then
		-- Queue de fantôme qui remonte derrière
		ellipsoid(ctx, "Body", Vector3.new(2.0, 1.5, 1.9), CFrame.new(0, -0.7, 0.45), ctx.P.Body)
		ellipsoid(
			ctx,
			"Body",
			Vector3.new(1.25, 0.95, 1.3),
			CFrame.new(0, -0.8, 1.2) * CFrame.Angles(math.rad(-22), 0, 0),
			ctx.P.Body
		)
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Body",
				Vector3.new(0.72, 0.62, 0.9),
				CFrame.new(0, -0.52, 1.78) * CFrame.Angles(math.rad(-45), 0, 0),
				ctx.P.Accent,
				ctx.P.AccentMaterial
			)
		)
	end
	if not traits.Propellers then
		arms(ctx, body, -0.15, Vector3.new(0.5, 0.88, 0.5), 0.75)
	end
	return {
		Hip = 2.6,
		Head = body,
		Body = body,
		HeadPart = main,
		Eye = { U = 0.4, V = 0.16, Size = 1.0 },
		Mouth = -0.24,
		Floating = true,
	}
end

function Archetypes.Beast(ctx: Ctx): Shape
	local traits = ctx.Traits
	-- Corps court et tête rapprochée (chibi) : même les grandes bêtes tiennent dans leur case
	local body: Head = { C = Vector3.new(0, -0.1, 0.45), R = Vector3.new(1.3, 1.1, 1.5) }
	local head: Head = {
		C = Vector3.new(0, 1.0, if traits.Trunk then -0.85 else -1.0),
		R = Vector3.new(1.42, 1.28, 1.22),
	}
	ellipsoid(ctx, "Body", body.R * 2, CFrame.new(body.C), ctx.P.Body)
	local headPart = ellipsoid(ctx, "Body", head.R * 2, CFrame.new(head.C), ctx.P.Body)
	ellipsoid(ctx, "Belly", Vector3.new(1.9, 0.8, 2.2), CFrame.new(0, -0.82, 0.4), ctx.P.Belly)
	local muzzle: Head? = nil
	local muzzlePart: BasePart? = nil
	if not traits.Trunk then
		local cf = onSurface(head, Vector3.new(0, -0.55, -1), 0.3)
		muzzlePart = ellipsoid(ctx, "Belly", Vector3.new(1.3, 0.82, 0.8), cf, ctx.P.Belly)
		ball(ctx, "Nose", 0.4, cf * CFrame.new(0, 0.2, -0.36), ctx.P.Pupil, SMOOTH)
		muzzle = { C = cf.Position, R = Vector3.new(0.65, 0.41, 0.4) }
	end
	for _, z in { -0.25, 1.25 } do
		for _, side in { -1, 1 } do
			ellipsoid(ctx, "Leg", Vector3.new(0.82, 1.25, 0.82), CFrame.new(side * 0.74, -1.05, z), ctx.P.Limb)
			local paw = ellipsoid(
				ctx,
				"Foot",
				Vector3.new(0.95, 0.5, 1.1),
				CFrame.new(side * 0.74, -1.6, z - 0.12),
				if ctx.Style.Robot then ctx.P.Accent else ctx.P.Belly,
				if ctx.Style.Robot then NEON else nil
			)
			if ctx.Style.Robot then
				accent(ctx, paw)
			end
		end
	end
	if not traits.Tail then
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Tail",
				Vector3.new(0.42, 0.42, 1.35),
				CFrame.new(0, 0.42, 1.95) * CFrame.Angles(math.rad(-38), 0, 0),
				ctx.P.Accent,
				ctx.P.AccentMaterial
			)
		)
	end
	return {
		Hip = 1.85,
		Head = head,
		Body = body,
		HeadPart = headPart,
		Skin = muzzlePart,
		Eye = { U = 0.42, V = 0.24, Size = 0.88 },
		Mouth = if muzzle then -0.45 else nil,
		MouthOn = muzzle,
	}
end

-- Segments du corps du serpent (centre, demi-axes), de la nuque au bout de la queue.
-- La queue s'enroule sur le côté et revient vers l'avant : silhouette compacte qui tient
-- dans un emplacement de base (une queue droite traversait la rangée de derrière)
local SERPENT_SEGMENTS = {
	{ Vector3.new(0, 0.0, 0.0), Vector3.new(1.0, 0.95, 1.0) },
	{ Vector3.new(0.15, -0.5, 0.85), Vector3.new(0.92, 0.84, 0.92) },
	{ Vector3.new(0.95, -0.74, 1.15), Vector3.new(0.8, 0.7, 0.8) },
	{ Vector3.new(1.6, -0.86, 0.5), Vector3.new(0.64, 0.56, 0.64) },
	{ Vector3.new(1.72, -0.96, -0.28), Vector3.new(0.46, 0.4, 0.48) },
}

-- Direction du corps au segment i (vers la queue)
local function serpentTangent(i: number): Vector3
	local prev = SERPENT_SEGMENTS[math.max(i - 1, 1)][1]
	local next = SERPENT_SEGMENTS[math.min(i + 1, #SERPENT_SEGMENTS)][1]
	return (next - prev).Unit
end

function Archetypes.Serpent(ctx: Ctx): Shape
	local head: Head = { C = Vector3.new(0, 1.25, -0.62), R = Vector3.new(1.32, 1.18, 1.22) }
	for i, seg in SERPENT_SEGMENTS do
		local color = if i % 2 == 0 then ctx.P.Body:Lerp(ctx.P.Limb, 0.45) else ctx.P.Body
		ellipsoid(ctx, "Body", seg[2] * 2, CFrame.new(seg[1]), color)
	end
	local headPart = ellipsoid(ctx, "Body", head.R * 2, CFrame.new(head.C), ctx.P.Body)
	ellipsoid(ctx, "Belly", Vector3.new(1.5, 1.0, 1.4), CFrame.new(0, 0.15, -0.45), ctx.P.Belly)
	local first = SERPENT_SEGMENTS[2]
	return {
		Hip = 1.33,
		Head = head,
		Body = { C = first[1], R = first[2] },
		HeadPart = headPart,
		Eye = { U = 0.42, V = 0.2, Size = 0.9 },
		Mouth = -0.3,
	}
end

function Archetypes.Golem(ctx: Ctx): Shape
	local marshmallow = ctx.Traits.Marshmallow
	-- Guimauve : cylindres au lieu de blocs
	local function block(name: string, size: Vector3, position: Vector3, color: Color3): Part
		if marshmallow then
			return cylinder(ctx, name, size.Y, math.max(size.X, size.Z), CFrame.new(position), color)
		end
		return box(ctx, name, size, CFrame.new(position), color)
	end
	block("Body", Vector3.new(2.8, 2.3, 2.0), Vector3.zero, ctx.P.Body)
	if not marshmallow then
		box(ctx, "Belly", Vector3.new(1.9, 1.35, 0.25), CFrame.new(0, -0.12, -1.0), ctx.P.Belly)
		if ctx.Style.Robot and not ctx.Traits.Core then
			-- Voyant de mise sous tension
			accent(ctx, ball(ctx, "Led", 0.42, CFrame.new(0.5, 0.22, -1.12), ctx.P.Accent, NEON))
		end
	end
	-- Tête de guimauve : cylindre (un ellipsoïde très haut place le visage sur sa face avant)
	local head: Head = if marshmallow
		then { C = Vector3.new(0, 2.0, 0), R = Vector3.new(1.12, 3, 1.12) }
		else { C = Vector3.new(0, 2.05, -0.05), R = Vector3.new(1.15, 0.95, 1.0), Box = true }
	local headPart = block(
		"Body",
		if marshmallow then Vector3.new(2.24, 1.8, 2.24) else Vector3.new(2.3, 1.9, 2.0),
		head.C,
		if marshmallow then ctx.P.Belly else ctx.P.Body
	)
	for _, side in { -1, 1 } do
		block("Arm", Vector3.new(1.05, 1.0, 1.25), Vector3.new(side * 1.82, 0.72, 0), ctx.P.Limb)
		block("Arm", Vector3.new(0.9, 1.5, 0.9), Vector3.new(side * 1.88, -0.35, 0), ctx.P.Limb)
		block("Arm", Vector3.new(1.15, 0.95, 1.15), Vector3.new(side * 1.92, -1.3, -0.05), ctx.P.Body)
		block("Leg", Vector3.new(1.0, 1.0, 1.1), Vector3.new(side * 0.62, -1.62, 0), ctx.P.Limb)
	end
	return {
		Hip = 2.12,
		Head = head,
		HeadPart = headPart,
		Body = { C = Vector3.zero, R = Vector3.new(1.4, 1.15, 1.0), Box = true },
		Eye = { U = 0.42, V = 0.12, Size = 0.82 },
		Mouth = if marshmallow then -0.3 else -0.42,
		Top = if marshmallow then head.C.Y + 0.9 else nil,
	}
end

---------------------------------------------------------------------------
-- Traits (oreilles, cornes, ailes, queues, détails)
---------------------------------------------------------------------------
local Features = {}

-- Sommet de la tête (là où se posent accessoire, couronne et auréole)
local function headTop(shape: Shape): Vector3
	local head = shape.Head
	return Vector3.new(head.C.X, shape.Top or (head.C.Y + head.R.Y), head.C.Z)
end

local EARS = {
	Cat = { Size = Vector3.new(0.74, 1.1, 0.34), Dir = Vector3.new(0.56, 0.82, 0.02), Tilt = 0.3 },
	Lynx = { Size = Vector3.new(0.74, 1.15, 0.34), Dir = Vector3.new(0.56, 0.82, 0.02), Tilt = 0.25, Tuft = true },
	Wolf = { Size = Vector3.new(0.72, 1.38, 0.4), Dir = Vector3.new(0.5, 0.86, 0.08), Tilt = 0.18 },
	Bear = { Size = Vector3.new(0.84, 0.84, 0.38), Dir = Vector3.new(0.64, 0.74, 0.05), Tilt = 0.45 },
	Bat = { Size = Vector3.new(0.8, 1.55, 0.3), Dir = Vector3.new(0.62, 0.76, 0.1), Tilt = 0.6 },
}

function Features.Ears(ctx: Ctx, shape: Shape, kind: string)
	local head = shape.Head
	if kind == "Elephant" then
		for _, side in { -1, 1 } do
			local p = surface(head, Vector3.new(side, 0.15, 0.1))
			ellipsoid(
				ctx,
				"Ear",
				Vector3.new(0.3, 1.75, 1.6),
				CFrame.new(p + Vector3.new(side * 0.1, -0.1, 0.25)) * CFrame.Angles(0, side * 0.35, side * 0.15),
				ctx.P.Limb
			)
		end
		return
	end
	local spec = EARS[kind]
	if not spec then
		return
	end
	local inner = if ctx.Style == STYLES.Cyber then ctx.P.Accent else INNER_EAR
	for _, side in { -1, 1 } do
		local p, n = surface(head, Vector3.new(side * spec.Dir.X, spec.Dir.Y, spec.Dir.Z))
		local up = (n + Vector3.new(side * spec.Tilt, 0.1, 0)).Unit
		local cf = upright(p + up * spec.Size.Y * 0.3, up)
		ellipsoid(ctx, "Ear", spec.Size, cf, ctx.P.Body)
		ellipsoid(
			ctx,
			"Ear",
			spec.Size * Vector3.new(0.56, 0.68, 0.6),
			cf * CFrame.new(0, -spec.Size.Y * 0.05, -spec.Size.Z * 0.3),
			inner,
			if ctx.Style == STYLES.Cyber then NEON else SMOOTH
		)
		if spec.Tuft then
			ellipsoid(ctx, "Ear", Vector3.new(0.16, 0.55, 0.16), cf * CFrame.new(0, spec.Size.Y * 0.62, 0), INK)
		end
	end
end

function Features.Horns(ctx: Ctx, shape: Shape, kind: string)
	local head = shape.Head
	if kind == "Unicorn" then
		-- Corne torsadée en sucre d'orge (anneaux alternés)
		local p = surface(head, Vector3.new(0, 0.95, -0.55))
		local up = Vector3.new(0, 1, -0.42).Unit
		for i = 0, 3 do
			local width = 0.62 - i * 0.13
			accent(
				ctx,
				ellipsoid(
					ctx,
					"Horn",
					Vector3.new(width, 0.62, width),
					upright(p + up * (0.12 + i * 0.42), up),
					if i % 2 == 0 then ctx.P.Belly else WHITE,
					SMOOTH
				)
			)
		end
		return
	end
	for _, side in { -1, 1 } do
		if kind == "Imp" then
			local p, n = surface(head, Vector3.new(side * 0.5, 0.88, -0.05))
			local up = (n + Vector3.new(side * 0.3, 0.25, 0)).Unit
			ellipsoid(ctx, "Horn", Vector3.new(0.42, 0.95, 0.42), upright(p + up * 0.25, up), ctx.P.Limb)
			accent(ctx, ball(ctx, "Horn", 0.3, CFrame.new(p + up * 0.72), ctx.P.Accent, ctx.P.AccentMaterial))
		elseif kind == "Dragon" then
			-- Cornes de la couleur du corps, assombries (des cornes crème derrière une couronne
			-- se lisaient comme des oreilles de lapin) ; couchées vers l'arrière sous une couronne
			local color = ctx.P.Limb:Lerp(INK, 0.3)
			local p, n = surface(head, Vector3.new(side * 0.55, 0.82, 0.25))
			local up = (n + Vector3.new(side * 0.15, 0.2, 0.55 + (if ctx.Crowned then 0.35 else 0))).Unit
			ellipsoid(ctx, "Horn", Vector3.new(0.5, 1.15, 0.5), upright(p + up * 0.35, up), color)
			local up2 = (up + Vector3.new(0, -0.15, 0.6)).Unit
			ellipsoid(ctx, "Horn", Vector3.new(0.34, 0.9, 0.34), upright(p + up * 0.85 + up2 * 0.3, up2), color)
		elseif kind == "Ram" then
			local p = surface(head, Vector3.new(side, 0.55, 0.05))
			for i, data in { { 0, 0.35, 0, 0.72 }, { 0.32, 0.05, -0.32, 0.58 }, { 0.2, -0.3, -0.62, 0.44 } } do
				ball(
					ctx,
					"Horn",
					data[4],
					CFrame.new(p + Vector3.new(side * data[1], data[2], data[3])),
					if i == 3 then ctx.P.Belly else HORN
				)
			end
		elseif kind == "Nub" then
			local p, n = surface(head, Vector3.new(side * 0.5, 0.86, 0.05))
			accent(ctx, ellipsoid(ctx, "Horn", Vector3.new(0.48, 0.6, 0.48), upright(p + n * 0.12, n), ctx.P.Accent2))
		end
	end
end

function Features.Wings(ctx: Ctx, shape: Shape, kind: string, palette: { Color3 }?)
	local body = shape.Body
	for _, side in { -1, 1 } do
		local p, n = surface(body, Vector3.new(side * 0.5, 0.42, 0.8))
		local base = p - n * 0.1
		if kind == "Bird" or kind == "Angel" then
			local colors = palette
				or (if kind == "Angel" then { WHITE, WHITE, GOLD_LIGHT } else { ctx.P.Limb, ctx.P.Body, ctx.P.Accent })
			for i = 1, 3 do
				local length = 1.9 - (i - 1) * 0.32
				local angle = math.rad(28 + (i - 1) * 24)
				local dir = Vector3.new(side * math.cos(angle), math.sin(angle), 0.35).Unit
				local feather = ellipsoid(
					ctx,
					"Wing",
					Vector3.new(0.26, 0.72, length),
					lookAt(base, base + dir) * CFrame.new(0, 0, -length * 0.42),
					colors[i],
					if kind == "Bird" and i == 3 then ctx.P.AccentMaterial else SMOOTH
				)
				if kind == "Bird" then
					accent(ctx, feather)
				end
			end
		elseif kind == "Bat" then
			for i = 1, 2 do
				local length = if i == 1 then 1.9 else 1.35
				local angle = math.rad(if i == 1 then 42 else 12)
				local dir = Vector3.new(side * math.cos(angle), math.sin(angle), 0.3).Unit
				ellipsoid(
					ctx,
					"Wing",
					Vector3.new(0.18, 1.0, length),
					lookAt(base, base + dir) * CFrame.new(0, 0, -length * 0.42),
					ctx.P.Limb
				)
			end
		elseif kind == "Fairy" then
			for i = 1, 2 do
				local length = if i == 1 then 1.7 else 1.15
				local angle = math.rad(if i == 1 then 38 else -8)
				local dir = Vector3.new(side * math.cos(angle), math.sin(angle), 0.4).Unit
				local wing = ellipsoid(
					ctx,
					"Wing",
					Vector3.new(0.1, 1.0, length),
					lookAt(base, base + dir) * CFrame.new(0, 0, -length * 0.42),
					ctx.P.Accent,
					NEON
				)
				wing.Transparency = 0.22
				accent(ctx, wing)
			end
		end
	end
end

function Features.Tail(ctx: Ctx, shape: Shape, kind: string)
	local body = shape.Body
	local p, n = surface(body, Vector3.new(0, -0.1, 1))
	if kind == "Short" then
		ball(ctx, "Tail", 0.8, CFrame.new(p + n * 0.2), ctx.P.Belly)
	elseif kind == "Devil" then
		local dir = Vector3.new(0, 0.55, 1).Unit
		ellipsoid(ctx, "Tail", Vector3.new(0.22, 0.22, 1.6), lookAt(p, p + dir) * CFrame.new(0, 0, -0.7), ctx.P.Limb)
		local tip = p + dir * 1.5
		accent(
			ctx,
			box(
				ctx,
				"Tail",
				Vector3.new(0.5, 0.5, 0.16),
				CFrame.new(tip) * CFrame.Angles(0, 0, math.rad(45)),
				ctx.P.Accent,
				ctx.P.AccentMaterial
			)
		)
	elseif kind == "Cat" or kind == "Wolf" then
		local bushy = kind == "Wolf"
		local dir = Vector3.new(0, 1.0, 0.9).Unit
		local width = if bushy then 0.82 else 0.4
		local length = if bushy then 1.5 else 1.3
		local cf = lookAt(p, p + dir) * CFrame.new(0, 0, -length * 0.42)
		ellipsoid(ctx, "Tail", Vector3.new(width, width, length), cf, ctx.P.Body)
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Tail",
				Vector3.new(width * 0.8, width * 0.8, length * 0.4),
				cf * CFrame.new(0, 0, -length * 0.4),
				if bushy then ctx.P.Belly else ctx.P.Accent,
				if bushy then SMOOTH else ctx.P.AccentMaterial
			)
		)
	elseif kind == "Feathers" or kind == "Flame" then
		local flame = kind == "Flame"
		local colors = if flame
			then { rgb(255, 92, 10), rgb(255, 170, 20), rgb(255, 236, 120) }
			else { ctx.P.Limb, ctx.P.Accent2, ctx.P.Accent }
		for i, data in { { 0, 0.85, 1.55 }, { 0.42, 0.5, 1.25 }, { -0.42, 0.5, 1.25 } } do
			local dir = Vector3.new(data[1], data[2], 1).Unit
			local length = data[3]
			accent(
				ctx,
				ellipsoid(
					ctx,
					"Tail",
					Vector3.new(if flame then 0.7 else 0.32, if flame then 0.7 else 0.75, length),
					lookAt(p, p + dir) * CFrame.new(0, 0, -length * 0.4),
					colors[i],
					if flame then NEON else ctx.P.AccentMaterial
				)
			)
		end
	end
end

-- Bec (pingouin, phénix)
function Features.Beak(ctx: Ctx, shape: Shape)
	local cf = onSurface(shape.Head, Vector3.new(0, shape.Eye.V - 0.38, -1), 0.12)
	ellipsoid(ctx, "Beak", Vector3.new(0.78, 0.46, 0.95), cf * CFrame.new(0, 0, -0.18), BEAK, SMOOTH)
	ellipsoid(ctx, "Beak", Vector3.new(0.6, 0.3, 0.7), cf * CFrame.new(0, -0.22, -0.08), BEAK:Lerp(INK, 0.15), SMOOTH)
end

-- Trompe et défenses (mammouth)
function Features.Trunk(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local p, n = surface(head, Vector3.new(0, -0.32, -1))
	local start = p + n * 0.1
	ellipsoid(ctx, "Trunk", Vector3.new(0.78, 0.78, 0.9), CFrame.new(start), ctx.P.Body)
	ellipsoid(ctx, "Trunk", Vector3.new(0.62, 1.2, 0.62), CFrame.new(start + Vector3.new(0, -0.62, -0.08)), ctx.P.Body)
	ellipsoid(
		ctx,
		"Trunk",
		Vector3.new(0.5, 0.5, 0.7),
		CFrame.new(start + Vector3.new(0, -1.12, -0.18)) * CFrame.Angles(math.rad(25), 0, 0),
		ctx.P.Body
	)
	-- Défenses courtes qui se relèvent
	for _, side in { -1, 1 } do
		local q = surface(head, Vector3.new(side * 0.55, -0.55, -1))
		local dir = Vector3.new(side * 0.35, -0.1, -1).Unit
		ellipsoid(ctx, "Tusk", Vector3.new(0.34, 0.34, 0.95), lookAt(q, q + dir) * CFrame.new(0, 0, -0.32), HORN)
		ellipsoid(
			ctx,
			"Tusk",
			Vector3.new(0.3, 0.3, 0.7),
			CFrame.new(q + dir * 0.72 + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(65), 0, 0),
			HORN
		)
	end
end

-- Tentacules (méduse) sous le corps
function Features.Tentacles(ctx: Ctx, shape: Shape)
	local body = shape.Body
	ellipsoid(ctx, "Belly", Vector3.new(3.0, 0.75, 2.9), CFrame.new(body.C + Vector3.new(0, -0.62, 0)), ctx.P.Belly)
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + 0.3
		local x, z = math.cos(a) * 0.9, math.sin(a) * 0.85
		local y = body.C.Y - 1.15
		local tentacle = ellipsoid(
			ctx,
			"Tentacle",
			Vector3.new(0.38, 1.2, 0.38),
			CFrame.new(x, y, z) * CFrame.Angles(0, 0, if i % 2 == 0 then 0.2 else -0.2),
			if i % 2 == 0 then ctx.P.Accent else ctx.P.Limb,
			if i % 2 == 0 then ctx.P.AccentMaterial else nil
		)
		if i % 2 == 0 then
			accent(ctx, tentacle)
		end
		ellipsoid(
			ctx,
			"Tentacle",
			Vector3.new(0.3, 0.9, 0.3),
			CFrame.new(x * 1.12, y - 0.85, z * 1.12) * CFrame.Angles(0, 0, if i % 2 == 0 then -0.25 else 0.25),
			ctx.P.Limb
		)
	end
end

-- Hélices (drone)
function Features.Propellers(ctx: Ctx, shape: Shape)
	local body = shape.Body
	for i = 1, 4 do
		local a = (i - 0.5) * math.pi / 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = body.C + dir * 2.1 + Vector3.new(0, 0.55, 0)
		box(
			ctx,
			"Arm",
			Vector3.new(0.26, 0.2, 1.4),
			CFrame.new(body.C + dir * 1.45 + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			STEEL
		)
		cylinder(ctx, "Arm", 0.4, 0.34, CFrame.new(tip), STEEL)
		local rotor = cylinder(ctx, "Rotor", 0.06, 1.55, CFrame.new(tip + Vector3.new(0, 0.24, 0)), ctx.P.Accent, NEON)
		rotor.Transparency = 0.45
		accent(ctx, rotor)
	end
end

-- Nageoires (léviathan)
function Features.Fins(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local p = surface(head, Vector3.new(0, 0.8, 0.6))
	accent(
		ctx,
		ellipsoid(
			ctx,
			"Fin",
			Vector3.new(0.22, 1.35, 1.5),
			CFrame.new(p + Vector3.new(0, 0.3, 0.2)) * CFrame.Angles(math.rad(25), 0, 0),
			ctx.P.Accent,
			ctx.P.AccentMaterial
		)
	)
	for _, side in { -1, 1 } do
		local q = surface(head, Vector3.new(side, 0.1, 0.2))
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Fin",
				Vector3.new(0.18, 0.95, 1.2),
				CFrame.new(q + Vector3.new(side * 0.2, 0.1, 0.15)) * CFrame.Angles(0, side * 0.5, side * -0.6),
				ctx.P.Accent2,
				ctx.P.AccentMaterial
			)
		)
	end
end

-- Branchies d'axolotl (salamandre) : trois plumets de chaque côté de la tête
function Features.Frills(ctx: Ctx, shape: Shape)
	local head = shape.Head
	for _, side in { -1, 1 } do
		local p = surface(head, Vector3.new(side, 0.25, 0.25))
		for i = 1, 3 do
			local angle = math.rad(-35 + (i - 1) * 35)
			local dir = Vector3.new(side * math.cos(angle), math.sin(angle) + 0.25, 0.25).Unit
			accent(
				ctx,
				ellipsoid(
					ctx,
					"Frill",
					Vector3.new(0.26, 0.3, 1.05),
					lookAt(p, p + dir) * CFrame.new(0, 0, -0.4),
					if i == 2 then ctx.P.Accent else ctx.P.Accent2,
					ctx.P.AccentMaterial
				)
			)
		end
	end
end

-- Taches lumineuses sur le dos
function Features.Spots(ctx: Ctx, shape: Shape)
	local target = shape.Body
	for i, dir in
		{
			Vector3.new(0.45, 0.75, 0.5),
			Vector3.new(-0.5, 0.65, 0.6),
			Vector3.new(0.1, 0.9, 0.25),
			Vector3.new(0.65, 0.3, 0.75),
			Vector3.new(-0.62, 0.25, 0.8),
		}
	do
		local size = if i % 2 == 0 then 0.55 else 0.42
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Spot",
				Vector3.new(size, size * 0.8, 0.2),
				onSurface(target, dir, 0.04),
				ctx.P.Accent,
				ctx.P.AccentMaterial
			)
		)
	end
end

-- Fissures lumineuses (golems de lave)
function Features.Cracks(ctx: Ctx, shape: Shape)
	local body = shape.Body
	-- Autour de la plaque de ventre (coins hauts et flancs)
	for _, data in
		{
			{ -0.95, 0.82, 0.7, 0.75 },
			{ -0.6, 0.88, -0.5, 0.5 },
			{ 1.0, 0.8, -0.6, 0.7 },
			{ 1.18, -0.45, 0.35, 0.8 },
			{ -1.18, -0.6, -0.3, 0.7 },
		}
	do
		local cf = CFrame.new(body.C + Vector3.new(data[1], data[2], -body.R.Z - 0.03)) * CFrame.Angles(0, 0, data[3])
		accent(ctx, box(ctx, "Crack", Vector3.new(0.17, data[4], 0.12), cf, ctx.P.Accent, NEON))
	end
end

-- Cœur lumineux dans la poitrine (titans)
function Features.Core(ctx: Ctx, shape: Shape)
	local cf = onSurface(shape.Body, Vector3.new(0, 0, -1), 0.1)
	ellipsoid(ctx, "Core", Vector3.new(1.2, 1.2, 0.5), cf, rgb(34, 30, 44), SMOOTH)
	accent(ctx, ball(ctx, "Core", 0.82, cf * CFrame.new(0, 0, -0.12), ctx.P.Accent, NEON))
end

-- Crête de plumes de feu (phénix)
function Features.Crest(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local p = surface(head, Vector3.new(0, 1, 0.1))
	for i, data in { { 0, 1.35, 0.15 }, { -0.25, 1.0, 0.55 }, { 0.25, 1.0, 0.55 } } do
		local dir = Vector3.new(data[1], 1, data[3]).Unit
		local length = data[2]
		accent(
			ctx,
			ellipsoid(
				ctx,
				"Crest",
				Vector3.new(0.34, 0.5, length),
				lookAt(p, p + dir) * CFrame.new(0, 0, -length * 0.38),
				if i == 1 then ctx.P.Accent else ctx.P.Accent2,
				NEON
			)
		)
	end
end

-- Pics dorsaux le long d'un serpent, couchés vers la queue (suivent l'enroulement)
function Features.Spines(ctx: Ctx, _shape: Shape)
	for i, seg in SERPENT_SEGMENTS do
		if i < #SERPENT_SEGMENTS then
			local tangent = serpentTangent(i)
			local top = seg[1] + Vector3.new(0, seg[2].Y * 0.85, 0)
			accent(
				ctx,
				ellipsoid(
					ctx,
					"Spike",
					Vector3.new(0.3, 0.85, 0.55) * (1.1 - i * 0.12),
					upright(top, Vector3.yAxis + tangent * 0.45, -tangent),
					ctx.P.Accent,
					ctx.P.AccentMaterial
				)
			)
		end
	end
end

-- Écharpe (pingouin)
function Features.Scarf(ctx: Ctx, shape: Shape, color: Color3)
	local body = shape.Body
	local y = -0.42
	local k = math.sqrt(1 - (y / body.R.Y) ^ 2)
	ellipsoid(
		ctx,
		"Scarf",
		Vector3.new(body.R.X * 2 * k + 0.2, 0.46, body.R.Z * 2 * k + 0.2),
		CFrame.new(0, y, 0),
		color
	)
	local p = surface(body, Vector3.new(0.45, y - 0.25, -1))
	box(
		ctx,
		"Scarf",
		Vector3.new(0.48, 0.95, 0.22),
		CFrame.new(p + Vector3.new(0, -0.3, -0.12)) * CFrame.Angles(0.2, 0, 0.12),
		color
	)
end

-- Cape dans le dos
function Features.Cape(ctx: Ctx, shape: Shape, color: Color3)
	local body = shape.Body
	local cf = CFrame.new(body.C + Vector3.new(0, 0.1, body.R.Z + 0.08)) * CFrame.Angles(math.rad(-8), 0, 0)
	ellipsoid(ctx, "Cape", Vector3.new(body.R.X * 2.3, body.R.Y * 2.5, 0.3), cf, color)
	if shape.Head ~= shape.Body then
		-- Col d'hermine entre le corps et la tête
		ellipsoid(
			ctx,
			"Cape",
			Vector3.new(body.R.X * 2.0, 0.42, 1.1),
			CFrame.new(body.C + Vector3.new(0, body.R.Y * 0.95, 0.35)),
			WHITE
		)
	end
end

-- Capuche (archonte) : tissu de la couleur des membres à peine assombri (une capuche
-- noire faisait de la tête une boule de bowling), posée en arrière pour dégager le visage,
-- liseré néon qui encadre le visage
function Features.Hood(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local cloth = ctx.P.Limb:Lerp(INK, 0.12)
	local size = head.R * Vector3.new(2.3, 2.1, 2.0)
	local center = head.C + Vector3.new(0, 0.5, 0.45)
	ellipsoid(ctx, "Hood", size, CFrame.new(center), cloth)
	-- Pointe de capuche vers l'arrière
	ellipsoid(
		ctx,
		"Hood",
		Vector3.new(0.95, 1.6, 0.95),
		CFrame.new(center + Vector3.new(0, size.Y * 0.38, size.Z * 0.3)) * CFrame.Angles(math.rad(50), 0, 0),
		cloth
	)
	-- Liseré : disque néon juste derrière l'avant du visage, plus haut que lui. La tête en
	-- cache le centre et le bas : il ne reste qu'un arc autour du front et des tempes
	local depth = 0.7
	local k = math.sqrt(1 - depth * depth) -- section de la tête à cette profondeur
	local trim = ellipsoid(
		ctx,
		"Hood",
		Vector3.new(head.R.X * k * 2 + 0.3, head.R.Y * k * 2 + 0.16, 0.24),
		CFrame.new(head.C + Vector3.new(0, 0.24, -head.R.Z * depth)),
		ctx.P.Accent,
		ctx.P.AccentMaterial
	)
	accent(ctx, trim)
	shape.Top = center.Y + size.Y * 0.5 - 0.1
end

-- Casque de chevalier de glace + plumet
function Features.Helmet(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local c = head.C + Vector3.new(0, 0.95, 0.06)
	ellipsoid(
		ctx,
		"Helmet",
		Vector3.new(head.R.X * 2.12, head.R.Y * 1.25, head.R.Z * 2.14),
		CFrame.new(c),
		rgb(226, 242, 255)
	)
	box(ctx, "Helmet", Vector3.new(0.28, 0.5, head.R.Z * 2.1), CFrame.new(c + Vector3.new(0, 0.62, 0)), GOLD)
	accent(
		ctx,
		ellipsoid(
			ctx,
			"Helmet",
			Vector3.new(0.42, 1.0, 1.5),
			CFrame.new(c + Vector3.new(0, 1.15, 0.45)) * CFrame.Angles(math.rad(30), 0, 0),
			ctx.P.Accent,
			ctx.P.AccentMaterial
		)
	)
	shape.Top = c.Y + head.R.Y * 0.62
end

-- Bâton tenu à droite : lance (glace), baguette (reine), sceptre (roi), sucette géante
function Features.Staff(ctx: Ctx, shape: Shape, kind: string)
	local body = shape.Body
	-- Sans bras (créature qui plane), le bâton flotte tout contre le corps
	local x = body.C.X - body.R.X - (if shape.Floating then 0.22 else 0.6)
	local base = Vector3.new(x, body.C.Y - 0.6, body.C.Z - 0.5)
	local up = Vector3.new(0.04, 1, -0.12).Unit
	local length = if kind == "Spear" then 4.4 else 3.4
	local top = base + up * length
	local stick = if kind == "Spear" then STEEL elseif kind == "Lollipop" then WHITE else GOLD
	cylinder(ctx, "Staff", length, 0.24, upright(base + up * length * 0.5, up), stick)
	if kind == "Lollipop" then
		-- Disque de sucre d'orge face à la caméra : anneaux concentriques = spirale
		local center = top + up * 0.75
		for i, data in { { 1.7, ctx.P.Accent }, { 1.2, WHITE }, { 0.76, ctx.P.Body }, { 0.36, WHITE } } do
			local ring = newPart(
				ctx,
				"Staff",
				Vector3.new(0.32 + i * 0.02, data[1], data[1]),
				CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
				data[2],
				SMOOTH
			)
			ring.Shape = Enum.PartType.Cylinder
			if i == 1 then
				accent(ctx, ring)
			end
		end
	elseif kind == "Spear" then
		accent(
			ctx,
			ellipsoid(ctx, "Staff", Vector3.new(0.5, 1.3, 0.5), upright(top + up * 0.45, up), ctx.P.Accent, GLASS)
		)
	elseif kind == "Wand" then
		local star = ctx.P.Accent
		accent(ctx, ball(ctx, "Staff", 0.75, CFrame.new(top + up * 0.3), star, NEON))
		for i = 0, 3 do
			accent(
				ctx,
				box(
					ctx,
					"Staff",
					Vector3.new(0.2, 1.25, 0.2),
					CFrame.new(top + up * 0.3) * CFrame.Angles(0, 0, i * math.pi / 4),
					star,
					NEON
				)
			)
		end
	else
		ball(ctx, "Staff", 0.75, CFrame.new(top + up * 0.3), GOLD, SMOOTH)
		accent(
			ctx,
			ball(ctx, "Staff", 0.42, CFrame.new(top + up * 0.3 + Vector3.new(0, 0, -0.3)), rgb(255, 40, 90), NEON)
		)
	end
end

-- Touffes de fourrure (yéti, mammouth)
function Features.Fur(ctx: Ctx, shape: Shape)
	local target = shape.Body
	local fur = if ctx.P.Body.R + ctx.P.Body.G + ctx.P.Body.B > 2.6 then ctx.P.Limb else WHITE
	for i, dir in
		{
			Vector3.new(0.7, 0.62, 0.2),
			Vector3.new(-0.7, 0.62, 0.2),
			Vector3.new(0.35, 0.85, 0.65),
			Vector3.new(-0.35, 0.85, 0.65),
			Vector3.new(0, 0.95, -0.1),
		}
	do
		local p = surface(target, dir)
		ball(ctx, "Fur", if i == 5 then 1.0 else 0.82, CFrame.new(p), fur)
	end
	local top = surface(shape.Head, Vector3.new(0.1, 1, 0.15))
	ball(ctx, "Fur", 0.85, CFrame.new(top), fur)
end

-- Nuages de barbe à papa sur le dos
function Features.Clouds(ctx: Ctx, _shape: Shape)
	local colors = { rgb(255, 150, 216), rgb(120, 214, 255), rgb(255, 255, 255), rgb(255, 150, 216) }
	for i, seg in SERPENT_SEGMENTS do
		if i <= 4 then
			ball(ctx, "Cloud", 1.25 - i * 0.12, CFrame.new(seg[1] + Vector3.new(0, seg[2].Y * 0.85, 0.05)), colors[i])
		end
	end
end

-- Vermicelles colorés
function Features.Sprinkles(ctx: Ctx, shape: Shape)
	local target = shape.Head
	local colors = {
		rgb(255, 60, 90),
		rgb(255, 214, 40),
		rgb(60, 220, 120),
		rgb(40, 180, 255),
		rgb(255, 255, 255),
		rgb(170, 90, 255),
	}
	for i, dir in
		{
			Vector3.new(0.5, 0.85, 0.1),
			Vector3.new(-0.45, 0.88, 0.25),
			Vector3.new(0.1, 0.95, 0.5),
			Vector3.new(-0.15, 0.92, -0.35),
			Vector3.new(0.7, 0.6, 0.45),
			Vector3.new(-0.72, 0.55, -0.2),
		}
	do
		local p, n = surface(target, dir)
		box(
			ctx,
			"Sprinkle",
			Vector3.new(0.16, 0.16, 0.5),
			lookAt(p, p + n) * CFrame.Angles(0, 0, i * 1.1) * CFrame.Angles(math.rad(80), 0, 0),
			colors[i],
			SMOOTH
		)
	end
end

-- Cubes « bug » qui flottent autour (glitch)
function Features.Glitch(ctx: Ctx, shape: Shape)
	local body = shape.Body
	for i, data in { { 1.0, 0.8, -0.4, 0.55 }, { -1.15, 0.2, 0.3, 0.45 }, { 0.75, -0.55, 0.8, 0.4 } } do
		local part = box(
			ctx,
			"Glitch",
			Vector3.one * data[4],
			CFrame.new(body.C + Vector3.new(data[1] * (body.R.X + 0.3), data[2], data[3])),
			if i == 2 then rgb(255, 50, 200) else ctx.P.Accent2,
			NEON
		)
		accent(ctx, part)
	end
end

-- Anneau planétaire (IA, singularité) : un disque fin traversant le corps
function Features.Ring(ctx: Ctx, shape: Shape)
	local body = shape.Body
	local ring = cylinder(
		ctx,
		"Ring",
		0.16,
		math.max(body.R.X, body.R.Z) * 2.5,
		CFrame.new(body.C) * CFrame.Angles(math.rad(-24), 0, math.rad(-20)),
		ctx.P.Accent,
		NEON
	)
	ring.Transparency = 0.2
	accent(ctx, ring)
end

-- Cristaux de glace en orbite (Zéro Absolu)
function Features.OrbitCrystals(ctx: Ctx, shape: Shape)
	local body = shape.Body
	local radius = orbitRadius(ctx, 2.3, 0.56)
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		local part = box(
			ctx,
			"Orbit",
			Vector3.new(0.42, 1.0, 0.42),
			CFrame.new(math.cos(a) * radius, orbitHeight(body, i, 0.35), math.sin(a) * radius)
				* CFrame.Angles(0, a, 0.5),
			ctx.P.Accent,
			NEON
		)
		accent(ctx, part)
	end
end

-- Éclats de cristal sur le dos (lynx)
function Features.Shards(ctx: Ctx, shape: Shape)
	local body = shape.Body
	for i, data in { { 0, 1, 0.1, 1.2 }, { 0.45, 0.85, 0.5, 0.9 }, { -0.45, 0.85, 0.55, 0.85 } } do
		local dir = Vector3.new(data[1], data[2], data[3]).Unit
		local p = surface(body, dir)
		accent(
			ctx,
			box(
				ctx,
				"Spike",
				Vector3.new(0.48, data[4], 0.48),
				upright(p + dir * data[4] * 0.25, dir) * CFrame.Angles(0, math.rad(45), 0),
				if i == 1 then ctx.P.Accent else WHITE,
				GLASS
			)
		)
	end
end

-- Crinière de bonbons (licorne)
function Features.Mane(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local colors = { rgb(255, 92, 186), rgb(255, 214, 46), rgb(56, 230, 196), rgb(90, 170, 255) }
	for i = 1, 4 do
		local p = surface(head, Vector3.new(if i % 2 == 0 then 0.25 else -0.25, 1, -0.45 + i * 0.4))
		ball(ctx, "Mane", 0.98 - i * 0.08, CFrame.new(p + Vector3.new(0, 0.12, 0.1 * i)), colors[i])
	end
end

-- Deux têtes supplémentaires sur de longs cous (hydre)
function Features.Heads(ctx: Ctx, shape: Shape)
	local body = shape.Body
	for _, side in { -1, 1 } do
		local neckBase = body.C + Vector3.new(side * body.R.X * 0.62, 0.45, 0.2)
		local headCenter = body.C + Vector3.new(side * 1.62, 1.82, -0.15)
		local dir = (headCenter - neckBase).Unit
		ellipsoid(
			ctx,
			"Body",
			Vector3.new(0.7, 0.7, (headCenter - neckBase).Magnitude + 0.4),
			lookAt(neckBase, headCenter) * CFrame.new(0, 0, -(headCenter - neckBase).Magnitude * 0.5),
			ctx.P.Body:Lerp(ctx.P.Limb, 0.35)
		)
		local small: Head = { C = headCenter + dir * 0.1, R = Vector3.new(0.88, 0.8, 0.84) }
		local smallPart = ellipsoid(ctx, "Body", small.R * 2, CFrame.new(small.C), ctx.P.Body)
		for _, eyeSide in { -1, 1 } do
			addEye(ctx, small, eyeSide * 0.4, 0.18, 0.6, true)
		end
		addMouth(ctx, small, -0.34, 0.6, "Smile", smallPart)
	end
end

---------------------------------------------------------------------------
-- Accessoires de dimension (sur la tête) et couronnes (rareté)
---------------------------------------------------------------------------
local Toppers = {}

-- Flamme de dessin animé (pièces opaques) : base orange, langue principale, cœur jaune
-- devant, pointe claire et deux petites langues sur les côtés
local function flame(ctx: Ctx, base: Vector3, scale: number)
	local function tongue(size: Vector3, offset: Vector3, roll: number, color: Color3): Part
		return ellipsoid(
			ctx,
			"Flame",
			size * scale,
			CFrame.new(base + offset * scale) * CFrame.Angles(math.rad(14), 0, roll),
			color,
			NEON
		)
	end
	accent(ctx, tongue(Vector3.new(1.25, 1.05, 1.2), Vector3.new(0, 0.42, 0), 0, rgb(255, 72, 12)))
	tongue(Vector3.new(0.9, 1.65, 0.85), Vector3.new(0, 1.0, 0.1), 0.06, rgb(255, 120, 14))
	tongue(Vector3.new(0.5, 0.9, 0.5), Vector3.new(0.18, 0.62, -0.22), -0.4, rgb(255, 120, 14))
	tongue(Vector3.new(0.46, 0.8, 0.46), Vector3.new(-0.22, 0.55, -0.15), 0.45, rgb(255, 120, 14))
	tongue(Vector3.new(0.55, 1.0, 0.4), Vector3.new(0, 0.72, -0.36), 0, rgb(255, 210, 40))
	tongue(Vector3.new(0.3, 0.6, 0.3), Vector3.new(0.02, 1.72, 0.22), 0.1, rgb(255, 246, 170))
end

function Toppers.Flame(ctx: Ctx, shape: Shape)
	flame(ctx, headTop(shape) - Vector3.new(0, 0.2, 0), 1)
end

function Toppers.BigFlame(ctx: Ctx, shape: Shape)
	flame(ctx, headTop(shape) - Vector3.new(0, 0.45, -0.1), 1.45)
end

function Toppers.Crest(ctx: Ctx, shape: Shape)
	Features.Crest(ctx, shape)
end

-- Néant : deux antennes terminées par une perle lumineuse
function Toppers.Antennae(ctx: Ctx, shape: Shape)
	local head = shape.Head
	for _, side in { -1, 1 } do
		local p, n = surface(head, Vector3.new(side * 0.35, 1, 0.05))
		local up = (n + Vector3.new(side * 0.35, 0.2, 0)).Unit
		cylinder(ctx, "Antenna", 1.0, 0.14, upright(p + up * 0.45, up), ctx.P.Limb)
		accent(ctx, ball(ctx, "Antenna", 0.5, CFrame.new(p + up * 1.0), ctx.P.Accent, NEON))
	end
end

-- Glace : bonnet de neige + deux cristaux
function Toppers.Snow(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local top = headTop(shape)
	local width = math.min(head.R.X, 1.4)
	ellipsoid(
		ctx,
		"Snow",
		Vector3.new(width * 1.6, 0.62, width * 1.5),
		CFrame.new(top + Vector3.new(0, -0.08, 0.05)),
		WHITE
	)
	for _, data in { { -0.32, 1.05, -0.35 }, { 0.32, 0.8, 0.4 } } do
		accent(
			ctx,
			box(
				ctx,
				"Spike",
				Vector3.new(0.42, data[2], 0.42),
				CFrame.new(top + Vector3.new(data[1], data[2] * 0.42, 0.1)) * CFrame.Angles(0, math.rad(45), data[3]),
				ctx.P.Accent,
				GLASS
			)
		)
	end
end

-- Bonbon : chantilly + cerise
function Toppers.Cream(ctx: Ctx, shape: Shape)
	local top = headTop(shape) - Vector3.new(0, 0.12, 0)
	ellipsoid(ctx, "Cream", Vector3.new(1.45, 0.62, 1.4), CFrame.new(top), WHITE)
	ellipsoid(ctx, "Cream", Vector3.new(1.0, 0.55, 0.98), CFrame.new(top + Vector3.new(0, 0.38, 0)), WHITE)
	ellipsoid(ctx, "Cream", Vector3.new(0.52, 0.52, 0.52), CFrame.new(top + Vector3.new(0, 0.72, 0)), WHITE)
	ball(ctx, "Cherry", 0.62, CFrame.new(top + Vector3.new(0.05, 1.08, -0.05)), rgb(236, 18, 52), SMOOTH)
	box(
		ctx,
		"Cherry",
		Vector3.new(0.08, 0.55, 0.08),
		CFrame.new(top + Vector3.new(0.15, 1.5, 0.05)) * CFrame.Angles(0, 0, -0.5),
		rgb(60, 140, 40),
		SMOOTH
	)
end

-- Cyber : antenne + perle néon
function Toppers.Antenna(ctx: Ctx, shape: Shape)
	local top = headTop(shape)
	cylinder(ctx, "Antenna", 1.1, 0.16, CFrame.new(top + Vector3.new(0, 0.45, 0.05)), STEEL, Enum.Material.Metal)
	accent(ctx, ball(ctx, "Antenna", 0.52, CFrame.new(top + Vector3.new(0, 1.05, 0.05)), ctx.P.Accent, NEON))
end

-- Couronne dorée (Légendaire et plus) : coiffe de velours, bandeau à liseré clair, cinq
-- pointes triangulaires terminées par une petite perle d'or, une seule gemme (frontale,
-- taillée en losange) de la couleur de la rareté
local function addCrown(ctx: Ctx, shape: Shape, rarity)
	local head = shape.Head
	local radius = math.min(head.R.X, head.R.Z, 1.3) * 0.7
	local base = CFrame.new(headTop(shape) + Vector3.new(0, -0.2, 0.05)) * CFrame.Angles(0, 0, math.rad(-9))
	local gemColor = if rarity.Tier == 4 then rgb(40, 200, 255) else rarity.Color
	ellipsoid(
		ctx,
		"Crown",
		Vector3.new(radius * 1.7, 0.9, radius * 1.7),
		base * CFrame.new(0, 0.42, 0),
		rgb(214, 24, 58)
	)
	cylinder(ctx, "Crown", 0.52, radius * 2, base * CFrame.new(0, 0.2, 0), GOLD, SMOOTH)
	cylinder(ctx, "Crown", 0.1, radius * 2 + 0.08, base * CFrame.new(0, 0.47, 0), GOLD_LIGHT, SMOOTH)
	for i = 1, 5 do
		local a = (i - 1) / 5 * math.pi * 2
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local position = dir * radius * 0.84 + Vector3.new(0, 0.5, 0)
		-- Carré posé sur la pointe : le bas est caché dans le bandeau, reste un triangle
		box(
			ctx,
			"Crown",
			Vector3.new(0.6, 0.6, 0.22),
			base * CFrame.new(position) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(45)),
			GOLD,
			SMOOTH
		)
		ball(ctx, "Crown", 0.16, base * CFrame.new(position + Vector3.new(0, 0.44, 0)), GOLD_LIGHT, SMOOTH)
	end
	local front = box(
		ctx,
		"Crown",
		Vector3.new(0.34, 0.34, 0.16),
		base * CFrame.new(0, 0.22, -radius - 0.03) * CFrame.Angles(0, 0, math.rad(45)),
		gemColor,
		NEON
	)
	if rarity.Rainbow then
		rainbow(front, 0.1)
	end
end

---------------------------------------------------------------------------
-- Effets : rareté et mutations
---------------------------------------------------------------------------
local function addParticles(
	root: BasePart,
	name: string,
	color: ColorSequence,
	rate: number,
	size: number,
	zOffset: number?
): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	-- Les particules naissent dans Root, au cœur du corps opaque : sans décalage vers la
	-- caméra (environ le rayon du corps), la plupart restent cachées par le corps
	emitter.ZOffset = zOffset or 0
	emitter.Color = color
	-- Émission lumineuse partielle : des étincelles purement additives disparaissent sur le
	-- sol blanc des bases et sur les socles
	emitter.LightEmission = 0.35
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Speed = NumberRange.new(1.2, 2.6)
	emitter.SpreadAngle = Vector2.new(75, 75)
	emitter.Acceleration = Vector3.new(0, 1.2, 0)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = root
	return emitter
end

local function addLight(root: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = root
	return light
end

-- Disque de rareté au sol, lisible de loin : anneau néon de la couleur de la rareté et
-- disque intérieur plus clair (pièces opaques), jamais plus large que le socle d'une base.
-- Secret : anneau arc-en-ciel fin (teinte animée par CreatureAnimator)
local function addRarityDisc(ctx: Ctx, rarity, hip: number, footprint: number)
	local radius = math.min(footprint, SLOT_RADIUS / ctx.Scale)
	local y = -hip + 0.08
	if rarity.Rainbow then
		local count = 16
		local width = 0.34
		for i = 1, count do
			local a = i / count * math.pi * 2
			local segment = box(
				ctx,
				"RarityDisc",
				Vector3.new(radius * 2 * math.pi / count * 1.08, 0.14, width),
				CFrame.new(math.cos(a) * (radius - width / 2), y, math.sin(a) * (radius - width / 2))
					* CFrame.Angles(0, -a - math.pi / 2, 0),
				WHITE,
				NEON
			)
			rainbow(segment, i / count)
		end
		return
	end
	cylinder(ctx, "RarityDisc", 0.12, radius * 2, CFrame.new(0, y, 0), rarity.Color, NEON)
	cylinder(
		ctx,
		"RarityDisc",
		0.13,
		radius * 2 - 0.7,
		CFrame.new(0, y + 0.015, 0),
		rarity.Color:Lerp(WHITE, 0.5),
		SMOOTH
	)
end

local function applyRarity(ctx: Ctx, rarity, shape: Shape, footprint: number)
	if rarity.Tier >= 2 then
		addRarityDisc(ctx, rarity, shape.Hip, footprint)
	end
	if rarity.Tier >= 4 then
		local colors = if rarity.Rainbow
			then sequence(Rarities.RainbowColors)
			else ColorSequence.new(rarity.Color, rarity.Color:Lerp(WHITE, 0.5))
		addParticles(ctx.Root, "Sparkles", colors, 5 + (rarity.Tier - 4) * 6, 0.58 * ctx.Scale, 1.7 * ctx.Scale)
	end
	if rarity.Tier >= 5 then
		addLight(ctx.Root, if rarity.Rainbow then WHITE else rarity.Color, 1.4, 12 * ctx.Scale)
	end
	if rarity.Rainbow then
		-- Aura arc-en-ciel : huit petites étincelles en orbite autour du ventre (sous le
		-- visage, dans la case du socle) et un nuage de particules arc-en-ciel tout autour
		local body = shape.Body
		local radius = orbitRadius(ctx, math.max(body.R.X, body.R.Z) + 0.9, 0.15)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local orb = ball(
				ctx,
				"Orbit",
				0.3,
				CFrame.new(math.cos(a) * radius, orbitHeight(body, i, 0.22), math.sin(a) * radius),
				WHITE,
				NEON
			)
			rainbow(orb, i / 8)
		end
		local aura = addParticles(
			ctx.Root,
			"RainbowAura",
			sequence(Rarities.RainbowColors),
			10,
			0.5 * ctx.Scale,
			1.7 * ctx.Scale
		)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Speed = NumberRange.new(0.5, 1)
		aura.Lifetime = NumberRange.new(1.5, 2.5)
		aura.Acceleration = Vector3.zero
	end
end

local MutationEffects = {}

-- Éclair en zigzag (deux segments néon décalés, comme ⚡) partant de "base" le long de "dir"
local function bolt(ctx: Ctx, base: Vector3, dir: Vector3, length: number, color: Color3)
	local d = dir.Unit
	local side = d:Cross(Vector3.zAxis)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local segment = length * 0.55
	local up = d + side * (0.32 / segment)
	box(
		ctx,
		"Spark",
		Vector3.new(0.26, segment, 0.26),
		upright(base + d * length * 0.28 - side * 0.09, up),
		color,
		NEON
	)
	box(
		ctx,
		"Spark",
		Vector3.new(0.26, segment, 0.26),
		upright(base + d * length * 0.72 + side * 0.09, up),
		color,
		NEON
	)
end

-- Instable : yeux électriques (makePalette), couronne d'éclairs sur la tête, éclats
-- d'énergie en orbite
function MutationEffects.Shards(ctx: Ctx, shape: Shape, mutation)
	local head = shape.Head
	for i = 1, 4 do
		local azimuth = (i - 0.5) * math.pi / 2
		local p, n = surface(head, Vector3.new(math.sin(azimuth) * 0.75, 0.7, -math.cos(azimuth) * 0.75))
		bolt(ctx, p - n * 0.1, n + Vector3.yAxis * 0.8, 1.45, mutation.Accent)
	end
	local body = shape.Body
	local radius = orbitRadius(ctx, math.max(body.R.X, body.R.Z) + 1.1, 0.52)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.5
		box(
			ctx,
			"Orbit",
			Vector3.new(0.42, 0.84, 0.42),
			CFrame.new(math.cos(a) * radius, orbitHeight(body, i, 0.3), math.sin(a) * radius)
				* CFrame.Angles(a, a * 0.7, 0.6),
			if i == 2 then mutation.Color else mutation.Accent,
			NEON
		)
	end
end

-- Prismatique : le corps devient arc-en-ciel (paintRainbowBody) + gemmes arc-en-ciel en orbite
function MutationEffects.Prism(ctx: Ctx, shape: Shape, _mutation)
	local body = shape.Body
	local radius = orbitRadius(ctx, math.max(body.R.X, body.R.Z) + 1.1, 0.52)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.9
		local gem = box(
			ctx,
			"Orbit",
			Vector3.one * 0.6,
			gemCFrame(Vector3.new(math.cos(a) * radius, orbitHeight(body, i, 0.3), math.sin(a) * radius)),
			WHITE,
			NEON
		)
		rainbow(gem, i / 3 + 0.05)
	end
end

-- Abyssal : bioluminescence des grands fonds. Corps bleu nuit (makePalette), yeux et taches
-- lumineuses cyan, leurre de baudroie au-dessus du front (sauf sous une couronne), aura
function MutationEffects.Abyss(ctx: Ctx, shape: Shape, mutation)
	local body = shape.Body
	local diameter = math.min(math.max(body.R.X, body.R.Y, body.R.Z) * 2 + 1.6, 2 * ORBIT_REACH / ctx.Scale)
	local aura = ball(ctx, "MutationAura", diameter, CFrame.new(body.C), mutation.Color, Enum.Material.ForceField)
	aura.Transparency = 0.15
	aura.CastShadow = false
	for i, dir in
		{
			Vector3.new(0.85, 0.35, -0.4),
			Vector3.new(-0.85, 0.35, -0.4),
			Vector3.new(0.75, -0.35, -0.6),
			Vector3.new(-0.75, -0.35, -0.6),
		}
	do
		local size = if i <= 2 then 0.38 else 0.3
		accent(
			ctx,
			ellipsoid(ctx, "Spot", Vector3.new(size, size, 0.14), onSurface(body, dir, 0.03), mutation.Accent, NEON)
		)
	end
	if not ctx.Crowned then
		local head = shape.Head
		local p, n = surface(head, Vector3.new(0, 0.72, -0.7))
		local bend = p + n * 0.5 + Vector3.new(0, 0.5, 0)
		local tip = bend + Vector3.new(0, 0.02, -0.6)
		for _, span in { { p, bend }, { bend, tip } } do
			local length = (span[2] - span[1]).Magnitude
			ellipsoid(
				ctx,
				"Lure",
				Vector3.new(0.15, 0.15, length + 0.12),
				lookAt(span[1], span[2]) * CFrame.new(0, 0, -length / 2),
				ctx.P.Limb
			)
		end
		accent(ctx, ball(ctx, "Lure", 0.52, CFrame.new(tip + Vector3.new(0, -0.14, 0)), mutation.Accent, NEON))
	end
end

-- Céleste : statue d'or (makePalette), auréole dorée au-dessus de la couronne ou de
-- l'accessoire, ailes d'ange
function MutationEffects.Halo(ctx: Ctx, shape: Shape, mutation)
	local head = shape.Head
	local top = headTop(shape)
	local y = math.max(top.Y + (if ctx.Crowned then 1.2 else 0.65), (shape.HatTop or -math.huge) + 0.35)
	local center = Vector3.new(top.X, y, top.Z + 0.1)
	local radius = math.min(head.R.X, head.R.Z) * 0.62
	local count = 12
	for i = 1, count do
		local a = i / count * math.pi * 2
		box(
			ctx,
			"Halo",
			Vector3.new(radius * 2 * math.pi / count * 1.12, 0.16, 0.2),
			CFrame.new(center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
				* CFrame.Angles(0, -a - math.pi / 2, 0),
			mutation.Accent,
			NEON
		)
	end
	if ctx.Traits.Wings == nil then
		Features.Wings(ctx, shape, "Angel")
	end
end

local function applyMutation(ctx: Ctx, shape: Shape?, mutationId: string)
	local mutation = Mutations.Get(mutationId)
	if not mutation then
		return
	end
	if shape then
		local effect = MutationEffects[mutation.Effect]
		if effect then
			effect(ctx, shape, mutation)
		end
	else
		-- Modèle 3D fourni : on ne connaît pas ses accents, simple aura colorée
		local aura = ball(ctx, "MutationAura", 5, CFrame.new(), mutation.Color, Enum.Material.ForceField)
		aura.Transparency = 0.15
		aura.CastShadow = false
	end
	local colors = if mutation.GradientColors
		then sequence(mutation.GradientColors)
		else ColorSequence.new(mutation.Color, mutation.Accent)
	addParticles(ctx.Root, "Aura", colors, 6 + mutation.Multiplier * 2, 0.4 * ctx.Scale, 1.7 * ctx.Scale)
	-- Une seule lumière par créature : celle de la rareté (Mythique+) prend la couleur de la mutation
	local light = ctx.Root:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = mutation.Color
		light.Brightness = math.max(light.Brightness, mutation.LightBrightness)
	else
		addLight(ctx.Root, mutation.Color, mutation.LightBrightness, 10 * ctx.Scale)
	end
end

---------------------------------------------------------------------------
-- Billboard d'informations (texte seul, style « Steal a ... »)
---------------------------------------------------------------------------
-- Étiquette au-dessus de la créature, de haut en bas :
--   [MUTATION xN]  (si mutée)            Luckiest Guy, dégradé de la mutation
--   Nom                                   Fredoka One, blanc
--   RARETÉ                                Luckiest Guy, dégradé de la rareté (arc-en-ciel pour Secret)
--   $X/s                                  Luckiest Guy (« /s » en Fredoka One), jaune-or
--   $Prix  (seulement sur le tapis)       Luckiest Guy, vert vif
-- Taille mixte : une part en studs (l'étiquette rétrécit avec la distance comme un objet
-- du monde) + un plancher en pixels (LABEL_FLOOR par stud : le texte reste lisible de loin
-- et sur téléphone). TextScaled remplit chaque ligne, UITextSizeConstraint évite les
-- lettres géantes de près, le contour noir garde le texte lisible sur n'importe quel fond.
--
-- Luckiest Guy n'a que des capitales, collées en haut de la ligne (le bas reste vide), et
-- ses accents (É) dépassent de 0,27 em au-dessus. Chaque ligne Luckiest Guy réserve donc
-- LG_TOP de sa hauteur en haut (UIPadding) : les accents y tiennent et les capitales sont
-- centrées dans leur ligne comme les lettres de Fredoka One. Avec LINE_GAP pixels entre
-- les lignes, l'espacement est régulier et ni les lettres ni les contours ne se touchent.
local LABEL_WIDTH = 9 -- studs
-- Pixels ajoutés par stud (plancher de taille) : plus généreux sur le tapis (on repère les
-- bonnes affaires de loin), discret dans les bases (rangées serrées)
local LABEL_FLOOR = { Carpet = 12, Base = 6 }
-- Distance d'affichage : le tapis se surveille depuis sa base ; dans une base, un voleur
-- lit les rangées du fond depuis le trottoir (de loin, CreatureAnimator ne garde que la
-- rareté et le revenu : pas de mur de texte)
local LABEL_MAX_DISTANCE = { Carpet = 90, Base = 80 }
local LG_TOP = 0.23
-- Taille des lettres de chaque ligne (unités de hauteur d'étiquette)
local GLYPH = { Mutation = 0.7, Name = 0.8, Rarity = 0.76, Income = 0.7, Price = 0.88 }
-- Taille de police maximale (pixels) : plus petite dans les bases, où les étiquettes
-- s'empilent
local MAX_TEXT_SIZE = {
	Carpet = { Mutation = 44, Name = 54, Rarity = 50, Income = 46, Price = 58 },
	Base = { Mutation = 28, Name = 35, Rarity = 32, Income = 30, Price = 36 },
}
local LINE_GAP = 3 -- pixels entre deux lignes
local STROKE = 2.5 -- contour noir (pixels)
local INCOME_COLOR = rgb(255, 215, 40)
local PRICE_COLOR = rgb(80, 255, 90)
local LUCKIEST = Enum.Font.LuckiestGuy
local FREDOKA = Enum.Font.FredokaOne

-- Dégradé vertical vif posé sur les capitales d'une ligne Luckiest Guy (bande LG_TOP..0,77
-- de la ligne) : clair en haut, couleur franche au milieu, un peu plus sombre en bas
local function verticalGradient(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.3)),
		ColorSequenceKeypoint.new(0.3, color:Lerp(WHITE, 0.25)),
		ColorSequenceKeypoint.new(0.55, color),
		ColorSequenceKeypoint.new(0.78, color:Lerp(INK, 0.14)),
		ColorSequenceKeypoint.new(1, color:Lerp(INK, 0.14)),
	})
end

-- Largeur approchée d'un texte en Luckiest Guy (em) : capitales et chiffres ~0,59 em,
-- espace 0,2 (les octets de continuation UTF-8 ne comptent pas : É = un caractère)
local function luckiestWidth(text: string): number
	local chars = #(string.gsub(text, "[\128-\191]", ""))
	local _, spaces = string.gsub(text, " ", "")
	return (chars - spaces) * 0.59 + spaces * 0.2
end

-- Dégradé horizontal (arc-en-ciel) resserré sur le texte. Un UIGradient s'étale sur toute
-- la largeur de l'étiquette (9 studs) : sur un mot court comme SECRET, seules les couleurs
-- du milieu toucheraient les lettres. La taille du texte suit la hauteur de sa ligne, donc
-- la part de largeur qu'il occupe est à peu près constante.
local function spanGradient(colors: { Color3 }, text: string, glyph: number): ColorSequence
	local span = math.clamp(luckiestWidth(text) * glyph / LABEL_WIDTH, 0.15, 1)
	local first = 0.5 - span / 2
	local keypoints = { ColorSequenceKeypoint.new(0, colors[1]) }
	for i, color in colors do
		local t = first + span * (i - 1) / math.max(#colors - 1, 1)
		if t > 0.001 and t < 0.999 then
			table.insert(keypoints, ColorSequenceKeypoint.new(t, color))
		end
	end
	table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[#colors]))
	return ColorSequence.new(keypoints)
end

type LabelLine = {
	Name: string,
	Font: Enum.Font,
	Text: string,
	Gradient: ColorSequence,
	Horizontal: boolean?, -- dégradé de gauche à droite (arc-en-ciel)
	Rich: boolean?, -- texte riche (« /s » du revenu)
}

-- Hauteur d'une ligne (unités) : les lignes Luckiest Guy réservent LG_TOP en haut
local function lineHeight(info: LabelLine): number
	return if info.Font == LUCKIEST then GLYPH[info.Name] / (1 - LG_TOP) else GLYPH[info.Name]
end

local function addLine(gui: BillboardGui, info: LabelLine, order: number, share: number, gaps: number, maxSize: number)
	local label = Instance.new("TextLabel")
	label.Name = info.Name
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	-- Sa part de la hauteur de l'étiquette, moins sa part des espaces entre lignes
	label.Size = UDim2.new(1, 0, share, -math.round(gaps * share))
	label.Font = info.Font
	label.RichText = info.Rich == true
	label.Text = info.Text
	label.TextColor3 = WHITE -- le dégradé teinte le blanc
	label.TextScaled = true
	label.TextWrapped = false
	if info.Font == LUCKIEST then
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(LG_TOP, 0)
		padding.Parent = label
	end
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = STROKE
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	local tint = Instance.new("UIGradient")
	tint.Color = info.Gradient
	tint.Rotation = if info.Horizontal then 0 else 90
	tint.Parent = label
	label.Parent = gui
end

function CreatureVisuals.CreateBillboard(
	root: BasePart,
	def,
	mutationId: string,
	heightOffset: number,
	priceText: string?
): BillboardGui
	local rarity = Rarities.Get(def.Rarity)
	local mutation = Mutations.Get(mutationId)
	local place = if priceText then "Carpet" else "Base"

	local lines: { LabelLine } = {}
	if mutation then
		local text = string.format("%s X%d", Format.Upper(mutation.Name), mutation.Multiplier)
		table.insert(lines, {
			Name = "Mutation",
			Font = LUCKIEST,
			Text = text,
			Gradient = if mutation.GradientColors
				then spanGradient(mutation.GradientColors, text, GLYPH.Mutation)
				else verticalGradient(mutation.Color),
			Horizontal = mutation.GradientColors ~= nil,
		})
	end
	table.insert(lines, { Name = "Name", Font = FREDOKA, Text = def.Name, Gradient = ColorSequence.new(WHITE) })
	local rainbowRarity = rarity ~= nil and rarity.Rainbow == true
	local rarityText = Format.Upper(if rarity then rarity.Name else tostring(def.Rarity))
	table.insert(lines, {
		Name = "Rarity",
		Font = LUCKIEST,
		Text = rarityText,
		Gradient = if rainbowRarity
			then spanGradient(Rarities.RainbowColors, rarityText, GLYPH.Rarity)
			else verticalGradient(if rarity then rarity.Color else WHITE),
		Horizontal = rainbowRarity,
	})
	-- « /s » en minuscules de Fredoka One (Luckiest Guy n'a que des capitales : « /S »)
	local income = Format.Income(def.Income * Mutations.GetMultiplier(mutationId))
	table.insert(lines, {
		Name = "Income",
		Font = LUCKIEST,
		Text = (string.gsub(income, "/s$", '<font face="FredokaOne">/s</font>')),
		Gradient = verticalGradient(INCOME_COLOR),
		Rich = true,
	})
	if priceText then
		table.insert(
			lines,
			{ Name = "Price", Font = LUCKIEST, Text = priceText, Gradient = verticalGradient(PRICE_COLOR) }
		)
	end

	local total = 0
	for _, info in lines do
		total += lineHeight(info)
	end
	local gaps = LINE_GAP * (#lines - 1)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = root
	local floor = LABEL_FLOOR[place]
	gui.Size = UDim2.new(LABEL_WIDTH, LABEL_WIDTH * floor, total, total * floor + gaps)
	-- Le bas de l'étiquette est posé à heightOffset au-dessus du centre de la créature
	-- (SizeOffset Y positif = vers le haut, en fraction de la taille affichée)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, heightOffset, 0)
	gui.MaxDistance = LABEL_MAX_DISTANCE[place]
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, LINE_GAP)
	layout.Parent = gui

	for order, info in lines do
		addLine(gui, info, order, lineHeight(info) / total, gaps, MAX_TEXT_SIZE[place][info.Name])
	end

	gui.Parent = root
	return gui
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function getAssetTemplate(def): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Creatures")
	if not folder then
		return nil
	end
	local template = folder:FindFirstChild(def.Model or def.Id)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function makeRoot(model: Model, size: Vector3): Part
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return root
end

-- Ancre ou soude toutes les pièces à Root
local function finalizePhysics(model: Model, root: BasePart, anchored: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Anchored = anchored
			if not anchored then
				descendant.Massless = true
				if descendant ~= root then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end
		end
	end
end

-- Petite variation de teinte déterministe par créature (deux créatures du même
-- archétype et de la même dimension ne se ressemblent pas)
local function hashId(id: string): number
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 1000003
	end
	return (h % 1000) / 1000
end

local function makePalette(def, style: Style, traits: Traits, mutation): Palette
	local over = traits.Palette or {}
	local hue = hashId(def.Id)
	local palette: Palette = {
		Body = over.Body or style.Body:Lerp(style.Limb, hue * 0.2),
		Belly = over.Belly or style.Belly,
		Limb = over.Limb or style.Limb:Lerp(style.Body, hue * 0.2),
		Accent = over.Accent or style.Accent,
		Accent2 = over.Accent2 or style.Accent2,
		Pupil = style.Pupil,
		Sclera = WHITE,
		PupilMaterial = SMOOTH,
		Material = SMOOTH,
		AccentMaterial = if style.Glow then NEON else SMOOTH,
	}
	if traits.GlowEyes then
		palette.Sclera = rgb(30, 10, 60)
		palette.Pupil = palette.Accent
		palette.PupilMaterial = NEON
	end
	if mutation then
		-- Les couleurs de la mutation remplacent (en grande partie) celles de la créature :
		-- un mélange RVB de teintes opposées donnerait du gris
		local mix = mutation.Mix
		if mutation.Body then
			palette.Body = palette.Body:Lerp(mutation.Body, mix)
		end
		if mutation.Belly then
			palette.Belly = palette.Belly:Lerp(mutation.Belly, mix)
		end
		if mutation.Limb then
			palette.Limb = palette.Limb:Lerp(mutation.Limb, mix)
		end
		palette.Accent = mutation.Accent
		palette.Accent2 = mutation.Color
		palette.AccentMaterial = NEON
		if mutation.Effect == "Abyss" then
			-- Yeux luisants des grands fonds
			palette.Sclera = rgb(8, 14, 30)
			palette.Pupil = mutation.Accent
			palette.PupilMaterial = NEON
		elseif mutation.Effect == "Shards" then
			-- Yeux électriques : pupilles néon (la mutation se repère de loin)
			palette.Pupil = mutation.Color
			palette.PupilMaterial = NEON
		end
	end
	return palette
end

-- Prismatique : le corps entier passe à l'arc-en-ciel (dégradé vertical, animé côté
-- client par CreatureAnimator) ; visage, couronne et effets gardent leurs couleurs
local KEEP_COLORS = {
	Root = true,
	Eye = true,
	Pupil = true,
	Shine = true,
	Mouth = true,
	Blush = true,
	Brow = true,
	Visor = true,
	Nose = true,
	Crown = true,
	Halo = true,
	RarityDisc = true,
	Orbit = true,
	MutationAura = true,
}

local function paintRainbowBody(ctx: Ctx)
	for _, part in ctx.Model:GetChildren() do
		if
			part:IsA("BasePart")
			and not KEEP_COLORS[part.Name]
			and part:GetAttribute("Rainbow") == nil
			and not ctx.SkinOf[part]
		then
			-- Teinte selon la hauteur (bien étalée : même immobile, la créature est
			-- multicolore), couleurs franches ; le ventre reste plus clair pour le relief
			local hue = (0.5 + part.CFrame.Position.Y / ctx.Scale * 0.34) % 1
			part.Color = Color3.fromHSV(hue, if part.Name == "Belly" then 0.5 else 0.9, 1)
			part:SetAttribute("Rainbow", hue)
		end
	end
	-- Lèvres : exactement la couleur (et donc l'animation) de la pièce qu'elles recouvrent
	for lip, skin in ctx.SkinOf do
		lip.Color = skin.Color
		lip:SetAttribute("Rainbow", skin:GetAttribute("Rainbow"))
	end
end

-- Hauteur du point le plus haut du modèle au-dessus de Root (boîtes englobantes des pièces)
local function topOf(model: Model, root: BasePart): number
	local top = 0
	local origin = root.CFrame.Position.Y
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and part.Name ~= "RarityDisc" and part.Name ~= "MutationAura" then
			top = math.max(top, part.CFrame.Position.Y - origin + halfExtent(part, Vector3.yAxis))
		end
	end
	return top
end

-- Facteur (<= 1) qui fait tenir le corps dans sa case de base (SLOT_HALF_WIDTH x
-- SLOT_HALF_DEPTH autour du centre). Disque de rareté, orbites et aura sont déjà bornés
-- en studs et ne comptent pas.
local FIT_IGNORE = { Root = true, RarityDisc = true, Orbit = true, MutationAura = true }

local function fitFactor(model: Model): number
	local halfX, halfZ = 0, 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and not FIT_IGNORE[part.Name] then
			local position = part.CFrame.Position
			halfX = math.max(halfX, math.abs(position.X) + halfExtent(part, Vector3.xAxis))
			halfZ = math.max(halfZ, math.abs(position.Z) + halfExtent(part, Vector3.zAxis))
		end
	end
	return math.min(1, SLOT_HALF_WIDTH / math.max(halfX, 1e-3), SLOT_HALF_DEPTH / math.max(halfZ, 1e-3))
end

local function buildProcedural(
	model: Model,
	root: BasePart,
	def,
	rarity,
	style: Style,
	mutationId: string,
	scale: number
)
	local traits = TRAITS[def.Id] or NO_TRAITS
	-- L'archétype est utile aux traits (3e œil) : copie locale enrichie
	local localTraits: Traits = table.clone(traits)
	localTraits.Archetype = def.Visual.Archetype
	local mutation = Mutations.Get(mutationId)
	local ctx: Ctx = {
		Model = model,
		Root = root,
		Scale = scale,
		P = makePalette(def, style, traits, mutation),
		Style = style,
		Traits = localTraits,
		Accents = {},
		RainbowAccents = mutation ~= nil and mutation.Effect == "Prism",
		Blush = style.Blush and not (mutation ~= nil and mutation.Effect == "Abyss"),
		Crowned = rarity.Tier >= 4,
		SkinOf = {},
		Freckles = if mutation and mutation.Effect == "Abyss" then mutation.Accent else nil,
	}

	local builder = Archetypes[def.Visual.Archetype] or Archetypes.Blob
	local shape: Shape = builder(ctx)

	addFace(ctx, shape)
	for _, feature in { "Ears", "Horns", "Tail" } do
		if traits[feature] then
			Features[feature](ctx, shape, traits[feature])
		end
	end
	if traits.Wings then
		Features.Wings(ctx, shape, traits.Wings)
	end
	for _, feature in
		{
			"Beak",
			"Trunk",
			"Tentacles",
			"Propellers",
			"Fins",
			"Frills",
			"Spots",
			"Cracks",
			"Core",
			"Spines",
			"Hood",
			"Helmet",
			"Fur",
			"Clouds",
			"Sprinkles",
			"Glitch",
			"Ring",
			"OrbitCrystals",
			"Shards",
			"Mane",
			"Heads",
		}
	do
		if traits[feature] then
			Features[feature](ctx, shape)
		end
	end
	if traits.Scarf then
		Features.Scarf(ctx, shape, traits.Scarf)
	end
	if traits.Cape then
		Features.Cape(ctx, shape, traits.Cape)
	end
	if traits.Staff then
		Features.Staff(ctx, shape, traits.Staff)
	end

	-- Couronne dès Légendaire, sinon l'accessoire de la dimension ; on mesure son sommet
	-- (l'auréole Céleste se pose au-dessus)
	local hat: { BasePart } = {}
	ctx.Track = hat
	if rarity.Tier >= 4 then
		addCrown(ctx, shape, rarity)
	else
		local topper = Toppers[traits.Topper or style.Topper]
		if topper then
			topper(ctx, shape)
		end
	end
	ctx.Track = nil
	for _, part in hat do
		local top = part.CFrame.Position.Y + halfExtent(part, Vector3.yAxis)
		shape.HatTop = math.max(shape.HatTop or -math.huge, top / scale)
	end

	local body = shape.Body
	local footprint = math.clamp(math.max(body.R.X, body.R.Z, shape.Head.R.X) * 1.15 + 0.35, 1.9, 2.6)
	applyRarity(ctx, rarity, shape, footprint)
	applyMutation(ctx, shape, mutationId)
	if mutation and mutation.Effect == "Prism" then
		paintRainbowBody(ctx)
	end
	-- Créature qui plane (CreatureAnimator la fait flotter au lieu de sautiller)
	if shape.Floating or traits.Ghost then
		model:SetAttribute("Floating", true)
	end
	return shape.Hip * scale
end

function CreatureVisuals.Build(creatureId: string, mutationId: string?, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local anchored = if opts.Anchored == nil then true else opts.Anchored
	local mutation = mutationId or Mutations.None

	local def = Creatures.Get(creatureId)
	assert(def, "Créature inconnue : " .. tostring(creatureId))
	local rarity = Rarities.Get(def.Rarity)
	assert(rarity, "Rareté invalide pour " .. creatureId)
	local style = STYLES[def.Dimension] or STYLES.Lava

	local scale = rarity.Scale * (def.Visual.Scale or 1)
	local model: Model
	local root: BasePart
	local hipHeight: number

	local template = getAssetTemplate(def)
	if template then
		-- Modèle 3D fourni par le développeur
		model = template:Clone()
		local boxCFrame, boxSize = model:GetBoundingBox()
		model:PivotTo(boxCFrame:Inverse() * model:GetPivot())
		root = makeRoot(model, Vector3.one)
		hipHeight = boxSize.Y / 2
		local ctx: Ctx = {
			Model = model,
			Root = root,
			Scale = math.max(boxSize.X, boxSize.Y, boxSize.Z) / 4.6,
			P = makePalette(def, style, NO_TRAITS, nil),
			Style = style,
			Traits = NO_TRAITS,
			Accents = {},
			RainbowAccents = false,
			Blush = false,
			Crowned = false,
			SkinOf = {},
		}
		local shape: Shape = {
			Hip = hipHeight / ctx.Scale,
			Head = { C = Vector3.zero, R = boxSize / 2 / ctx.Scale },
			Body = { C = Vector3.zero, R = boxSize / 2 / ctx.Scale },
			Eye = { U = 0, V = 0, Size = 1 },
		}
		applyRarity(ctx, rarity, shape, math.clamp(math.max(boxSize.X, boxSize.Z) / 2 / ctx.Scale, 1.9, 2.6))
		applyMutation(ctx, nil, mutation)
	else
		model = Instance.new("Model")
		root = makeRoot(model, Vector3.one * 2 * scale)
		hipHeight = buildProcedural(model, root, def, rarity, style, mutation, scale)
		-- Trop grande pour sa case de base (ailes, queue, bâton...) : reconstruite un peu plus
		-- petite, pour que deux voisines ne se chevauchent jamais
		local fit = fitFactor(model)
		if fit < 1 then
			model:Destroy()
			scale *= math.max(fit, MIN_FIT)
			model = Instance.new("Model")
			root = makeRoot(model, Vector3.one * 2 * scale)
			hipHeight = buildProcedural(model, root, def, rarity, style, mutation, scale)
		end
	end

	model.Name = def.Id
	model:SetAttribute("CreatureId", def.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("HipHeight", hipHeight)
	-- Le modèle arrive entier chez le client (jamais une créature à moitié chargée)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	if opts.Billboard then
		CreatureVisuals.CreateBillboard(root, def, mutation, topOf(model, root) + 0.6, opts.PriceText)
	end

	finalizePhysics(model, root, anchored)
	return model
end

return CreatureVisuals
