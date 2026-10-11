--[[
	CreatureVisuals
	===============
	Fabrique de modèles de créatures, direction artistique v3 « propre »
	(docs/ART_DIRECTION.md, section 4) : formes rondes et lisibles, couleurs franches mais
	maîtrisées, UNE seule couleur d'accent par créature (en plastique, pas en néon), les
	mêmes yeux pour toutes les créatures organiques, peu de pièces.

	Le néon est réservé à ce qui doit briller : l'anneau de rareté, la visière et l'objectif
	des robots Cyber, les cœurs d'énergie (titan, noyau), les fissures du golem de scories,
	les étincelles Secrètes et quelques effets de mutation (auréole Céleste, lueurs
	Abyssales). Rien ne clignote en permanence.

	1. Si un modèle nommé def.Model (ou def.Id) existe dans
	   ReplicatedStorage.Assets.Creatures, il est cloné (vos vrais modèles 3D).
	2. Sinon, un modèle procédural est construit :
	   - corps en ellipsoïdes lisses (SpecialMesh Sphere : aucun asset requis)
	   - archétypes : Blob, Spiky, Tall, Crystal, Wisp, Beast, Serpent, Golem
	   - traits propres à chaque créature (TRAITS : oreilles, cornes, ailes, bec,
	     trompe, tentacules, hélices...) : les 40 créatures ont leur silhouette
	   - accessoire de dimension : Lave (flamme), Néant (antennes), Glace (bonnet de neige
	     et cristal), Bonbon (chantilly et cerise), Cyber (antenne)
	   - rareté : taille, anneau néon fin au sol (dès Rare), couronne dorée dès Légendaire
	     (gemme dès Mythique), arc-en-ciel pour Secret (anneau, gemme, étincelles en orbite)
	   - mutation : couleurs de la mutation + effet propre (voir Mutations.luau)
	   - étiquette (CreateBillboard) : texte seul, contours encre bleu nuit
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

local WHITE = rgb(255, 255, 255)
-- Encre bleu nuit de la direction artistique : contours des étiquettes, pupilles,
-- sourcils (jamais de noir pur)
local INK = rgb(28, 31, 58)
local MOUTH = rgb(92, 24, 46)
local TONGUE = rgb(255, 112, 140)
local BLUSH = rgb(255, 112, 150)
local INNER_EAR = rgb(255, 150, 186)
local BEAK = rgb(255, 172, 36)
local HORN = rgb(255, 240, 214)
local GOLD = rgb(255, 200, 52)
local GOLD_DARK = rgb(240, 158, 30)
local STEEL = rgb(72, 80, 102)
local SCREEN = rgb(24, 27, 46) -- visière et écrans des robots
-- Dessus d'un socle débloqué (PlotService) : l'intérieur de l'anneau de rareté s'y fond
local PEDESTAL_TOP = rgb(250, 250, 255)
-- Flamme de dessin animé (accessoire Lave, queue du Braisillon) : orange à la base, pointe
-- jaune, cœur jaune pâle lumineux (seul néon de la flamme : c'est du feu)
local FLAME = rgb(255, 150, 36)
local FLAME_TIP = rgb(255, 206, 48)
local FLAME_CORE = rgb(255, 232, 128)

-- Emplacement d'une base (studs) : colonnes espacées de 11, rangées de 9, socle de 6,4 de
-- diamètre. Chaque créature tient dans une case de 10 x 8,8 centrée sur son socle (les
-- voisines ne se touchent jamais) ; anneau de rareté et orbites restent dans la case.
local SLOT_HALF_WIDTH = 5.0
local SLOT_HALF_DEPTH = 4.4
local SLOT_RADIUS = 3.1 -- rayon max de l'anneau de rareté (le socle fait 3,2)
local RING_WIDTH = 0.42 -- largeur de l'anneau de rareté (studs, quelle que soit la taille)
local ORBIT_REACH = 4.3 -- distance max au centre des pièces en orbite (étincelles, éclats)
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
-- Styles par dimension (une couleur de corps, un ventre clair, des membres plus
-- soutenus et UNE couleur d'accent ; voir docs/ART_DIRECTION.md)
---------------------------------------------------------------------------
type Style = {
	Body: Color3,
	Belly: Color3,
	Limb: Color3,
	Accent: Color3, -- seule couleur d'accent (plastique plein)
	Robot: boolean?, -- yeux d'écran (Cyber)
	Topper: string, -- accessoire de tête par défaut
	Blush: boolean,
	Eyes: string?, -- style d'yeux par défaut
}

local STYLES: { [string]: Style } = {
	Lava = {
		-- Rouge corail, ventre crème, accent jaune flamme (le jaune tranche sur le corail)
		Body = rgb(252, 106, 74),
		Belly = rgb(255, 228, 172),
		Limb = rgb(214, 62, 56),
		Accent = rgb(255, 208, 62),
		Topper = "Flame",
		Blush = true,
	},
	Void = {
		-- Violet franc (plus clair que l'Épique), ventre lilas, accent rose
		Body = rgb(146, 112, 255),
		Belly = rgb(218, 204, 255),
		Limb = rgb(104, 72, 218),
		Accent = rgb(255, 120, 200),
		Topper = "Antennae",
		Blush = true,
	},
	Ice = {
		-- Bleu glacier, ventre neige, accent cyan pâle (cristaux)
		Body = rgb(104, 196, 255),
		Belly = rgb(242, 251, 255),
		Limb = rgb(58, 142, 236),
		Accent = rgb(176, 242, 255),
		Topper = "Snow",
		Blush = true,
	},
	Candy = {
		-- Rose bonbon, ventre crème, accent menthe
		Body = rgb(255, 140, 198),
		Belly = rgb(255, 242, 248),
		Limb = rgb(240, 94, 162),
		Accent = rgb(92, 222, 192),
		Topper = "Cream",
		Blush = true,
	},
	Cyber = {
		-- Acier bleuté (un gris clair disparaîtrait sur les socles blancs), écrans sombres,
		-- accent vert : seuls les yeux d'écran sont en néon
		Body = rgb(170, 184, 214),
		Belly = rgb(46, 52, 76),
		Limb = rgb(88, 98, 130),
		Accent = rgb(60, 238, 132),
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
	Lava_Salamandre = { Frills = true },
	Lava_GolemScories = {
		-- Roche de lave charbon + fissures néon orange : fort contraste, lisible de loin
		Palette = {
			Body = rgb(70, 50, 58),
			Belly = rgb(52, 38, 44),
			Limb = rgb(58, 42, 48),
			Accent = rgb(255, 128, 28),
		},
		Cracks = true,
		Brows = "Angry",
	},
	Lava_PhenixFele = { Wings = "Bird", Beak = true, Topper = "Crest", Tail = "Feathers", Mouth = "None" },
	Lava_WyrmVolcanique = { Horns = "Dragon", Spines = true },
	-- Plaque de poitrine en roche sombre : le cœur de magma ressort
	Lava_TitanNoyau = { Palette = { Belly = rgb(78, 52, 58) }, Core = true, Horns = "Dragon", Brows = "Angry" },
	Lava_IgnisPrimordial = { Palette = { Body = rgb(255, 134, 36) } },
	-- Néant
	Void_Ombrelin = { Horns = "Imp", Tail = "Devil", Topper = "None" },
	Void_OeilErrant = { Eyes = "Cyclops", Wings = "Bat", Mouth = "None" },
	-- Fantôme pâle (lilas presque blanc) : il se distingue des autres créatures du Néant
	Void_SpectreCreux = {
		Palette = { Body = rgb(206, 192, 255), Belly = rgb(244, 240, 255), Limb = rgb(158, 136, 244) },
		Ghost = true,
		Mouth = "O",
		Topper = "None",
	},
	Void_MeduseVide = { Tentacles = true },
	Void_DevoreurEchos = { Mouth = "Fangs", Ears = "Bat", Topper = "None" },
	Void_ArchonteSilencieux = { Hood = true, Cape = rgb(78, 46, 170), Topper = "None" },
	Void_LeviathanAbyssal = { Fins = true, Horns = "Dragon" },
	Void_CeluiQuiNestPas = { Eyes = "Many", Palette = { Body = rgb(98, 60, 200), Limb = rgb(66, 38, 150) } },
	-- Glace
	Ice_FloconGrognon = { Snowflake = true, Brows = "Grumpy", Mouth = "Flat", Topper = "None" },
	Ice_PingouinGivre = {
		-- Pingouin bleu roi, bec et pattes orange, écharpe rouge (son accent)
		Palette = { Body = rgb(40, 102, 220), Limb = rgb(255, 160, 40), Accent = rgb(255, 72, 96) },
		Beak = true,
		Flippers = true,
		Scarf = true,
		Mouth = "None",
		Topper = "None",
	},
	Ice_LynxCristallin = { Ears = "Lynx", Tail = "Short", Shards = true, Topper = "None" },
	Ice_YetiMiniature = {
		-- Corps bleu glacier, touffes de fourrure blanche (un yéti blanc disparaît sur le socle)
		Palette = { Body = rgb(120, 200, 255), Belly = rgb(242, 250, 255), Limb = rgb(70, 150, 236) },
		Fur = true,
		Topper = "None",
	},
	Ice_SentinelleGivre = { Helmet = true, Staff = "Spear", Topper = "None" },
	Ice_MammouthBoreal = { Trunk = true, Ears = "Elephant", Fur = true },
	Ice_ReineBlizzard = { Staff = "Wand" },
	Ice_ZeroAbsolu = { Palette = { Body = rgb(150, 222, 255), Limb = rgb(70, 170, 245) }, OrbitCrystals = true },
	-- Bonbon
	Candy_Gommy = { Ears = "Bear", Topper = "None" },
	Candy_Marshmallo = {
		-- Corps rose, tête blanche (Belly) : le blanc se détache sur le ciel, pas sur le socle
		Palette = { Body = rgb(255, 146, 202), Belly = rgb(255, 250, 252), Limb = rgb(255, 188, 222) },
		Marshmallow = true,
	},
	Candy_LicorneReglisse = {
		-- Réglisse violet foncé, ventre et crinière roses (son accent)
		Palette = {
			Body = rgb(106, 60, 168),
			Belly = rgb(255, 196, 228),
			Limb = rgb(76, 42, 124),
			Accent = rgb(255, 116, 196),
		},
		Horns = "Unicorn",
		Mane = true,
		Topper = "None",
	},
	Candy_GolemPraline = {
		Palette = { Body = rgb(164, 92, 52), Belly = rgb(255, 214, 160), Limb = rgb(124, 66, 36) },
	},
	Candy_DragonBarbeAPapa = { Clouds = true, Wings = "Fairy", Horns = "Nub", Topper = "None" },
	Candy_RoiCaramel = {
		-- Caramel doré, cape rouge (son accent), sceptre d'or
		Palette = {
			Body = rgb(255, 170, 60),
			Belly = rgb(255, 234, 174),
			Limb = rgb(220, 120, 32),
			Accent = rgb(232, 44, 76),
		},
		Cape = true,
		Staff = "Scepter",
	},
	Candy_HydreSucreOrge = { Heads = true },
	Candy_SucreneaInfinie = { Wings = "Fairy", Staff = "Lollipop" },
	-- Cyber
	Cyber_BitBot = {},
	Cyber_DronePixel = { Eyes = "Lens", Propellers = true, Topper = "None" },
	Cyber_Glitchat = { Ears = "Cat", Tail = "Cat", Topper = "None" },
	Cyber_SerpentBinaire = { Spines = true },
	Cyber_MechaLoup = { Ears = "Wolf", Tail = "Wolf", Topper = "None" },
	Cyber_IARebelle = { Eyes = "Lens", Ring = true },
	Cyber_KernelOmega = { Core = true },
	Cyber_SingulariteExe = {
		Palette = { Body = rgb(86, 94, 132), Limb = rgb(50, 56, 82) },
		Ring = true,
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
	Pupil: Color3,
	Material: Enum.Material,
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
local function rainbow(part: BasePart, phase: number, saturation: number?)
	local hue = phase % 1
	part.Color = Color3.fromHSV(hue, saturation or 0.72, 1)
	part:SetAttribute("Rainbow", hue)
end

-- Pièce d'accent (la couleur d'accent de la créature ; arc-en-ciel si Prismatique)
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
-- Œil (le même pour toutes les créatures organiques) : ovale blanc, grosse pupille bleu
-- nuit qui n'en laisse qu'un liseré (lisible sur les peaux sombres), un grand reflet en
-- haut et un petit en bas, toujours du même côté. Reflets en plastique blanc (pas de néon).
-- "simple" : un seul reflet (petits yeux). Renvoie le centre de l'œil.
local function addEye(ctx: Ctx, head: Head, u: number, v: number, size: number, simple: boolean?): Vector3
	local depth = size * 0.5
	local cf = onSurface(head, Vector3.new(u, v, -1), depth * 0.2)
	ellipsoid(ctx, "Eye", Vector3.new(size, size * 1.18, depth), cf, WHITE, SMOOTH)
	local side = if u > 0.01 then 1 elseif u < -0.01 then -1 else 0
	local pupilDepth = depth * 0.4
	ellipsoid(
		ctx,
		"Pupil",
		Vector3.new(size * 0.8, size * 0.98, pupilDepth),
		cf * CFrame.new(-side * size * 0.04, -size * 0.06, -depth * 0.5 + pupilDepth * 0.45),
		ctx.P.Pupil,
		SMOOTH
	)
	ball(ctx, "Shine", size * 0.34, cf * CFrame.new(size * 0.14, size * 0.2, -depth * 0.55), WHITE, SMOOTH)
	if not simple then
		ball(ctx, "Shine", size * 0.15, cf * CFrame.new(-size * 0.15, -size * 0.24, -depth * 0.52), WHITE, SMOOTH)
	end
	return cf.Position
end

-- Visière de robot : écran sombre + deux yeux d'écran en néon (le seul néon du robot)
local function addVisor(ctx: Ctx, head: Head, v: number, size: number)
	local width = math.min(head.R.X * 1.55, size * 2.9)
	local height = size * 1.15
	local depth = 0.5
	local cf = onSurface(head, Vector3.new(0, v, -1), depth * 0.32)
	if head.Box then
		box(ctx, "Visor", Vector3.new(width, height, depth), cf, SCREEN, SMOOTH)
	else
		ellipsoid(ctx, "Visor", Vector3.new(width, height, depth), cf, SCREEN, SMOOTH)
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

-- Objectif d'appareil photo (drone, IA) : bague sombre + iris néon + reflet
local function addLens(ctx: Ctx, head: Head, v: number, size: number)
	local cf = onSurface(head, Vector3.new(0, v, -1), size * 0.2)
	ellipsoid(ctx, "Eye", Vector3.new(size * 1.5, size * 1.5, size * 0.7), cf, SCREEN, SMOOTH)
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
	ball(ctx, "Shine", size * 0.3, cf * CFrame.new(size * 0.22, size * 0.24, -size * 0.42), WHITE, SMOOTH)
end

-- Bouche. "skin" : pièce qui porte la bouche (la lèvre en prend la couleur)
local function addMouth(ctx: Ctx, head: Head, v: number, size: number, kind: string, skin: BasePart?)
	local cf = onSurface(head, Vector3.new(0, v, -1), size * 0.12)
	if (kind == "Smile" or kind == "Wide") and skin then
		-- Sourire en « D » : ovale sombre dont le haut est caché par une lèvre couleur de
		-- peau (un ovale entier donne un air étonné), langue au fond
		local width = if kind == "Wide" then 1.3 else 0.82
		ellipsoid(ctx, "Mouth", Vector3.new(size * width, size * 0.44, size * 0.3), cf, MOUTH, SMOOTH)
		ellipsoid(
			ctx,
			"Mouth",
			Vector3.new(size * width * 0.56, size * 0.18, size * 0.2),
			cf * CFrame.new(0, -size * 0.14, -size * 0.08),
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
		local width = if kind == "Wide" then 1.2 elseif kind == "Fangs" then 0.95 else 0.6
		ellipsoid(ctx, "Mouth", Vector3.new(size * width, size * 0.4, size * 0.3), cf, MOUTH, SMOOTH)
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
					Vector3.new(size * 0.18, size * 0.3, size * 0.14),
					cf * CFrame.new(side * size * 0.24, size * 0.06, -size * 0.13),
					WHITE,
					SMOOTH
				)
			end
		end
	elseif kind == "O" then
		ellipsoid(ctx, "Mouth", Vector3.new(size * 0.34, size * 0.42, size * 0.3), cf, MOUTH, SMOOTH)
	elseif kind == "Flat" then
		ellipsoid(
			ctx,
			"Mouth",
			Vector3.new(size * 0.52, size * 0.14, size * 0.28),
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
		table.insert(eyeCenters, addEye(ctx, head, 0, e.V + 0.04, e.Size * 1.6))
	elseif kind == "Many" then
		-- Un grand œil au centre et deux petits en haut sur les côtés (plus bas, ils se
		-- lisaient comme des oreilles) : les mêmes yeux que les autres
		addEye(ctx, head, 0, e.V - 0.06, e.Size * 1.3)
		for _, side in { -1, 1 } do
			addEye(ctx, head, side * 0.66, e.V + 0.36, e.Size * 0.6, true)
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

	-- Sourcils froncés (au-dessus de chaque œil, inclinés vers le centre), bleu nuit ; de la
	-- couleur d'accent sur une peau sombre (golem de scories), où ils disparaîtraient
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
				if dark then ctx.P.Accent else INK,
				SMOOTH
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
			ball(ctx, "Spot", e.Size * 0.22, onSurfaceAt(head, point, 0), ctx.Freckles, NEON)
		end
	end

	-- Joues roses (opaques : pas de tri de transparence à chaque image)
	if ctx.Blush and not robot and #eyeCenters == 2 then
		for i, center in eyeCenters do
			local side = if i == 1 then -1 else 1
			local point = center + Vector3.new(side * e.Size * 0.48, -e.Size * 0.68, 0)
			ellipsoid(
				ctx,
				"Blush",
				Vector3.new(e.Size * 0.52, e.Size * 0.28, e.Size * 0.16),
				onSurfaceAt(head, point, e.Size * 0.05),
				BLUSH:Lerp(skinColor, 0.2),
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
		ellipsoid(
			ctx,
			"Foot",
			Vector3.new(width, width * 0.58, width * 1.25),
			CFrame.new(side * spacing, y, -0.28),
			ctx.P.Limb
		)
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
		Eye = { U = 0.38, V = 0.16, Size = 1.0 },
		Mouth = -0.22,
	}
end

function Archetypes.Spiky(ctx: Ctx): Shape
	local body: Head = { C = Vector3.zero, R = Vector3.new(1.62, 1.52, 1.56) }
	local main = ellipsoid(ctx, "Body", body.R * 2, CFrame.new(), ctx.P.Body)
	belly(ctx, body, Vector3.new(0, -1.0, -1), Vector3.new(1.75, 1.05, 0.85))
	-- Huit piques de la couleur d'accent sur le dos et le dessus (jamais sur le visage) :
	-- longues vers le haut, plus courtes sur les côtés et à l'arrière (la créature tient
	-- dans sa case de base)
	local spikes = {
		{ Vector3.new(0, 1, 0.15), 2.0 },
		{ Vector3.new(0.62, 0.78, 0.3), 1.8 },
		{ Vector3.new(-0.62, 0.78, 0.3), 1.8 },
		{ Vector3.new(0.4, 0.9, -0.4), 1.5 },
		{ Vector3.new(-0.4, 0.9, -0.4), 1.5 },
		{ Vector3.new(0, 0.6, 0.88), 1.5 },
		{ Vector3.new(0.9, 0.38, 0.5), 1.35 },
		{ Vector3.new(-0.9, 0.38, 0.5), 1.35 },
	}
	for _, spike in spikes do
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
				Vector3.new(0.8, 0.8, length),
				lookAt(p, p + dir) * CFrame.new(0, 0, -length * 0.2),
				ctx.P.Accent
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
		Eye = { U = 0.38, V = 0.12, Size = 0.98 },
		Mouth = -0.27,
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
		for i = 1, 3 do
			local x = -0.82 + (i - 1) * 0.82
			ball(ctx, "Body", 0.82, CFrame.new(x, -1.75, if i == 2 then -0.28 else -0.12), ctx.P.Body)
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
		Eye = { U = 0.37, V = 0.06, Size = 0.98 },
		Mouth = -0.34,
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
		-- Flocon derrière le corps, dans le plan du visage : trois barres qui se croisent au
		-- centre (six branches) et une pointe en losange au bout de chaque branche
		for i = 0, 2 do
			local a = i * math.pi / 3 + math.pi / 2
			local cf = CFrame.new(body.C + Vector3.new(0, 0, 0.35)) * CFrame.Angles(0, 0, a - math.pi / 2)
			accent(ctx, box(ctx, "Spike", Vector3.new(0.46, 4.8, 0.34), cf, ctx.P.Accent))
			for _, tip in { 1, -1 } do
				accent(
					ctx,
					box(
						ctx,
						"Spike",
						Vector3.new(0.6, 0.6, 0.34),
						cf * CFrame.new(0, tip * 2.35, 0) * CFrame.Angles(0, 0, math.rad(45)),
						ctx.P.Accent
					)
				)
			end
		end
	else
		-- Pointe de gemme sous le corps
		accent(ctx, box(ctx, "Spike", Vector3.one * 1.1, gemCFrame(Vector3.new(0, -0.9, 0)), ctx.P.Accent))
		-- Couronne de cristaux sur la tête (remplacée par la couronne dorée dès Légendaire :
		-- des cristaux repoussés derrière elle se lisaient comme une boîte qui dépasse)
		if not ctx.Crowned then
			for i, data in { { 0, 1.75, 0, 0.62 }, { -0.62, 1.25, 0.25, 0.48 }, { 0.62, 1.3, -0.1, 0.48 } } do
				local x, height, z, width = data[1], data[2], data[3], data[4]
				local top = body.C.Y + body.R.Y * (if i == 1 then 0.92 else 0.72)
				accent(
					ctx,
					box(
						ctx,
						"Spike",
						Vector3.new(width, height, width),
						CFrame.new(x, top + height * 0.3, z) * CFrame.Angles(0, math.rad(45), -x * 0.55),
						ctx.P.Accent
					)
				)
			end
		end
	end
	return {
		Hip = if traits.Snowflake then 2.9 else 2.75,
		Head = body,
		Body = body,
		HeadPart = main,
		Eye = { U = 0.4, V = 0.1, Size = 0.92 },
		Mouth = -0.31,
		-- Sommet des cristaux (la couronne se pose sur la tête)
		Top = if traits.Snowflake or ctx.Crowned then nil else body.C.Y + body.R.Y + 0.35,
		Floating = true,
	}
end

function Archetypes.Wisp(ctx: Ctx): Shape
	local traits = ctx.Traits
	local body: Head = { C = Vector3.zero, R = Vector3.new(1.45, 1.36, 1.4) }
	local main = ellipsoid(ctx, "Body", body.R * 2, CFrame.new(), ctx.P.Body)
	if not (traits.Tentacles or traits.Propellers or traits.Tail) then
		-- Queue de fantôme qui remonte derrière, bout de la couleur d'accent
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
				ctx.P.Accent
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
		Eye = { U = 0.4, V = 0.14, Size = 1.0 },
		Mouth = -0.25,
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
		ball(ctx, "Nose", 0.4, cf * CFrame.new(0, 0.2, -0.36), INK, SMOOTH)
		muzzle = { C = cf.Position, R = Vector3.new(0.65, 0.41, 0.4) }
	end
	-- Quatre pattes rondes d'une seule pièce
	for _, z in { -0.25, 1.25 } do
		for _, side in { -1, 1 } do
			ellipsoid(ctx, "Leg", Vector3.new(0.9, 1.3, 0.95), CFrame.new(side * 0.74, -1.18, z), ctx.P.Limb)
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
				ctx.P.Accent
			)
		)
	end
	return {
		Hip = 1.85,
		Head = head,
		Body = body,
		HeadPart = headPart,
		Skin = muzzlePart,
		Eye = { U = 0.42, V = 0.22, Size = 0.88 },
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
		local color = if i % 2 == 0 then ctx.P.Body:Lerp(ctx.P.Limb, 0.35) else ctx.P.Body
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
		Eye = { U = 0.42, V = 0.18, Size = 0.9 },
		Mouth = -0.31,
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
	-- Bras d'un bloc (épaule comprise) terminés par un gros poing, jambes courtes
	for _, side in { -1, 1 } do
		block("Arm", Vector3.new(1.0, 1.95, 1.15), Vector3.new(side * 1.84, 0.12, 0), ctx.P.Limb)
		block("Arm", Vector3.new(1.18, 0.98, 1.2), Vector3.new(side * 1.9, -1.28, -0.05), ctx.P.Body)
		block("Leg", Vector3.new(1.0, 1.0, 1.1), Vector3.new(side * 0.62, -1.62, 0), ctx.P.Limb)
	end
	return {
		Hip = 2.12,
		Head = head,
		HeadPart = headPart,
		Body = { C = Vector3.zero, R = Vector3.new(1.4, 1.15, 1.0), Box = true },
		Eye = { U = 0.42, V = 0.1, Size = 0.82 },
		Mouth = if marshmallow then -0.32 else -0.44,
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
	Lynx = { Size = Vector3.new(0.76, 1.2, 0.34), Dir = Vector3.new(0.56, 0.82, 0.02), Tilt = 0.25 },
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
	-- Intérieur rose (couleur d'accent pour les robots)
	local inner = if ctx.Style.Robot then ctx.P.Accent else INNER_EAR:Lerp(ctx.P.Body, 0.15)
	for _, side in { -1, 1 } do
		local p, n = surface(head, Vector3.new(side * spec.Dir.X, spec.Dir.Y, spec.Dir.Z))
		local up = (n + Vector3.new(side * spec.Tilt, 0.1, 0)).Unit
		local cf = upright(p + up * spec.Size.Y * 0.3, up)
		ellipsoid(ctx, "Ear", spec.Size, cf, ctx.P.Body)
		local innerPart = ellipsoid(
			ctx,
			"Ear",
			spec.Size * Vector3.new(0.56, 0.68, 0.6),
			cf * CFrame.new(0, -spec.Size.Y * 0.05, -spec.Size.Z * 0.3),
			inner,
			SMOOTH
		)
		if ctx.Style.Robot then
			accent(ctx, innerPart)
		end
	end
end

function Features.Horns(ctx: Ctx, shape: Shape, kind: string)
	local head = shape.Head
	if kind == "Unicorn" then
		-- Corne torsadée en sucre d'orge (anneaux accent / blanc)
		local p = surface(head, Vector3.new(0, 0.95, -0.55))
		local up = Vector3.new(0, 1, -0.42).Unit
		for i = 0, 2 do
			local width = 0.6 - i * 0.16
			local ring = ellipsoid(
				ctx,
				"Horn",
				Vector3.new(width, 0.7, width),
				upright(p + up * (0.14 + i * 0.5), up),
				if i % 2 == 0 then ctx.P.Accent else WHITE,
				SMOOTH
			)
			if i % 2 == 0 then
				accent(ctx, ring)
			end
		end
		return
	end
	for _, side in { -1, 1 } do
		if kind == "Imp" then
			local p, n = surface(head, Vector3.new(side * 0.5, 0.88, -0.05))
			local up = (n + Vector3.new(side * 0.3, 0.25, 0)).Unit
			ellipsoid(ctx, "Horn", Vector3.new(0.46, 1.05, 0.46), upright(p + up * 0.3, up), ctx.P.Limb)
		elseif kind == "Dragon" then
			-- Cornes de la couleur des membres, assombries (des cornes crème derrière une
			-- couronne se lisaient comme des oreilles de lapin) ; couchées sous une couronne
			local color = ctx.P.Limb:Lerp(INK, 0.25)
			local p, n = surface(head, Vector3.new(side * 0.55, 0.82, 0.25))
			local up = (n + Vector3.new(side * 0.15, 0.2, 0.55 + (if ctx.Crowned then 0.35 else 0))).Unit
			ellipsoid(ctx, "Horn", Vector3.new(0.5, 1.4, 0.5), upright(p + up * 0.45, up), color)
		elseif kind == "Ram" then
			local p = surface(head, Vector3.new(side, 0.55, 0.05))
			for i, data in { { 0, 0.35, 0, 0.74 }, { 0.3, -0.05, -0.34, 0.56 } } do
				ball(
					ctx,
					"Horn",
					data[4],
					CFrame.new(p + Vector3.new(side * data[1], data[2], data[3])),
					if i == 2 then ctx.P.Belly else HORN
				)
			end
		elseif kind == "Nub" then
			local p, n = surface(head, Vector3.new(side * 0.5, 0.86, 0.05))
			accent(ctx, ellipsoid(ctx, "Horn", Vector3.new(0.48, 0.6, 0.48), upright(p + n * 0.12, n), ctx.P.Accent))
		end
	end
end

function Features.Wings(ctx: Ctx, shape: Shape, kind: string)
	local body = shape.Body
	for _, side in { -1, 1 } do
		local p, n = surface(body, Vector3.new(side * 0.5, 0.42, 0.8))
		local base = p - n * 0.1
		if kind == "Bird" or kind == "Angel" then
			-- Trois plumes (oiseau : membres, corps, accent) ou deux plumes blanches (ange)
			local colors = if kind == "Angel" then { WHITE, WHITE } else { ctx.P.Limb, ctx.P.Body, ctx.P.Accent }
			for i, color in colors do
				local length = 1.9 - (i - 1) * (if kind == "Angel" then 0.45 else 0.32)
				local angle = math.rad(28 + (i - 1) * (if kind == "Angel" then 34 else 24))
				local dir = Vector3.new(side * math.cos(angle), math.sin(angle), 0.35).Unit
				local feather = ellipsoid(
					ctx,
					"Wing",
					Vector3.new(0.26, 0.74, length),
					lookAt(base, base + dir) * CFrame.new(0, 0, -length * 0.42),
					color,
					SMOOTH
				)
				if kind == "Bird" and i == 3 then
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
			-- Ailes de fée : couleur d'accent légèrement translucide (plastique, pas de néon)
			for i = 1, 2 do
				local length = if i == 1 then 1.7 else 1.15
				local angle = math.rad(if i == 1 then 38 else -8)
				local dir = Vector3.new(side * math.cos(angle), math.sin(angle), 0.4).Unit
				local wing = ellipsoid(
					ctx,
					"Wing",
					Vector3.new(0.1, 1.0, length),
					lookAt(base, base + dir) * CFrame.new(0, 0, -length * 0.42),
					ctx.P.Accent:Lerp(WHITE, 0.25),
					SMOOTH
				)
				wing.Transparency = 0.25
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
		ellipsoid(ctx, "Tail", Vector3.new(0.24, 0.24, 1.6), lookAt(p, p + dir) * CFrame.new(0, 0, -0.7), ctx.P.Limb)
		local tip = p + dir * 1.5
		accent(
			ctx,
			box(
				ctx,
				"Tail",
				Vector3.new(0.52, 0.52, 0.18),
				CFrame.new(tip) * CFrame.Angles(0, 0, math.rad(45)),
				ctx.P.Accent
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
				if bushy then ctx.P.Belly else ctx.P.Accent
			)
		)
	elseif kind == "Feathers" or kind == "Flame" then
		-- Flamme : langue rouge-orange et pointe jaune ; plumes : membres / accent / membres
		local flame = kind == "Flame"
		local data = if flame
			then { { 0, 0.8, 1.5, FLAME }, { 0, 0.55, 0.9, FLAME_CORE } }
			else {
				{ 0, 0.85, 1.55, ctx.P.Accent },
				{ 0.42, 0.5, 1.25, ctx.P.Limb },
				{ -0.42, 0.5, 1.25, ctx.P.Limb },
			}
		for i, spec in data do
			local dir = Vector3.new(spec[1], spec[2], 1).Unit
			local length = spec[3]
			local width = if flame then (if i == 1 then 0.78 else 0.5) else 0.34
			local part = ellipsoid(
				ctx,
				"Tail",
				Vector3.new(width, if flame then width else 0.75, length),
				lookAt(p, p + dir) * CFrame.new(0, if flame and i == 2 then 0.06 else 0, -length * 0.4),
				spec[4],
				if spec[4] == FLAME_CORE then NEON else SMOOTH
			)
			if spec[4] == ctx.P.Accent or spec[4] == FLAME then
				accent(ctx, part)
			end
		end
	end
end

-- Bec (pingouin, phénix)
function Features.Beak(ctx: Ctx, shape: Shape)
	local cf = onSurface(shape.Head, Vector3.new(0, shape.Eye.V - 0.38, -1), 0.12)
	ellipsoid(ctx, "Beak", Vector3.new(0.78, 0.46, 0.95), cf * CFrame.new(0, 0, -0.18), BEAK, SMOOTH)
	ellipsoid(ctx, "Beak", Vector3.new(0.6, 0.3, 0.7), cf * CFrame.new(0, -0.22, -0.08), BEAK:Lerp(INK, 0.12), SMOOTH)
end

-- Trompe et défenses (mammouth)
function Features.Trunk(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local p, n = surface(head, Vector3.new(0, -0.32, -1))
	local start = p + n * 0.1
	ellipsoid(ctx, "Trunk", Vector3.new(0.8, 1.5, 0.8), CFrame.new(start + Vector3.new(0, -0.45, -0.04)), ctx.P.Body)
	ellipsoid(
		ctx,
		"Trunk",
		Vector3.new(0.56, 0.56, 0.78),
		CFrame.new(start + Vector3.new(0, -1.12, -0.2)) * CFrame.Angles(math.rad(25), 0, 0),
		ctx.P.Body
	)
	-- Défenses courtes qui pointent vers l'avant
	for _, side in { -1, 1 } do
		local q = surface(head, Vector3.new(side * 0.55, -0.55, -1))
		local dir = Vector3.new(side * 0.3, 0.25, -1).Unit
		ellipsoid(ctx, "Tusk", Vector3.new(0.34, 0.34, 1.05), lookAt(q, q + dir) * CFrame.new(0, 0, -0.36), HORN)
	end
end

-- Tentacules (méduse) sous le corps : une jupe claire et six tentacules d'une pièce
function Features.Tentacles(ctx: Ctx, shape: Shape)
	local body = shape.Body
	ellipsoid(ctx, "Belly", Vector3.new(3.0, 0.75, 2.9), CFrame.new(body.C + Vector3.new(0, -0.62, 0)), ctx.P.Belly)
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + 0.3
		local x, z = math.cos(a) * 0.9, math.sin(a) * 0.85
		local tentacle = ellipsoid(
			ctx,
			"Tentacle",
			Vector3.new(0.42, 1.7, 0.42),
			CFrame.new(x * 1.06, body.C.Y - 1.45, z * 1.06) * CFrame.Angles(-math.sin(a) * 0.22, 0, math.cos(a) * 0.22),
			if i % 2 == 0 then ctx.P.Accent else ctx.P.Limb
		)
		if i % 2 == 0 then
			accent(ctx, tentacle)
		end
	end
end

-- Hélices (drone) : quatre bras et quatre disques d'hélice de la couleur d'accent
function Features.Propellers(ctx: Ctx, shape: Shape)
	local body = shape.Body
	for i = 1, 4 do
		local a = (i - 0.5) * math.pi / 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = body.C + dir * 2.1 + Vector3.new(0, 0.55, 0)
		box(
			ctx,
			"Arm",
			Vector3.new(0.28, 0.22, 1.5),
			CFrame.new(body.C + dir * 1.45 + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			STEEL
		)
		local rotor = cylinder(ctx, "Rotor", 0.08, 1.5, CFrame.new(tip + Vector3.new(0, 0.12, 0)), ctx.P.Accent)
		rotor.Transparency = 0.3
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
			ctx.P.Accent
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
				ctx.P.Accent
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
					Vector3.new(0.3, 0.34, 1.05),
					lookAt(p, p + dir) * CFrame.new(0, 0, -0.4),
					ctx.P.Accent
				)
			)
		end
	end
end

-- Taches de la couleur d'accent sur le dos (crapaud)
function Features.Spots(ctx: Ctx, shape: Shape)
	local target = shape.Body
	for i, dir in
		{
			Vector3.new(0.5, 0.72, 0.5),
			Vector3.new(-0.55, 0.62, 0.62),
			Vector3.new(0.1, 0.88, 0.3),
		}
	do
		local size = if i == 3 then 0.62 else 0.5
		accent(
			ctx,
			ellipsoid(ctx, "Spot", Vector3.new(size, size * 0.8, 0.2), onSurface(target, dir, 0.04), ctx.P.Accent)
		)
	end
end

-- Fissures de lave lumineuses (golem de scories) : leur néon EST la créature
function Features.Cracks(ctx: Ctx, shape: Shape)
	local body = shape.Body
	-- Autour de la plaque de ventre (coins hauts et flancs)
	for _, data in
		{
			{ -0.95, 0.82, 0.7, 0.75 },
			{ 1.0, 0.8, -0.6, 0.7 },
			{ 1.18, -0.45, 0.35, 0.8 },
		}
	do
		local cf = CFrame.new(body.C + Vector3.new(data[1], data[2], -body.R.Z - 0.03)) * CFrame.Angles(0, 0, data[3])
		accent(ctx, box(ctx, "Crack", Vector3.new(0.18, data[4], 0.12), cf, ctx.P.Accent, NEON))
	end
end

-- Cœur d'énergie lumineux dans la poitrine (titans)
function Features.Core(ctx: Ctx, shape: Shape)
	local cf = onSurface(shape.Body, Vector3.new(0, 0, -1), 0.1)
	ellipsoid(ctx, "Core", Vector3.new(1.2, 1.2, 0.5), cf, SCREEN, SMOOTH)
	accent(ctx, ball(ctx, "Core", 0.8, cf * CFrame.new(0, 0, -0.12), ctx.P.Accent, NEON))
end

-- Crête de plumes (phénix)
function Features.Crest(ctx: Ctx, shape: Shape)
	local head = shape.Head
	local p = surface(head, Vector3.new(0, 1, 0.1))
	for i, data in { { 0, 1.35, 0.15 }, { -0.25, 1.0, 0.55 }, { 0.25, 1.0, 0.55 } } do
		local dir = Vector3.new(data[1], 1, data[3]).Unit
		local length = data[2]
		local part = ellipsoid(
			ctx,
			"Crest",
			Vector3.new(0.36, 0.5, length),
			lookAt(p, p + dir) * CFrame.new(0, 0, -length * 0.38),
			if i == 1 then ctx.P.Accent else FLAME
		)
		if i == 1 then
			accent(ctx, part)
		end
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
					ctx.P.Accent
				)
			)
		end
	end
end

-- Écharpe de la couleur d'accent (pingouin)
function Features.Scarf(ctx: Ctx, shape: Shape)
	local body = shape.Body
	local y = -0.42
	local k = math.sqrt(1 - (y / body.R.Y) ^ 2)
	accent(
		ctx,
		ellipsoid(
			ctx,
			"Scarf",
			Vector3.new(body.R.X * 2 * k + 0.2, 0.46, body.R.Z * 2 * k + 0.2),
			CFrame.new(0, y, 0),
			ctx.P.Accent
		)
	)
	local p = surface(body, Vector3.new(0.45, y - 0.25, -1))
	accent(
		ctx,
		box(
			ctx,
			"Scarf",
			Vector3.new(0.48, 0.95, 0.22),
			CFrame.new(p + Vector3.new(0, -0.3, -0.12)) * CFrame.Angles(0.2, 0, 0.12),
			ctx.P.Accent
		)
	)
end

-- Cape dans le dos (couleur donnée, ou la couleur d'accent) et col d'hermine
function Features.Cape(ctx: Ctx, shape: Shape, color: Color3?)
	local body = shape.Body
	local cf = CFrame.new(body.C + Vector3.new(0, 0.1, body.R.Z + 0.08)) * CFrame.Angles(math.rad(-8), 0, 0)
	local cape = ellipsoid(ctx, "Cape", Vector3.new(body.R.X * 2.3, body.R.Y * 2.5, 0.3), cf, color or ctx.P.Accent)
	if not color then
		accent(ctx, cape)
	end
	if shape.Head ~= shape.Body then
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
-- liseré de la couleur d'accent
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
	-- Liseré de la couleur d'accent (plastique) : disque juste derrière l'avant du visage,
	-- plus haut que lui ; la tête en cache le centre et le bas, il ne reste qu'un arc
	-- autour du front et des tempes
	local depth = 0.7
	local k = math.sqrt(1 - depth * depth) -- section de la tête à cette profondeur
	accent(
		ctx,
		ellipsoid(
			ctx,
			"Hood",
			Vector3.new(head.R.X * k * 2 + 0.3, head.R.Y * k * 2 + 0.16, 0.24),
			CFrame.new(head.C + Vector3.new(0, 0.24, -head.R.Z * depth)),
			ctx.P.Accent
		)
	)
	shape.Top = center.Y + size.Y * 0.5 - 0.1
end

-- Casque de chevalier de glace + plumet de la couleur d'accent
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
			ctx.P.Accent
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
		-- Disque de sucre d'orge face à la caméra : anneaux concentriques accent / blanc
		local center = top + up * 0.75
		for i, data in { { 1.7, ctx.P.Accent }, { 1.15, WHITE }, { 0.6, ctx.P.Accent } } do
			local ring = newPart(
				ctx,
				"Staff",
				Vector3.new(0.32 + i * 0.02, data[1], data[1]),
				CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
				data[2],
				SMOOTH
			)
			ring.Shape = Enum.PartType.Cylinder
			if data[2] == ctx.P.Accent then
				accent(ctx, ring)
			end
		end
	elseif kind == "Spear" then
		accent(ctx, ellipsoid(ctx, "Staff", Vector3.new(0.5, 1.3, 0.5), upright(top + up * 0.45, up), ctx.P.Accent))
	elseif kind == "Wand" then
		-- Flocon de givre face à la caméra : une perle et trois branches croisées (six pointes)
		local center = top + up * 0.4
		accent(ctx, ball(ctx, "Staff", 0.62, CFrame.new(center), ctx.P.Accent))
		for i = 0, 2 do
			accent(
				ctx,
				box(
					ctx,
					"Staff",
					Vector3.new(0.2, 1.5, 0.2),
					CFrame.new(center) * CFrame.Angles(0, 0, i * math.pi / 3),
					ctx.P.Accent
				)
			)
		end
	else
		ball(ctx, "Staff", 0.75, CFrame.new(top + up * 0.3), GOLD, SMOOTH)
		accent(ctx, ball(ctx, "Staff", 0.42, CFrame.new(top + up * 0.3 + Vector3.new(0, 0, -0.3)), ctx.P.Accent))
	end
end

-- Touffes de fourrure (yéti, mammouth) : deux épaules et le haut de la tête
function Features.Fur(ctx: Ctx, shape: Shape)
	local target = shape.Body
	local fur = if ctx.P.Body.R + ctx.P.Body.G + ctx.P.Body.B > 2.6 then ctx.P.Limb else ctx.P.Belly
	for _, dir in { Vector3.new(0.72, 0.62, 0.1), Vector3.new(-0.72, 0.62, 0.1) } do
		local p = surface(target, dir)
		ball(ctx, "Fur", 0.95, CFrame.new(p), fur)
	end
	local top = surface(shape.Head, Vector3.new(0.1, 1, 0.15))
	ball(ctx, "Fur", 0.9, CFrame.new(top), fur)
end

-- Nuages de barbe à papa sur le dos (blanc, accent, blanc)
function Features.Clouds(ctx: Ctx, _shape: Shape)
	for i, seg in SERPENT_SEGMENTS do
		if i <= 3 then
			local cloud = ball(
				ctx,
				"Cloud",
				1.3 - i * 0.12,
				CFrame.new(seg[1] + Vector3.new(0, seg[2].Y * 0.85, 0.05)),
				if i == 2 then ctx.P.Accent else WHITE
			)
			if i == 2 then
				accent(ctx, cloud)
			end
		end
	end
end

-- Anneau planétaire (IA, singularité) : un disque fin de la couleur d'accent
function Features.Ring(ctx: Ctx, shape: Shape)
	local body = shape.Body
	accent(
		ctx,
		cylinder(
			ctx,
			"Ring",
			0.14,
			math.max(body.R.X, body.R.Z) * 2.5,
			CFrame.new(body.C) * CFrame.Angles(math.rad(-24), 0, math.rad(-20)),
			ctx.P.Accent
		)
	)
end

-- Cristaux de glace en orbite (Zéro Absolu)
function Features.OrbitCrystals(ctx: Ctx, shape: Shape)
	local body = shape.Body
	local radius = orbitRadius(ctx, 2.3, 0.56)
	for i = 1, 3 do
		local a = i * math.pi * 2 / 3 + 0.4
		local part = box(
			ctx,
			"Orbit",
			Vector3.new(0.44, 1.0, 0.44),
			CFrame.new(math.cos(a) * radius, orbitHeight(body, i, 0.3), math.sin(a) * radius) * CFrame.Angles(0, a, 0.5),
			ctx.P.Accent
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
		local shard = box(
			ctx,
			"Spike",
			Vector3.new(0.48, data[4], 0.48),
			upright(p + dir * data[4] * 0.25, dir) * CFrame.Angles(0, math.rad(45), 0),
			if i == 1 then ctx.P.Accent else WHITE
		)
		if i == 1 then
			accent(ctx, shard)
		end
	end
end

-- Crinière de bonbons (licorne) : trois boules de la couleur d'accent
function Features.Mane(ctx: Ctx, shape: Shape)
	local head = shape.Head
	for i = 1, 3 do
		local p = surface(head, Vector3.new(if i % 2 == 0 then 0.25 else -0.25, 1, -0.3 + i * 0.45))
		accent(
			ctx,
			ball(
				ctx,
				"Mane",
				1.0 - i * 0.1,
				CFrame.new(p + Vector3.new(0, 0.1, 0.12 * i)),
				ctx.P.Accent:Lerp(WHITE, (i - 1) * 0.12)
			)
		)
	end
end

-- Deux têtes supplémentaires sur de longs cous (hydre) : yeux simples, sans bouche
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
		ellipsoid(ctx, "Body", small.R * 2, CFrame.new(small.C), ctx.P.Body)
		for _, eyeSide in { -1, 1 } do
			addEye(ctx, small, eyeSide * 0.4, 0.1, 0.6, true)
		end
	end
end

---------------------------------------------------------------------------
-- Accessoires de dimension (sur la tête) et couronnes (rareté)
---------------------------------------------------------------------------
local Toppers = {}

-- Flamme de dessin animé (silhouette 🔥) : socle arrondi orange, grande langue centrale
-- jaune penchée vers l'arrière, deux petites langues orange penchées vers l'extérieur ;
-- cœur jaune pâle lumineux devant (le seul néon de la flamme)
local function flame(ctx: Ctx, base: Vector3, scale: number)
	local function lick(size: Vector3, offset: Vector3, roll: number, pitch: number, color: Color3, material): Part
		return ellipsoid(
			ctx,
			"Flame",
			size * scale,
			CFrame.new(base + offset * scale) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll)),
			color,
			material
		)
	end
	accent(ctx, lick(Vector3.new(1.25, 0.95, 1.15), Vector3.new(0, 0.35, 0.05), 0, 0, FLAME, SMOOTH))
	accent(ctx, lick(Vector3.new(0.7, 1.75, 0.66), Vector3.new(0, 1.05, 0.15), 0, 14, FLAME_TIP, SMOOTH))
	for _, side in { -1, 1 } do
		accent(
			ctx,
			lick(Vector3.new(0.46, 1.05, 0.46), Vector3.new(side * 0.42, 0.72, 0.1), -side * 28, 8, FLAME, SMOOTH)
		)
	end
	lick(Vector3.new(0.6, 0.85, 0.46), Vector3.new(0, 0.55, -0.38), 0, 8, FLAME_CORE, NEON)
end

function Toppers.Flame(ctx: Ctx, shape: Shape)
	flame(ctx, headTop(shape) - Vector3.new(0, 0.2, 0), 1)
end

function Toppers.BigFlame(ctx: Ctx, shape: Shape)
	flame(ctx, headTop(shape) - Vector3.new(0, 0.45, -0.1), 1.4)
end

function Toppers.Crest(ctx: Ctx, shape: Shape)
	Features.Crest(ctx, shape)
end

-- Néant : deux antennes terminées par une perle de la couleur d'accent
function Toppers.Antennae(ctx: Ctx, shape: Shape)
	local head = shape.Head
	for _, side in { -1, 1 } do
		local p, n = surface(head, Vector3.new(side * 0.35, 1, 0.05))
		local up = (n + Vector3.new(side * 0.35, 0.2, 0)).Unit
		cylinder(ctx, "Antenna", 1.0, 0.16, upright(p + up * 0.45, up), ctx.P.Limb)
		accent(ctx, ball(ctx, "Antenna", 0.56, CFrame.new(p + up * 1.0), ctx.P.Accent))
	end
end

-- Glace : bonnet de neige + un cristal
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
	accent(
		ctx,
		box(
			ctx,
			"Spike",
			Vector3.new(0.46, 1.05, 0.46),
			CFrame.new(top + Vector3.new(-0.3, 0.44, 0.1)) * CFrame.Angles(0, math.rad(45), -0.3),
			ctx.P.Accent
		)
	)
end

-- Bonbon : chantilly + cerise
function Toppers.Cream(ctx: Ctx, shape: Shape)
	local top = headTop(shape) - Vector3.new(0, 0.12, 0)
	ellipsoid(ctx, "Cream", Vector3.new(1.45, 0.66, 1.4), CFrame.new(top), WHITE)
	ellipsoid(ctx, "Cream", Vector3.new(0.92, 0.62, 0.9), CFrame.new(top + Vector3.new(0, 0.42, 0)), WHITE)
	ball(ctx, "Cherry", 0.62, CFrame.new(top + Vector3.new(0.05, 0.92, -0.05)), rgb(236, 30, 64), SMOOTH)
end

-- Cyber : antenne + perle de la couleur d'accent
function Toppers.Antenna(ctx: Ctx, shape: Shape)
	local top = headTop(shape)
	cylinder(ctx, "Antenna", 1.1, 0.16, CFrame.new(top + Vector3.new(0, 0.45, 0.05)), STEEL)
	accent(ctx, ball(ctx, "Antenna", 0.52, CFrame.new(top + Vector3.new(0, 1.05, 0.05)), ctx.P.Accent))
end

-- Couronne dorée (Légendaire et plus) : bandeau et cinq pointes d'or, une seule gemme
-- frontale dès Mythique (couleur de la rareté, arc-en-ciel pour Secret)
local function addCrown(ctx: Ctx, shape: Shape, rarity)
	local head = shape.Head
	local radius = math.min(head.R.X, head.R.Z, 1.3) * 0.68
	local base = CFrame.new(headTop(shape) + Vector3.new(0, -0.2, 0.05)) * CFrame.Angles(0, 0, math.rad(-8))
	cylinder(ctx, "Crown", 0.55, radius * 2, base * CFrame.new(0, 0.22, 0), GOLD, SMOOTH)
	for i = 1, 5 do
		local a = (i - 1) / 5 * math.pi * 2
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local position = dir * radius * 0.84 + Vector3.new(0, 0.52, 0)
		-- Carré posé sur la pointe : le bas est caché dans le bandeau, reste un triangle
		box(
			ctx,
			"Crown",
			Vector3.new(0.62, 0.62, 0.22),
			base * CFrame.new(position) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(45)),
			if i == 1 then GOLD else GOLD:Lerp(GOLD_DARK, 0.35),
			SMOOTH
		)
	end
	if rarity.Tier >= 5 then
		local gem = box(
			ctx,
			"Crown",
			Vector3.new(0.36, 0.36, 0.16),
			base * CFrame.new(0, 0.24, -radius - 0.03) * CFrame.Angles(0, 0, math.rad(45)),
			rarity.Color,
			NEON
		)
		if rarity.Rainbow then
			-- Départ sur le bleu : une gemme jaune disparaîtrait sur l'or
			rainbow(gem, 0.58, 0.8)
		end
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
	-- sol clair des bases et sur les socles
	emitter.LightEmission = 0.3
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(0.6, 1.4)
	emitter.SpreadAngle = Vector2.new(75, 75)
	emitter.Acceleration = Vector3.new(0, 0.8, 0)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
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

-- Anneau de rareté au sol : anneau néon fin de la couleur de la rareté, intérieur blanc
-- comme le dessus des socles (sur un socle, on ne voit qu'un liseré lumineux), jamais plus
-- large que le socle d'une base. Secret : anneau de douze arcs arc-en-ciel (teinte animée
-- par CreatureAnimator ; toutes les couleurs restent visibles sur une capture)
local function addRarityDisc(ctx: Ctx, rarity, hip: number, footprint: number)
	local radius = math.min(footprint, SLOT_RADIUS / ctx.Scale)
	local width = RING_WIDTH / ctx.Scale
	local y = -hip + 0.07
	if rarity.Rainbow then
		local count = 12
		-- Les coins extérieurs des arcs droits dépassent un peu le cercle : rayon réduit
		local mid = (radius - width / 2) * 0.97
		local length = mid * 2 * math.pi / count * 1.04
		for i = 1, count do
			local a = i / count * math.pi * 2
			local segment = box(
				ctx,
				"RarityDisc",
				Vector3.new(length, 0.12, width),
				CFrame.new(math.cos(a) * mid, y, math.sin(a) * mid) * CFrame.Angles(0, -a - math.pi / 2, 0),
				WHITE,
				NEON
			)
			rainbow(segment, i / count, 0.75)
		end
		return
	end
	cylinder(ctx, "RarityDisc", 0.12, radius * 2, CFrame.new(0, y, 0), rarity.Color, NEON)
	cylinder(
		ctx,
		"RarityDisc",
		0.13,
		radius * 2 - width * 2,
		CFrame.new(0, y + 0.012, 0),
		PEDESTAL_TOP,
		Enum.Material.Plastic
	)
end

local function applyRarity(ctx: Ctx, rarity, shape: Shape, footprint: number)
	if rarity.Tier >= 2 then
		addRarityDisc(ctx, rarity, shape.Hip, footprint)
	end
	if rarity.Tier >= 5 then
		-- Quelques étincelles discrètes (Mythique : couleur de la rareté, Secret : arc-en-ciel)
		local colors = if rarity.Rainbow
			then sequence(Rarities.RainbowColors)
			else ColorSequence.new(rarity.Color, rarity.Color:Lerp(WHITE, 0.6))
		addParticles(ctx.Root, "Sparkles", colors, if rarity.Rainbow then 6 else 3, 0.5 * ctx.Scale, 1.7 * ctx.Scale)
	end
	if rarity.Rainbow then
		-- Aura Secrète : six petites étincelles arc-en-ciel en orbite autour du ventre (sous
		-- le visage, dans la case du socle) et une lumière douce
		local body = shape.Body
		local radius = orbitRadius(ctx, math.max(body.R.X, body.R.Z) + 0.9, 0.17)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local orb = ball(
				ctx,
				"Orbit",
				0.3,
				CFrame.new(math.cos(a) * radius, orbitHeight(body, i, 0.22), math.sin(a) * radius),
				WHITE,
				NEON
			)
			rainbow(orb, i / 6, 0.75)
		end
		addLight(ctx.Root, WHITE, 1, 10 * ctx.Scale)
	end
end

local MutationEffects = {}

-- Éclair ⚡ en trois barres (diagonale, petite marche, diagonale) dans le plan XY de
-- "frame" (face à la caméra), hauteur ~2 x "size"
local function bolt(ctx: Ctx, frame: CFrame, size: number, color: Color3)
	local thick = 0.32 * size
	local points = {
		Vector3.new(0.32, 1.0, 0),
		Vector3.new(-0.2, 0.06, 0),
		Vector3.new(0.24, 0.06, 0),
		Vector3.new(-0.3, -1.0, 0),
	}
	for i = 1, 3 do
		local a, b = points[i] * size, points[i + 1] * size
		local d = b - a
		local part = box(
			ctx,
			"Spark",
			Vector3.new(d.Magnitude + thick * 0.7, thick, thick * 0.8),
			frame * CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)),
			color,
			SMOOTH
		)
		accent(ctx, part)
	end
end

-- Instable : deux éclairs jaunes qui jaillissent des côtés de la tête (couleurs de la
-- créature conservées) ; les étincelles de particules font le reste
function MutationEffects.Shards(ctx: Ctx, shape: Shape, mutation)
	local head = shape.Head
	for _, side in { -1, 1 } do
		local p, n = surface(head, Vector3.new(side * 0.8, 0.7, 0.15))
		local center = p + (n + Vector3.new(0, 0.7, 0)).Unit * 0.95
		bolt(ctx, CFrame.new(center) * CFrame.Angles(0, 0, -side * 0.38), 1.05, mutation.Accent)
	end
end

-- Prismatique : tout se passe dans paintRainbowBody (corps arc-en-ciel animé) et dans
-- les étincelles arc-en-ciel ; pas de pièces en plus (des gemmes en orbite faisaient
-- confettis)
function MutationEffects.Prism(_ctx: Ctx, _shape: Shape, _mutation) end

-- Abyssal : bioluminescence des grands fonds. Corps bleu nuit (makePalette), taches
-- lumineuses cyan sur les joues (addFace) et les flancs, leurre de baudroie au-dessus du
-- front (sauf sous une couronne). Le néon fait ici l'effet : peu de pièces
function MutationEffects.Abyss(ctx: Ctx, shape: Shape, mutation)
	local body = shape.Body
	for _, dir in { Vector3.new(0.85, 0.3, -0.35), Vector3.new(-0.85, 0.3, -0.35) } do
		accent(
			ctx,
			ellipsoid(ctx, "Spot", Vector3.new(0.4, 0.4, 0.14), onSurface(body, dir, 0.03), mutation.Accent, NEON)
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
				Vector3.new(0.16, 0.16, length + 0.12),
				lookAt(span[1], span[2]) * CFrame.new(0, 0, -length / 2),
				ctx.P.Limb
			)
		end
		accent(ctx, ball(ctx, "Lure", 0.52, CFrame.new(tip + Vector3.new(0, -0.14, 0)), mutation.Accent, NEON))
	end
end

-- Céleste : statue d'or (makePalette), auréole lumineuse au-dessus de la couronne ou de
-- l'accessoire, ailes d'ange blanches
function MutationEffects.Halo(ctx: Ctx, shape: Shape, mutation)
	local head = shape.Head
	local top = headTop(shape)
	local y = math.max(top.Y + (if ctx.Crowned then 1.2 else 0.65), (shape.HatTop or -math.huge) + 0.35)
	local center = Vector3.new(top.X, y, top.Z + 0.1)
	local radius = math.min(head.R.X, head.R.Z) * 0.6
	local count = 8
	for i = 1, count do
		local a = i / count * math.pi * 2
		box(
			ctx,
			"Halo",
			Vector3.new(radius * 2 * math.pi / count * 1.1, 0.18, 0.22),
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
	addParticles(ctx.Root, "Aura", colors, 2 + mutation.Multiplier, 0.4 * ctx.Scale, 1.7 * ctx.Scale)
	-- Une seule lumière par créature : celle de la rareté (Secret) prend la couleur de la mutation
	local light = ctx.Root:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = mutation.Color
		light.Brightness = math.max(light.Brightness, mutation.LightBrightness)
	else
		addLight(ctx.Root, mutation.Color, mutation.LightBrightness, 8 * ctx.Scale)
	end
end

---------------------------------------------------------------------------
-- Étiquette d'informations (texte seul, docs/ART_DIRECTION.md section 4)
---------------------------------------------------------------------------
-- Étiquette au-dessus de la créature, de haut en bas :
--   Mutation xN   (si mutée)            Fredoka One, dégradé de la mutation
--   Nom                                 Fredoka One, blanc
--   RARETÉ                              Luckiest Guy, dégradé de la rareté (arc-en-ciel pour Secret)
--   $X/s                                Luckiest Guy (« /s » en Fredoka One), or
--   $Prix  (seulement sur le tapis)     Luckiest Guy, vert
-- Contours encre bleu nuit (jamais noirs). Taille mixte : une part en studs (l'étiquette
-- rétrécit avec la distance comme un objet du monde) + un plancher en pixels (LABEL_FLOOR
-- par stud : le texte reste lisible de loin et sur téléphone). TextScaled remplit chaque
-- ligne, UITextSizeConstraint évite les lettres géantes de près.
--
-- Luckiest Guy n'a que des capitales, collées en haut de la ligne (le bas reste vide), et
-- ses accents (É) dépassent de 0,27 em au-dessus. Chaque ligne Luckiest Guy réserve donc
-- LG_TOP de sa hauteur en haut (UIPadding) : les accents y tiennent et les capitales sont
-- centrées dans leur ligne comme les lettres de Fredoka One. Avec LINE_GAP pixels entre
-- les lignes, l'espacement est régulier et ni les lettres ni les contours ne se touchent.
local LABEL_WIDTH = 9 -- studs
-- Pixels ajoutés par stud (plancher de taille) : plus généreux sur le tapis (on repère les
-- bonnes affaires de loin), discret dans les bases (rangées serrées)
local LABEL_FLOOR = { Carpet = 12, Base = 7 }
-- Distance d'affichage : le tapis se surveille depuis sa base ; dans une base, un voleur
-- lit les rangées du fond depuis le trottoir (de loin, CreatureAnimator ne garde que la
-- rareté et le revenu : pas de mur de texte)
local LABEL_MAX_DISTANCE = { Carpet = 90, Base = 80 }
local LG_TOP = 0.23
-- Taille des lettres de chaque ligne (unités de hauteur d'étiquette)
local GLYPH = { Mutation = 0.72, Name = 0.8, Rarity = 0.72, Income = 0.7, Price = 0.86 }
-- Taille de police maximale (pixels) : plus petite dans les bases, où les étiquettes
-- s'empilent
local MAX_TEXT_SIZE = {
	Carpet = { Mutation = 44, Name = 52, Rarity = 46, Income = 44, Price = 54 },
	Base = { Mutation = 30, Name = 34, Rarity = 30, Income = 29, Price = 34 },
}
local LINE_GAP = 3 -- pixels entre deux lignes
local STROKE = { Carpet = 2.5, Base = 2 } -- contour encre (pixels)
local INCOME_COLOR = rgb(255, 201, 60) -- jeton « Récompense » (revenus/s)
local PRICE_COLOR = rgb(47, 203, 85) -- jeton « Action / argent »
local LUCKIEST = Enum.Font.LuckiestGuy
local FREDOKA = Enum.Font.FredokaOne

-- Dégradé vertical posé sur les lettres d'une ligne : clair en haut, couleur franche au
-- milieu, un peu plus soutenu en bas. "band" : part de la ligne occupée par les lettres
-- (Luckiest Guy : sous la marge LG_TOP)
local function verticalGradient(color: Color3, top: number): ColorSequence
	local span = 1 - top
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.35)),
		ColorSequenceKeypoint.new(top + span * 0.12, color:Lerp(WHITE, 0.3)),
		ColorSequenceKeypoint.new(top + span * 0.45, color),
		ColorSequenceKeypoint.new(top + span * 0.8, color:Lerp(INK, 0.12)),
		ColorSequenceKeypoint.new(1, color:Lerp(INK, 0.12)),
	})
end

-- Largeur approchée d'un texte (em) : capitales et chiffres de Luckiest Guy ~0,59 em,
-- lettres de Fredoka One ~0,55 em, espace 0,22 (les octets de continuation UTF-8 ne
-- comptent pas : É = un caractère)
local function textWidth(text: string, font: Enum.Font): number
	local chars = #(string.gsub(text, "[\128-\191]", ""))
	local _, spaces = string.gsub(text, " ", "")
	local em = if font == LUCKIEST then 0.59 else 0.55
	return (chars - spaces) * em + spaces * 0.22
end

-- Dégradé horizontal (arc-en-ciel) resserré sur le texte. Un UIGradient s'étale sur toute
-- la largeur de l'étiquette (9 studs) : sur un mot court comme SECRET, seules les couleurs
-- du milieu toucheraient les lettres. La taille du texte suit la hauteur de sa ligne, donc
-- la part de largeur qu'il occupe est à peu près constante.
local function spanGradient(colors: { Color3 }, text: string, font: Enum.Font, glyph: number): ColorSequence
	local span = math.clamp(textWidth(text, font) * glyph / LABEL_WIDTH, 0.15, 1)
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
	Color: Color3?, -- couleur unie (sans dégradé)
	Gradient: ColorSequence?,
	Horizontal: boolean?, -- dégradé de gauche à droite (arc-en-ciel)
	Rich: boolean?, -- texte riche (« /s » du revenu)
}

