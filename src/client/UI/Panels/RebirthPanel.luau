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
RebirthPanel.Height = 530

local PINK = Color3.fromRGB(255, 70, 180)

local function bigStat(parent: Instance, position: UDim2, title: string, tint: Color3?)
	local card = UIKit.Card({ Position = position, Size = UDim2.fromOffset(256, 136), Parent = parent }, tint)
	UIKit.Text({
		Text = title,
		TextSize = 18,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.new(1, 0, 0, 24),
		Stroke = 2.2,
		Parent = card,
	})
	local value = UIKit.Text({
		Text = "x1",
		TextSize = 58,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 62),
		Stroke = 5,
		Parent = card,
	})
	UIKit.Gradient(value, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 226, 120))
	local sub = UIKit.Text({
		Text = "",
		TextSize = 16,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(8, 100),
		Size = UDim2.new(1, -16, 0, 24),
		Stroke = 2.2,
		Fit = true,
		Parent = card,
	})
	return value, sub
end

function RebirthPanel.Create(content: Frame, ctx)
	local nowValue, nowSub = bigStat(content, UDim2.new(0.5, -338, 0, 4), "MAINTENANT", nil)
	local nextValue, nextSub = bigStat(content, UDim2.new(0.5, 82, 0, 4), "APRÈS REBIRTH", PINK)
	-- Grosse flèche dorée (police du jeu, pas d'émoji)
	UIKit.Text({
		Text = "»",
		TextSize = 96,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(120, 100),
		Stroke = 5,
		Parent = content,
	})

	local progress = UIKit.ProgressBar(
		{ Position = UDim2.fromOffset(40, 160), Size = UDim2.new(1, -80, 0, 40), Parent = content },
		Theme.Money
	)
	local progressLabel = progress.Instance:FindFirstChild("Label") :: TextLabel
	UIKit.Fit(progressLabel, 20)

	local confirming = false
	local button
	button = UIKit.Button({
		Text = "🔁 RENAÎTRE",
		Color = "Pink",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 216),
		Size = UDim2.fromOffset(400, 80),
		Radius = 16,
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
		UIKit.Inset({ Position = UDim2.fromOffset(40, 314), Size = UDim2.new(1, -80, 0, 104), Parent = content })
	local warningRow =
		Widgets.Row({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 36), Parent = warning }, 8)
	UIKit.Text({
		Text = "TU PERDS",
		TextSize = 19,
		TextColor3 = Color3.fromRGB(255, 130, 130),
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		LayoutOrder = 0,
		Stroke = 2,
		Parent = warningRow,
	})
	UIKit.Pill(
		"❌ Argent remis à " .. Format.Money(GameConfig.Economy.StartingMoney),
		Theme.Danger,
		{ Parent = warningRow, LayoutOrder = 1, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)
	UIKit.Pill(
		"❌ Créatures",
		Theme.Danger,
		{ Parent = warningRow, LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)
	local keepRow =
		Widgets.Row({ Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 36), Parent = warning }, 8)
	UIKit.Text({
		Text = "TU GARDES",
		TextSize = 19,
		TextColor3 = Theme.Money,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		LayoutOrder = 0,
		Stroke = 2,
		Parent = keepRow,
	})
	local KEEP_GREEN = Color3.fromRGB(40, 200, 60)
	UIKit.Pill(
		"✅ Améliorations",
		KEEP_GREEN,
		{ Parent = keepRow, LayoutOrder = 1, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)
	UIKit.Pill(
		"✅ Index",
		KEEP_GREEN,
		{ Parent = keepRow, LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)
	UIKit.Pill(
		"✅ Gamepasses",
		KEEP_GREEN,
		{ Parent = keepRow, LayoutOrder = 3, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)

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
