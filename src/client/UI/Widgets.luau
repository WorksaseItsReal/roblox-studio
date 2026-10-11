--[[
	Widgets
	=======
	Petits assemblages réutilisés par plusieurs panneaux.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Widgets = {}

-- Dégradé arc-en-ciel (rareté Secrète)
Widgets.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 240, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(40, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
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
	return if rarity then rarity.Color else Theme.Text
end

-- Nom de la rareté en gros texte coloré, contour noir (arc-en-ciel pour Secret)
function Widgets.RarityText(rarityId: string, props: { [string]: any }): TextLabel
	local rarity = Rarities.Get(rarityId)
	local merged: { [string]: any } = {
		Name = "Rarity",
		Text = Format.Upper(if rarity then rarity.Name else rarityId),
		TextSize = 16,
		TextColor3 = if rarity then rarity.Color else Theme.Text,
		TextWrapped = false,
		Stroke = 2.2,
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	if rarityId == "Secret" then
		merged.TextColor3 = Color3.new(1, 1, 1)
	end
	local label = UIKit.Text(merged)
	if rarityId == "Secret" then
		UIKit.New("UIGradient", { Color = Widgets.Rainbow, Parent = label })
	end
	return label
end

--[[
	Rareté sur un encart bleu nuit à largeur automatique : chaque couleur de rareté
	(gris, bleu, violet, or, rouge, arc-en-ciel) ressort, quelle que soit la carte.
	props : propriétés du cadre (Position, AnchorPoint, LayoutOrder, Parent...) + TextSize
]]
function Widgets.RarityTag(rarityId: string, props: { [string]: any }): Frame
	local textSize = props.TextSize or 16
	local tag = UIKit.New("Frame", {
		Name = "RarityTag",
		BackgroundColor3 = Theme.Inset,
		Size = UDim2.fromOffset(0, textSize + 8),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "TextSize" then
			(tag :: any)[key] = value
		end
	end
	UIKit.Corner(tag, 7)
	UIKit.Stroke(tag, 2)
	UIKit.Padding(tag, 0, 8, 0, 8)
	Widgets.RarityText(rarityId, {
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Stroke = math.clamp(textSize / 7, 1.8, 2.6),
		ZIndex = tag.ZIndex,
		Parent = tag,
	})
	tag.Parent = props.Parent
	return tag
end

-- Carré d'icône aux couleurs de la rareté (arc-en-ciel pour Secret)
function Widgets.RarityTile(icon: string, rarityId: string, size: number, props: { [string]: any }?): Frame
	local tile = UIKit.IconTile(icon, Widgets.RarityColor(rarityId), size, props)
	if rarityId == "Secret" then
		local gradient = tile:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = Widgets.Rainbow
			gradient.Rotation = 45
		end
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

-- Titre de section dans une liste (gros texte blanc + filet bleu nuit dessous)
function Widgets.Section(parent: Instance, text: string, order: number): TextLabel
	local label = UIKit.Text({
		Name = "Section",
		Text = text,
		TextSize = 23,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = order,
		Stroke = 2.8,
		Parent = parent,
	})
	local rule = UIKit.New("Frame", {
		Name = "Rule",
		BackgroundColor3 = Theme.Inset,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 4),
		Parent = label,
	})
	UIKit.Round(rule)
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
	UIKit.IconCircle(icon, Theme.Palette.Dark[1], 92, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Parent = holder,
	})
	UIKit.Body({
		Text = text,
		TextSize = 20,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(20, 118),
		Size = UDim2.new(1, -40, 0, 60),
		Stroke = 1.8,
		Parent = holder,
	})
	return holder
end

-- Avatar rond d'un joueur (miniature Roblox, aucun asset à publier)
function Widgets.Avatar(userId: number, size: number, props: { [string]: any }?): Frame
	local frame = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Inset,
		Size = UDim2.fromOffset(size, size),
	})
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	UIKit.Round(frame)
	UIKit.Stroke(frame, 3)
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

-- Change le texte d'une étiquette créée par UIKit.Pill
function Widgets.SetPillText(pill: Frame, text: string)
	local label = pill:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

return Widgets
