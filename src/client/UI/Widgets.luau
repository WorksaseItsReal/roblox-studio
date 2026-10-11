--[[
	Widgets
	=======
	Petits assemblages réutilisés par plusieurs panneaux.
]]

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Widgets = {}

-- Rangée horizontale (pastilles, boutons...)
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

-- Titre de section dans une liste
function Widgets.Section(parent: Instance, text: string, order: number): TextLabel
	return UIKit.Text({
		Text = text,
		TextSize = 22,
		TextColor3 = Theme.Gold,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Stroke = 2.5,
		Parent = parent,
	})
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
	UIKit.IconCircle(icon, Theme.Palette.Dark[1], 90, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Parent = holder,
	})
	UIKit.Text({
		Text = text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(20, 118),
		Size = UDim2.new(1, -40, 0, 60),
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

-- Change le texte d'une pastille créée par UIKit.Pill
function Widgets.SetPillText(pill: Frame, text: string)
	local label = pill:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

return Widgets
