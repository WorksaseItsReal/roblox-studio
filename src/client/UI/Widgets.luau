--[[
	Widgets
	=======
	Petits assemblages réutilisés par plusieurs panneaux (style v3 : cartes claires,
	texte foncé, raretés en pastilles colorées).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Widgets = {}

-- Dégradé arc-en-ciel (rareté Secrète), de gauche à droite
Widgets.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 64, 64)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 30)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 220, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(30, 190, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 80, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 200)),
})

--[[
	Dégradé propre à une mutation (Prismatique...), quelle que soit sa forme dans la
	config (ColorSequence "Gradient" ou liste de couleurs "GradientColors").
	nil si la mutation n'en a pas.
]]
function Widgets.MutationGradient(mutation: any): ColorSequence?
	if typeof(mutation.Gradient) == "ColorSequence" then
		return mutation.Gradient
	end
	local colors = mutation.GradientColors
	if type(colors) == "table" and #colors >= 2 then
		local keypoints = {}
		for index, color in colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
		end
		return ColorSequence.new(keypoints)
	end
	return nil
end

function Widgets.RarityColor(rarityId: string): Color3
	local rarity = Rarities.Get(rarityId)
	return if rarity then rarity.Color else Theme.TextMuted
end

function Widgets.RarityName(rarityId: string): string
	local rarity = Rarities.Get(rarityId)
	return if rarity then rarity.Name else rarityId
end

-- Remplace le dégradé d'une pastille ou d'une tuile par l'arc-en-ciel (Secrète)
local function rainbow(frame: Frame, rotation: number)
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = Widgets.Rainbow
		gradient.Rotation = rotation
	end
end

--[[
	Rareté en pastille colorée (arc-en-ciel pour Secret) : texte blanc à contour encre.
	props : propriétés du cadre (Position, AnchorPoint, LayoutOrder, Parent...) + TextSize
]]
function Widgets.RarityTag(rarityId: string, props: { [string]: any }): Frame
	local textSize = props.TextSize or 14
	local merged: { [string]: any } = { Name = "RarityTag", Size = UDim2.fromOffset(0, textSize + 9) }
	for key, value in pairs(props) do
		merged[key] = value
	end
	merged.TextSize = textSize
	local tag = UIKit.Pill(Widgets.RarityName(rarityId), Widgets.RarityColor(rarityId), merged)
	if rarityId == "Secret" then
		rainbow(tag, 0)
	end
	return tag
end

-- Mutation en pastille (dégradé propre à la mutation s'il existe : Prismatique...)
function Widgets.MutationTag(mutation: any, props: { [string]: any }): Frame
	local textSize = props.TextSize or 14
	local merged: { [string]: any } = { Name = "MutationTag", Size = UDim2.fromOffset(0, textSize + 9) }
	for key, value in pairs(props) do
		merged[key] = value
	end
	merged.TextSize = textSize
	local tag = UIKit.Pill(string.format("%s x%d", mutation.Name, mutation.Multiplier), mutation.Color, merged)
	-- Forme ronde : une mutation ne se confond pas avec une rareté de la même couleur
	local corner = tag:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	local sequence = Widgets.MutationGradient(mutation)
	local gradient = tag:FindFirstChildOfClass("UIGradient")
	if sequence and gradient then
		gradient.Color = sequence
		gradient.Rotation = 0
	end
	return tag
end

-- Carré d'icône aux couleurs de la rareté (arc-en-ciel pour Secret)
function Widgets.RarityTile(icon: string, rarityId: string, size: number, props: { [string]: any }?): Frame
	local tile = UIKit.IconTile(icon, Widgets.RarityColor(rarityId), size, props)
	if rarityId == "Secret" then
		rainbow(tile, 45)
	end
	return tile
end

-- Rangée horizontale (étiquettes, boutons...)
function Widgets.Row(props: { [string]: any }, padding: number?, hAlign: Enum.HorizontalAlignment?): Frame
	local row = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(row :: any)[key] = value
		end
	end
	UIKit.List(row, Enum.FillDirection.Horizontal, padding or 8, hAlign, Enum.VerticalAlignment.Center)
	row.Parent = props.Parent
	return row
end

-- Titre de section dans une liste : texte foncé + filet clair dessous
function Widgets.Section(parent: Instance, text: string, order: number): TextLabel
	local label = UIKit.Label({
		Name = "Section",
		Text = text,
		TextSize = 20,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.New("Frame", {
		Name = "Rule",
		BackgroundColor3 = Theme.CardStroke,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = label,
	})
	return label
end

-- Message centré quand une liste est vide
function Widgets.Empty(parent: Instance, icon: string, text: string, order: number?): Frame
	local holder = UIKit.New("Frame", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 200),
		LayoutOrder = order or 999,
		Parent = parent,
	})
	local circle = UIKit.New("Frame", {
		Name = "Icon",
		BackgroundColor3 = Theme.Chip,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(88, 88),
		Parent = holder,
	})
	UIKit.Round(circle)
	UIKit.Text({
		Name = "Glyph",
		Text = icon,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		Parent = circle,
	})
	UIKit.Body({
		Text = text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(40, 116),
		Size = UDim2.new(1, -80, 0, 56),
		Parent = holder,
	})
	return holder
end

-- Avatar rond d'un joueur (miniature Roblox, aucun asset à publier)
function Widgets.Avatar(userId: number, size: number, props: { [string]: any }?): Frame
	local frame = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Chip,
		Size = UDim2.fromOffset(size, size),
	})
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	UIKit.Round(frame)
	UIKit.Stroke(frame, 2.5)
	local image = UIKit.New("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId),
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})
	UIKit.Round(image)
	if props and props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

-- Change le texte d'une étiquette créée par UIKit.Pill ou UIKit.Chip
function Widgets.SetPillText(pill: Frame, text: string)
	local label = pill:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Change la couleur d'une pastille créée par UIKit.Pill
function Widgets.SetPillColor(pill: Frame, color: Color3)
	local gradient = pill:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(Theme.Lighten(color, 0.14), color)
		gradient.Rotation = 90
	end
end

return Widgets
