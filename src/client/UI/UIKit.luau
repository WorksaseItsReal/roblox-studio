--[[
	UIKit
	=====
	Composants de l'interface v3 « propre » (jetons dans Theme), tous créés par code :
	  Text        texte blanc à contour encre (sur un fond coloré ou sur le monde)
	  Label       texte foncé sans contour (dans les fenêtres et les cartes)
	  Body        texte secondaire gris-bleu (descriptions)
	  Button      bouton d'action : dégradé léger, rebord inférieur plus foncé, contour encre
	  IconButton  tuile blanche du HUD (gros emoji, libellé blanc à contour sous la tuile)
	  Badge       pastille rouge « ! » dans le coin d'un bouton
	  Plate       plaque 3D non cliquable (bandeaux)
	  Card        carte claire à contour fin (teintée quand elle est mise en avant)
	  Pill        pastille colorée (rareté, mutation, revenus)
	  Chip        étiquette d'information neutre
	  IconCircle / IconTile  rond / carré coloré contenant une icône
	  ProgressBar jauge avec texte
	  ScrollList / ScrollGrid
	Règle d'or : une couleur = un sens (voir Theme).
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

-- Copie des propriétés sur une instance (sauf celles listées dans skip)
local function assign(instance: Instance, props: Props?, skip: { [string]: boolean }?)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" and not (skip and skip[key]) then
			(instance :: any)[key] = value
		end
	end
end

---------------------------------------------------------------------------
-- Décorateurs
---------------------------------------------------------------------------
function UIKit.Corner(parent: Instance, radius: number | UDim | nil)
	local value = if typeof(radius) == "UDim"
		then radius
		elseif type(radius) == "number" then UDim.new(0, radius)
		else UDim.new(0, 12)
	return UIKit.New("UICorner", { CornerRadius = value, Parent = parent })
end

function UIKit.Round(parent: Instance)
	return UIKit.New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = parent })
end

