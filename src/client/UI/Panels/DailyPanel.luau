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
DailyPanel.Title = "Récompense quotidienne"

function DailyPanel.Create(content: Frame, ctx)
	local status = UIKit.Label({ Text = "", TextSize = 18, Size = UDim2.new(1, 0, 0, 30), Parent = content })
	local row = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 90),
		Parent = content,
	})
	UIKit.List(row, Enum.FillDirection.Horizontal, 6)
	local dayCards = {}
	for day = 1, #GameConfig.Daily.Rewards do
		local card = UIKit.New("Frame", {
			BackgroundColor3 = Theme.SurfaceLight,
			Size = UDim2.new(1 / #GameConfig.Daily.Rewards, -6, 1, 0),
			LayoutOrder = day,
			Parent = row,
		})
		UIKit.Corner(card, UDim.new(0, 8))
		UIKit.Label({
			Text = "Jour " .. day,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 24),
			Parent = card,
		})
		local amount = UIKit.Label({
			Text = "",
			TextSize = 14,
			TextColor3 = Theme.Money,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 0, 30),
			Size = UDim2.new(1, 0, 0, 40),
			Parent = card,
		})
		dayCards[day] = { Card = card, Amount = amount }
	end
	local button = UIKit.Button("Réclamer", Theme.Gold, function()
		ctx.Net.Request("ClaimDaily")
	end, { Position = UDim2.new(0, 0, 0, 140), Size = UDim2.new(1, 0, 0, 48), TextSize = 22 })
	button.Parent = content

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
		local cycle = #GameConfig.Daily.Rewards

		for day, item in dayCards do
			-- Jours affichés pour la semaine en cours de la série
			local streakDay = (math.max(nextDay, 1) - 1) // cycle * cycle + day
			item.Amount.Text = Format.Money(Economy.GetDailyReward(streakDay, profile.Rebirths, ctx.State.GetIncome()))
			local done = streakDay <= currentStreak
			item.Card.BackgroundColor3 = if done
				then Theme.Success
				elseif streakDay == nextDay then Theme.Primary
				else Theme.SurfaceLight
		end

		if claimedToday then
			status.Text = string.format(
				"Série : %d jour(s). Prochaine récompense dans %s",
				currentStreak,
				Format.Time((today + 1) * 86400 - now)
			)
			UIKit.SetButtonEnabled(button, false, Theme.Gold)
			button.Text = "Déjà réclamée"
		else
			status.Text = string.format("Série actuelle : %d jour(s). Réclame le jour %d !", currentStreak, nextDay)
			UIKit.SetButtonEnabled(button, true, Theme.Gold)
			button.Text = "Réclamer"
		end
	end

	return self
end

return DailyPanel
