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
DailyPanel.Height = 520

function DailyPanel.Create(content: Frame, ctx)
	local status = UIKit.Text({
		Text = "",
		TextSize = 27,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 38),
		Stroke = 3,
		Parent = content,
	})

	local row = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 178),
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
		-- Centrée dans son cadre : le jour à réclamer pulse depuis son centre
		local card = UIKit.Card({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Parent = holder,
		})
		local gradient = card:FindFirstChildOfClass("UIGradient") :: UIGradient
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		UIKit.Text({
			Text = if day == cycle then "JOUR 7 ⭐" else "JOUR " .. day,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(4, 8),
			Size = UDim2.new(1, -8, 0, 22),
			Stroke = 2,
			Fit = true,
			Parent = card,
		})
		local icon = UIKit.Text({
			Text = "🎁",
			TextSize = if day == cycle then 54 else 46,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 64),
			Stroke = 0,
			Parent = card,
		})
		-- Montant dans un encart sombre : le vert reste lisible quelle que soit la carte
		local chip = UIKit.New("Frame", {
			Name = "Amount",
			BackgroundColor3 = Theme.Inset,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -9),
			Size = UDim2.new(1, -14, 0, 32),
			Parent = card,
		})
		UIKit.Corner(chip, 9)
		UIKit.Stroke(chip, 2.5)
		local amount = UIKit.Text({
			Text = "",
			TextSize = 17,
			TextColor3 = Theme.Money,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.new(1, -8, 1, 0),
			Stroke = 2,
			Fit = true,
			Parent = chip,
		})
		dayCards[day] = { Card = card, Gradient = gradient, Stroke = stroke, Icon = icon, Amount = amount }
	end

	local button = UIKit.Button({
		Text = "🎁 RÉCLAMER",
		Color = "Gold",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 254),
		Size = UDim2.fromOffset(420, 82),
		Radius = 16,
		Parent = content,
		OnClick = function()
			ctx.Net.Request("ClaimDaily")
		end,
	})
	UIKit.Body({
		Text = "Connecte-toi chaque jour : un jour manqué remet la série à zéro. Les montants augmentent avec tes revenus et tes rebirths.",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(60, 356),
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
			-- Jour à réclamer : or, contour épais, pulse ; jours passés : bleu nuit éteint
			if isNext then
				item.Gradient.Color = ColorSequence.new(Theme.Palette.Gold[1], Theme.Palette.Gold[2])
			elseif done then
				item.Gradient.Color = ColorSequence.new(Theme.Lighten(Theme.Inset, 0.15), Theme.Inset)
			else
				item.Gradient.Color = ColorSequence.new(Theme.CardTop, Theme.CardBottom)
			end
			item.Stroke.Thickness = if isNext then 5 else 3
			item.Icon.Text = if done then "✅" elseif isNext then "🎉" else "🎁"
			UIKit.Pulse(item.Card, isNext, 0.06)
		end

		if claimedToday then
			status.Text = string.format("🔥 Série de %d jour(s) !", currentStreak)
			button:SetEnabled(false)
			button:SetText("⏳ " .. Format.Time((today + 1) * 86400 - now))
		else
			status.Text = string.format("🎉 Jour %d disponible !", nextDay)
			button:SetEnabled(true)
			button:SetText("🎁 RÉCLAMER")
		end
	end

	-- Comptes à rebours rafraîchis chaque seconde
	self.Tick = self.Refresh

	return self
end

return DailyPanel