-- Contour d'un cadre (encre bleu nuit par défaut)
function UIKit.Stroke(parent: Instance, thickness: number?, color: Color3?, transparency: number?)
	return UIKit.New("UIStroke", {
		Color = color or Theme.Ink,
		Thickness = thickness or 2.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

-- Contour d'un texte (encre bleu nuit)
function UIKit.TextStroke(label: Instance, thickness: number?, color: Color3?)
	return UIKit.New("UIStroke", {
		Color = color or Theme.Ink,
		Thickness = thickness or 1.5,
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

--[[
	Ombre portée douce : deux calques d'encre translucides décalés vers le bas. À placer
	DERRIÈRE l'élément (même parent, ZIndex inférieur, même taille et position).
]]
function UIKit.Shadow(props: Props, radius: number?): Frame
	local corner = radius or 20
	local shadow = UIKit.New("Frame", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	assign(shadow, props)
	for index, layer in { { Offset = 4, Grow = 0, Transparency = 0.78 }, { Offset = 9, Grow = 4, Transparency = 0.86 } } do
		local frame = UIKit.New("Frame", {
			Name = "Layer" .. index,
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = layer.Transparency,
			Position = UDim2.fromOffset(-layer.Grow / 2, layer.Offset),
			Size = UDim2.new(1, layer.Grow, 1, 0),
			ZIndex = shadow.ZIndex,
			Parent = shadow,
		})
		UIKit.Corner(frame, corner + layer.Grow / 2)
	end
	shadow.Parent = props.Parent
	return shadow
end

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
--[[
	Luckiest Guy (Theme.DisplayFont) dessine certaines minuscules autrement que les
	capitales : un texte en casse mixte y paraît cassé. Tout texte dans CETTE police reste
	donc en MAJUSCULES (accents compris), même quand il change plus tard. Fredoka One
	(le reste de l'interface) garde la casse normale.
]]
function UIKit.KeepUpper(label: TextLabel | TextBox)
	local function apply()
		if label.Font ~= Theme.DisplayFont then
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
	Texte blanc à contour encre : boutons, bandeaux colorés, HUD posé sur le monde.
	Props additionnelles :
	  Stroke : épaisseur du contour (0 = aucun ; par défaut 1,5, 2 au-delà de 26 px)
	  Fit    : true = le texte rétrécit s'il est trop long (TextSize = taille maximale)
]]
function UIKit.Text(props: Props): TextLabel
	local strokeThickness = props.Stroke
	local label = UIKit.New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 26),
	})
	assign(label, props, { Stroke = true, Fit = true })
	if strokeThickness ~= 0 then
		local default = if label.Font == Theme.DisplayFont
			then math.clamp(label.TextSize / 12, 2, 5)
			elseif label.TextSize >= 26 then 2
			else 1.5
		UIKit.TextStroke(label, strokeThickness or default)
	end
	if props.Fit then
		UIKit.Fit(label)
	end
	if label.Font == Theme.DisplayFont then
		UIKit.KeepUpper(label)
	end
	label.Parent = props.Parent
	return label
end

-- Texte foncé sans contour : titres et valeurs DANS les fenêtres
function UIKit.Label(props: Props): TextLabel
	local merged: Props = { TextColor3 = Theme.TextDark, Stroke = 0 }
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UIKit.Text(merged)
end

-- Texte secondaire (descriptions) : gris-bleu, sans contour. 16 au minimum (téléphone).
function UIKit.Body(props: Props): TextLabel
	local merged: Props = { TextSize = 16, TextColor3 = Theme.TextMuted, Stroke = 0 }
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UIKit.Text(merged)
end

---------------------------------------------------------------------------
-- Boutons
---------------------------------------------------------------------------
export type Button = {
	Instance: Frame,
	Face: TextButton,
	Label: TextLabel,
	Enabled: boolean,
	SetText: (self: Button, text: string) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	SetColor: (self: Button, palette: any) -> (),
	SetStatus: (self: Button, text: string) -> (),
}

-- Palette { haut, bas, rebord, Light? } (table libre : le champ Light est optionnel)
local function resolvePalette(palette: any): any
	if type(palette) == "table" then
		return palette
	end
	return Theme.Palette[palette or "Blue"] or Theme.Palette.Blue
end

--[[
	opts : Text, Color (clé de Theme.Palette ou {haut, bas, rebord}), Size, Position,
	       AnchorPoint, LayoutOrder, TextSize, OnClick, Parent, ZIndex, Name, Visible,
	       Radius (arrondi : nombre ou UDim, 12 par défaut), Depth (rebord, 4),
	       StrokeThickness (2,5), Fit (false = pas de rétrécissement automatique du texte)
	Structure : Instance (cadre) > Lip (rebord foncé + contour encre) + Face (dégradé) > Label
	Gris (Theme.Palette.Gray) = indisponible pour l'instant (redeviendra cliquable) ;
	SetStatus(texte) = simple statut plat, non cliquable (« ✅ Reçu », « 🔒 2:20 »...) :
	seules les actions possibles ressemblent à des boutons.
]]
function UIKit.Button(opts: Props): Button
	local palette = resolvePalette(opts.Color)
	local radius = opts.Radius or 12
	local depth = opts.Depth or Theme.LipDepth
	local holder = UIKit.New("Frame", {
		Name = opts.Name or "Button",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(150, 48),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = opts.ZIndex or 1,
		Visible = if opts.Visible == nil then true else opts.Visible,
	})
	-- Rebord inférieur plus foncé, et UN SEUL contour encre autour de tout le bouton
	local lip = UIKit.New("Frame", {
		Name = "Lip",
		BackgroundColor3 = Theme.Lip(palette),
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.Corner(lip, radius)
	local lipStroke = UIKit.Stroke(lip, opts.StrokeThickness or 2.5)

	local face = UIKit.New("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	UIKit.Corner(face, radius)
	local gradient = UIKit.Gradient(face, palette[1], palette[2])

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
		Size = UDim2.new(1, -16, 0, math.ceil(textSize * 1.25)),
		Stroke = 1.5,
		ZIndex = face.ZIndex + 1,
		Parent = face,
	})
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
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

	-- Couleurs d'un état : bouton clair = texte foncé sans contour ; bouton indisponible
	-- (gris) = contour du texte adouci, pour qu'il ne paraisse pas cliquable
	local function paint(colors: any)
		gradient.Color = ColorSequence.new(colors[1], colors[2])
		lip.BackgroundColor3 = Theme.Lip(colors)
		lipStroke.Enabled = colors.Flat ~= true
		local light = colors.Light == true
		label.TextColor3 = if colors.Flat then Theme.TextMuted elseif light then Theme.TextDark else Theme.Text
		if labelStroke then
			labelStroke.Enabled = not light
			labelStroke.Transparency = if colors == Theme.Palette.Gray then 0.45 else 0
		end
	end
	paint(palette)

	function button.SetText(_self, text: string)
		label.Text = text
	end

	function button.SetColor(_self, newPalette)
		palette = resolvePalette(newPalette)
		if button.Enabled then
			paint(palette)
		end
	end

	function button.SetEnabled(_self, enabled: boolean)
		button.Enabled = enabled
		paint(if enabled then palette else Theme.Palette.Gray)
	end

	function button.SetStatus(_self, text: string)
		button.Enabled = false
		label.Text = text
		paint(Theme.Palette.Status)
	end

	face.MouseEnter:Connect(function()
		if button.Enabled then
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
		end
	end)
	face.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		face.Position = UDim2.new()
	end)
	face.MouseButton1Down:Connect(function()
		if button.Enabled then
			-- Le dessus s'enfonce dans son rebord
			face.Position = UDim2.fromOffset(0, depth - 1)
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
		scale.Scale = 0.95
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

export type Window = {
	Instance: TextButton,
	Body: Frame,
	Header: Frame,
	Icon: TextLabel,
	Title: TextLabel,
	Close: Button?,
}

-- Hauteur de l'en-tête violet des fenêtres
UIKit.HeaderHeight = 64

--[[
	Fenêtre : corps blanc à contour encre, en-tête violet de marque (icône + titre),
	bouton fermer rond rouge, ombre portée douce.
	Le cadre extérieur est un bouton SANS texte ni effet : il absorbe les clics (un Frame
	les laisse passer jusqu'au fond, et un tap sur une zone vide fermait la fenêtre).
	props : propriétés du cadre (Size, Position, AnchorPoint, ZIndex, Visible, Name...)
	opts  : Title, Icon, OnClose (nil = pas de bouton fermer)
	Le contenu se place dans Instance, avec un ZIndex >= ZIndex de la fenêtre + 2.
]]
function UIKit.Window(props: Props, opts: Props): Window
	local window = UIKit.New("TextButton", {
		Name = "Window",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(760, 520),
	})
	assign(window, props)
	local z = window.ZIndex
	UIKit.Shadow({ ZIndex = z, Parent = window }, 22)
	local body = UIKit.New("Frame", {
		Name = "Body",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = window,
	})
	UIKit.Corner(body, 20)
	UIKit.Stroke(body, 3)
	UIKit.Gradient(body, Theme.WindowTop, Theme.WindowBottom)

	-- En-tête : coins arrondis en haut seulement (un remplissage carré couvre le bas),
	-- rebord plus foncé en bas (même relief que les boutons)
	local height = UIKit.HeaderHeight
	local header = UIKit.New("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = z + 2,
		Parent = window,
	})
	UIKit.Corner(header, 20)
	UIKit.Gradient(header, Theme.Brand, Theme.Brand:Lerp(Theme.BrandDark, 0.6))
	local fill = UIKit.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = z + 2,
		Parent = header,
	})
	UIKit.Gradient(fill, Theme.Brand:Lerp(Theme.BrandDark, 0.38), Theme.Brand:Lerp(Theme.BrandDark, 0.6))
	UIKit.New("Frame", {
		Name = "Lip",
		BackgroundColor3 = Theme.Darken(Theme.BrandDark, 0.18),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = z + 3,
		Parent = header,
	})
	local icon = UIKit.Text({
		Name = "Icon",
		Text = opts.Icon or "⭐",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, -2),
		Size = UDim2.fromOffset(40, 40),
		Stroke = 0,
		ZIndex = z + 3,
		Parent = header,
	})
	local title = UIKit.Text({
		Name = "Title",
		Text = opts.Title or "",
		TextSize = 30,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 64, 0.5, -2),
		Size = UDim2.new(1, -140, 0, 40),
		Stroke = 2,
		Fit = true,
		ZIndex = z + 3,
		Parent = header,
	})

	local close = nil
	if opts.OnClose then
		close = UIKit.Button({
			Name = "Close",
			Text = "X",
			Color = "Red",
			TextSize = 24,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(44, 44),
			Radius = UDim.new(0.5, 0),
			Fit = false,
			ZIndex = z + 4,
			OnClick = opts.OnClose,
			Parent = window,
		})
		close.Label.Position = UDim2.new(0.5, 0, 0.5, 1)
	end

	window.Parent = props.Parent
	return {
		Instance = window,
		Body = body,
		Header = header,
		Icon = icon,
		Title = title,
		Close = close,
	}
