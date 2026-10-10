--[[
	BasePanel : améliorations de base (emplacements, barrière, alarme).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local BasePanel = {}
BasePanel.Title = "Améliorations de base"

function BasePanel.Create(content: Frame, ctx)
	local info = UIKit.Label({
		Text = "",
		Font = Theme.BodyFont,
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = content,
	})
	local list = UIKit.ScrollList(content, { Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 1, -46) })

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		info.Text = string.format(
			"Emplacements : %d   •   Barrière : %s   •   Les améliorations sont conservées après un rebirth.",
			profile.MaxSlots,
			Format.Time(Economy.GetBarrierDuration(profile, profile.Passes))
		)
		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })
		local money = ctx.State.GetMoney()

		for order, upgrade in Upgrades.List do
			local level = profile.Upgrades[upgrade.Id] or 0
			local cost = Upgrades.GetCost(upgrade.Id, level)
			local card = UIKit.Card(78, order)
			card.Parent = list
			UIKit.Label({
				Text = string.format("%s  (niv. %d/%d)", upgrade.Name, level, upgrade.MaxLevel),
				Size = UDim2.new(1, -150, 0, 24),
				Parent = card,
			})
			UIKit.Label({
				Text = upgrade.Description .. "\nActuel : " .. upgrade.LevelText(level),
				Font = Theme.BodyFont,
				TextSize = 13,
				TextColor3 = Theme.TextDim,
				Position = UDim2.new(0, 0, 0, 24),
				Size = UDim2.new(1, -150, 0, 36),
				Parent = card,
			})
			local button = UIKit.Button(if cost then Format.Money(cost) else "MAX", Theme.Success, function()
				ctx.Net.Request("BuyUpgrade", upgrade.Id)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 130, 0, 40),
			})
			UIKit.SetButtonEnabled(button, cost ~= nil and money >= cost, Theme.Success)
			button.Parent = card
		end
	end

	return self
end

return BasePanel
