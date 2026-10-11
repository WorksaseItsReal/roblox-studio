--[[
	BoardController
	===============
	Remplit les deux tableaux de classement géants à côté de la Rift
	(Map.Boards.MoneyBoard / StealsBoard) avec le top 10 global.
	Voir son nom affiché en grand dans le monde motive énormément.

	Style « Steal a … » : lignes bleu foncé à contour noir, pastille de rang
	(or / argent / bronze pour le podium), montants en Luckiest Guy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Net = require(script.Parent.Net)

local BoardController = {}

local ROWS = 10
local INK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 215, 40)
local MONEY = Color3.fromRGB(80, 255, 90)
local DANGER = Color3.fromRGB(255, 90, 90)
local ROW_COLORS = { Color3.fromRGB(18, 52, 140), Color3.fromRGB(26, 66, 168) }
-- Pastilles du podium : or, argent, bronze
local PODIUM = { Color3.fromRGB(255, 200, 30), Color3.fromRGB(205, 215, 230), Color3.fromRGB(230, 130, 50) }
local LUCKIEST = Font.fromEnum(Enum.Font.LuckiestGuy)
local FREDOKA = Font.fromEnum(Enum.Font.FredokaOne)

local function addStroke(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

local function addCorner(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function makeLabel(
	parent: Instance,
	text: string,
	xScale: number,
	width: number,
	align: Enum.TextXAlignment,
	color: Color3,
	font: Font
)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(xScale, 0.1)
	label.Size = UDim2.fromScale(width, 0.8)
	label.FontFace = font
	label.TextScaled = true
	label.TextXAlignment = align
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	addStroke(label, 2.5)
	return label
end

-- Reconstruit les lignes d'un tableau. Fonction pure (aucun service) : elle sert
-- aussi aux aperçus de la map hors Roblox.
function BoardController.Fill(board: Instance?, entries: { any }?, isMoney: boolean, localUserId: number?)
	local gui = board and board:FindFirstChild("BoardGui")
	local rows = gui and gui:FindFirstChild("Rows", true)
	if not rows then
		return
	end
	for _, child in rows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for rank = 1, ROWS do
		local entry = entries and entries[rank]
		local isMe = entry ~= nil and localUserId ~= nil and entry.UserId == localUserId
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.LayoutOrder = rank
		-- Hauteur relative : s'adapte à la taille du tableau (10 lignes + espacements)
		row.Size = UDim2.new(1, 0, 1 / ROWS, -5)
		row.BackgroundColor3 = ROW_COLORS[rank % 2 + 1]
		row.Parent = rows
		addCorner(row, UDim.new(0, 12))
		local rowStroke = addStroke(row, if isMe then 3.5 else 2.5)
		rowStroke.Color = if isMe then GOLD else INK

		-- Pastille de rang
		local badge = Instance.new("Frame")
		badge.Name = "Rank"
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 6, 0.5, 0)
		badge.Size = UDim2.new(0.085, 0, 0.82, 0)
		badge.BackgroundColor3 = PODIUM[rank] or Color3.fromRGB(10, 30, 90)
		badge.Parent = row
		addCorner(badge, UDim.new(0.5, 0))
		addStroke(badge, 2.5)
		local number = Instance.new("TextLabel")
		number.BackgroundTransparency = 1
		number.Size = UDim2.fromScale(1, 1)
		number.FontFace = LUCKIEST
		number.TextScaled = true
		number.TextColor3 = WHITE
		number.Text = tostring(rank)
		number.Parent = badge
		addStroke(number, 2)

		makeLabel(
			row,
			if entry then entry.Name else "—",
			0.12,
			0.52,
			Enum.TextXAlignment.Left,
			if isMe then GOLD else WHITE,
			FREDOKA
		)
		local value = if not entry then "" elseif isMoney then Format.Money(entry.Value) else tostring(entry.Value)
		makeLabel(row, value, 0.64, 0.34, Enum.TextXAlignment.Right, if isMoney then MONEY else DANGER, LUCKIEST)
	end
end

function BoardController.Start()
	local map = workspace:WaitForChild("Map")
	local boards = map:WaitForChild("Boards", 30)
	if not boards then
		return
	end
	local moneyBoard = boards:WaitForChild("MoneyBoard", 10)
	local stealsBoard = boards:WaitForChild("StealsBoard", 10)
	local userId = Players.LocalPlayer.UserId

	local function apply(data)
		if type(data) ~= "table" then
			return
		end
		BoardController.Fill(moneyBoard, data.Money, true, userId)
		BoardController.Fill(stealsBoard, data.Steals, false, userId)
	end

	Remotes.GetEvent("LeaderboardUpdated").OnClientEvent:Connect(apply)
	BoardController.Fill(moneyBoard, nil, true, userId)
	BoardController.Fill(stealsBoard, nil, false, userId)
	task.delay(12, function()
		local response = Net.Invoke("GetLeaderboard")
		if response.Ok then
			apply(response.Data)
		end
	end)
end

return BoardController
