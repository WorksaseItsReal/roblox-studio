--[[
	RebirthPanel : avant / après, coût, ce qu'on perd / ce qu'on garde, et confirmation
	en deux clics.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local RebirthPanel = {}
RebirthPanel.Title = "Rebirth"
RebirthPanel.Icon = "🔁"
RebirthPanel.Height = 520

-- Carte « multiplicateur » : titre, gros chiffre, détail
local function bigStat(parent: Instance, position: UDim2, title: string, highlight: boolean)
	local card = UIKit.Card(
		{ AnchorPoint = Vector2.new(0.5, 0), Position = position, Size = UDim2.fromOffset(280, 128), Parent = parent },
		if highlight then Theme.Brand else nil
	)
	UIKit.Body({
		Text = title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = card,
	})
	local value = UIKit.Label({
		Text = "x1",
		TextSize = 46,
		TextColor3 = if highlight then Theme.Brand else Theme.TextDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 52),
		Parent = card,
	})
	local sub = UIKit.Body({
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(8, 92),
		Size = UDim2.new(1, -16, 0, 20),
		Fit = true,
		Parent = card,
	})
	return value, sub
end

-- Carte « Tu perds » / « Tu gardes » : titre coloré + une ligne par élément
local function consequences(parent: Instance, position: UDim2, title: string, color: Color3, lines: { string })
	local card = UIKit.Card({ Position = position, Size = UDim2.new(0.5, -6, 0, 132), Parent = parent })
	UIKit.Padding(card, 14, 16, 14, 16)
	UIKit.List(card, Enum.FillDirection.Vertical, 6)
	UIKit.Label({
		Text = title,
		TextSize = 18,
		TextColor3 = color,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 0,
		Parent = card,
	})
	for order, line in lines do
		UIKit.Label({
			Text = line,
			TextSize = 16,
			TextWrapped = false,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = order,
			Parent = card,
		})
	end
end

function RebirthPanel.Create(content: Frame, ctx)
	local nowValue, nowSub = bigStat(content, UDim2.new(0.5, -176, 0, 0), "Maintenant", false)
	local nextValue, nextSub = bigStat(content, UDim2.new(0.5, 176, 0, 0), "Après le rebirth", true)
	UIKit.Label({
		Text = "»",
		TextSize = 56,
		TextColor3 = Theme.Brand,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(60, 60),
		Parent = content,
	})

	local progress = UIKit.ProgressBar(
		{ Position = UDim2.fromOffset(40, 144), Size = UDim2.new(1, -80, 0, 30), Parent = content },
		Theme.Money
	)
	UIKit.Fit(progress.Instance:FindFirstChild("Label") :: TextLabel, 17)

	local confirming = false
	local button
	button = UIKit.Button({
		Text = "🔁 Renaître",
		Color = "Green",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.fromOffset(320, 56),
		Radius = 14,
		Parent = content,
		OnClick = function()
			if not confirming then
				confirming = true
				button:SetColor("Red")
				button:SetText("⚠️ Sûr ? Clique encore")
				task.delay(3, function()
					confirming = false
					button:SetColor("Green")
					button:SetText("🔁 Renaître")
				end)
				return
			end
			confirming = false
			button:SetColor("Green")
			button:SetText("🔁 Renaître")
			ctx.Net.Request("Rebirth")
		end,
	})

	consequences(content, UDim2.fromOffset(0, 274), "Tu perds", Theme.DangerText, {
		"❌ Ton argent (remis à " .. Format.Money(GameConfig.Economy.StartingMoney) .. ")",
		"❌ Tes créatures",
	})
	consequences(content, UDim2.new(0.5, 6, 0, 274), "Tu gardes", Theme.MoneyText, {
		"✅ Tes améliorations de base",
		"✅ Ton index",
		"✅ Tes gamepasses",
	})

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
		nowSub.Text = string.format("Rebirth %d · +%d empl.", rebirths, slotsNow)
		nextValue.Text = string.format("x%.1f", Economy.GetRebirthMultiplier(rebirths + 1))
		nextSub.Text = string.format("Rebirth %d · +%d empl.", rebirths + 1, slotsNext)

		progress:SetProgress(money / cost)
		progress:SetText(Format.Money(money) .. " / " .. Format.Money(cost))
		if not confirming then
			button:SetEnabled(money >= cost)
		end
	end

	return self
end

return RebirthPanel
