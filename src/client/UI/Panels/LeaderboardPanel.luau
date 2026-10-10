--[[
	LeaderboardPanel : classement global (argent total gagné, vols réussis).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local LeaderboardPanel = {}
LeaderboardPanel.Title = "Classement global"

function LeaderboardPanel.Create(content: Frame, ctx)
	local mode = "Money"
	local cached = nil
	local self = {} :: any

	local tabs = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = content })
	UIKit.List(tabs, Enum.FillDirection.Horizontal, 6)
	local moneyTab = UIKit.Button("Argent total", Theme.Primary, function()
		mode = "Money"
		self.Refresh()
	end, { Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 1 })
	moneyTab.Parent = tabs
	local stealsTab = UIKit.Button("Vols réussis", Theme.SurfaceLight, function()
		mode = "Steals"
		self.Refresh()
	end, { Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 2 })
	stealsTab.Parent = tabs

	local list = UIKit.ScrollList(content, { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42) })

	function self.Refresh()
		moneyTab.BackgroundColor3 = if mode == "Money" then Theme.Primary else Theme.SurfaceLight
		stealsTab.BackgroundColor3 = if mode == "Steals" then Theme.Primary else Theme.SurfaceLight
		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })
		local entries = cached and cached[mode]
		if not entries or #entries == 0 then
			UIKit.Label({ Text = "Classement en cours de chargement...", TextColor3 = Theme.TextDim, Parent = list })
			return
		end
		for _, entry in entries do
			local card = UIKit.Card(40, entry.Rank)
			card.Parent = list
			local color = if entry.Rank == 1
				then Theme.Gold
				elseif entry.Rank <= 3 then Color3.fromRGB(200, 200, 220)
				else Theme.Text
			UIKit.Label({
				Text = string.format("#%d  %s", entry.Rank, entry.Name),
				TextColor3 = color,
				Size = UDim2.new(0.65, 0, 1, 0),
				Parent = card,
			})
			UIKit.Label({
				Text = if mode == "Money" then Format.Money(entry.Value) else tostring(entry.Value),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if mode == "Money" then Theme.Money else Theme.Text,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0.35, 0, 1, 0),
				Parent = card,
			})
		end
	end

	function self.OnOpen()
		if not cached then
			local response = ctx.Net.Invoke("GetLeaderboard")
			if response.Ok and type(response.Data) == "table" then
				cached = response.Data
				self.Refresh()
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