-- Hauteur d'une ligne (unités) : les lignes Luckiest Guy réservent LG_TOP en haut
local function lineHeight(info: LabelLine): number
	return if info.Font == LUCKIEST then GLYPH[info.Name] / (1 - LG_TOP) else GLYPH[info.Name]
end

local function addLine(
	gui: BillboardGui,
	info: LabelLine,
	order: number,
	share: number,
	gaps: number,
	maxSize: number,
	stroke: number
)
	local label = Instance.new("TextLabel")
	label.Name = info.Name
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	-- Sa part de la hauteur de l'étiquette, moins sa part des espaces entre lignes
	label.Size = UDim2.new(1, 0, share, -math.round(gaps * share))
	label.Font = info.Font
	label.RichText = info.Rich == true
	label.Text = info.Text
	label.TextColor3 = info.Color or WHITE -- un dégradé teinte le blanc
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
	local outline = Instance.new("UIStroke")
	outline.Color = INK
	outline.Thickness = stroke
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = label
	if info.Gradient then
		local tint = Instance.new("UIGradient")
		tint.Color = info.Gradient
		tint.Rotation = if info.Horizontal then 0 else 90
		tint.Parent = label
	end
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
		-- Casse normale en Fredoka One (« Céleste x5 »), comme le reste de l'interface
		local text = string.format("%s x%d", mutation.Name, mutation.Multiplier)
		table.insert(lines, {
			Name = "Mutation",
			Font = FREDOKA,
			Text = text,
			Gradient = if mutation.GradientColors
				then spanGradient(mutation.GradientColors, text, FREDOKA, GLYPH.Mutation)
				else verticalGradient(mutation.Color, 0),
			Horizontal = mutation.GradientColors ~= nil,
		})
	end
	table.insert(lines, { Name = "Name", Font = FREDOKA, Text = def.Name, Color = WHITE })
	local rainbowRarity = rarity ~= nil and rarity.Rainbow == true
	local rarityText = Format.Upper(if rarity then rarity.Name else tostring(def.Rarity))
	table.insert(lines, {
		Name = "Rarity",
		Font = LUCKIEST,
		Text = rarityText,
		Gradient = if rainbowRarity
			then spanGradient(Rarities.RainbowColors, rarityText, LUCKIEST, GLYPH.Rarity)
			else verticalGradient(if rarity then rarity.Color else WHITE, LG_TOP),
		Horizontal = rainbowRarity,
	})
	-- « /s » en minuscules de Fredoka One (Luckiest Guy n'a que des capitales : « /S »)
	local income = Format.Income(def.Income * Mutations.GetMultiplier(mutationId))
	table.insert(lines, {
		Name = "Income",
		Font = LUCKIEST,
		Text = (string.gsub(income, "/s$", '<font face="FredokaOne">/s</font>')),
		Gradient = verticalGradient(INCOME_COLOR, LG_TOP),
		Rich = true,
	})
	if priceText then
		table.insert(
			lines,
			{ Name = "Price", Font = LUCKIEST, Text = priceText, Gradient = verticalGradient(PRICE_COLOR, LG_TOP) }
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
		addLine(gui, info, order, lineHeight(info) / total, gaps, MAX_TEXT_SIZE[place][info.Name], STROKE[place])
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
		Body = over.Body or style.Body:Lerp(style.Limb, hue * 0.18),
		Belly = over.Belly or style.Belly,
		Limb = over.Limb or style.Limb:Lerp(style.Body, hue * 0.2),
		Accent = over.Accent or style.Accent,
		Pupil = INK,
		Material = SMOOTH,
	}
	if mutation then
		-- Les couleurs de la mutation remplacent (en grande partie) celles de la créature :
		-- un mélange RVB de teintes opposées donnerait du gris. L'accent devient celui de la
		-- mutation (toujours en plastique plein)
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
	Core = true,
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
			-- multicolore), couleurs vives mais pas criardes ; le ventre reste plus clair
			local hue = (0.5 + part.CFrame.Position.Y / ctx.Scale * 0.3) % 1
			part.Color = Color3.fromHSV(hue, if part.Name == "Belly" then 0.35 else 0.68, 1)
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
-- SLOT_HALF_DEPTH autour du centre). Anneau de rareté, orbites et aura sont déjà bornés
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
	local mutation = Mutations.Get(mutationId)
	local ctx: Ctx = {
		Model = model,
		Root = root,
		Scale = scale,
		P = makePalette(def, style, traits, mutation),
		Style = style,
		Traits = traits,
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
			"Scarf",
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
	if traits.Cape then
		-- Cape de couleur imposée (archonte) : celle des membres si une mutation recolore
		-- la créature (une cape violette sur une statue d'or jurait)
		local recolored = mutation ~= nil and mutation.Limb ~= nil
		local color = if typeof(traits.Cape) == "Color3" then traits.Cape else nil
		Features.Cape(ctx, shape, if recolored and color then ctx.P.Limb else color)
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
