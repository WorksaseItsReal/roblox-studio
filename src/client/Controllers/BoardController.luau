--[[
	BoardController
	===============
	Remplit les deux tableaux de classement géants à côté de la Rift
	(Map.Boards.MoneyBoard / StealsBoard) avec le top 10 global.
	Voir son nom affiché en grand dans le monde motive énormément.

	Style v3 (docs/ART_DIRECTION.md) : fenêtre blanche, lignes en cartes claires à
	texte foncé, pastille de rang (or / argent / bronze pour le podium), montants
	en Luckiest Guy (vert pour l'argent, rouge pour les vols), contours encre bleu
	nuit (jamais de noir pur). La ligne du joueur local est liserée d'or.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Net = require(script.Parent.Net)

local BoardController = {}

local ROWS = 10
local INK = Color3.fromRGB(28, 31, 58)
local WHITE = Color3.fromRGB(255, 255, 255)
local TEXT_DARK = Color3.fromRGB(31, 37, 68)
local TEXT_MUTED = Color3.fromRGB(110, 118, 150)
local BRAND = Color3.fromRGB(91, 63, 224)
local GOLD = Color3.fromRGB(255, 201, 60)
local MONEY = Color3.fromRGB(31, 165, 68)
local DANGER = Color3.fromRGB(226, 56, 64)
-- Cartes claires alternées, contour gris-bleu (jetons « Carte » de l'interface)
local ROW_COLORS = { Color3.fromRGB(244, 246, 251), Color3.fromRGB(233, 237, 246) }
local ROW_STROKE = Color3.fromRGB(217, 223, 234)
-- Pastilles du podium : or, argent, bronze ; les autres rangs en gris-bleu
local PODIUM = { Color3.fromRGB(255, 196, 40), Color3.fromRGB(176, 188, 206), Color3.fromRGB(222, 132, 62) }
local RANK_DEFAULT = Color3.fromRGB(201, 207, 219)
local LUCKIEST = Font.fromEnum(Enum.Font.LuckiestGuy)
local FREDOKA = Font.fromEnum(Enum.Font.FredokaOne)

local function addStroke(parent: Instance, thickness: number, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or INK
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

-- Texte foncé sans contour (sur carte claire)
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
	label.Position = UDim2.fromScale(xScale, 0.14)
	label.Size = UDim2.fromScale(width, 0.72)
	label.FontFace = font
	label.TextScaled = true
	label.TextXAlignment = align
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
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
		addStroke(row, if isMe then 4 else 2, if isMe then GOLD else ROW_STROKE)

		-- Pastille de rang
		local badge = Instance.new("Frame")
		badge.Name = "Rank"
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 6, 0.5, 0)
		badge.Size = UDim2.new(0.085, 0, 0.82, 0)
		badge.BackgroundColor3 = PODIUM[rank] or RANK_DEFAULT
		badge.Parent = row
		addCorner(badge, UDim.new(0.5, 0))
		addStroke(badge, 2)
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
			if not entry then TEXT_MUTED elseif isMe then BRAND else TEXT_DARK,
			FREDOKA
		)
		local value = if not entry then "" elseif isMoney then Format.Money(entry.Value) else tostring(entry.Value)
		makeLabel(row, value, 0.62, 0.35, Enum.TextXAlignment.Right, if isMoney then MONEY else DANGER, LUCKIEST)
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