end

export type Plate = {
	Instance: Frame,
	Face: Frame,
	SetColor: (self: Plate, palette: any) -> (),
}

--[[
	Plaque 3D non cliquable (bandeaux du HUD) : même relief que les boutons.
	Le contenu se place dans Face.
	props : propriétés du cadre extérieur (Size, Position, AnchorPoint, ZIndex, Name...)
	        + StrokeThickness
]]
function UIKit.Plate(props: Props, palette: any, depth: number?, radius: number?): Plate
	local colors = resolvePalette(palette)
	local lipDepth = depth or 5
	local corner = radius or 16
	local holder = UIKit.New("Frame", {
		Name = "Plate",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 80),
	})
	assign(holder, props, { StrokeThickness = true })
	local lip = UIKit.New("Frame", {
		Name = "Lip",
		BackgroundColor3 = Theme.Lip(colors),
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.Corner(lip, corner)
	UIKit.Stroke(lip, props.StrokeThickness or 3)
	local face = UIKit.New("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -lipDepth),
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	})
	UIKit.Corner(face, corner)
	local gradient = UIKit.Gradient(face, colors[1], colors[2])

	local plate = { Instance = holder, Face = face }
	function plate.SetColor(_self, newPalette)
		local newColors = resolvePalette(newPalette)
		gradient.Color = ColorSequence.new(newColors[1], newColors[2])
		lip.BackgroundColor3 = Theme.Lip(newColors)
	end
	holder.Parent = props.Parent
	return (plate :: any) :: Plate
end

--[[
	Tuile du HUD : carré blanc à contour encre et rebord gris, gros emoji au centre,
	libellé blanc à contour encre à cheval sur le bas de la tuile. Toutes les tuiles
	sont identiques (seuls l'emoji et le libellé changent).
	opts : Name, Icon, Text, Size, IconSize, CaptionSize, LayoutOrder, OnClick, Parent
]]
function UIKit.IconButton(opts: Props): Button
	local button = UIKit.Button({
		Name = opts.Name,
		Color = "White",
		Size = opts.Size or UDim2.fromOffset(72, 72),
		LayoutOrder = opts.LayoutOrder,
		OnClick = opts.OnClick,
		Parent = opts.Parent,
		Text = "",
		Radius = 16,
		Depth = 5,
		StrokeThickness = 3,
		Fit = false,
	})
	local icon = button.Label
	icon.Text = opts.Icon or ""
	icon.TextSize = opts.IconSize or 34
	icon.Size = UDim2.new(1, 0, 1, -6)
	-- Pas de contour sur un emoji
	local iconStroke = icon:FindFirstChildOfClass("UIStroke")
	if iconStroke then
		iconStroke:Destroy()
	end
	UIKit.Text({
		Name = "Caption",
		Text = opts.Text or "",
		TextSize = opts.CaptionSize or 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 1),
		Size = UDim2.new(1, 18, 0, 18),
		Stroke = 1.75,
		Fit = true,
		ZIndex = button.Face.ZIndex + 2,
		Parent = button.Instance,
	})
	return button
end

-- Pastille rouge « ! » (ou un texte court) dans le coin d'un bouton : attire l'œil
-- vers ce qui est à réclamer. Invisible par défaut.
function UIKit.Badge(button: Button, text: string?): Frame
	local badge = UIKit.New("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = button.Face.ZIndex + 5,
		Parent = button.Instance,
	})
	UIKit.Round(badge)
	UIKit.Stroke(badge, 2.5)
	UIKit.Gradient(badge, Theme.Lighten(Theme.Danger, 0.12), Theme.Darken(Theme.Danger, 0.06))
	UIKit.Text({
		Name = "Text",
		Text = text or "!",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 1.5,
		ZIndex = badge.ZIndex + 1,
		Parent = badge,
	})
	return badge
