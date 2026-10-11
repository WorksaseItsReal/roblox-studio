--[[
	NameTagService
	==============
	Étiquette au-dessus de chaque joueur : titre (selon les rebirths), pseudo,
	nombre de vols et de rebirths. Le statut visible de tous est un puissant
	moteur de progression ("je veux le même titre que lui").
	Créée par le serveur : visible par tous les joueurs.

	Même langage visuel que les étiquettes des créatures (docs/ART_DIRECTION.md) :
	contours noirs épais, titre en Luckiest Guy dans une pastille au dégradé vif,
	pseudo en Fredoka One blanc, statistiques en jaune-or.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Modules.Economy)
local Format = require(ReplicatedStorage.Shared.Modules.Format)

local NameTagService = {}

local Services

local INK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 215, 40)

local function stroke(parent: Instance, thickness: number, mode: Enum.ApplyStrokeMode?)
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

local function label(parent: Instance, name: string, order: number, size: number, font: Enum.Font, color: Color3)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0, size + 4)
	text.Font = font
	text.TextSize = size
	text.TextColor3 = color
	text.Text = ""
	text.Parent = parent
	stroke(text, 2.5)
	return text
end

local function build(head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(280, 90)
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

	-- Pastille de titre : dégradé vif, reflet en haut, contour noir épais
	local holder = Instance.new("Frame")
	holder.Name = "TitleHolder"
	holder.LayoutOrder = 1
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 28)
	holder.Parent = gui
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.Size = UDim2.fromOffset(0, 28)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = WHITE
	pill.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	stroke(pill, 3, Enum.ApplyStrokeMode.Border)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Rotation = 90
	gradient.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = pill
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.new(0.5, 0, 0, 3)
	shine.Size = UDim2.new(1, 6, 0.36, 0)
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Parent = pill
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(0.5, 0)
	shineCorner.Parent = shine
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0, 1)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 17
	title.TextColor3 = WHITE
	title.ZIndex = 2
	title.Parent = pill
	stroke(title, 2)

	label(gui, "PlayerName", 2, 24, Enum.Font.FredokaOne, WHITE)
	label(gui, "Stats", 3, 16, Enum.Font.FredokaOne, GOLD)
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
	-- Dégradé vif : clair en haut, couleur saturée au milieu, plus sombre en bas
	local hue, saturation, value = titleInfo.Color:ToHSV()
	local vivid = Color3.fromHSV(hue, math.min(1, saturation * 1.25), value)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, vivid:Lerp(WHITE, 0.35)),
		ColorSequenceKeypoint.new(0.5, vivid),
		ColorSequenceKeypoint.new(1, vivid:Lerp(INK, 0.22)),
	});
	(pill:FindFirstChild("Title") :: TextLabel).Text = Format.Upper(titleInfo.Name);
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
