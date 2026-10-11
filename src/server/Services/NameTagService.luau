--[[
	NameTagService
	==============
	Étiquette au-dessus de chaque joueur : titre (selon les rebirths), pseudo,
	nombre de vols et de rebirths. Le statut visible de tous est un puissant
	moteur de progression ("je veux le même titre que lui").
	Créée par le serveur : visible par tous les joueurs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Modules.Economy)

local NameTagService = {}

local Services

local INK = Color3.fromRGB(26, 16, 48)

local function stroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.Parent = parent
end

local function label(parent: Instance, name: string, order: number, size: number, color: Color3)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0, size + 4)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = size
	text.TextColor3 = color
	text.Text = ""
	text.Parent = parent
	stroke(text, 2)
	return text
end

local function build(head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(240, 78)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 1)
	layout.Parent = gui

	-- Pastille de titre
	local holder = Instance.new("Frame")
	holder.Name = "TitleHolder"
	holder.LayoutOrder = 1
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 24)
	holder.Parent = gui
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.Size = UDim2.fromOffset(0, 24)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	stroke(pill, 2)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Rotation = 90
	gradient.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = pill
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0, 1)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 15
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = pill
	stroke(title, 1.5)

	label(gui, "PlayerName", 2, 22, Color3.new(1, 1, 1))
	label(gui, "Stats", 3, 15, Color3.fromRGB(255, 214, 70))
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
	gradient.Color = ColorSequence.new(
		titleInfo.Color:Lerp(Color3.new(1, 1, 1), 0.25),
		titleInfo.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	);
	(pill:FindFirstChild("Title") :: TextLabel).Text = titleInfo.Name;
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
