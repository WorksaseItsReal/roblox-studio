--[[
	LeaderboardPanel : classement global (argent total gagné, vols réussis).
]]

local Players = game:GetService("Players")
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

local MEDALS = { "🥇", "🥈", "🥉" }
-- Or, argent, bronze : fond très clair teinté et contour de la couleur de la médaille
local MEDAL_COLORS = {
	Color3.fromRGB(255, 190, 30),
	Color3.fromRGB(160, 172, 196),
	Color3.fromRGB(214, 122, 56),
}

function LeaderboardPanel.Create(content: Frame, ctx)
	local mode = "Money"
	local cached = nil
	local self = {} :: any

	-- Onglets (onglet actif : violet de marque)
	local tabs = Widgets.Row({ Size = UDim2.new(1, 0, 0, 44), Parent = content }, 8)
	local moneyTab = UIKit.Button({
		Text = "💰 Argent total",
		Color = "Brand",
		TextSize = 19,
		Size = UDim2.new(0.5, -4, 0, 44),
		LayoutOrder = 1,
		Parent = tabs,
		OnClick = function()
			mode = "Money"
			self.Refresh()
		end,
	})
	local stealsTab = UIKit.Button({
		Text = "🦹 Vols réussis",
		Color = "White",
		TextSize = 19,
		Size = UDim2.new(0.5, -4, 0, 44),
		LayoutOrder = 2,
		Parent = tabs,
		OnClick = function()
			mode = "Steals"
			self.Refresh()
		end,
	})

	local list = UIKit.ScrollList(content, UIKit.ScrollArea(56))

	function self.Refresh()
		moneyTab:SetColor(if mode == "Money" then "Brand" else "White")
		stealsTab:SetColor(if mode == "Steals" then "Brand" else "White")
		UIKit.ClearChildren(list)
		local entries = cached and cached[mode]
		if not entries or #entries == 0 then
			Widgets.Empty(list, "⏳", "Classement en cours de chargement...")
			return
		end
		for _, entry in entries do
			-- Podium teinté ; la ligne du joueur local est sélectionnée (violet de marque)
			local isMe = entry.UserId == Players.LocalPlayer.UserId
			local tint = if isMe then Theme.Brand else MEDAL_COLORS[entry.Rank]
			local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 64), LayoutOrder = entry.Rank, Parent = list }, tint)
			if MEDALS[entry.Rank] then
				UIKit.Text({
					Text = MEDALS[entry.Rank],
					TextSize = 32,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 12, 0.5, 0),
					Size = UDim2.fromOffset(44, 40),
					Stroke = 0,
					Parent = card,
				})
			else
				UIKit.Label({
					Text = "#" .. entry.Rank,
					TextSize = 20,
					TextColor3 = Theme.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 12, 0.5, 0),
					Size = UDim2.fromOffset(44, 32),
					Fit = true,
					Parent = card,
				})
			end
			Widgets.Avatar(
				entry.UserId,
				44,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 68, 0.5, 0), Parent = card }
			)
			UIKit.Label({
				Text = entry.Name,
				TextSize = 19,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(126, 0),
				Size = UDim2.new(1, -350, 1, 0),
				Parent = card,
			})
			UIKit.Label({
				Text = if mode == "Money" then Format.Money(entry.Value) else "🦹 " .. tostring(entry.Value),
				TextSize = 21,
				TextColor3 = if mode == "Money" then Theme.MoneyText else Theme.DangerText,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextWrapped = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -18, 0.5, 0),
				Size = UDim2.fromOffset(200, 30),
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
