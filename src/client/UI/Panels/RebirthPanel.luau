--[[
	RebirthPanel : coût, gains et confirmation du rebirth.
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

function RebirthPanel.Create(content: Frame, ctx)
	local summary = UIKit.Label({ Text = "", TextSize = 20, Size = UDim2.new(1, 0, 0, 90), Parent = content })
	local warning = UIKit.Label({
		Text = "Le rebirth remet ton argent à "
			.. Format.Money(GameConfig.Economy.StartingMoney)
			.. " et supprime TOUTES tes créatures. Tu gardes tes améliorations, ton index et tes gamepasses.",
		Font = Theme.BodyFont,
		TextSize = 14,
		TextColor3 = Theme.Warning,
		Position = UDim2.new(0, 0, 0, 96),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = content,
	})
	local barBack = UIKit.New("Frame", {
		BackgroundColor3 = Theme.SurfaceLight,
		Position = UDim2.new(0, 0, 0, 146),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})
	UIKit.Corner(barBack, UDim.new(0, 8))
	local barFill = UIKit.New(
		"Frame",
		{ BackgroundColor3 = Color3.fromRGB(255, 100, 200), Size = UDim2.fromScale(0, 1), Parent = barBack }
	)
	UIKit.Corner(barFill, UDim.new(0, 8))
	local barText = UIKit.Label({
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = barBack,
	})

	local confirming = false
	local button
	button = UIKit.Button("Renaître", Color3.fromRGB(255, 100, 200), function()
		if not confirming then
			confirming = true
			button.Text = "Sûr ? Clique encore"
			task.delay(3, function()
				confirming = false
				button.Text = "Renaître"
			end)
			return
		end
		confirming = false
		button.Text = "Renaître"
		ctx.Net.Request("Rebirth")
	end, { Position = UDim2.new(0, 0, 0, 184), Size = UDim2.new(1, 0, 0, 48), TextSize = 22 })
	button.Parent = content
	local _ = warning

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		local rebirths = profile.Rebirths
		local cost = Economy.GetRebirthCost(rebirths)
		local money = ctx.State.GetMoney()
		local slotBonusNow = math.min(rebirths * GameConfig.Rebirth.SlotPerLevel, GameConfig.Rebirth.SlotBonusCap)
		local slotBonusNext =
			math.min((rebirths + 1) * GameConfig.Rebirth.SlotPerLevel, GameConfig.Rebirth.SlotBonusCap)
		summary.Text = string.format(
			"Rebirths : %d\nMultiplicateur : x%.1f  ->  x%.1f\nEmplacements bonus : +%d  ->  +%d",
			rebirths,
			Economy.GetRebirthMultiplier(rebirths),
			Economy.GetRebirthMultiplier(rebirths + 1),
			slotBonusNow,
			slotBonusNext
		)
		local ratio = math.clamp(money / cost, 0, 1)
		barFill.Size = UDim2.fromScale(ratio, 1)
		barText.Text = Format.Money(money) .. " / " .. Format.Money(cost)
		if not confirming then
			UIKit.SetButtonEnabled(button, money >= cost, Color3.fromRGB(255, 100, 200))
		end
	end

	return self
end

return RebirthPanel