end

-- Champ de saisie : fond clair, texte foncé, contour violet de marque quand il est actif
function UIKit.Input(props: Props): TextBox
	local box = UIKit.New("TextBox", {
		BackgroundColor3 = Theme.Card,
		Font = Theme.Font,
		TextSize = 22,
		TextColor3 = Theme.TextDark,
		PlaceholderColor3 = Theme.TextMuted,
		ClearTextOnFocus = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 52),
	})
	assign(box, props)
	UIKit.Corner(box, 12)
	local stroke = UIKit.Stroke(box, 2.5, Theme.CardStroke)
	UIKit.Padding(box, 0, 16, 0, 16)
	box.Focused:Connect(function()
		stroke.Color = Theme.Brand
	end)
	box.FocusLost:Connect(function()
		stroke.Color = Theme.CardStroke
	end)
	box.Parent = props.Parent
	return box
end

---------------------------------------------------------------------------
-- Cartes, étiquettes, icônes, jauges
---------------------------------------------------------------------------
--[[
	Met une carte en avant (fond très clair teinté + contour de la couleur), ou la
	remet au neutre (tint = nil). amount (0 à 1) dose la teinte du fond.
]]
function UIKit.SetCardTint(card: Frame, tint: Color3?, amount: number?)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if tint then
		card.BackgroundColor3 = Theme.Tint(tint, 0.14 * (amount or 1))
		if stroke then
			stroke.Color = tint
			stroke.Thickness = 2.5
		end
	else
		card.BackgroundColor3 = Theme.Card
		if stroke then
			stroke.Color = Theme.CardStroke
			stroke.Thickness = 2
		end
	end
