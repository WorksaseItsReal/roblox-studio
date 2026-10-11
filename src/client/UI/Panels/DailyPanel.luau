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
DailyPanel.Icon = "📅"
DailyPanel.Height = 440

function DailyPanel.Create(content: Frame, ctx)
	local status = UIKit.Label({
		Text = "",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = content,
	})

	local row = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 150),
		Parent = content,
	})
	UIKit.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local cycle = #GameConfig.Daily.Rewards
	local dayCards = {}
	for day = 1, cycle do
		local holder = UIKit.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / cycle, -7, 1, 0),
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
		local title = UIKit.Label({
			Text = if day == cycle then "Jour 7 ⭐" else "Jour " .. day,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(4, 12),
			Size = UDim2.new(1, -8, 0, 20),
			Fit = true,
			Parent = card,
		})
		local icon = UIKit.Text({
			Text = "🎁",
			TextSize = if day == cycle then 46 else 40,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 56),
			Stroke = 0,
			Parent = card,
		})
		local amount = UIKit.Label({
			Text = "",
			TextSize = 16,
			TextColor3 = Theme.MoneyText,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -12),
			Size = UDim2.new(1, -8, 0, 22),
			Fit = true,
			Parent = card,
		})
		dayCards[day] = { Card = card, Title = title, Icon = icon, Amount = amount }
	end

	local button = UIKit.Button({
		Text = "🎁 Réclamer",
		Color = "Green",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 216),
		Size = UDim2.fromOffset(320, 56),
		Radius = 14,
		Parent = content,
		OnClick = function()
			ctx.Net.Request("ClaimDaily")
		end,
	})
	UIKit.Body({
		Text = "Connecte-toi chaque jour : un jour manqué remet la série à zéro. Les montants augmentent avec tes revenus et tes rebirths.",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(60, 290),
		Size = UDim2.new(1, -120, 0, 40),
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
			-- Jour à réclamer : carte dorée qui pulse ; jours passés : grisés et cochés
			UIKit.SetCardTint(item.Card, if isNext then Theme.Gold elseif done then Theme.Disabled else nil)
			item.Title.TextColor3 = if done then Theme.TextMuted else Theme.TextDark
			item.Amount.TextColor3 = if done then Theme.TextMuted else Theme.MoneyText
			item.Icon.Text = if done then "✅" elseif isNext then "🎉" else "🎁"
			UIKit.Pulse(item.Card, isNext, 0.05)
		end

		if claimedToday then
			status.Text =
				string.format("🔥 Série de %d jour%s !", currentStreak, if currentStreak > 1 then "s" else "")
			button:SetStatus("⏳ Prochain cadeau dans " .. Format.Time((today + 1) * 86400 - now))
		else
			status.Text = string.format("🎉 Jour %d disponible !", nextDay)
			button:SetEnabled(true)
			button:SetText("🎁 Réclamer")
		end
	end

	-- Comptes à rebours rafraîchis chaque seconde
	self.Tick = self.Refresh

	return self
end

return DailyPanel
