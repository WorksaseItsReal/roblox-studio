--[[
	HUD
	===
	- Haut gauche  : argent + revenu/s
	- Haut centre  : dimension active, timer avant la suivante, chance serveur
	- Gauche       : boutons des panneaux
	- Bas centre   : barrière (état / recharge) + bandeau de vol en cours
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Dimensions = require(Shared.Config.Dimensions)
local Creatures = require(Shared.Config.Creatures)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

local player = Players.LocalPlayer

local MENU = {
	{ Panel = "Inventory", Text = "Créatures", Color = Color3.fromRGB(90, 160, 255) },
	{ Panel = "Fusion", Text = "Fusion", Color = Color3.fromRGB(170, 90, 255) },
	{ Panel = "Base", Text = "Base", Color = Color3.fromRGB(255, 140, 60) },
	{ Panel = "Index", Text = "Index", Color = Color3.fromRGB(80, 200, 160) },
	{ Panel = "Rebirth", Text = "Rebirth", Color = Color3.fromRGB(255, 100, 200) },
	{ Panel = "Shortcut", Text = "Raccourci", Color = Color3.fromRGB(120, 120, 255) },
	{ Panel = "Daily", Text = "Quotidien", Color = Color3.fromRGB(255, 200, 60) },
	{ Panel = "Leaderboard", Text = "Classement", Color = Color3.fromRGB(100, 220, 255) },
	{ Panel = "Shop", Text = "Boutique", Color = Color3.fromRGB(70, 200, 110) },
}

function HUD.Create(screen: ScreenGui, ctx)
	local State = ctx.State

	-------------------------------------------------- Argent
	local moneyFrame = UIKit.New("Frame", {
		Name = "Money",
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 230, 0, 70),
		Parent = screen,
	})
	UIKit.Corner(moneyFrame)
	UIKit.Stroke(moneyFrame, Theme.Money, 2)
	local moneyLabel = UIKit.Label({
		Text = "$0",
		TextSize = 32,
		TextColor3 = Theme.Money,
		Position = UDim2.new(0, 12, 0, 4),
		Size = UDim2.new(1, -24, 0, 38),
		Parent = moneyFrame,
	})
	local incomeLabel = UIKit.Label({
		Text = "+$0/s",
		Font = Theme.BodyFont,
		TextSize = 16,
		TextColor3 = Theme.TextDim,
		Position = UDim2.new(0, 12, 0, 42),
		Size = UDim2.new(1, -24, 0, 22),
		Parent = moneyFrame,
	})

	-------------------------------------------------- Dimension
	local dimFrame = UIKit.New("Frame", {
		Name = "Dimension",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 300, 0, 76),
		Parent = screen,
	})
	UIKit.Corner(dimFrame)
	local dimStroke = UIKit.Stroke(dimFrame, Theme.Stroke, 3)
	local dimTitle = UIKit.Label({
		Text = "Dimension",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = dimFrame,
	})
	local dimTimer = UIKit.Label({
		Text = "",
		Font = Theme.BodyFont,
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = dimFrame,
	})
	local luckLabel = UIKit.Label({
		Text = "",
		TextSize = 15,
		TextColor3 = Theme.Money,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = dimFrame,
	})

	-------------------------------------------------- Menu
	local menu = UIKit.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.new(0, 130, 0, #MENU * 42),
		Parent = screen,
	})
	UIKit.List(menu, Enum.FillDirection.Vertical, 6)
	for order, item in MENU do
		local button = UIKit.Button(item.Text, item.Color, function()
			ctx.UI.Toggle(item.Panel)
		end, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = order })
		button.Parent = menu
	end

	-------------------------------------------------- Barrière
	local barrierButton = UIKit.Button("Barrière", Theme.Danger, function()
		ctx.Net.Request("ActivateBarrier")
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 240, 0, 46),
		TextSize = 20,
	})
	barrierButton.Parent = screen

	-------------------------------------------------- Bandeau de vol
	local carryBanner = UIKit.Label({
		Name = "CarryBanner",
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(120, 20, 30),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -72),
		Size = UDim2.new(0, 520, 0, 40),
		Visible = false,
		Parent = screen,
	})
	UIKit.Corner(carryBanner)
	UIKit.New("UISizeConstraint", { MaxSize = Vector2.new(520, 40), Parent = carryBanner })
	carryBanner.Size = UDim2.new(0.9, 0, 0, 40)

	-------------------------------------------------- Mises à jour
	local function refreshMoney()
		moneyLabel.Text = Format.Money(State.GetMoney())
		incomeLabel.Text = "+" .. Format.Income(State.GetIncome())
	end
	State.MoneyChanged:Connect(refreshMoney)
	refreshMoney()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local now = workspace:GetServerTimeNow()

		-- Dimension
		local stateFolder = State.GameState
		if stateFolder then
			local dimension = Dimensions.Get(State.GetDimension())
			if dimension then
				dimTitle.Text = "Dimension : " .. dimension.Name
				dimTitle.TextColor3 = dimension.Visual.RiftColor
				dimStroke.Color = dimension.Visual.RiftColor
				local nextDimension = Dimensions.Get(Dimensions.Next(dimension.Id))
				local endsAt = stateFolder:GetAttribute("DimensionEndsAt") or now
				dimTimer.Text = string.format(
					"%s dans %s",
					if nextDimension then nextDimension.Name else "?",
					Format.Time(endsAt - now)
				)
			end
			local luck = State.GetLuck()
			if luck > 1 then
				local luckEnds = stateFolder:GetAttribute("LuckEndsAt") or now
				luckLabel.Text = string.format("Chance x%g  •  %s", luck, Format.Time(luckEnds - now))
			else
				luckLabel.Text = ""
			end
		end

		-- Barrière
		local plot = nil
		for _, candidate in workspace.Map.Plots:GetChildren() do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				plot = candidate
				break
			end
		end
		if plot then
			if plot:GetAttribute("BarrierActive") then
				barrierButton.Text = "Barrière active : "
					.. Format.Time((plot:GetAttribute("BarrierEndsAt") or now) - now)
				UIKit.SetButtonEnabled(barrierButton, false, Theme.Danger)
			else
				local cooldown = (plot:GetAttribute("BarrierCooldownEndsAt") or 0) - now
				if cooldown > 0 then
					barrierButton.Text = "Recharge : " .. Format.Time(cooldown)
					UIKit.SetButtonEnabled(barrierButton, false, Theme.Danger)
				else
					barrierButton.Text = "Activer la barrière"
					UIKit.SetButtonEnabled(barrierButton, true, Theme.Danger)
				end
			end
		end

		-- Vol en cours
		local profile = State.Profile
		if profile and profile.Carrying then
			local def = Creatures.Get(profile.Carrying.CreatureId)
			local left = (profile.Carrying.SecondsLeft or 0) - (os.clock() - profile.ReceivedAt)
			carryBanner.Visible = true
			carryBanner.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
			carryBanner.Text = string.format(
				"Tu portes %s : rentre dans ta base ! (%s)",
				if def then def.Name else "une créature",
				Format.Time(left)
			)
		elseif profile and profile.BeingStolen and #profile.BeingStolen > 0 then
			carryBanner.Visible = true
			carryBanner.BackgroundColor3 = Color3.fromRGB(140, 20, 30)
			carryBanner.Text = "ON TE VOLE ! Rattrape et touche le voleur !"
		else
			carryBanner.Visible = false
		end
	end)
end

return HUD