end

-- Carte claire à contour fin ; "tint" la met en avant (voir SetCardTint)
function UIKit.Card(props: Props, tint: Color3?, tintAmount: number?): Frame
	local card = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Card,
		Size = UDim2.new(1, 0, 0, 80),
	})
	assign(card, props)
	UIKit.Corner(card, 14)
	UIKit.Stroke(card, 2, Theme.CardStroke)
	if tint then
		UIKit.SetCardTint(card, tint, tintAmount)
	end
	card.Parent = props.Parent
	return card
end

-- Zone creusée claire (regroupe du contenu sans contour)
function UIKit.Inset(props: Props): Frame
	local inset = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Well,
		Size = UDim2.fromScale(1, 1),
	})
	assign(inset, props)
	UIKit.Corner(inset, 12)
	inset.Parent = props.Parent
	return inset
end

-- Pastille colorée à largeur automatique : fond de la couleur, texte blanc à contour encre
function UIKit.Pill(text: string, color: Color3, props: Props?): Frame
	local pill = UIKit.New("Frame", {
		Name = "Pill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	assign(pill, props, { TextSize = true })
	UIKit.Corner(pill, 8)
	UIKit.Stroke(pill, 2)
	UIKit.Gradient(pill, Theme.Lighten(color, 0.14), color)
	UIKit.Padding(pill, 0, 9, 0, 9)
	UIKit.Text({
		Name = "Text",
		Text = text,
		TextSize = (props and props.TextSize) or 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Stroke = 1.5,
		ZIndex = pill.ZIndex,
		Parent = pill,
	})
	if props and props.Parent then
		pill.Parent = props.Parent
	end
	return pill
end

-- Étiquette d'information neutre (fond gris-bleu clair, texte foncé), largeur automatique
function UIKit.Chip(text: string, props: Props?): Frame
	local chip = UIKit.New("Frame", {
		Name = "Chip",
		BackgroundColor3 = Theme.Chip,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	assign(chip, props, { TextSize = true })
	UIKit.Corner(chip, 10)
	UIKit.Padding(chip, 0, 12, 0, 12)
	UIKit.Label({
		Name = "Text",
		Text = text,
		TextSize = (props and props.TextSize) or 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = chip.ZIndex,
		Parent = chip,
	})
	if props and props.Parent then
		chip.Parent = props.Parent
	end
	return chip
end

local function iconHolder(shape: "Circle" | "Tile", icon: string, color: Color3, size: number, props: Props?): Frame
	local holder = UIKit.New("Frame", {
		Name = "Icon",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	})
	assign(holder, props)
	if shape == "Circle" then
		UIKit.Round(holder)
	else
		UIKit.Corner(holder, math.floor(size * 0.24))
	end
	UIKit.Stroke(holder, if size >= 64 then 3 else 2.5)
	UIKit.Gradient(holder, Theme.Lighten(color, 0.3), color)
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

-- Jauge : fond creusé, remplissage de la couleur du sens, texte blanc à contour
function UIKit.ProgressBar(props: Props, color: Color3): ProgressBar
	local back = UIKit.New("Frame", {
		Name = "ProgressBar",
		BackgroundColor3 = Theme.Well,
		Size = UDim2.new(1, 0, 0, 28),
	})
	assign(back, props)
	local radius = math.floor(math.min(10, back.Size.Y.Offset / 2))
	UIKit.Corner(back, radius)
	UIKit.Stroke(back, 2)
	local fill = UIKit.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = back.ZIndex + 1,
		Parent = back,
	})
	UIKit.Corner(fill, radius)
	local gradient = UIKit.Gradient(fill, Theme.Lighten(color, 0.16), color)
	local label = UIKit.Text({
		Name = "Label",
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Stroke = 1.5,
		ZIndex = back.ZIndex + 2,
		Parent = back,
	})
	UIKit.Fit(label, 15)
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
		gradient.Color = ColorSequence.new(Theme.Lighten(newColor, 0.16), newColor)
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
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(176, 185, 205),
		ScrollBarImageTransparency = 0,
		Parent = parent,
	})
	assign(scroll, props)
	return scroll
end

-- Marges intérieures des listes : de quoi ne pas couper les contours (et les pulsations)
local SCROLL_PADDING = { 5, 14, 10, 5 }

--[[
	Position et taille d'une zone défilante qui commence à "top" dans le contenu d'une
	fenêtre : les cartes s'alignent exactement sur les bords du contenu (marges
	intérieures comprises) et la barre de défilement tombe dans la marge de droite.
]]
function UIKit.ScrollArea(top: number): Props
	local outerTop = top - SCROLL_PADDING[1]
	return {
		Position = UDim2.fromOffset(-SCROLL_PADDING[4], outerTop),
		Size = UDim2.new(1, SCROLL_PADDING[2] + SCROLL_PADDING[4], 1, SCROLL_PADDING[3] - outerTop),
	}
end

function UIKit.ScrollList(parent: Instance, props: Props?): ScrollingFrame
	local scroll = scrollFrame(parent, props)
	UIKit.List(scroll, Enum.FillDirection.Vertical, 10)
	UIKit.Padding(scroll, table.unpack(SCROLL_PADDING))
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
	UIKit.Padding(scroll, table.unpack(SCROLL_PADDING))
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
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or 0.04) }
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
