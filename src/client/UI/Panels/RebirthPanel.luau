--[[
	RebirthPanel : avant / après, coût, et confirmation en deux clics.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local RebirthPanel = {}
RebirthPanel.Title = "Rebirth"
RebirthPanel.Icon = "🔁"
RebirthPanel.Color = "Pink"

local PINK = Color3.fromRGB(240, 90, 190)

local function bigStat(parent: Instance, position: UDim2, title: string, color: Color3)
	local card = UIKit.Card({ Position = position, Size = UDim2.fromOffset(250, 130), Parent = parent }, color, 0.45)
	UIKit.Text({
		Text = title,
		TextSize = 18,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = card,
	})
	local value = UIKit.Text({
		Text = "x1",
		TextSize = 54,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 58),
		Stroke = 4,
		Parent = card,
	})
	local sub = UIKit.Text({
		Text = "",
		TextSize = 16,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = card,
	})
	return value, sub
end

function RebirthPanel.Create(content: Frame, ctx)
	local nowValue, nowSub = bigStat(content, UDim2.new(0.5, -330, 0, 6), "MAINTENANT", Color3.fromRGB(120, 110, 200))
	local nextValue, nextSub = bigStat(content, UDim2.new(0.5, 80, 0, 6), "APRÈS REBIRTH", PINK)
	UIKit.Text({
		Text = "➜",
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(120, 70),
		TextColor3 = Theme.Gold,
		Stroke = 4,
		Parent = content,
	})

	local progress = UIKit.ProgressBar(
		{ Position = UDim2.fromOffset(40, 156), Size = UDim2.new(1, -80, 0, 38), Parent = content },
		PINK
	)

	local confirming = false
	local button
	button = UIKit.Button({
		Text = "🔁 RENAÎTRE",
		Color = "Pink",
		TextSize = 28,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.fromOffset(380, 76),
		Parent = content,
		OnClick = function()
			if not confirming then
				confirming = true
				button:SetText("⚠️ SÛR ? CLIQUE ENCORE")
				task.delay(3, function()
					confirming = false
					button:SetText("🔁 RENAÎTRE")
				end)
				return
			end
			confirming = false
			button:SetText("🔁 RENAÎTRE")
			ctx.Net.Request("Rebirth")
		end,
	})

	local warning =
		UIKit.Inset({ Position = UDim2.fromOffset(40, 306), Size = UDim2.new(1, -80, 0, 100), Parent = content })
	local warningRow =
		Widgets.Row({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 30), Parent = warning }, 8)
	UIKit.Pill(
		"❌ Argent remis à " .. Format.Money(GameConfig.Economy.StartingMoney),
		Theme.Danger,
		{ Parent = warningRow, LayoutOrder = 1, TextSize = 14 }
	)
	UIKit.Pill("❌ Créatures perdues", Theme.Danger, { Parent = warningRow, LayoutOrder = 2, TextSize = 14 })
	local keepRow =
		Widgets.Row({ Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 30), Parent = warning }, 8)
	UIKit.Pill("✅ Améliorations", Color3.fromRGB(60, 190, 90), { Parent = keepRow, LayoutOrder = 1, TextSize = 14 })
	UIKit.Pill("✅ Index", Color3.fromRGB(60, 190, 90), { Parent = keepRow, LayoutOrder = 2, TextSize = 14 })
	UIKit.Pill("✅ Gamepasses", Color3.fromRGB(60, 190, 90), { Parent = keepRow, LayoutOrder = 3, TextSize = 14 })

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		local rebirths = profile.Rebirths
		local cost = Economy.GetRebirthCost(rebirths)
		local money = ctx.State.GetMoney()
		local slotsNow = math.min(rebirths * GameConfig.Rebirth.SlotPerLevel, GameConfig.Rebirth.SlotBonusCap)
		local slotsNext = math.min((rebirths + 1) * GameConfig.Rebirth.SlotPerLevel, GameConfig.Rebirth.SlotBonusCap)

		nowValue.Text = string.format("x%.1f", Economy.GetRebirthMultiplier(rebirths))
		nowSub.Text = string.format("Rebirth %d • +%d empl.", rebirths, slotsNow)
		nextValue.Text = string.format("x%.1f", Economy.GetRebirthMultiplier(rebirths + 1))
		nextSub.Text = string.format("Rebirth %d • +%d empl.", rebirths + 1, slotsNext)

		progress:SetProgress(money / cost)
		progress:SetText(Format.Money(money) .. " / " .. Format.Money(cost))
		if not confirming then
			button:SetEnabled(money >= cost)
		end
	end

	return self
end

return RebirthPanel
