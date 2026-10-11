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
LeaderboardPanel.Color = "Dark"

local MEDALS = { "🥇", "🥈", "🥉" }
local MEDAL_COLORS = {
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(200, 205, 225),
	Color3.fromRGB(220, 140, 80),
}

function LeaderboardPanel.Create(content: Frame, ctx)
	local mode = "Money"
	local cached = nil
	local self = {} :: any

	local tabs = Widgets.Row({ Size = UDim2.new(1, 0, 0, 54), Parent = content }, 10)
	local moneyTab = UIKit.Button({
		Text = "💰 Argent total",
		Color = "Green",
		TextSize = 20,
		Size = UDim2.new(0.5, -5, 0, 52),
		LayoutOrder = 1,
		Parent = tabs,
		OnClick = function()
			mode = "Money"
			self.Refresh()
		end,
	})
	local stealsTab = UIKit.Button({
		Text = "🦹 Vols réussis",
		Color = "Dark",
		TextSize = 20,
		Size = UDim2.new(0.5, -5, 0, 52),
		LayoutOrder = 2,
		Parent = tabs,
		OnClick = function()
			mode = "Steals"
			self.Refresh()
		end,
	})

	local list = UIKit.ScrollList(content, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66) })

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
				UIKit.Card({ Size = UDim2.new(1, 0, 0, 70), LayoutOrder = entry.Rank, Parent = list }, medalColor, 0.35)
			if MEDALS[entry.Rank] then
				UIKit.IconCircle(MEDALS[entry.Rank], medalColor, 52, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Parent = card,
				})
			else
				UIKit.Text({
					Text = "#" .. entry.Rank,
					TextSize = 24,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.fromOffset(52, 40),
					Parent = card,
				})
			end
			Widgets.Avatar(
				entry.UserId,
				50,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 74, 0.5, 0), Parent = card }
			)
			UIKit.Text({
				Text = entry.Name,
				TextSize = 21,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(136, 0),
				Size = UDim2.new(1, -330, 1, 0),
				Parent = card,
			})
			UIKit.Text({
				Text = if mode == "Money" then Format.Money(entry.Value) else "🦹 " .. tostring(entry.Value),
				TextSize = 24,
				TextColor3 = if mode == "Money" then Theme.Money else Color3.fromRGB(255, 160, 160),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextWrapped = false,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, 0),
				Size = UDim2.new(0, 190, 1, 0),
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
