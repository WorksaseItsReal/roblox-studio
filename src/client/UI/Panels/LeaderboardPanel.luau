--[[
	LeaderboardPanel : classement global (argent total gagné, vols réussis).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local LeaderboardPanel = {}
LeaderboardPanel.Title = "Classement global"
LeaderboardPanel.Icon = "🏆"
LeaderboardPanel.Color = "Royal"

local MEDALS = { "🥇", "🥈", "🥉" }
-- Or, argent, bronze : assez soutenus pour que les noms blancs restent lisibles
local MEDAL_COLORS = {
	Color3.fromRGB(255, 190, 0),
	Color3.fromRGB(122, 142, 188),
	Color3.fromRGB(214, 104, 30),
}

function LeaderboardPanel.Create(content: Frame, ctx)
	local mode = "Money"
	local cached = nil
	local self = {} :: any

	local tabs = Widgets.Row({ Size = UDim2.new(1, 0, 0, 56), Parent = content }, 10)
	local moneyTab = UIKit.Button({
		Text = "💰 ARGENT TOTAL",
		Color = "Green",
		TextSize = 21,
		Size = UDim2.new(0.5, -5, 0, 54),
		LayoutOrder = 1,
		Parent = tabs,
		OnClick = function()
			mode = "Money"
			self.Refresh()
		end,
	})
	local stealsTab = UIKit.Button({
		Text = "🦹 VOLS RÉUSSIS",
		Color = "Dark",
		TextSize = 21,
		Size = UDim2.new(0.5, -5, 0, 54),
		LayoutOrder = 2,
		Parent = tabs,
		OnClick = function()
			mode = "Steals"
			self.Refresh()
		end,
	})

	local list = UIKit.ScrollList(content, { Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68) })

	function self.Refresh()
		moneyTab:SetColor(if mode == "Money" then "Green" else "Dark")
		stealsTab:SetColor(if mode == "Steals" then "Red" else "Dark")
		UIKit.ClearChildren(list)
		local entries = cached and cached[mode]
		if not entries or #entries == 0 then
			Widgets.Empty(list, "⏳", "Classement en cours de chargement...")
			return
		end
		for _, entry in entries do
			local medalColor = MEDAL_COLORS[entry.Rank]
			local card =
				UIKit.Card({ Size = UDim2.new(1, 0, 0, 72), LayoutOrder = entry.Rank, Parent = list }, medalColor)
			if MEDALS[entry.Rank] then
				UIKit.IconCircle(MEDALS[entry.Rank], medalColor, 54, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Parent = card,
				})
			else
				UIKit.Text({
					Text = "#" .. entry.Rank,
					TextSize = 26,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.fromOffset(54, 40),
					Stroke = 3,
					Fit = true,
					Parent = card,
				})
			end
			Widgets.Avatar(
				entry.UserId,
				52,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 76, 0.5, 0), Parent = card }
			)
			UIKit.Body({
				Text = entry.Name,
				TextSize = 22,
				TextColor3 = Theme.Text,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(140, 0),
				Size = UDim2.new(1, -350, 1, 0),
				Stroke = 2,
				Parent = card,
			})
			UIKit.Text({
				Text = if mode == "Money" then Format.Money(entry.Value) else "🦹 " .. tostring(entry.Value),
				TextSize = 27,
				TextColor3 = if mode == "Money" then Theme.Money else Color3.fromRGB(255, 120, 120),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextWrapped = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(200, 36),
				Stroke = 3,
				Fit = true,
				Parent = card,
			})
		end
	end

	function self.OnOpen()
		if not cached then
			local response = ctx.Net.Invoke("GetLeaderboard")
			if response.Ok and type(response.Data) == "table" then
				cached = response.Data
			end
		end
	end

	Remotes.GetEvent("LeaderboardUpdated").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			cached = data
			if ctx.UI.IsOpen("Leaderboard") then
				self.Refresh()
			end
		end
	end)

	return self
end

return LeaderboardPanel
