--[[
	DailyPanel : série de 7 jours et réclamation de la récompense quotidienne.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local DailyPanel = {}
DailyPanel.Title = "Cadeau quotidien"
DailyPanel.Icon = "🎁"
DailyPanel.Color = "Gold"

local GOLD = Color3.fromRGB(255, 190, 40)
local GREEN = Color3.fromRGB(70, 200, 100)

function DailyPanel.Create(content: Frame, ctx)
	local status = UIKit.Text({
		Text = "",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = content,
	})

	local row = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 170),
		Parent = content,
	})
	UIKit.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local cycle = #GameConfig.Daily.Rewards
	local dayCards = {}
	for day = 1, cycle do
		local holder = UIKit.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / cycle, -8, 1, 0),
			LayoutOrder = day,
			Parent = row,
		})
		local card = UIKit.Card({ Size = UDim2.fromScale(1, 1), Parent = holder })
		local gradient = card:FindFirstChildOfClass("UIGradient") :: UIGradient
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		UIKit.Text({
			Text = if day == cycle then "JOUR 7 ⭐" else "JOUR " .. day,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = card,
		})
		local icon = UIKit.Text({
			Text = "🎁",
			TextSize = if day == cycle then 52 else 44,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 60),
			Stroke = 0,
			Parent = card,
		})
		local amount = UIKit.Text({
			Text = "",
			TextSize = 16,
			TextColor3 = Theme.Money,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			TextScaled = true,
			Position = UDim2.fromOffset(6, 110),
			Size = UDim2.new(1, -12, 0, 26),
			Parent = card,
		})
		UIKit.New("UITextSizeConstraint", { MaxTextSize = 18, Parent = amount })
		dayCards[day] = { Gradient = gradient, Stroke = stroke, Icon = icon, Amount = amount }
	end

	local button = UIKit.Button({
		Text = "🎁 RÉCLAMER",
		Color = "Gold",
		TextSize = 28,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 252),
		Size = UDim2.fromOffset(400, 78),
		Parent = content,
		OnClick = function()
			ctx.Net.Request("ClaimDaily")
		end,
	})
	UIKit.Body({
		Text = "Connecte-toi chaque jour : un jour manqué remet la série à zéro. Les montants augmentent avec tes revenus et tes rebirths.",
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(60, 352),
		Size = UDim2.new(1, -120, 0, 44),
		Parent = content,
	})

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		local now = ctx.State.GetServerUnixTime()
		local today = Economy.GetUtcDay(now)
		local claimedToday = profile.Daily.LastDay == today
		local streakAlive = profile.Daily.LastDay == today - 1 or claimedToday
		local currentStreak = if streakAlive then profile.Daily.Streak else 0
		local nextDay = if claimedToday then currentStreak else currentStreak + 1
		local weekStart = (math.max(nextDay, 1) - 1) // cycle * cycle

		for day, item in dayCards do
			local streakDay = weekStart + day
			item.Amount.Text = Format.Money(Economy.GetDailyReward(streakDay, profile.Rebirths, ctx.State.GetIncome()))
			local done = streakDay <= currentStreak
			local isNext = streakDay == nextDay and not claimedToday
			local color = if done then GREEN elseif isNext then GOLD else Theme.CardBottom
			item.Gradient.Color = ColorSequence.new(Theme.Lighten(color, 0.25), Theme.Darken(color, 0.25))
			item.Stroke.Color = if isNext then Color3.new(1, 1, 1) else Theme.Ink
			item.Icon.Text = if done then "✅" elseif isNext then "🎉" else "🎁"
		end

		if claimedToday then
			status.Text = string.format("🔥 Série de %d jour(s) !", currentStreak)
			button:SetEnabled(false)
			button:SetText("⏳ " .. Format.Time((today + 1) * 86400 - now))
		else
			status.Text = string.format("Jour %d disponible !", nextDay)
			button:SetEnabled(true)
			button:SetText("🎁 RÉCLAMER")
		end
	end

	return self
end

return DailyPanel
