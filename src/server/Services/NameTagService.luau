--[[
	NameTagService
	==============
	Étiquette au-dessus de chaque joueur : titre (selon les rebirths), pseudo,
	nombre de vols et de rebirths. Le statut visible de tous est un puissant
	moteur de progression ("je veux le même titre que lui").
	Créée par le serveur : visible par tous les joueurs.

	Même langage visuel que les étiquettes des créatures (docs/ART_DIRECTION.md) :
	tout en Fredoka One en casse normale, contours encre bleu nuit (jamais noirs),
	titre dans une pastille de la couleur du titre (léger dégradé, contour encre),
	pseudo blanc, statistiques en or « Récompense ».
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Modules.Economy)

local NameTagService = {}

local Services

local INK = Color3.fromRGB(28, 31, 58) -- encre bleu nuit (contours)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 201, 60) -- jeton « Récompense »
local FONT = Enum.Font.FredokaOne
local PILL_HEIGHT = 26

local function stroke(parent: Instance, thickness: number, mode: Enum.ApplyStrokeMode?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	if mode then
		s.ApplyStrokeMode = mode
	end
	s.Parent = parent
	return s
end

local function label(parent: Instance, name: string, order: number, size: number, color: Color3, outline: number)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0, size + 4)
	text.Font = FONT
	text.TextSize = size
	text.TextColor3 = color
	text.Text = ""
	text.Parent = parent
	stroke(text, outline)
	return text
end

-- Luminance perçue (0..1) : texte bleu nuit sur les pastilles claires, blanc sinon
local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function build(head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(280, 84)
	-- Le bas de l'étiquette est posé 1,6 stud au-dessus de la tête (SizeOffset Y positif =
	-- vers le haut, en fraction de la taille) : taille fixe en pixels, elle ne descend
	-- jamais sur l'avatar quand il s'éloigne
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 2)
	layout.Parent = gui

	-- Pastille de titre : couleur du titre en léger dégradé (haut un peu plus clair),
	-- coins ronds, contour encre ; largeur automatique selon le titre
	local holder = Instance.new("Frame")
	holder.Name = "TitleHolder"
	holder.LayoutOrder = 1
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, PILL_HEIGHT + 4)
	holder.Parent = gui
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = WHITE
	pill.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	stroke(pill, 2.5, Enum.ApplyStrokeMode.Border)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Rotation = 90
	gradient.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = pill
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0, 1)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Font = FONT
	title.TextSize = 16
	title.TextColor3 = WHITE
	title.ZIndex = 2
	title.Parent = pill
	stroke(title, 1.5).Name = "TitleStroke"

	label(gui, "PlayerName", 2, 24, WHITE, 2)
	label(gui, "Stats", 3, 15, GOLD, 1.5)
	gui.Parent = head
	return gui
end

function NameTagService.Refresh(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local data = Services.DataService.GetData(player)
	if not head or not head:IsA("BasePart") or not data then
		return
	end
	local gui = head:FindFirstChild("NameTag") :: BillboardGui?
	if not gui then
		gui = build(head)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local nameTag = gui :: BillboardGui
	local titleInfo = Economy.GetTitle(data.Rebirths)
	local pill = nameTag:FindFirstChild("TitleHolder"):FindFirstChild("Pill")
	local gradient = pill:FindFirstChild("Gradient") :: UIGradient
	-- Léger dégradé : haut un peu plus clair, bas un peu plus soutenu (couleur maîtrisée)
	local color = titleInfo.Color
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.2)),
		ColorSequenceKeypoint.new(0.55, color),
		ColorSequenceKeypoint.new(1, color:Lerp(INK, 0.1)),
	})
	-- Pastille claire (Novice, Maître des dimensions...) : texte bleu nuit sans contour ;
	-- pastille soutenue : texte blanc à contour encre
	local light = luminance(color) > 0.66
	local title = pill:FindFirstChild("Title") :: TextLabel
	title.Text = titleInfo.Name
	title.TextColor3 = if light then INK else WHITE
	local titleStroke = title:FindFirstChild("TitleStroke") :: UIStroke
	titleStroke.Enabled = not light;
	(nameTag:FindFirstChild("PlayerName") :: TextLabel).Text = player.DisplayName;
	(nameTag:FindFirstChild("Stats") :: TextLabel).Text =
		string.format("🦹 %d vols  •  🔁 %d", data.Stats.Steals, data.Rebirths)
end

function NameTagService.Init(services)
	Services = services
end

function NameTagService.Start()
	local function setup(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			NameTagService.Refresh(player)
		end)
		if player.Character then
			task.spawn(NameTagService.Refresh, player)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Services.DataService.ProfileLoaded:Connect(function(player: Player)
		NameTagService.Refresh(player)
	end)
end

return NameTagService
