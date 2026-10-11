--[[
	BasePanel : améliorations de base (emplacements, barrière, alarme), avec jauge de niveau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local BasePanel = {}
BasePanel.Title = "Améliorations"
BasePanel.Icon = "🏰"
BasePanel.Color = "Orange"

local ICONS = { Slots = "🧩", Barrier = "🛡️", Alarm = "🚨" }
local COLORS = {
	Slots = Color3.fromRGB(90, 160, 255),
	Barrier = Color3.fromRGB(255, 90, 100),
	Alarm = Color3.fromRGB(255, 180, 50),
}

function BasePanel.Create(content: Frame, ctx)
	local top = Widgets.Row({ Size = UDim2.new(1, 0, 0, 40), Parent = content }, 10)
	local slotsPill = UIKit.Pill(
		"📦 8 emplacements",
		COLORS.Slots,
		{ Parent = top, LayoutOrder = 1, Size = UDim2.fromOffset(0, 36), TextSize = 17 }
	)
	local barrierPill = UIKit.Pill(
		"🛡️ 1:00",
		COLORS.Barrier,
		{ Parent = top, LayoutOrder = 2, Size = UDim2.fromOffset(0, 36), TextSize = 17 }
	)
	UIKit.Body({
		Text = "Conservées après un rebirth",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		LayoutOrder = 3,
		Parent = top,
	})

	local list = UIKit.ScrollList(content, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52) })
	local rows = {}

	for order, upgrade in Upgrades.List do
		local color = COLORS[upgrade.Id] or Theme.Palette.Blue[2]
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 120), LayoutOrder = order, Parent = list }, color, 0.25)
		UIKit.IconCircle(ICONS[upgrade.Id] or "⭐", color, 84, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Parent = card,
		})
		UIKit.Text({
			Text = upgrade.Name,
			TextSize = 24,
			TextWrapped = false,
			Position = UDim2.fromOffset(112, 10),
			Size = UDim2.new(1, -310, 0, 28),
			Parent = card,
		})
		UIKit.Body({
			Text = upgrade.Description,
			TextColor3 = Color3.fromRGB(230, 222, 255),
			Position = UDim2.fromOffset(112, 40),
			Size = UDim2.new(1, -310, 0, 36),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		-- Jauge de niveau (une pastille par niveau)
		local pips =
			Widgets.Row({ Position = UDim2.fromOffset(112, 82), Size = UDim2.new(1, -310, 0, 22), Parent = card }, 5)
		local pipFrames = {}
		for level = 1, upgrade.MaxLevel do
			local pip = UIKit.New("Frame", {
				BackgroundColor3 = Theme.Inset,
				Size = UDim2.fromOffset(18, 18),
				LayoutOrder = level,
				Parent = pips,
			})
			UIKit.Round(pip)
			UIKit.Stroke(pip, 2)
			pipFrames[level] = pip
		end
		local levelText = UIKit.Text({
			Text = "",
			TextSize = 15,
			TextColor3 = Theme.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 12),
			Size = UDim2.fromOffset(176, 22),
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "",
			Color = "Gold",
			TextSize = 20,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -12),
			Size = UDim2.fromOffset(176, 58),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("BuyUpgrade", upgrade.Id)
			end,
		})
		rows[upgrade.Id] =
			{ Upgrade = upgrade, Pips = pipFrames, Button = button, LevelText = levelText, Color = color }
	end

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		Widgets.SetPillText(slotsPill, string.format("📦 %d emplacements", profile.MaxSlots))
		Widgets.SetPillText(
			barrierPill,
			"🛡️ Barrière " .. Format.Time(Economy.GetBarrierDuration(profile, profile.Passes))
		)
		local money = ctx.State.GetMoney()

		for id, row in rows do
			local level = profile.Upgrades[id] or 0
			for index, pip in row.Pips do
				pip.BackgroundColor3 = if index <= level then Theme.Lighten(row.Color, 0.2) else Theme.Inset
			end
			local cost = Upgrades.GetCost(id, level)
			row.LevelText.Text =
				string.format("Niv. %d ➜ %s", level, if cost then row.Upgrade.LevelText(level + 1) else "MAX")
			if cost then
				row.Button:SetText("💰 " .. Format.Money(cost))
				row.Button:SetEnabled(money >= cost)
			else
				row.Button:SetText("✅ MAX")
				row.Button:SetEnabled(false)
			end
		end
	end

	return self
end

return BasePanel
