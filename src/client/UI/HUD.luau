--[[
	HUD
	===
	- Haut gauche  : argent (icône, gros chiffre, revenu/s) + stats (rebirths, vols)
	- Haut centre  : carte de dimension (icône, nom, timer avec barre) + chance serveur
	- Gauche       : menu en grille de gros boutons-icônes
	- Bas centre   : bouton de barrière (état / recharge) + bandeau de vol en cours
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Dimensions = require(Shared.Config.Dimensions)
local Creatures = require(Shared.Config.Creatures)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

local player = Players.LocalPlayer

local MENU = {
	{ Panel = "Inventory", Text = "Créatures", Icon = "🐾", Color = "Blue" },
	{ Panel = "Fusion", Text = "Fusion", Icon = "🌀", Color = "Purple" },
	{ Panel = "Base", Text = "Base", Icon = "🏰", Color = "Orange" },
	{ Panel = "Index", Text = "Index", Icon = "📖", Color = "Teal" },
	{ Panel = "Rebirth", Text = "Rebirth", Icon = "🔁", Color = "Pink" },
	{ Panel = "Shortcut", Text = "Portail", Icon = "🌠", Color = "Cyan" },
	{ Panel = "Daily", Text = "Cadeau", Icon = "🎁", Color = "Gold" },
	{ Panel = "Leaderboard", Text = "Top", Icon = "🏆", Color = "Dark" },
	{ Panel = "Shop", Text = "Boutique", Icon = "🛒", Color = "Green" },
}

local function findMyPlot(): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function pillText(pill: Frame): TextLabel
	return pill:FindFirstChild("Text") :: TextLabel
end

function HUD.Create(root: Frame, ctx)
	local State = ctx.State

	-------------------------------------------------- Argent
	local moneyHolder = UIKit.New("Frame", {
		Name = "Money",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.fromOffset(300, 80),
		Parent = root,
	})
	local moneyCapsule = UIKit.New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(34, 8),
		Size = UDim2.new(1, -34, 0, 64),
		Parent = moneyHolder,
	})
	UIKit.Round(moneyCapsule)
	UIKit.Stroke(moneyCapsule, 3.5)
	UIKit.Gradient(moneyCapsule, Color3.fromRGB(78, 64, 150), Color3.fromRGB(40, 30, 90))
	UIKit.IconCircle("💰", Theme.Gold, 80, { Parent = moneyHolder, ZIndex = 3 })
	local moneyLabel = UIKit.Text({
		Name = "Amount",
		Text = "$0",
		TextSize = 34,
		TextWrapped = false,
		Position = UDim2.fromOffset(54, 2),
		Size = UDim2.new(1, -66, 0, 38),
		Stroke = 3,
		Parent = moneyCapsule,
	})
	UIKit.Gradient(moneyLabel, Color3.fromRGB(220, 255, 210), Color3.fromRGB(90, 235, 90))
	local incomeLabel = UIKit.Text({
		Name = "Income",
		Text = "+$0/s",
		TextSize = 18,
		TextColor3 = Theme.Gold,
		TextWrapped = false,
		Position = UDim2.fromOffset(56, 36),
		Size = UDim2.new(1, -66, 0, 22),
		Parent = moneyCapsule,
	})
	local moneyScale = UIKit.New("UIScale", { Parent = moneyLabel })

	-- Petites stats sous l'argent
	local statsRow = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(52, 100),
		Size = UDim2.fromOffset(300, 30),
		Parent = root,
	})
	UIKit.List(statsRow, Enum.FillDirection.Horizontal, 8)
	local rebirthPill =
		UIKit.Pill("🔁 Rebirth 0", Color3.fromRGB(230, 90, 190), { Parent = statsRow, LayoutOrder = 1 })
	local stealsPill = UIKit.Pill("🦹 Vols 0", Color3.fromRGB(90, 140, 255), { Parent = statsRow, LayoutOrder = 2 })

	-------------------------------------------------- Dimension
	local dimHolder = UIKit.New("Frame", {
		Name = "Dimension",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(400, 136),
		Parent = root,
	})
	local dimCard = UIKit.New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(30, 6),
		Size = UDim2.new(1, -30, 0, 84),
		Parent = dimHolder,
	})
	UIKit.Corner(dimCard, 22)
	UIKit.Stroke(dimCard, 3.5)
	local dimGradient = UIKit.Gradient(dimCard, Color3.fromRGB(255, 140, 70), Color3.fromRGB(150, 40, 20))
	local dimIcon = UIKit.IconCircle("🔥", Color3.fromRGB(255, 120, 40), 88, { Parent = dimHolder, ZIndex = 3 })
	local dimTitle = UIKit.Text({
		Text = "DIMENSION LAVE",
		TextSize = 26,
		TextWrapped = false,
		Position = UDim2.fromOffset(66, 6),
		Size = UDim2.new(1, -78, 0, 30),
		Stroke = 3,
		Parent = dimCard,
	})
	local dimTimer = UIKit.ProgressBar({
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.new(1, -82, 0, 28),
		Parent = dimCard,
	}, Color3.fromRGB(255, 255, 255))
	local luckPill = UIKit.Pill("🍀 Chance x2", Color3.fromRGB(80, 210, 90), {
		Parent = dimHolder,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 15, 0, 100),
		Size = UDim2.fromOffset(0, 30),
		TextSize = 17,
		Visible = false,
	})

	-------------------------------------------------- Menu
	local menu = UIKit.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 46),
		Size = UDim2.fromOffset(176, 456),
		Parent = root,
	})
	UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(82, 84),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	for order, item in MENU do
		UIKit.IconButton({
			Name = item.Panel,
			Icon = item.Icon,
			Text = item.Text,
			Color = item.Color,
			LayoutOrder = order,
			Parent = menu,
			OnClick = function()
				ctx.UI.Toggle(item.Panel)
			end,
		})
	end

	-------------------------------------------------- Barrière
	local barrier = UIKit.Button({
		Name = "Barrier",
		Text = "🛡️ ACTIVER LA BARRIÈRE",
		Color = "Red",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(340, 68),
		Parent = root,
		OnClick = function()
			ctx.Net.Request("ActivateBarrier")
		end,
	})
	-- Voile de recharge par-dessus le bouton
	local cooldownFill = UIKit.New("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Size = UDim2.fromScale(0, 1),
		ZIndex = barrier.Label.ZIndex - 1,
		Parent = barrier.Face,
	})
	UIKit.Corner(cooldownFill, 14)

	-------------------------------------------------- Bandeau de vol
	local carryBanner = UIKit.New("Frame", {
		Name = "CarryBanner",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(580, 54),
		Visible = false,
		Parent = root,
	})
	UIKit.Round(carryBanner)
	UIKit.Stroke(carryBanner, 3.5)
	local carryGradient = UIKit.Gradient(carryBanner, Color3.fromRGB(255, 110, 110), Color3.fromRGB(190, 30, 50))
	local carryText = UIKit.Text({
		Text = "",
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 2.5,
		Parent = carryBanner,
	})
	local carryScale = UIKit.New("UIScale", { Parent = carryBanner })

	-------------------------------------------------- Mises à jour
	local lastMoney = State.GetMoney()
	local function refreshMoney()
		local money = State.GetMoney()
		moneyLabel.Text = Format.Money(money)
		incomeLabel.Text = "+" .. Format.Income(State.GetIncome())
		-- Petit rebond quand on gagne une grosse somme d'un coup (récompense, vente...)
		if money > lastMoney * 1.05 + 10 then
			moneyScale.Scale = 1.15
			TweenService:Create(moneyScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastMoney = money
	end
	State.MoneyChanged:Connect(refreshMoney)
	refreshMoney()

	local function refreshStats()
		local profile = State.Profile
		if profile then
			pillText(rebirthPill).Text = "🔁 Rebirth " .. profile.Rebirths
			pillText(stealsPill).Text = "🦹 Vols " .. profile.Stats.Steals
		end
	end
	State.ProfileChanged:Connect(refreshStats)
	refreshStats()

	local currentDimension = nil
	local function update()
		local now = workspace:GetServerTimeNow()

		-- Dimension
		local stateFolder = State.GameState
		if stateFolder then
			local dimension = Dimensions.Get(State.GetDimension())
			if dimension then
				if dimension.Id ~= currentDimension then
					currentDimension = dimension.Id
					local color = dimension.Visual.RiftColor
					dimGradient.Color = ColorSequence.new(Theme.Lighten(color, 0.15), Theme.Darken(color, 0.5))
					dimTitle.Text = "DIMENSION " .. Format.Upper(dimension.Name)
					local glyph = dimIcon:FindFirstChild("Glyph") :: TextLabel
					glyph.Text = Theme.DimensionIcons[dimension.Id] or "🌀"
					local iconGradient = dimIcon:FindFirstChildOfClass("UIGradient")
					if iconGradient then
						iconGradient.Color = ColorSequence.new(Theme.Lighten(color, 0.4), Theme.Darken(color, 0.1))
					end
					dimTimer:SetColor(Theme.Lighten(color, 0.3))
					UIKit.Pop(dimHolder)
				end
				local nextDimension = Dimensions.Get(Dimensions.Next(dimension.Id))
				local endsAt = stateFolder:GetAttribute("DimensionEndsAt") or now
				local left = math.max(0, endsAt - now)
				dimTimer:SetProgress(left / GameConfig.Rift.DimensionDurationSeconds)
				dimTimer:SetText(
					string.format("%s dans %s", if nextDimension then nextDimension.Name else "?", Format.Time(left))
				)
			end
			local luck = State.GetLuck()
			luckPill.Visible = luck > 1
			if luck > 1 then
				local luckEnds = stateFolder:GetAttribute("LuckEndsAt") or now
				pillText(luckPill).Text = string.format("🍀 Chance x%g • %s", luck, Format.Time(luckEnds - now))
			end
		end

		-- Barrière
		local plot = findMyPlot()
		if plot then
			if plot:GetAttribute("BarrierActive") then
				local left = (plot:GetAttribute("BarrierEndsAt") or now) - now
				barrier:SetColor("Cyan")
				barrier:SetEnabled(true)
				barrier:SetText("🛡️ PROTÉGÉE • " .. Format.Time(left))
				barrier.Enabled = false -- reste coloré, mais ne réagit plus
				cooldownFill.Size = UDim2.fromScale(0, 1)
			else
				local cooldown = (plot:GetAttribute("BarrierCooldownEndsAt") or 0) - now
				if cooldown > 0 then
					barrier:SetEnabled(false)
					barrier:SetText("⏳ RECHARGE • " .. Format.Time(cooldown))
					cooldownFill.Size = UDim2.fromScale(math.clamp(cooldown / GameConfig.Barrier.Cooldown, 0, 1), 1)
				else
					barrier:SetColor("Red")
					barrier:SetEnabled(true)
					barrier:SetText("🛡️ ACTIVER LA BARRIÈRE")
					cooldownFill.Size = UDim2.fromScale(0, 1)
				end
			end
		end

		-- Vol en cours
		local profile = State.Profile
		if profile and profile.Carrying then
			local def = Creatures.Get(profile.Carrying.CreatureId)
			local left = (profile.Carrying.SecondsLeft or 0) - (os.clock() - profile.ReceivedAt)
			carryBanner.Visible = true
			carryGradient.Color = ColorSequence.new(Color3.fromRGB(130, 245, 120), Color3.fromRGB(30, 150, 60))
			carryText.Text = string.format(
				"🏃 Rapporte %s dans ta base ! %s",
				if def then def.Name else "ta prise",
				Format.Time(left)
			)
			carryScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.03
		elseif profile and profile.BeingStolen and #profile.BeingStolen > 0 then
			carryBanner.Visible = true
			carryGradient.Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(190, 30, 50))
			carryText.Text = "🚨 ON TE VOLE ! Touche le voleur pour récupérer ta créature !"
			carryScale.Scale = 1 + math.abs(math.sin(os.clock() * 6)) * 0.05
		else
			carryBanner.Visible = false
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			update()
		end
	end)
	update()
end

return HUD
