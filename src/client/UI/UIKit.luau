--[[
	UIKit
	=====
	Composants d'interface style « Steal a … », tous créés par code :
	  Text        gros texte (Luckiest Guy) avec contour noir épais
	  Body        texte courant (Fredoka One) avec contour noir fin
	  Button      bouton 3D (dégradé vif, rebord inférieur foncé, contour noir, appui)
	  IconButton  tuile carrée du menu (grosse icône + libellé)
	  Card        carte claire (ou teintée d'une couleur vive) avec contour noir
	  Pill        étiquette aux coins arrondis (rareté, statut...)
	  IconCircle  rond coloré contenant une icône
	  IconTile    carré arrondi coloré contenant une icône
	  ProgressBar barre de progression brillante avec texte
	  ScrollList / ScrollGrid
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Modules.Format)
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

-- Contour d'un cadre (noir pur par défaut)
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

-- Reflet brillant (bande blanche translucide en haut d'un élément)
function UIKit.Shine(parent: GuiObject, radius: number?, transparency: number?, height: number?): Frame
	local shine = UIKit.New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = transparency or 0.72,
		Position = UDim2.fromOffset(5, 3),
		Size = UDim2.new(1, -10, height or 0.32, 0),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	UIKit.Corner(shine, math.max(2, (radius or 12) - 4))
	return shine
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
--[[
	Luckiest Guy dessine certaines minuscules (e, m, n...) autrement que les capitales :
	un texte en casse mixte paraît cassé ("INDeX"). Tout texte dans cette police reste
	donc en MAJUSCULES (accents compris), y compris quand il change plus tard
	(minuteurs, SetText, messages du serveur). Les autres polices ne sont pas touchées.
]]
function UIKit.KeepUpper(label: TextLabel | TextBox)
	local function apply()
		if label.Font ~= Theme.Font then
			return
		end
		local upper = Format.Upper(label.Text)
		if upper == label.Text then
			return
		end
		if label:IsA("TextBox") then
			-- Même longueur en octets : le curseur de saisie reste à sa place
			local cursor = label.CursorPosition
			label.Text = upper
			label.CursorPosition = cursor
		else
			label.Text = upper
		end
	end
	apply()
	label:GetPropertyChangedSignal("Text"):Connect(apply)
end

-- Rétrécit le texte s'il ne tient pas dans son cadre (jamais plus grand que maxSize)
function UIKit.Fit(label: TextLabel, maxSize: number?, minSize: number?)
	label.TextScaled = true
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		or UIKit.New("UITextSizeConstraint", { Parent = label })
	constraint.MaxTextSize = math.floor(maxSize or label.TextSize)
	constraint.MinTextSize = math.floor(minSize or 8)
	return constraint
end

--[[
	Props additionnelles :
	  Stroke : épaisseur du contour noir (0 = aucun)
	  Fit    : true = le texte rétrécit s'il est trop long (TextSize = taille maximale)
]]
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
		if key ~= "Stroke" and key ~= "Parent" and key ~= "Fit" then
			(label :: any)[key] = value
		end
	end
	if strokeThickness ~= 0 then
		UIKit.TextStroke(label, strokeThickness or math.clamp(label.TextSize / 9, 1.5, 5))
	end
	if props.Fit then
		UIKit.Fit(label)
	end
	if label.Font == Theme.Font then
		UIKit.KeepUpper(label)
	end
	label.Parent = props.Parent
	return label
end

-- Texte courant (descriptions) : Fredoka One, contour noir fin. 16 au minimum :
-- lisible sur téléphone, où l'interface est réduite d'environ 40 %.
function UIKit.Body(props: Props): TextLabel
	local size = props.TextSize or 16
	local merged: Props = {
		Font = Theme.BodyFont,
		TextSize = size,
		TextColor3 = Theme.TextDim,
		Stroke = math.max(1, size / 12),
	}
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
	       AnchorPoint, LayoutOrder, TextSize, OnClick, Parent, ZIndex, Name,
	       Radius (arrondi, 12 par défaut), Fit (false = pas de rétrécissement auto)
	Structure : Instance (cadre) > Shadow (socle foncé + contour noir) + Face (dégradé)
]]
function UIKit.Button(opts: Props): Button
	local palette = resolvePalette(opts.Color)
	local radius = opts.Radius or 12
	local holder = UIKit.New("Frame", {
		Name = opts.Name or "Button",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(150, 50),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = opts.ZIndex or 1,
	})
	-- Socle : rebord inférieur plus foncé, et UN SEUL contour noir autour du bouton
	local shadow = UIKit.New("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Lip(palette),
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.Corner(shadow, radius)
	UIKit.Stroke(shadow, opts.StrokeThickness or 3.5)

	local face = UIKit.New("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -DEPTH),
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	UIKit.Corner(face, radius)
	local gradient = UIKit.Gradient(face, palette[1], palette[2])
	UIKit.Shine(face, radius, 0.74, 0.3)

	local textSize = opts.TextSize or 20
	local label = UIKit.Text({
		Name = "Label",
		Text = opts.Text or "",
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		-- Hauteur limitée à une ligne : un texte trop long rétrécit au lieu de passer à la ligne
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 0, math.ceil(textSize * 1.3)),
		Stroke = math.clamp(textSize / 8, 1.8, 3.5),
		ZIndex = face.ZIndex + 1,
		Parent = face,
	})
	if opts.Fit ~= false then
		UIKit.Fit(label, textSize)
	end

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
			shadow.BackgroundColor3 = Theme.Lip(palette)
		end
	end

	function button.SetEnabled(_self, enabled: boolean)
		button.Enabled = enabled
		local colors = if enabled then palette else Theme.Palette.Gray
		gradient.Color = ColorSequence.new(colors[1], colors[2])
		shadow.BackgroundColor3 = Theme.Lip(colors)
		label.TextColor3 = if enabled then Theme.Text else Color3.fromRGB(236, 240, 248)
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
			-- Le dessus s'enfonce dans son socle
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

export type Plate = {
	Instance: Frame,
	Face: Frame,
	SetColor: (self: Plate, palette: any) -> (),
}

--[[
	Plaque 3D non cliquable (bandeaux, cartes du HUD, fenêtres surgissantes) :
	même relief que les boutons. Le contenu se place dans Face.
	props : propriétés du cadre extérieur (Size, Position, AnchorPoint, ZIndex, Name...)
]]
function UIKit.Plate(props: Props, palette: any, depth: number?, radius: number?): Plate
	local colors = resolvePalette(palette)
	local lipDepth = depth or DEPTH
	local corner = radius or 16
	local holder = UIKit.New("Frame", {
		Name = "Plate",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 80),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "StrokeThickness" then
			(holder :: any)[key] = value
		end
	end
	local shadow = UIKit.New("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Lip(colors),
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.Corner(shadow, corner)
	UIKit.Stroke(shadow, props.StrokeThickness or 4)
	local face = UIKit.New("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -lipDepth),
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	UIKit.Corner(face, corner)
	local gradient = UIKit.Gradient(face, colors[1], colors[2])
	UIKit.Shine(face, corner, 0.78, 0.3)

	local plate = { Instance = holder, Face = face }
	function plate.SetColor(_self, newPalette)
		local newColors = resolvePalette(newPalette)
		gradient.Color = ColorSequence.new(newColors[1], newColors[2])
		shadow.BackgroundColor3 = Theme.Lip(newColors)
	end
	holder.Parent = props.Parent
	return (plate :: any) :: Plate
end

-- Tuile carrée du menu : grosse icône + libellé en bas (style « Steal a … »)
function UIKit.IconButton(opts: Props): Button
	local button = UIKit.Button({
		Name = opts.Name,
		Color = opts.Color,
		Size = opts.Size or UDim2.fromOffset(78, 78),
		LayoutOrder = opts.LayoutOrder,
		OnClick = opts.OnClick,
		Parent = opts.Parent,
		Text = "",
		Radius = 14,
		Fit = false,
	})
	local icon = button.Label
	icon.Text = opts.Icon or ""
	icon.TextSize = opts.IconSize or 34
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 5)
	icon.Size = UDim2.new(1, 0, 0.6, 0)
	-- Pas de contour sur un emoji
	local iconStroke = icon:FindFirstChildOfClass("UIStroke")
	if iconStroke then
		iconStroke:Destroy()
	end
	UIKit.Text({
		Name = "Caption",
		Text = opts.Text or "",
		TextSize = opts.CaptionSize or 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -6, 0, 20),
		Stroke = 2,
		Fit = true,
		ZIndex = icon.ZIndex,
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
		Position = UDim2.new(1, -6, 0, 5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = button.Face.ZIndex + 5,
		Parent = button.Instance,
	})
	UIKit.Round(badge)
	UIKit.Stroke(badge, 3)
	UIKit.Gradient(badge, Color3.fromRGB(255, 100, 100), Color3.fromRGB(214, 16, 36))
	UIKit.Text({
		Name = "Text",
		Text = text or "!",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 2,
		ZIndex = badge.ZIndex + 1,
		Parent = badge,
	})
	return badge
end

-- Champ de saisie : fond blanc, gros texte, contour noir
function UIKit.Input(props: Props): TextBox
	local box = UIKit.New("TextBox", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font,
		TextSize = 24,
		TextColor3 = Theme.TextDark,
		PlaceholderColor3 = Color3.fromRGB(128, 150, 196),
		ClearTextOnFocus = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 56),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(box :: any)[key] = value
		end
	end
	UIKit.Corner(box, 14)
	UIKit.Stroke(box, 3.5)
	UIKit.Gradient(box, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 230, 255))
	UIKit.Padding(box, 0, 16, 0, 16)
	-- Saisie en majuscules (les codes sont normalisés en majuscules par le serveur)
	UIKit.KeepUpper(box)
	box.Parent = props.Parent
	return box
end

---------------------------------------------------------------------------
-- Cartes, étiquettes, icônes, barres
---------------------------------------------------------------------------
--[[
	Carte claire avec contour noir. "tint" donne à la carte une couleur vive (rareté,
	récompense...) ; tintAmount (0 à 1, 1 par défaut) dose le mélange avec le bleu clair.
]]
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
	UIKit.Corner(card, 14)
	UIKit.Stroke(card, 3)
	local top, bottom = Theme.CardTop, Theme.CardBottom
	if tint then
		local amount = tintAmount or 1
		top = top:Lerp(Theme.Lighten(tint, 0.28), amount)
		bottom = bottom:Lerp(Theme.Darken(tint, 0.12), amount)
	end
	UIKit.Gradient(card, top, bottom)
	card.Parent = props.Parent
	return card
end

-- Cadre creusé (bleu nuit) pour regrouper du contenu
function UIKit.Inset(props: Props): Frame
	local inset = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Inset,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
	})
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(inset :: any)[key] = value
		end
	end
	UIKit.Corner(inset, 14)
	inset.Parent = props.Parent
	return inset
end

-- Étiquette colorée à largeur automatique (coins arrondis moyens, contour noir)
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
	UIKit.Corner(pill, 8)
	UIKit.Stroke(pill, 2.5)
	-- Couleur franche (une mutation pastel devient vive), les gris restent gris
	local vivid = Theme.Vivid(color)
	UIKit.Gradient(pill, Theme.Lighten(vivid, 0.2), Theme.Darken(vivid, 0.18))
	UIKit.Padding(pill, 0, 10, 0, 10)
	local textSize = (props and props.TextSize) or 15
	UIKit.Text({
		Name = "Text",
		Text = text,
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Stroke = math.clamp(textSize / 8, 1.6, 2.6),
		Parent = pill,
	})
	if props and props.Parent then
		pill.Parent = props.Parent
	end
	return pill
end

local function iconHolder(shape: "Circle" | "Tile", icon: string, color: Color3, size: number, props: Props?): Frame
	local holder = UIKit.New("Frame", {
		Name = "Icon",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	})
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			(holder :: any)[key] = value
		end
	end
	if shape == "Circle" then
		UIKit.Round(holder)
	else
		UIKit.Corner(holder, math.floor(size * 0.2))
	end
	UIKit.Stroke(holder, if size >= 60 then 3.5 else 3)
	UIKit.Gradient(holder, Theme.Lighten(color, 0.32), Theme.Darken(color, 0.15))
	UIKit.Text({
		Name = "Glyph",
		Text = icon,
		TextSize = math.floor(size * 0.56),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	if props and props.Parent then
		holder.Parent = props.Parent
	end
	return holder
end

-- Rond coloré avec une icône (emoji) au centre
function UIKit.IconCircle(icon: string, color: Color3, size: number, props: Props?): Frame
	return iconHolder("Circle", icon, color, size, props)
end

-- Carré arrondi coloré avec une icône (emoji) au centre
function UIKit.IconTile(icon: string, color: Color3, size: number, props: Props?): Frame
	return iconHolder("Tile", icon, color, size, props)
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
	UIKit.Corner(back, 9)
	UIKit.Stroke(back, 3)
	local fill = UIKit.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = back.ZIndex + 1,
		Parent = back,
	})
	UIKit.Corner(fill, 9)
	local gradient = UIKit.Gradient(fill, Theme.Lighten(color, 0.3), Theme.Darken(color, 0.12))
	UIKit.Shine(fill, 9, 0.6, 0.34)
	local label = UIKit.Text({
		Name = "Label",
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Stroke = 2,
		ZIndex = back.ZIndex + 2,
		Parent = back,
	})
	UIKit.Fit(label, 16)
	back.Parent = props.Parent

	local bar = { Instance = back, Label = label }
	function bar.SetProgress(_self, ratio: number)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		fill.Visible = ratio > 0.005
	end
	function bar.SetText(_self, text: string)
		label.Text = text
	end
	function bar.SetColor(_self, newColor: Color3)
		gradient.Color = ColorSequence.new(Theme.Lighten(newColor, 0.3), Theme.Darken(newColor, 0.12))
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
		ScrollBarImageColor3 = Theme.Inset,
		ScrollBarImageTransparency = 0.1,
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

-- Pulsations en cours (clé faible : un élément détruit est oublié)
local pulses: { [GuiObject]: Tween } = setmetatable({}, { __mode = "k" }) :: any

--[[
	Pulsation douce et continue (ce qui est à réclamer attire l'œil). enabled = false
	l'arrête et remet l'échelle à 1. Le cadre doit être centré sur son AnchorPoint
	(0.5, 0.5) pour grossir depuis son centre.
]]
function UIKit.Pulse(target: GuiObject, enabled: boolean, amount: number?)
	local running = pulses[target]
	if enabled == (running ~= nil) then
		return
	end
	local scale = target:FindFirstChildOfClass("UIScale") or UIKit.New("UIScale", { Parent = target })
	if running then
		running:Cancel()
		pulses[target] = nil
		scale.Scale = 1
		return
	end
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or 0.05) }
	)
	pulses[target] = tween
	tween:Play()
end

-- Petite animation "pop" (UIScale)
function UIKit.Pop(target: GuiObject, from: number?)
	local scale = target:FindFirstChildOfClass("UIScale") or UIKit.New("UIScale", { Parent = target })
	scale.Scale = from or 0.85
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return UIKit
