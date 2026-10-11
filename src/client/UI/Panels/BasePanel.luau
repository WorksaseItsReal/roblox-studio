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
BasePanel.Icon = "🛠️"

local ICONS = { Slots = "🧩", Barrier = "🛡️", Alarm = "🚨" }
-- Couleur selon le sens : emplacements = infos, barrière = défense, alarme = avertissement
local COLORS = {
	Slots = Theme.Info,
	Barrier = Theme.Danger,
	Alarm = Theme.Warning,
}

function BasePanel.Create(content: Frame, ctx)
	local top = Widgets.Row({ Size = UDim2.new(1, 0, 0, 40), Parent = content }, 8)
	local slotsChip = UIKit.Chip("📦 8 emplacements", { LayoutOrder = 1, Parent = top })
	local barrierChip = UIKit.Chip("🛡️ Barrière 1:00", { LayoutOrder = 2, Parent = top })
	UIKit.Body({
		Text = "♻️ Conservées après un rebirth",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		LayoutOrder = 3,
		Parent = top,
	})

	local list = UIKit.ScrollList(content, UIKit.ScrollArea(52))
	local rows = {}

	for order, upgrade in Upgrades.List do
		local color = COLORS[upgrade.Id] or Theme.Info
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 112), LayoutOrder = order, Parent = list })
		UIKit.IconTile(ICONS[upgrade.Id] or "⭐", color, 72, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Parent = card,
		})
		UIKit.Label({
			Text = upgrade.Name,
			TextSize = 20,
			TextWrapped = false,
			Position = UDim2.fromOffset(104, 12),
			Size = UDim2.new(1, -324, 0, 26),
			Fit = true,
			Parent = card,
		})
		UIKit.Body({
			Text = upgrade.Description,
			TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(104, 40),
			Size = UDim2.new(1, -324, 0, 38),
			Parent = card,
		})
		-- Jauge de niveau (un segment par niveau)
		local pips =
			Widgets.Row({ Position = UDim2.fromOffset(104, 82), Size = UDim2.new(1, -324, 0, 14), Parent = card }, 4)
		local pipFrames = {}
		for level = 1, upgrade.MaxLevel do
			local pip = UIKit.New("Frame", {
				BackgroundColor3 = Theme.Well,
				Size = UDim2.fromOffset(if upgrade.MaxLevel > 6 then 22 else 34, 12),
				LayoutOrder = level,
				Parent = pips,
			})
			UIKit.Corner(pip, 6)
			pipFrames[level] = pip
		end
		local levelText = UIKit.Body({
			Text = "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 12),
			Size = UDim2.fromOffset(188, 22),
			Fit = true,
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "",
			Color = "Green",
			TextSize = 21,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -14),
			Size = UDim2.fromOffset(188, 52),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("BuyUpgrade", upgrade.Id)
			end,
		})
		rows[upgrade.Id] = { Upgrade = upgrade, Pips = pipFrames, Button = button, LevelText = levelText }
	end

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		Widgets.SetPillText(slotsChip, string.format("📦 %d emplacements", profile.MaxSlots))
		Widgets.SetPillText(
			barrierChip,
			"🛡️ Barrière " .. Format.Time(Economy.GetBarrierDuration(profile, profile.Passes))
		)
		local money = ctx.State.GetMoney()

		for id, row in rows do
			local level = profile.Upgrades[id] or 0
			for index, pip in row.Pips do
				pip.BackgroundColor3 = if index <= level then Theme.Brand else Theme.Well
			end
			local cost = Upgrades.GetCost(id, level)
			row.LevelText.Text = if cost
				then string.format("Niv. %d » %s", level, row.Upgrade.LevelText(level + 1))
				else string.format("Niv. %d · maximum", level)
			if cost then
				row.Button:SetText(Format.Money(cost))
				row.Button:SetEnabled(money >= cost)
			else
				row.Button:SetStatus("✅ Niveau max")
			end
		end
	end

	return self
end

return BasePanel
