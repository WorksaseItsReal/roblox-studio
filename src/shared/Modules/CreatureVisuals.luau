--[[
	CreatureVisuals
	===============
	Fabrique de modèles de créatures.

	1. Si un modèle nommé def.Model (ou def.Id) existe dans
	   ReplicatedStorage.Assets.Creatures, il est cloné (vos vrais modèles 3D).
	2. Sinon, un modèle procédural "style simulateur" est construit :
	   - corps en ellipsoïdes lisses (SpecialMesh Sphere : aucun asset requis)
	   - gros yeux brillants, bouche, joues
	   - style par dimension : Lave (flamme), Néant (halo + 3e œil), Glace
	     (couronne de glace), Bonbon (sucette), Cyber (visière + antenne)
	   - rareté : taille, disque lumineux au sol, couronne dès Légendaire
	   - archétypes : Blob, Spiky, Tall, Crystal, Wisp, Beast, Serpent, Golem

	Structure du modèle renvoyé :
	  Model (attributs CreatureId, Mutation, HipHeight)
	    Root (PrimaryPart, invisible, centre du corps)  <- les ProximityPrompts vont ici
	    ...pièces visuelles soudées à Root
	    Info (BillboardGui, optionnel)

	HipHeight = distance entre le centre de Root et le sol : pour poser la créature
	au point P, on fait model:PivotTo(CFrame.new(P + Vector3.yAxis * HipHeight)).

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

-- Style visuel par dimension
local STYLES = {
	Lava = {
		Body = Color3.fromRGB(255, 118, 52),
		Belly = Color3.fromRGB(255, 208, 150),
		Limb = Color3.fromRGB(205, 72, 42),
		Accent = Color3.fromRGB(255, 214, 70),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Flame",
		Blush = true,
	},
	Void = {
		Body = Color3.fromRGB(122, 74, 224),
		Belly = Color3.fromRGB(196, 168, 255),
		Limb = Color3.fromRGB(72, 42, 146),
		Accent = Color3.fromRGB(236, 226, 255),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Halo",
		ThirdEye = true,
	},
	Ice = {
		Body = Color3.fromRGB(150, 214, 255),
		Belly = Color3.fromRGB(238, 249, 255),
		Limb = Color3.fromRGB(92, 160, 232),
		Accent = Color3.fromRGB(200, 248, 255),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "IceCrown",
		Blush = true,
	},
	Candy = {
		Body = Color3.fromRGB(255, 142, 202),
		Belly = Color3.fromRGB(255, 236, 246),
		Limb = Color3.fromRGB(240, 96, 168),
		Accent = Color3.fromRGB(110, 236, 214),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Lollipop",
		Blush = true,
	},
	Cyber = {
		Body = Color3.fromRGB(86, 96, 120),
		Belly = Color3.fromRGB(150, 160, 182),
		Limb = Color3.fromRGB(46, 50, 66),
		Accent = Color3.fromRGB(0, 255, 168),
		Material = Enum.Material.Metal,
		Accessory = "Antenna",
		Visor = true,
	},
}

local EYE_WHITE = Color3.fromRGB(255, 255, 255)
local PUPIL = Color3.fromRGB(28, 22, 40)
local BLUSH = Color3.fromRGB(255, 120, 150)
local GOLD = Color3.fromRGB(255, 206, 60)

-- Contexte de construction partagé par les archétypes
type Ctx = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	Body: Color3,
	Belly: Color3,
	Limb: Color3,
	Accent: Color3,
	Material: Enum.Material,
	AccentParts: { BasePart },
}

-- Infos renvoyées par un archétype (unités avant mise à l'échelle)
type Shape = {
	Hip: number, -- distance centre -> sol
	Top: number, -- hauteur du sommet de la tête
	Eyes: { Y: number, Z: number, Spacing: number, Size: number }?,
}

---------------------------------------------------------------------------
-- Pièces de base
---------------------------------------------------------------------------
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
	part.Parent = ctx.Model
	return part
end

local function ellipsoid(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(ctx, "Body", size, cf, color, material or ctx.Material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function box(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return newPart(ctx, "Body", size, cf, color, material or ctx.Material)
end

local function ball(ctx: Ctx, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(ctx, "Body", Vector3.one * diameter, cf, color, material or ctx.Material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Cylindre debout
local function cylinder(
	ctx: Ctx,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = newPart(
		ctx,
		"Body",
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material or ctx.Material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function accent(ctx: Ctx, part: Part): Part
	table.insert(ctx.AccentParts, part)
	return part
end

---------------------------------------------------------------------------
-- Visage
---------------------------------------------------------------------------
local function addFace(ctx: Ctx, style, eyes, blush: boolean)
	local y, z, spacing, size = eyes.Y, eyes.Z, eyes.Spacing, eyes.Size
	if style.Visor then
		-- Visière lumineuse à la place des yeux
		local width = spacing * 2 + size * 1.3
		box(
			ctx,
			Vector3.new(width + 0.3, size * 0.95, 0.35),
			CFrame.new(0, y, z + 0.05),
			Color3.fromRGB(20, 22, 30),
			Enum.Material.SmoothPlastic
		)
		accent(
			ctx,
			box(ctx, Vector3.new(width, size * 0.55, 0.3), CFrame.new(0, y, z - 0.08), style.Accent, Enum.Material.Neon)
		)
	else
		for _, side in { -1, 1 } do
			ellipsoid(
				ctx,
				Vector3.new(size, size * 1.18, size * 0.55),
				CFrame.new(side * spacing, y, z),
				EYE_WHITE,
				Enum.Material.SmoothPlastic
			)
			ellipsoid(
				ctx,
				Vector3.new(size * 0.6, size * 0.75, size * 0.3),
				CFrame.new(side * spacing * 0.96, y - size * 0.06, z - size * 0.2),
				PUPIL,
				Enum.Material.SmoothPlastic
			)
			ball(
				ctx,
				size * 0.24,
				CFrame.new(side * spacing + size * 0.1, y + size * 0.2, z - size * 0.32),
				EYE_WHITE,
				Enum.Material.Neon
			)
		end
		-- Petite bouche souriante
		ellipsoid(
			ctx,
			Vector3.new(size * 0.7, size * 0.22, size * 0.2),
			CFrame.new(0, y - size * 0.95, z + 0.02),
			PUPIL,
			Enum.Material.SmoothPlastic
		)
	end
	if style.ThirdEye then
		ellipsoid(
			ctx,
			Vector3.new(size * 0.7, size * 0.8, size * 0.35),
			CFrame.new(0, y + size * 1.15, z + 0.08),
			EYE_WHITE,
			Enum.Material.SmoothPlastic
		)
		accent(ctx, ball(ctx, size * 0.36, CFrame.new(0, y + size * 1.12, z - 0.05), style.Accent, Enum.Material.Neon))
	end
	if blush and style.Blush then
		for _, side in { -1, 1 } do
			local cheek = ellipsoid(
				ctx,
				Vector3.new(size * 0.6, size * 0.3, size * 0.15),
				CFrame.new(side * (spacing + size * 0.45), y - size * 0.75, z + 0.12),
				BLUSH,
				Enum.Material.SmoothPlastic
			)
			cheek.Transparency = 0.25
		end
	end
end

---------------------------------------------------------------------------
-- Accessoires (dimension) et couronnes (rareté)
---------------------------------------------------------------------------
local Accessories = {}

function Accessories.Flame(ctx: Ctx, top: number, style)
	accent(
		ctx,
		ellipsoid(
			ctx,
			Vector3.new(1.3, 1.7, 1.3),
			CFrame.new(0, top + 0.55, 0.1),
			Color3.fromRGB(255, 120, 30),
			Enum.Material.Neon
		)
	)
	accent(
		ctx,
		ellipsoid(
			ctx,
			Vector3.new(0.85, 1.25, 0.85),
			CFrame.new(0.05, top + 0.95, 0.05),
			style.Accent,
			Enum.Material.Neon
		)
	)
	ellipsoid(
		ctx,
		Vector3.new(0.4, 0.6, 0.4),
		CFrame.new(0.08, top + 1.35, 0),
		Color3.fromRGB(255, 250, 220),
		Enum.Material.Neon
	)
end

function Accessories.Halo(ctx: Ctx, top: number, style)
	local count = 12
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		accent(
			ctx,
			box(
				ctx,
				Vector3.new(0.42, 0.18, 0.28),
				CFrame.new(math.cos(a) * 0.9, top + 0.9, math.sin(a) * 0.9) * CFrame.Angles(0, -a, 0),
				style.Accent,
				Enum.Material.Neon
			)
		)
	end
end

function Accessories.IceCrown(ctx: Ctx, top: number, style)
	for i, data in { { 0, 1.5, 0 }, { -0.45, 1.0, -0.35 }, { 0.45, 1.0, 0.35 } } do
		local spike = box(
			ctx,
			Vector3.new(0.45, data[2], 0.45),
			CFrame.new(data[1], top + data[2] / 2 - 0.1, (if i == 1 then 0 else 0.1))
				* CFrame.Angles(0, math.rad(45), data[1] * 0.5),
			style.Accent,
			Enum.Material.Glass
		)
		spike.Transparency = 0.15
		accent(ctx, spike)
	end
end

function Accessories.Lollipop(ctx: Ctx, top: number, style)
	cylinder(
		ctx,
		1.4,
		0.18,
		CFrame.new(0.35, top + 0.6, 0.2) * CFrame.Angles(0, 0, -0.2),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	local candy = newPart(
		ctx,
		"Body",
		Vector3.new(0.3, 1.3, 1.3),
		CFrame.new(0.5, top + 1.35, 0.2) * CFrame.Angles(0, math.rad(90), 0),
		style.Accent,
		Enum.Material.Neon
	)
	candy.Shape = Enum.PartType.Cylinder
	accent(ctx, candy)
	local swirl = newPart(
		ctx,
		"Body",
		Vector3.new(0.34, 0.75, 0.75),
		CFrame.new(0.5, top + 1.35, 0.2) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	swirl.Shape = Enum.PartType.Cylinder
end

function Accessories.Antenna(ctx: Ctx, top: number, style)
	cylinder(ctx, 1.1, 0.16, CFrame.new(0, top + 0.5, 0.1), Color3.fromRGB(40, 44, 58), Enum.Material.Metal)
	accent(ctx, ball(ctx, 0.5, CFrame.new(0, top + 1.15, 0.1), style.Accent, Enum.Material.Neon))
end

local function addCrown(ctx: Ctx, top: number, rarity)
	local color = if rarity.Tier >= 6
		then Color3.fromRGB(120, 255, 230)
		elseif rarity.Tier >= 5 then Color3.fromRGB(255, 80, 120)
		else GOLD
	local count = 6
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		box(
			ctx,
			Vector3.new(0.38, 0.75, 0.22),
			CFrame.new(math.cos(a) * 0.62, top + 0.35, math.sin(a) * 0.62) * CFrame.Angles(0, -a + math.pi / 2, 0),
			color,
			Enum.Material.Foil
		)
	end
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		box(
			ctx,
			Vector3.new(0.4, 0.22, 0.2),
			CFrame.new(math.cos(a) * 0.64, top + 0.05, math.sin(a) * 0.64) * CFrame.Angles(0, -a + math.pi / 2, 0),
			color,
			Enum.Material.Foil
		)
	end
	ball(ctx, 0.32, CFrame.new(0, top + 0.3, -0.7), rarity.Color, Enum.Material.Neon)
	if rarity.Tier >= 5 then
		-- Cornes pour les Mythiques et les Secrètes
		for _, side in { -1, 1 } do
			ellipsoid(
				ctx,
				Vector3.new(0.35, 1.2, 0.35),
				CFrame.new(side * 0.95, top + 0.3, 0) * CFrame.Angles(0, 0, side * -0.5),
				color,
				Enum.Material.SmoothPlastic
			)
		end
	end
end

---------------------------------------------------------------------------
-- Archétypes : construisent le corps, renvoient Hip / Top / Yeux
---------------------------------------------------------------------------
local Archetypes = {}

local function feet(ctx: Ctx, y: number, spacing: number, size: number)
	for _, side in { -1, 1 } do
		ellipsoid(ctx, Vector3.new(size, size * 0.6, size * 1.25), CFrame.new(side * spacing, y, -0.25), ctx.Limb)
	end
end

function Archetypes.Blob(ctx: Ctx): Shape
	ellipsoid(ctx, Vector3.new(3.2, 2.8, 3.0), CFrame.new(), ctx.Body)
	ellipsoid(ctx, Vector3.new(2.1, 1.7, 0.7), CFrame.new(0, -0.45, -1.15), ctx.Belly)
	for _, side in { -1, 1 } do
		ellipsoid(
			ctx,
			Vector3.new(0.65, 1.1, 0.65),
			CFrame.new(side * 1.55, -0.25, -0.15) * CFrame.Angles(0, 0, side * 0.55),
			ctx.Limb
		)
	end
	feet(ctx, -1.35, 0.8, 0.95)
	return { Hip = 1.62, Top = 1.38, Eyes = { Y = 0.45, Z = -1.32, Spacing = 0.62, Size = 0.78 } }
end

function Archetypes.Spiky(ctx: Ctx): Shape
	ellipsoid(ctx, Vector3.new(3.0, 2.9, 3.0), CFrame.new(), ctx.Body)
	ellipsoid(ctx, Vector3.new(1.9, 1.6, 0.6), CFrame.new(0, -0.5, -1.18), ctx.Belly)
	-- Piques sur le dos et le dessus (jamais sur le visage)
	local directions = {
		{ 0, 1, 0.2 },
		{ 0.6, 0.8, 0.5 },
		{ -0.6, 0.8, 0.5 },
		{ 0, 0.5, 1 },
		{ 0.8, 0.2, 0.7 },
		{ -0.8, 0.2, 0.7 },
		{ 0.5, -0.2, 1 },
		{ -0.5, -0.2, 1 },
		{ 0, 0.85, -0.45 },
	}
	for _, d in directions do
		local dir = Vector3.new(d[1], d[2], d[3]).Unit
		local base = dir * 1.35
		local spike = box(
			ctx,
			Vector3.new(0.55, 0.55, 1.5),
			CFrame.lookAt(base, base + dir) * CFrame.new(0, 0, -0.55),
			ctx.Accent,
			Enum.Material.Neon
		)
		accent(ctx, spike)
	end
	feet(ctx, -1.35, 0.75, 0.9)
	return { Hip = 1.6, Top = 1.7, Eyes = { Y = 0.35, Z = -1.33, Spacing = 0.6, Size = 0.74 } }
end

function Archetypes.Tall(ctx: Ctx): Shape
	ellipsoid(ctx, Vector3.new(2.2, 3.3, 2.0), CFrame.new(), ctx.Body)
	ellipsoid(ctx, Vector3.new(1.5, 2.1, 0.55), CFrame.new(0, -0.25, -0.86), ctx.Belly)
	ellipsoid(ctx, Vector3.new(2.5, 2.2, 2.2), CFrame.new(0, 2.35, 0), ctx.Body)
	for _, side in { -1, 1 } do
		ellipsoid(
			ctx,
			Vector3.new(0.7, 2.0, 0.7),
			CFrame.new(side * 1.35, -0.1, 0) * CFrame.Angles(0, 0, side * 0.25),
			ctx.Limb
		)
	end
	feet(ctx, -1.75, 0.6, 0.95)
	return { Hip = 1.98, Top = 3.45, Eyes = { Y = 2.45, Z = -1.0, Spacing = 0.55, Size = 0.68 } }
end

function Archetypes.Crystal(ctx: Ctx): Shape
	local gem = box(ctx, Vector3.new(1.9, 3.2, 1.9), CFrame.Angles(0, math.rad(45), 0), ctx.Body, Enum.Material.Glass)
	gem.Transparency = 0.12
	box(
		ctx,
		Vector3.new(1.3, 1.3, 1.3),
		CFrame.new(0, 1.85, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
		ctx.Belly,
		Enum.Material.Glass
	)
	box(
		ctx,
		Vector3.new(1.3, 1.3, 1.3),
		CFrame.new(0, -1.85, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
		ctx.Limb,
		Enum.Material.Glass
	)
	accent(ctx, ball(ctx, 1.1, CFrame.new(0, 0, 0), ctx.Accent, Enum.Material.Neon))
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + 0.5
		accent(
			ctx,
			box(
				ctx,
				Vector3.new(0.5, 0.9, 0.5),
				CFrame.new(math.cos(a) * 1.9, 0.6 - i * 0.4, math.sin(a) * 1.9 + 0.3) * CFrame.Angles(0.4, a, 0.3),
				ctx.Accent,
				Enum.Material.Neon
			)
		)
	end
	return { Hip = 2.9, Top = 2.6, Eyes = { Y = 0.55, Z = -1.38, Spacing = 0.42, Size = 0.6 } }
end

function Archetypes.Wisp(ctx: Ctx): Shape
	accent(ctx, ball(ctx, 1.5, CFrame.new(), ctx.Accent, Enum.Material.Neon))
	local shell = ellipsoid(ctx, Vector3.new(2.9, 2.7, 2.9), CFrame.new(), ctx.Body)
	shell.Transparency = 0.3
	for i, data in { { 1.9, 0.9, 1.5 }, { 1.4, 1.35, 2.25 }, { 0.9, 1.6, 2.9 } } do
		local tail = ellipsoid(
			ctx,
			Vector3.new(data[1], data[1] * 0.85, data[1] * 1.1),
			CFrame.new(0, -data[2] + 0.4, data[3] - 0.3),
			ctx.Body
		)
		tail.Transparency = 0.3 + i * 0.1
	end
	for _, side in { -1, 1 } do
		ellipsoid(
			ctx,
			Vector3.new(0.5, 0.9, 0.5),
			CFrame.new(side * 1.45, -0.1, -0.1) * CFrame.Angles(0, 0, side * 0.7),
			ctx.Limb
		)
	end
	return { Hip = 2.6, Top = 1.35, Eyes = { Y = 0.3, Z = -1.3, Spacing = 0.55, Size = 0.72 } }
end

function Archetypes.Beast(ctx: Ctx): Shape
	ellipsoid(ctx, Vector3.new(2.4, 2.0, 3.6), CFrame.new(0, 0, 0.25), ctx.Body)
	ellipsoid(ctx, Vector3.new(1.6, 1.0, 2.6), CFrame.new(0, -0.55, 0.25), ctx.Belly)
	ellipsoid(ctx, Vector3.new(2.1, 1.9, 1.9), CFrame.new(0, 0.85, -1.85), ctx.Body)
	ellipsoid(ctx, Vector3.new(1.15, 0.8, 0.8), CFrame.new(0, 0.45, -2.68), ctx.Belly)
	ball(ctx, 0.36, CFrame.new(0, 0.7, -3.08), PUPIL, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		ellipsoid(
			ctx,
			Vector3.new(0.5, 1.1, 0.35),
			CFrame.new(side * 0.7, 1.95, -1.65) * CFrame.Angles(0, 0, side * -0.35),
			ctx.Limb
		)
		for _, z in { -0.95, 1.35 } do
			cylinder(ctx, 1.3, 0.72, CFrame.new(side * 0.72, -1.15, z), ctx.Limb)
			ellipsoid(ctx, Vector3.new(0.85, 0.45, 1.0), CFrame.new(side * 0.72, -1.75, z - 0.15), ctx.Belly)
		end
	end
	accent(
		ctx,
		ellipsoid(
			ctx,
			Vector3.new(0.55, 0.55, 1.7),
			CFrame.new(0, 0.55, 2.25) * CFrame.Angles(math.rad(-35), 0, 0),
			ctx.Accent,
			Enum.Material.Neon
		)
	)
	return { Hip = 1.96, Top = 2.4, Eyes = { Y = 1.1, Z = -2.62, Spacing = 0.46, Size = 0.56 } }
end

function Archetypes.Serpent(ctx: Ctx): Shape
	local segments = {
		{ Vector3.new(1.9, 1.7, 1.9), Vector3.new(0, 0.05, -0.25) },
		{ Vector3.new(1.65, 1.45, 1.65), Vector3.new(0, -0.3, 0.9) },
		{ Vector3.new(1.35, 1.15, 1.4), Vector3.new(0, -0.45, 1.9) },
		{ Vector3.new(1.0, 0.85, 1.2), Vector3.new(0, -0.55, 2.75) },
	}
	for i, seg in segments do
		ellipsoid(ctx, seg[1], CFrame.new(seg[2]), if i % 2 == 0 then ctx.Limb else ctx.Body)
		accent(
			ctx,
			ellipsoid(
				ctx,
				Vector3.new(0.3, 0.5, 0.5),
				CFrame.new(seg[2] + Vector3.new(0, seg[1].Y / 2, 0)),
				ctx.Accent,
				Enum.Material.Neon
			)
		)
	end
	ellipsoid(ctx, Vector3.new(2.3, 2.0, 2.3), CFrame.new(0, 0.85, -1.55), ctx.Body)
	ellipsoid(ctx, Vector3.new(1.4, 0.7, 1.0), CFrame.new(0, 0.3, -2.4), ctx.Belly)
	for _, side in { -1, 1 } do
		accent(
			ctx,
			ellipsoid(
				ctx,
				Vector3.new(0.25, 1.0, 0.8),
				CFrame.new(side * 1.2, 1.3, -1.3) * CFrame.Angles(0, 0, side * -0.6),
				ctx.Accent,
				Enum.Material.Neon
			)
		)
	end
	return { Hip = 1.12, Top = 1.85, Eyes = { Y = 1.15, Z = -2.55, Spacing = 0.5, Size = 0.62 } }
end

function Archetypes.Golem(ctx: Ctx): Shape
	box(ctx, Vector3.new(2.6, 2.4, 1.8), CFrame.new(), ctx.Body)
	box(ctx, Vector3.new(1.8, 1.5, 0.3), CFrame.new(0, -0.15, -0.9), ctx.Belly)
	box(ctx, Vector3.new(1.7, 1.4, 1.5), CFrame.new(0, 1.95, 0), ctx.Body)
	for _, side in { -1, 1 } do
		box(ctx, Vector3.new(1.1, 0.9, 1.3), CFrame.new(side * 1.75, 0.95, 0), ctx.Limb)
		box(ctx, Vector3.new(0.85, 2.0, 0.85), CFrame.new(side * 1.8, -0.35, 0), ctx.Limb)
		box(ctx, Vector3.new(1.1, 0.9, 1.1), CFrame.new(side * 1.8, -1.55, -0.1), ctx.Body)
		box(ctx, Vector3.new(1.0, 1.2, 1.1), CFrame.new(side * 0.65, -1.8, 0), ctx.Limb)
	end
	-- Fissures lumineuses
	accent(
		ctx,
		box(
			ctx,
			Vector3.new(0.18, 1.3, 0.1),
			CFrame.new(-0.4, 0.1, -0.92) * CFrame.Angles(0, 0, 0.5),
			ctx.Accent,
			Enum.Material.Neon
		)
	)
	accent(
		ctx,
		box(
			ctx,
			Vector3.new(0.18, 0.9, 0.1),
			CFrame.new(0.45, -0.2, -0.92) * CFrame.Angles(0, 0, -0.6),
			ctx.Accent,
			Enum.Material.Neon
		)
	)
	return { Hip = 2.4, Top = 2.65, Eyes = { Y = 2.05, Z = -0.82, Spacing = 0.4, Size = 0.5 } }
end

---------------------------------------------------------------------------
-- Effets
---------------------------------------------------------------------------
local function addParticles(root: BasePart, color: ColorSequence, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Color = color
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
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

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

local function applyRarity(ctx: Ctx, rarity, hip: number)
	-- Disque lumineux au sol (lisibilité de la rareté de loin)
	if rarity.Tier >= 2 then
		local diskSize = 3.0 + rarity.Tier * 0.15
		local disk = newPart(
			ctx,
			"RarityDisc",
			Vector3.new(0.12, diskSize, diskSize),
			CFrame.new(0, -hip + 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)),
			rarity.Color,
			Enum.Material.Neon
		)
		disk.Shape = Enum.PartType.Cylinder
		disk.Transparency = 0.45
	end
	if rarity.Tier >= 4 then
		local colors = if rarity.Tier >= 6 then RAINBOW else ColorSequence.new(rarity.Color)
		addParticles(ctx.Root, colors, 4 + (rarity.Tier - 3) * 5, 0.3 * ctx.Scale)
	end
	if rarity.Tier >= 5 then
		addLight(ctx.Root, rarity.Color, 1.6, 12 * ctx.Scale)
	end
end

local function applyMutation(ctx: Ctx, mutationId: string)
	local mutation = Mutations.Get(mutationId)
	if not mutation then
		return
	end
	-- Accents recolorés à la couleur de la mutation
	for _, part in ctx.AccentParts do
		part.Color = mutation.Color
		part.Material = Enum.Material.Neon
	end
	-- Aura translucide unique par mutation
	local aura = Instance.new("Part")
	aura.Name = "MutationAura"
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.one * 5 * ctx.Scale
	aura.CFrame = CFrame.new()
	aura.Color = mutation.Color
	aura.Material = Enum.Material.ForceField
	aura.Transparency = 0.1
	aura.CanCollide = false
	aura.CanTouch = false
	aura.CanQuery = false
	aura.CastShadow = false
	aura.Anchored = true
	aura.Parent = ctx.Model
	addParticles(ctx.Root, ColorSequence.new(mutation.Color), 6 + mutation.Multiplier * 3, 0.35 * ctx.Scale)
	addLight(ctx.Root, mutation.Color, mutation.LightBrightness, 10 * ctx.Scale)
end

---------------------------------------------------------------------------
-- Billboard d'informations (pastille rareté + nom + revenu + prix)
---------------------------------------------------------------------------
local function stroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(18, 12, 34)
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function textLabel(parent: Instance, name: string, order: number, text: string, color: Color3, size: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	stroke(label, 2)
	return label
end

local function pill(parent: Instance, name: string, order: number, text: string, color: Color3)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 22)
	holder.Parent = parent
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0)
	frame.Size = UDim2.fromOffset(0, 22)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundColor3 = color
	frame.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	gradient.Rotation = 90
	gradient.Parent = frame
	stroke(frame, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = frame
	stroke(label, 1.5)
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

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(230, 106)
	gui.StudsOffsetWorldSpace = Vector3.new(0, heightOffset, 0)
	gui.MaxDistance = 75
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 1)
	layout.Parent = gui

	if mutation then
		pill(gui, "Mutation", 1, string.format("%s x%d", mutation.Name, mutation.Multiplier), mutation.Color)
	end
	pill(
		gui,
		"Rarity",
		2,
		if rarity then rarity.Name else def.Rarity,
		if rarity then rarity.Color else Color3.new(1, 1, 1)
	)
	textLabel(gui, "Name", 3, def.Name, Color3.new(1, 1, 1), 22)
	textLabel(
		gui,
		"Income",
		4,
		Format.Income(def.Income * Mutations.GetMultiplier(mutationId)),
		Color3.fromRGB(120, 255, 130),
		17
	)
	if priceText then
		textLabel(gui, "Price", 5, priceText, Color3.fromRGB(255, 214, 70), 19)
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
	local topHeight: number

	local template = getAssetTemplate(def)
	if template then
		-- Modèle 3D fourni par le développeur
		model = template:Clone()
		local boxCFrame, boxSize = model:GetBoundingBox()
		model:PivotTo(boxCFrame:Inverse() * model:GetPivot())
		root = makeRoot(model, Vector3.one)
		hipHeight = boxSize.Y / 2
		topHeight = boxSize.Y / 2
		local ctx: Ctx = {
			Model = model,
			Root = root,
			Scale = math.max(boxSize.X, boxSize.Y, boxSize.Z) / 4.6,
			Body = style.Body,
			Belly = style.Belly,
			Limb = style.Limb,
			Accent = style.Accent,
			Material = style.Material,
			AccentParts = {},
		}
		applyRarity(ctx, rarity, hipHeight / ctx.Scale)
		applyMutation(ctx, mutation)
	else
		model = Instance.new("Model")
		root = makeRoot(model, Vector3.one * 2 * scale)
		local hue = hashId(def.Id)
		local ctx: Ctx = {
			Model = model,
			Root = root,
			Scale = scale,
			Body = style.Body:Lerp(style.Limb, hue * 0.35),
			Belly = style.Belly,
			Limb = style.Limb:Lerp(style.Body, hue * 0.3),
			Accent = style.Accent,
			Material = style.Material,
			AccentParts = {},
		}
		local builder = Archetypes[def.Visual.Archetype] or Archetypes.Blob
		local shape: Shape = builder(ctx)
		if shape.Eyes then
			addFace(ctx, style, shape.Eyes, def.Visual.Archetype ~= "Golem")
		end
		if rarity.Tier >= 4 then
			addCrown(ctx, shape.Top, rarity)
		else
			local accessory = Accessories[style.Accessory]
			if accessory then
				accessory(ctx, shape.Top, style)
			end
		end
		if style.Accessory == "Halo" and rarity.Tier >= 4 then
			Accessories.Halo(ctx, shape.Top + 0.9, style)
		end
		applyRarity(ctx, rarity, shape.Hip)
		applyMutation(ctx, mutation)
		hipHeight = shape.Hip * scale
		topHeight = (shape.Top + 1.2) * scale
	end

	model.Name = def.Id
	model:SetAttribute("CreatureId", def.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("HipHeight", hipHeight)

	if opts.Billboard then
		CreatureVisuals.CreateBillboard(root, def, mutation, topHeight + 1, opts.PriceText)
	end

	finalizePhysics(model, root, anchored)
	return model
end

return CreatureVisuals
