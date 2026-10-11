--[[
	BoardController
	===============
	Remplit les deux tableaux de classement géants de l'esplanade
	(Map.Boards.MoneyBoard / StealsBoard) avec le top 10 global.
	Voir son nom affiché en grand dans le monde motive énormément.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Net = require(script.Parent.Net)

local BoardController = {}

local ROWS = 10
local MEDALS = { "🥇", "🥈", "🥉" }
local INK = Color3.fromRGB(16, 10, 34)

local function makeLabel(
	parent: Instance,
	text: string,
	xScale: number,
	width: number,
	align: Enum.TextXAlignment,
	color: Color3
)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(xScale, 0)
	label.Size = UDim2.fromScale(width, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = align
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

local function fill(board: Instance?, entries: { any }?, isMoney: boolean)
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
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.LayoutOrder = rank
		-- Hauteur relative : s'adapte à la taille du tableau (10 lignes + espacements)
		row.Size = UDim2.new(1, 0, 1 / ROWS, -4)
		row.BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(60, 48, 120) else Color3.fromRGB(48, 38, 100)
		row.BackgroundTransparency = 0.2
		row.Parent = rows
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = row
		local isMe = entry and entry.UserId == Players.LocalPlayer.UserId
		local nameColor = if isMe then Color3.fromRGB(255, 220, 80) else Color3.new(1, 1, 1)
		makeLabel(row, MEDALS[rank] or ("#" .. rank), 0.01, 0.12, Enum.TextXAlignment.Center, Color3.new(1, 1, 1))
		makeLabel(row, if entry then entry.Name else "—", 0.15, 0.5, Enum.TextXAlignment.Left, nameColor)
		local value = if not entry then "" elseif isMoney then Format.Money(entry.Value) else tostring(entry.Value)
		makeLabel(
			row,
			value,
			0.66,
			0.32,
			Enum.TextXAlignment.Right,
			if isMoney then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 160, 160)
		)
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

	local function apply(data)
		if type(data) ~= "table" then
			return
		end
		fill(moneyBoard, data.Money, true)
		fill(stealsBoard, data.Steals, false)
	end

	Remotes.GetEvent("LeaderboardUpdated").OnClientEvent:Connect(apply)
	fill(moneyBoard, nil, true)
	fill(stealsBoard, nil, false)
	task.delay(12, function()
		local response = Net.Invoke("GetLeaderboard")
		if response.Ok then
			apply(response.Data)
		end
	end)
end

return BoardController
