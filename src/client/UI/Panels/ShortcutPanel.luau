--[[
	ShortcutPanel : déblocage et utilisation du portail de raccourci.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local ShortcutPanel = {}
ShortcutPanel.Title = "Portail de raccourci"

function ShortcutPanel.Create(content: Frame, ctx)
	local info = UIKit.Label({
		Text = "",
		Font = Theme.BodyFont,
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, 0, 0, 58),
		Parent = content,
	})
	local list = UIKit.ScrollList(content, { Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 1, -64) })

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })

		if not profile.ShortcutUnlocked then
			info.Text = "Téléporte-toi devant la base d'un adversaire pour voler plus vite. Le propriétaire est alerté. "
				.. "Recharge : "
				.. Format.Time(GameConfig.Shortcut.Cooldown)
				.. "."
			local button = UIKit.Button(
				"Débloquer : " .. Format.Money(GameConfig.Shortcut.UnlockCost),
				Theme.Primary,
				function()
					ctx.Net.Request("UnlockShortcut")
				end,
				{ Size = UDim2.new(1, 0, 0, 46) }
			)
			UIKit.SetButtonEnabled(button, ctx.State.GetMoney() >= GameConfig.Shortcut.UnlockCost, Theme.Primary)
			button.Parent = list
			return
		end

		local cost = Economy.GetShortcutUseCost(ctx.State.GetIncome())
		local cooldown = (profile.ShortcutReadyAt or 0) - workspace:GetServerTimeNow()
		info.Text = string.format(
			"Coût par utilisation : %s  •  %s",
			Format.Money(cost),
			if cooldown > 0 then "Recharge : " .. Format.Time(cooldown) else "Prêt !"
		)

		local count = 0
		for _, other in Players:GetPlayers() do
			if other == Players.LocalPlayer or not other:GetAttribute("PlotId") then
				continue
			end
			count += 1
			local card = UIKit.Card(50, count)
			card.Parent = list
			UIKit.Label({
				Text = string.format(
					"%s  •  %s",
					other.DisplayName,
					Format.Income(other:GetAttribute("IncomePerSecond") or 0)
				),
				Size = UDim2.new(1, -140, 1, 0),
				Parent = card,
			})
			local button = UIKit.Button("Y aller", Theme.Primary, function()
				ctx.Net.Request("UseShortcut", other.UserId)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 34),
			})
			UIKit.SetButtonEnabled(button, cooldown <= 0, Theme.Primary)
			button.Parent = card
		end
		if count == 0 then
			UIKit.Label({ Text = "Aucun autre joueur avec une base.", TextColor3 = Theme.TextDim, Parent = list })
		end
	end

	return self
end

return ShortcutPanel
