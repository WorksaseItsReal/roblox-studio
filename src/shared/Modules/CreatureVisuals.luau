--[[
	CreatureVisuals
	===============
	Fabrique de modèles de créatures.

	1. Si un modèle nommé def.Model (ou def.Id) existe dans
	   ReplicatedStorage.Assets.Creatures, il est cloné (vos vrais modèles 3D).
	2. Sinon, un modèle procédural est construit à partir de l'archétype
	   (Blob, Spiky, Tall, Crystal, Wisp, Beast, Serpent, Golem), des couleurs de
	   la dimension et de la taille liée à la rareté.

	Structure du modèle renvoyé :
	  Model (attributs CreatureId, Mutation, HipHeight)
	    Root (PrimaryPart, invisible, centre du corps)  <- les ProximityPrompts vont ici
	    ...parties visuelles soudées à Root
	    Info (BillboardGui, optionnel)

	HipHeight = distance entre le centre de Root et le sol : pour poser la créature
	au point P, on fait model:PivotTo(CFrame.new(P + Vector3.yAxis * HipHeight)).

	Les mutations ajoutent un effet visuel unique (aura, particules, lumière, couleur
	d'accent). On évite volontairement l'instance Highlight : Roblox n'en affiche
	que 31 simultanément par client, ce qui casserait l'effet dans une base pleine.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Dimensions = require(Shared.Config.Dimensions)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Modules.Format)

local CreatureVisuals = {}

export type BuildOptions = {
	Anchored: boolean?, -- true (défaut) : pièces ancrées. false : soudées, sans masse (portée par un joueur)
	Billboard: boolean?, -- afficher le nom / la rareté / le revenu
	PriceText: string?, -- ligne de prix (créatures sur le chemin)
	IncomeMultiplier: number?, -- pour afficher le revenu réel (mutation incluse par défaut)
}

-- Contexte de construction partagé par les archétypes
type BuildContext = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Material: Enum.Material,
	AccentMaterial: Enum.Material,
	AccentParts: { BasePart },
}

local function addPart(
	ctx: BuildContext,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	isAccent: boolean?
): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size * ctx.Scale
	part.CFrame = CFrame.new(offset.Position * ctx.Scale) * offset.Rotation
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Anchored = true
	part.Parent = ctx.Model
	if isAccent then
		table.insert(ctx.AccentParts, part)
	end
	return part
end

-- Deux yeux lumineux + pupilles, face vers -Z (l'avant du modèle)
local function addEyes(ctx: BuildContext, y: number, z: number, spacing: number, size: number)
	for _, side in { -1, 1 } do
		addPart(
			ctx,
			Enum.PartType.Ball,
			Vector3.one * size,
			CFrame.new(side * spacing, y, z),
			Color3.new(1, 1, 1),
			Enum.Material.Neon
		)
		addPart(
			ctx,
			Enum.PartType.Ball,
			Vector3.one * size * 0.5,
			CFrame.new(side * spacing, y, z - size * 0.35),
			Color3.new(0.05, 0.05, 0.08),
			Enum.Material.SmoothPlastic
		)
	end
end

---------------------------------------------------------------------------
-- Archétypes : chaque fonction construit le corps et renvoie le HipHeight
-- (avant multiplication par l'échelle)
---------------------------------------------------------------------------
local Archetypes = {}

function Archetypes.Blob(ctx: BuildContext): number
	addPart(ctx, Enum.PartType.Ball, Vector3.one * 3, CFrame.new(), ctx.Primary, ctx.Material)
	addPart(ctx, Enum.PartType.Ball, Vector3.new(2.2, 1.2, 2.2), CFrame.new(0, 0.9, 0), ctx.Secondary, ctx.Material)
	addEyes(ctx, 0.35, -1.3, 0.6, 0.6)
	for _, side in { -1, 1 } do
		addPart(
			ctx,
			Enum.PartType.Block,
			Vector3.new(0.3, 0.9, 0.3),
			CFrame.new(side * 0.8, 1.7, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)),
			ctx.Accent,
			ctx.AccentMaterial,
			true
		)
	end
	return 1.5
end

function Archetypes.Spiky(ctx: BuildContext): number
	addPart(ctx, Enum.PartType.Ball, Vector3.one * 3, CFrame.new(), ctx.Primary, ctx.Material)
	local spikes = 10
	for i = 1, spikes do
		local yaw = (i / spikes) * math.pi * 2
		local pitch = if i % 2 == 0 then math.rad(35) else math.rad(-10)
		local direction = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		addPart(
			ctx,
			Enum.PartType.Block,
			Vector3.new(0.45, 0.45, 1.6),
			direction * CFrame.new(0, 0, -1.6),
			ctx.Accent,
			ctx.AccentMaterial,
			true
		)
	end
	addEyes(ctx, 0.3, -1.35, 0.55, 0.55)
	return 1.5
end

function Archetypes.Tall(ctx: BuildContext): number
	-- Le cylindre Roblox est orienté selon X : rotation de 90° pour le mettre debout
	addPart(
		ctx,
		Enum.PartType.Cylinder,
		Vector3.new(4, 1.7, 1.7),
		CFrame.Angles(0, 0, math.rad(90)),
		ctx.Primary,
		ctx.Material
	)
	addPart(ctx, Enum.PartType.Ball, Vector3.one * 1.9, CFrame.new(0, 2.6, 0), ctx.Secondary, ctx.Material)
	addEyes(ctx, 2.7, -0.8, 0.4, 0.45)
	for _, side in { -1, 1 } do
		addPart(
			ctx,
			Enum.PartType.Block,
			Vector3.new(0.4, 2.4, 0.4),
			CFrame.new(side * 1.15, 0.2, 0) * CFrame.Angles(0, 0, math.rad(side * 12)),
			ctx.Accent,
			ctx.AccentMaterial,
			true
		)
	end
	return 2
end

function Archetypes.Crystal(ctx: BuildContext): number
	addPart(
		ctx,
		Enum.PartType.Block,
		Vector3.new(1.6, 3.2, 1.6),
		CFrame.Angles(0, math.rad(45), math.rad(8)),
		ctx.Primary,
		ctx.Material
	)
	addPart(
		ctx,
		Enum.PartType.Block,
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		ctx.Accent,
		Enum.Material.Neon,
		true
	)
	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2
		addPart(
			ctx,
			Enum.PartType.Block,
			Vector3.new(0.7, 1.6, 0.7),
			CFrame.new(math.cos(angle) * 1.5, -0.6, math.sin(angle) * 1.5)
				* CFrame.Angles(math.rad(20), angle, math.rad(25)),
			ctx.Secondary,
			ctx.Material
		)
	end
	return 2.3 -- flotte légèrement au-dessus du sol
end

function Archetypes.Wisp(ctx: BuildContext): number
	addPart(ctx, Enum.PartType.Ball, Vector3.one * 1.8, CFrame.new(), ctx.Accent, Enum.Material.Neon, true)
	local shell = addPart(ctx, Enum.PartType.Ball, Vector3.one * 2.8, CFrame.new(), ctx.Primary, ctx.Material)
	shell.Transparency = 0.45
	addPart(
		ctx,
		Enum.PartType.Cylinder,
		Vector3.new(0.2, 4, 4),
		CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0),
		ctx.Secondary,
		ctx.Material
	).Transparency =
		0.3
	addEyes(ctx, 0.25, -1.25, 0.5, 0.5)
	return 2.2
end

function Archetypes.Beast(ctx: BuildContext): number
	addPart(ctx, Enum.PartType.Block, Vector3.new(1.8, 1.6, 3.4), CFrame.new(), ctx.Primary, ctx.Material)
	addPart(ctx, Enum.PartType.Block, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 0.7, -2), ctx.Secondary, ctx.Material)
	addEyes(ctx, 0.95, -2.72, 0.35, 0.4)
	for _, x in { -0.65, 0.65 } do
		for _, z in { -1.2, 1.2 } do
			addPart(
				ctx,
				Enum.PartType.Block,
				Vector3.new(0.5, 1.3, 0.5),
				CFrame.new(x, -1.35, z),
				ctx.Secondary,
				ctx.Material
			)
		end
	end
	addPart(
		ctx,
		Enum.PartType.Block,
		Vector3.new(0.35, 0.35, 1.6),
		CFrame.new(0, 0.6, 2.2) * CFrame.Angles(math.rad(-35), 0, 0),
		ctx.Accent,
		ctx.AccentMaterial,
		true
	)
	return 2
end

function Archetypes.Serpent(ctx: BuildContext): number
	local segments = 5
	for i = 1, segments do
		local size = 1.9 - (i - 1) * 0.25
		local z = -1.6 + (i - 1) * 1.1
		local y = math.sin(i * 1.3) * 0.35
		addPart(
			ctx,
			Enum.PartType.Ball,
			Vector3.one * size,
			CFrame.new(0, y, z),
			if i % 2 == 0 then ctx.Secondary else ctx.Primary,
			ctx.Material
		)
	end
	addEyes(ctx, 0.35, -2.45, 0.4, 0.45)
	addPart(
		ctx,
		Enum.PartType.Block,
		Vector3.new(0.25, 0.8, 0.25),
		CFrame.new(0, 1.1, -1.6),
		ctx.Accent,
		ctx.AccentMaterial,
		true
	)
	return 1
end

function Archetypes.Golem(ctx: BuildContext): number
	addPart(ctx, Enum.PartType.Block, Vector3.new(2.4, 2.4, 1.6), CFrame.new(), ctx.Primary, ctx.Material)
	addPart(ctx, Enum.PartType.Block, Vector3.new(1.3, 1.2, 1.2), CFrame.new(0, 1.8, 0), ctx.Secondary, ctx.Material)
	addEyes(ctx, 1.9, -0.62, 0.3, 0.32)
	addPart(
		ctx,
		Enum.PartType.Block,
		Vector3.new(0.9, 0.9, 0.2),
		CFrame.new(0, 0.2, -0.85),
		ctx.Accent,
		ctx.AccentMaterial,
		true
	)
	for _, side in { -1, 1 } do
		addPart(
			ctx,
			Enum.PartType.Block,
			Vector3.new(0.8, 2.2, 0.8),
			CFrame.new(side * 1.65, -0.1, 0),
			ctx.Secondary,
			ctx.Material
		)
		addPart(
			ctx,
			Enum.PartType.Block,
			Vector3.new(0.9, 1.2, 0.9),
			CFrame.new(side * 0.6, -1.8, 0),
			ctx.Secondary,
			ctx.Material
		)
	end
	return 2.4
end

---------------------------------------------------------------------------
-- Effets
---------------------------------------------------------------------------
local function addParticles(root: BasePart, color: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Color = ColorSequence.new(color)
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
		NumberSequenceKeypoint.new(0, 0.2),
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

local function applyMutation(ctx: BuildContext, mutationId: string)
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
	aura.Size = Vector3.one * 4.6 * ctx.Scale
	aura.CFrame = CFrame.new()
	aura.Color = mutation.Color
	aura.Material = Enum.Material.ForceField
	aura.Transparency = 0.2
	aura.CanCollide = false
	aura.CanTouch = false
	aura.CanQuery = false
	aura.CastShadow = false
	aura.Anchored = true
	aura.Parent = ctx.Model
	addParticles(ctx.Root, mutation.Color, 6 + mutation.Multiplier * 3, 0.35 * ctx.Scale)
	addLight(ctx.Root, mutation.Color, mutation.LightBrightness, 10 * ctx.Scale)
end

local function applyRarity(ctx: BuildContext, rarityId: string)
	local rarity = Rarities.Get(rarityId)
	if not rarity then
		return
	end
	if rarity.Tier >= 4 then
		addParticles(ctx.Root, rarity.Color, 4 + (rarity.Tier - 3) * 4, 0.25 * ctx.Scale)
	end
	if rarity.Tier >= 5 then
		addLight(ctx.Root, rarity.Color, 1.5, 12 * ctx.Scale)
	end
end

---------------------------------------------------------------------------
-- Billboard d'informations
---------------------------------------------------------------------------
local function makeLabel(parent: Instance, name: string, order: number, color: Color3, textSize: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, textSize + 4)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = parent
	return label
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
	gui.Size = UDim2.fromOffset(220, if priceText then 92 else 72)
	gui.StudsOffsetWorldSpace = Vector3.new(0, heightOffset, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local rarityText = if rarity then rarity.Name else def.Rarity
	if mutation then
		rarityText = mutation.Name .. " • " .. rarityText
	end

	local rarityColor = if mutation then mutation.Color elseif rarity then rarity.Color else Color3.new(1, 1, 1)
	makeLabel(gui, "Rarity", 1, rarityColor, 16).Text = rarityText
	makeLabel(gui, "Name", 2, Color3.new(1, 1, 1), 20).Text = def.Name
	local income = def.Income * Mutations.GetMultiplier(mutationId)
	makeLabel(gui, "Income", 3, Color3.fromRGB(110, 255, 120), 16).Text = Format.Income(income)
	if priceText then
		makeLabel(gui, "Price", 4, Color3.fromRGB(255, 220, 80), 18).Text = priceText
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

function CreatureVisuals.Build(creatureId: string, mutationId: string?, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local anchored = if opts.Anchored == nil then true else opts.Anchored
	local mutation = mutationId or Mutations.None

	local def = Creatures.Get(creatureId)
	assert(def, "Créature inconnue : " .. tostring(creatureId))
	local rarity = Rarities.Get(def.Rarity)
	local dimension = Dimensions.Get(def.Dimension)
	assert(rarity and dimension, "Rareté ou dimension invalide pour " .. creatureId)

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
		-- Recentre le modèle sur l'origine pour que Root soit au centre du corps
		model:PivotTo(boxCFrame:Inverse() * model:GetPivot())
		root = makeRoot(model, Vector3.one)
		hipHeight = boxSize.Y / 2
		topHeight = boxSize.Y / 2
		local ctx: BuildContext = {
			Model = model,
			Root = root,
			Scale = math.max(boxSize.X, boxSize.Y, boxSize.Z) / 4.6,
			Primary = dimension.Palette[1],
			Secondary = dimension.Palette[2],
			Accent = dimension.Palette[3],
			Material = dimension.Material,
			AccentMaterial = dimension.AccentMaterial,
			AccentParts = {},
		}
		applyRarity(ctx, def.Rarity)
		applyMutation(ctx, mutation)
	else
		model = Instance.new("Model")
		root = makeRoot(model, Vector3.one * 2 * scale)
		local ctx: BuildContext = {
			Model = model,
			Root = root,
			Scale = scale,
			Primary = dimension.Palette[1],
			Secondary = dimension.Palette[2],
			Accent = dimension.Palette[3],
			Material = dimension.Material,
			AccentMaterial = dimension.AccentMaterial,
			AccentParts = {},
		}
		local builder = Archetypes[def.Visual.Archetype] or Archetypes.Blob
		hipHeight = builder(ctx) * scale
		topHeight = 2.4 * scale
		applyRarity(ctx, def.Rarity)
		applyMutation(ctx, mutation)
	end

	model.Name = def.Id
	model:SetAttribute("CreatureId", def.Id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("HipHeight", hipHeight)

	if opts.Billboard then
		CreatureVisuals.CreateBillboard(root, def, mutation, topHeight + 1.5, opts.PriceText)
	end

	finalizePhysics(model, root, anchored)
	return model
end

return CreatureVisuals
