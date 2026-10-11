--[[
	UIKit
	=====
	Composants d'interface "style simulateur", tous créés par code :
	  Text        texte arrondi avec contour sombre
	  Button      bouton 3D (ombre, dégradé, reflet, contour, animation d'appui)
	  IconButton  bouton carré (grosse icône + libellé) pour les menus
	  Card        carte avec dégradé et contour
	  Pill        pastille arrondie (rareté, statut...)
	  IconCircle  rond coloré contenant une icône
	  ProgressBar barre de progression avec texte
	  ScrollList / ScrollGrid
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local UIKit = {}

-- Crochet appelé à chaque clic sur un bouton actif (le SoundController y branche le son)
UIKit.OnClick = nil :: (() -> ())?

type Props = { [string]: any }

-- Crée une instance avec ses propriétés et ses enfants
function UIKit.New(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

---------------------------------------------------------------------------
-- Décorateurs
---------------------------------------------------------------------------
function UIKit.Corner(parent: Instance, radius: number | UDim | nil)
	local value = if typeof(radius) == "UDim"
		then radius
		elseif type(radius) == "number" then UDim.new(0, radius)
		else UDim.new(0, 14)
	return UIKit.New("UICorner", { CornerRadius = value, Parent = parent })
end

function UIKit.Round(parent: Instance)
	return UIKit.New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = parent })
end

-- Contour d'un cadre
function UIKit.Stroke(parent: Instance, thickness: number?, color: Color3?, transparency: number?)
	return UIKit.New("UIStroke", {
		Color = color or Theme.Ink,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

-- Contour d'un texte
function UIKit.TextStroke(label: Instance, thickness: number?, color: Color3?)
	return UIKit.New("UIStroke", {
		Color = color or Theme.Ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
end

-- Dégradé vertical (haut -> bas), multiplié par la couleur de fond (blanche par défaut)
function UIKit.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	return UIKit.New("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, top: number, right: number?, bottom: number?, left: number?)
	return UIKit.New("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
		Parent = parent,
	})
end

function UIKit.List(
	parent: Instance,
	direction: Enum.FillDirection?,
	padding: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
)
	return UIKit.New("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
-- Props additionnelles : Stroke (épaisseur du contour, 0 = aucun)
function UIKit.Text(props: Props): TextLabel
	local strokeThickness = props.Stroke
	local label = UIKit.New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 26),
	})
	for key, value in pairs(props) do
		if key ~= "Stroke" and key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	if strokeThickness ~= 0 then
		UIKit.TextStroke(label, strokeThickness or math.max(1.5, label.TextSize / 11))
	end
	label.Parent = props.Parent
	return label
end

-- Texte plus discret pour les descriptions
function UIKit.Body(props: Props): TextLabel
	local merged: Props = { Font = Theme.BodyFont, TextSize = 15, TextColor3 = Theme.TextDim, Stroke = 0 }
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UIKit.Text(merged)
end

---------------------------------------------------------------------------
-- Boutons 3D
---------------------------------------------------------------------------
export type Button = {
	Instance: Frame,
	Face: TextButton,
	Label: TextLabel,
	Enabled: boolean,
	SetText: (self: Button, text: string) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	SetColor: (self: Button, palette: any) -> (),
}

local DEPTH = 5

local function resolvePalette(palette: any): { Color3 }
	if type(palette) == "table" then
		return palette
	end
	return Theme.Palette[palette or "Blue"] or Theme.Palette.Blue
end

--[[
	opts : Text, Color (clé de Theme.Palette ou {haut, bas}), Size, Position,
	       AnchorPoint, LayoutOrder, TextSize, OnClick, Parent, ZIndex, Name
]]
function UIKit.Button(opts: Props): Button
	local palette = resolvePalette(opts.Color)
	local holder = UIKit.New("Frame", {
		Name = opts.Name or "Button",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(150, 50),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = opts.ZIndex or 1,
	})
	local shadow = UIKit.New("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Darken(palette[2], 0.45),
		Position = UDim2.fromOffset(0, DEPTH),
		Size = UDim2.new(1, 0, 1, -DEPTH),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.Corner(shadow, 14)
	UIKit.Stroke(shadow, 3)

	local face = UIKit.New("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -DEPTH),
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	UIKit.Corner(face, 14)
	UIKit.Stroke(face, 3)
	local gradient = UIKit.Gradient(face, palette[1], palette[2])

	-- Reflet brillant sur la moitié haute
	local shine = UIKit.New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0.36, 0),
		ZIndex = face.ZIndex,
		Parent = face,
	})
	UIKit.Corner(shine, 10)

	local label = UIKit.Text({
		Name = "Label",
		Text = opts.Text or "",
		TextSize = opts.TextSize or 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		ZIndex = face.ZIndex + 1,
		Parent = face,
	})

	local scale = UIKit.New("UIScale", { Parent = holder })

	local button = {
		Instance = holder,
		Face = face,
		Label = label,
		Enabled = true,
	}

	function button.SetText(_self, text: string)
		label.Text = text
	end

	function button.SetColor(_self, newPalette)
		palette = resolvePalette(newPalette)
		if button.Enabled then
			gradient.Color = ColorSequence.new(palette[1], palette[2])
			shadow.BackgroundColor3 = Theme.Darken(palette[2], 0.45)
		end
	end

	function button.SetEnabled(_self, enabled: boolean)
		button.Enabled = enabled
		local colors = if enabled then palette else Theme.Palette.Gray
		gradient.Color = ColorSequence.new(colors[1], colors[2])
		shadow.BackgroundColor3 = Theme.Darken(colors[2], 0.45)
		label.TextColor3 = if enabled then Theme.Text else Color3.fromRGB(232, 228, 242)
	end

	face.MouseEnter:Connect(function()
		if button.Enabled then
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
		end
	end)
	face.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		face.Position = UDim2.new()
	end)
	face.MouseButton1Down:Connect(function()
		if button.Enabled then
			face.Position = UDim2.fromOffset(0, DEPTH - 2)
		end
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.Activated:Connect(function()
		face.Position = UDim2.new()
		if not button.Enabled then
			return
		end
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if UIKit.OnClick then
			UIKit.OnClick()
		end
		if opts.OnClick then
			opts.OnClick()
		end
	end)

	holder.Parent = opts.Parent
	return (button :: any) :: Button
end

-- Bouton carré du menu : grosse icône + libellé
function UIKit.IconButton(opts: Props): Button
	local button = UIKit.Button({
		Name = opts.Name,
		Color = opts.Color,
		Size = opts.Size or UDim2.fromOffset(78, 78),
		LayoutOrder = opts.LayoutOrder,
		OnClick = opts.OnClick,
		Parent = opts.Parent,
		Text = "",
	})
	button.Label.Text = opts.Icon or ""
	button.Label.TextSize = 32
	button.Label.Size = UDim2.new(1, 0, 0.64, 0)
	button.Label.Position = UDim2.fromOffset(0, 3)
	UIKit.Text({
		Name = "Caption",
		Text = opts.Text or "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.new(0, 0, 0.64, 0),
		ZIndex = button.Label.ZIndex,
		Parent = button.Face,
	})
	return button
end

-- Pastille rouge "!" (ou un texte court) dans le coin d'un bouton : attire l'œil
-- vers ce qui est à réclamer. Invisible par défaut.
function UIKit.Badge(button: Button, text: string?): Frame
	local badge = UIKit.New("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = button.Face.ZIndex + 5,
		Parent = button.Instance,
	})
	UIKit.Round(badge)
	UIKit.Stroke(badge, 2.5)
	UIKit.Gradient(badge, Color3.fromRGB(255, 110, 110), Color3.fromRGB(210, 30, 50))
	UIKit.Text({
		Name = "Text",
		Text = text or "!",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = badge.ZIndex + 1,
		Parent = badge,
	})
	return badge
end

-- Champ de saisie arrondi
function UIKit.Input(props: Props): TextBox
	local box = UIKit.New("TextBox", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font,
		TextSize = 24,
		TextColor3 = Theme.TextDark,
		PlaceholderColor3 = Color3.fromRGB(140, 130, 170),
		ClearTextOnFocus = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 56),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(box :: any)[key] = value
		end
	end
	UIKit.Corner(box, 16)
	UIKit.Stroke(box, 3.5)
	UIKit.Gradient(box, Color3.fromRGB(255, 255, 255), Color3.fromRGB(222, 216, 245))
	UIKit.Padding(box, 0, 16, 0, 16)
	box.Parent = props.Parent
	return box
end

---------------------------------------------------------------------------
-- Cartes, pastilles, icônes, barres
---------------------------------------------------------------------------
-- Carte avec dégradé ; "tint" mélange une couleur (ex : rareté) au dégradé
function UIKit.Card(props: Props, tint: Color3?, tintAmount: number?): Frame
	local card = UIKit.New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 80),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(card :: any)[key] = value
		end
	end
	UIKit.Corner(card, 16)
	UIKit.Stroke(card, 3)
	local top, bottom = Theme.CardTop, Theme.CardBottom
	if tint then
		top = top:Lerp(Theme.Lighten(tint, 0.2), tintAmount or 0.35)
		bottom = bottom:Lerp(Theme.Darken(tint, 0.3), tintAmount or 0.35)
	end
	UIKit.Gradient(card, top, bottom)
	card.Parent = props.Parent
	return card
end

-- Cadre creusé (fond sombre) pour regrouper du contenu
function UIKit.Inset(props: Props): Frame
	local inset = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Inset,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(inset :: any)[key] = value
		end
	end
	UIKit.Corner(inset, 16)
	inset.Parent = props.Parent
	return inset
end

-- Pastille arrondie à largeur automatique
function UIKit.Pill(text: string, color: Color3, props: Props?): Frame
	local pill = UIKit.New("Frame", {
		Name = "Pill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	for key, value in pairs(props or {}) do
		if key ~= "Parent" and key ~= "TextSize" then
			(pill :: any)[key] = value
		end
	end
	UIKit.Round(pill)
	UIKit.Stroke(pill, 2.5)
	UIKit.Gradient(pill, Theme.Lighten(color, 0.2), Theme.Darken(color, 0.15))
	UIKit.Padding(pill, 0, 12, 0, 12)
	UIKit.Text({
		Name = "Text",
		Text = text,
		TextSize = (props and props.TextSize) or 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Stroke = 1.6,
		Parent = pill,
	})
	if props and props.Parent then
		pill.Parent = props.Parent
	end
	return pill
end

-- Rond coloré avec une icône (emoji) au centre
function UIKit.IconCircle(icon: string, color: Color3, size: number, props: Props?): Frame
	local circle = UIKit.New("Frame", {
		Name = "Icon",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	})
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			(circle :: any)[key] = value
		end
	end
	UIKit.Round(circle)
	UIKit.Stroke(circle, 3)
	UIKit.Gradient(circle, Theme.Lighten(color, 0.3), Theme.Darken(color, 0.2))
	UIKit.Text({
		Name = "Glyph",
		Text = icon,
		TextSize = math.floor(size * 0.56),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		ZIndex = circle.ZIndex + 1,
		Parent = circle,
	})
	if props and props.Parent then
		circle.Parent = props.Parent
	end
	return circle
end

export type ProgressBar = {
	Instance: Frame,
	SetProgress: (self: ProgressBar, ratio: number) -> (),
	SetText: (self: ProgressBar, text: string) -> (),
	SetColor: (self: ProgressBar, color: Color3) -> (),
}

function UIKit.ProgressBar(props: Props, color: Color3): ProgressBar
	local back = UIKit.New("Frame", {
		Name = "ProgressBar",
		BackgroundColor3 = Theme.Inset,
		Size = UDim2.new(1, 0, 0, 28),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(back :: any)[key] = value
		end
	end
	UIKit.Round(back)
	UIKit.Stroke(back, 3)
	local fill = UIKit.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = back.ZIndex + 1,
		Parent = back,
	})
	UIKit.Round(fill)
	local gradient = UIKit.Gradient(fill, Theme.Lighten(color, 0.3), Theme.Darken(color, 0.15))
	local label = UIKit.Text({
		Name = "Label",
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = back.ZIndex + 2,
		Parent = back,
	})
	back.Parent = props.Parent

	local bar = { Instance = back }
	function bar.SetProgress(_self, ratio: number)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		fill.Visible = ratio > 0.005
	end
	function bar.SetText(_self, text: string)
		label.Text = text
	end
	function bar.SetColor(_self, newColor: Color3)
		gradient.Color = ColorSequence.new(Theme.Lighten(newColor, 0.3), Theme.Darken(newColor, 0.15))
	end
	return (bar :: any) :: ProgressBar
end

---------------------------------------------------------------------------
-- Listes
---------------------------------------------------------------------------
local function scrollFrame(parent: Instance, props: Props?): ScrollingFrame
	local scroll = UIKit.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.TextDim,
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(scroll :: any)[key] = value
	end
	return scroll
end

function UIKit.ScrollList(parent: Instance, props: Props?): ScrollingFrame
	local scroll = scrollFrame(parent, props)
	UIKit.List(scroll, Enum.FillDirection.Vertical, 10)
	UIKit.Padding(scroll, 6, 16, 10, 6)
	return scroll
end

function UIKit.ScrollGrid(parent: Instance, cellSize: UDim2, props: Props?): ScrollingFrame
	local scroll = scrollFrame(parent, props)
	UIKit.New("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	UIKit.Padding(scroll, 6, 16, 10, 6)
	return scroll
end

-- Vide un conteneur en gardant ses objets de mise en page
function UIKit.ClearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIGridStyleLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- Petite animation "pop" (UIScale)
function UIKit.Pop(target: GuiObject, from: number?)
	local scale = target:FindFirstChildOfClass("UIScale") or UIKit.New("UIScale", { Parent = target })
	scale.Scale = from or 0.85
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return UIKit
