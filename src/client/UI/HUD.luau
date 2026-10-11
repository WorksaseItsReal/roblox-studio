--[[
	HUD
	===
	- Haut gauche  : argent (icône, gros chiffre, revenu/s) + pastilles (rebirths,
	                 vols, bonus amis, boost x2 actif)
	- Haut centre  : carte de dimension (icône, nom, timer) + chance + tempête
	- Gauche       : menu principal (grille de gros boutons-icônes)
	- Droite       : rail de récompenses (cadeau du jour, cadeaux de session,
	                 codes, inviter des amis) avec pastilles rouges
	- Bas centre   : barrière, bandeau de vol, bouton Vengeance
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Dimensions = require(Shared.Config.Dimensions)
local Creatures = require(Shared.Config.Creatures)
local Economy = require(Shared.Modules.Economy)
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
	{ Panel = "Quests", Text = "Quêtes", Icon = "📜", Color = "Gold" },
	{ Panel = "Rebirth", Text = "Rebirth", Icon = "🔁", Color = "Pink" },
	{ Panel = "Shortcut", Text = "Portail", Icon = "🌠", Color = "Cyan" },
	{ Panel = "Leaderboard", Text = "Top", Icon = "🏆", Color = "Dark" },
	{ Panel = "Shop", Text = "Boutique", Icon = "🛒", Color = "Green" },
}

local RAIL = {
	{ Id = "Daily", Text = "Cadeau", Icon = "🎁", Color = "Gold" },
	{ Id = "Gifts", Text = "Bonus", Icon = "⏰", Color = "Pink" },
	{ Id = "Codes", Text = "Codes", Icon = "🔑", Color = "Cyan" },
	{ Id = "Invite", Text = "Amis", Icon = "👥", Color = "Green" },
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

-- Une récompense d'index est-elle réclamable ?
local function indexClaimable(profile): boolean
	for _, dimensionId in Dimensions.Order do
		for _, tier in { "Complete", "Perfect" } do
			if not profile.IndexClaimed[dimensionId .. ":" .. tier] then
				local complete = true
				for _, def in Creatures.ByDimension[dimensionId] or {} do
					if (tier == "Perfect" or def.Rarity ~= "Secret") and not profile.Index[def.Id] then
						complete = false
						break
					end
				end
				if complete then
					return true
				end
			end
		end
	end
	return false
end

local function promptInvite(ctx)
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and canInvite then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		ctx.Toast("Les invitations ne sont pas disponibles ici.", "Error")
	end
end

function HUD.Create(root: Frame, ctx)
	local State = ctx.State
	local Panels = ctx.UI.Panels

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

	-- Pastilles sous l'argent
	local statsRow = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(52, 100),
		Size = UDim2.fromOffset(420, 30),
		Parent = root,
	})
	UIKit.List(statsRow, Enum.FillDirection.Horizontal, 8)
	local rebirthPill =
		UIKit.Pill("🔁 Rebirth 0", Color3.fromRGB(230, 90, 190), { Parent = statsRow, LayoutOrder = 1 })
	local stealsPill = UIKit.Pill("🦹 Vols 0", Color3.fromRGB(90, 140, 255), { Parent = statsRow, LayoutOrder = 2 })
	local boostRow = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(52, 134),
		Size = UDim2.fromOffset(420, 30),
		Parent = root,
	})
	UIKit.List(boostRow, Enum.FillDirection.Horizontal, 8)
	local friendsPill =
		UIKit.Pill("👥 +0%", Color3.fromRGB(60, 190, 90), { Parent = boostRow, LayoutOrder = 1, Visible = false })
	local boostPill =
		UIKit.Pill("⚡ x2", Color3.fromRGB(255, 150, 40), { Parent = boostRow, LayoutOrder = 2, Visible = false })

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
	-- Chance + tempête sous la carte
	local eventRow = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 98),
		Size = UDim2.new(1, -30, 0, 32),
		Parent = dimHolder,
	})
	UIKit.List(eventRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local luckPill = UIKit.Pill("🍀 Chance x2", Color3.fromRGB(80, 210, 90), {
		Parent = eventRow,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 16,
		Visible = false,
	})
	local stormPill = UIKit.Pill("🌪️ Tempête", Color3.fromRGB(255, 80, 150), {
		Parent = eventRow,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 16,
		Visible = false,
	})
	local stormScale = UIKit.New("UIScale", { Parent = stormPill })

	-------------------------------------------------- Menu principal (gauche)
	local menu = UIKit.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 70),
		Size = UDim2.fromOffset(176, 456),
		Parent = root,
	})
	UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(82, 84),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local badges = {}
	for order, item in MENU do
		local button = UIKit.IconButton({
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
		badges[item.Panel] = UIKit.Badge(button)
	end

	-------------------------------------------------- Rail de récompenses (droite)
	local rail = UIKit.New("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, -30),
		Size = UDim2.fromOffset(82, 4 * 92),
		Parent = root,
	})
	UIKit.List(rail, Enum.FillDirection.Vertical, 8)
	local railButtons = {}
	for order, item in RAIL do
		local button = UIKit.IconButton({
			Name = item.Id,
			Icon = item.Icon,
			Text = item.Text,
			Color = item.Color,
			Size = UDim2.fromOffset(82, 84),
			LayoutOrder = order,
			Parent = rail,
			OnClick = function()
				if item.Id == "Invite" then
					promptInvite(ctx)
				else
					ctx.UI.Toggle(item.Id)
				end
			end,
		})
		railButtons[item.Id] = button
		badges[item.Id] = UIKit.Badge(button)
	end
	local giftCaption = railButtons.Gifts.Face:FindFirstChild("Caption", true) :: TextLabel
	local inviteBadge = badges.Invite;
	(inviteBadge:FindFirstChild("Text") :: TextLabel).Text =
		string.format("+%d%%", math.round(GameConfig.Social.FriendBonusPerFriend * 100))
	inviteBadge.Size = UDim2.fromOffset(52, 26)
	inviteBadge.Visible = true

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

	-------------------------------------------------- Vengeance
	local revengeTarget: number? = nil
	local revenge = UIKit.Button({
		Name = "Revenge",
		Text = "⚔️ VENGEANCE",
		Color = "Red",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -164),
		Size = UDim2.fromOffset(460, 66),
		Parent = root,
		OnClick = function()
			if revengeTarget then
				ctx.Net.Request("UseShortcut", revengeTarget)
			end
		end,
	})
	revenge.Instance.Visible = false
	local revengeScale = revenge.Instance:FindFirstChildOfClass("UIScale") :: UIScale

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
		if not profile then
			return
		end
		pillText(rebirthPill).Text = "🔁 Rebirth " .. profile.Rebirths
		pillText(stealsPill).Text = "🦹 Vols " .. profile.Stats.Steals
		local friends = profile.FriendCount or 0
		friendsPill.Visible = friends > 0
		pillText(friendsPill).Text =
			string.format("👥 %d ami(s) +%d%%", friends, math.round(Economy.GetFriendBonus(friends) * 100))
	end
	State.ProfileChanged:Connect(refreshStats)
	refreshStats()

	local currentDimension = nil
	local function update()
		local now = workspace:GetServerTimeNow()
		local profile = State.Profile
		local sinceSync = if profile then os.clock() - (profile.ReceivedAt or os.clock()) else 0

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

			local stormActive = State.IsStormActive()
			local purchased = State.GetPurchasedLuck()
			local shownLuck = State.GetLuck() -- inclut la tempête
			luckPill.Visible = shownLuck > 1
			if shownLuck > 1 then
				local luckEnds = stateFolder:GetAttribute("LuckEndsAt") or now
				pillText(luckPill).Text = if purchased > 1
					then string.format("🍀 Chance x%g • %s", shownLuck, Format.Time(luckEnds - now))
					else string.format("🍀 Chance x%g", shownLuck)
			end

			local stormStarts = stateFolder:GetAttribute("StormStartsAt") or 0
			local stormEnds = stateFolder:GetAttribute("StormEndsAt") or 0
			if stormActive then
				stormPill.Visible = true
				pillText(stormPill).Text = "🌪️ TEMPÊTE ! " .. Format.Time(stormEnds - now)
				stormScale.Scale = 1 + math.abs(math.sin(os.clock() * 5)) * 0.08
			elseif stormStarts - now <= 15 * 60 and stormStarts > now then
				stormPill.Visible = true
				pillText(stormPill).Text = "🌪️ Tempête dans " .. Format.Time(stormStarts - now)
				stormScale.Scale = 1
			else
				stormPill.Visible = false
			end
		end

		-- Boost x2 actif
		local boostLeft = if profile then (profile.BoostSecondsLeft or 0) - sinceSync else 0
		boostPill.Visible = boostLeft > 0
		if boostLeft > 0 then
			pillText(boostPill).Text =
				string.format("⚡ Argent x%d • %s", GameConfig.Boosts.MoneyMultiplier, Format.Time(boostLeft))
		end

		-- Pastilles rouges et compte à rebours des cadeaux
		if profile then
			badges.Quests.Visible = Panels.Quests.HasClaimable(profile)
			badges.Gifts.Visible = Panels.Gifts.HasClaimable(profile)
			badges.Index.Visible = indexClaimable(profile)
			local today = Economy.GetUtcDay(State.GetServerUnixTime())
			badges.Daily.Visible = profile.Daily.LastDay ~= today
			local nextGift = Panels.Gifts.NextUnlockIn(profile)
			giftCaption.Text = if badges.Gifts.Visible
				then "PRÊT !"
				elseif nextGift then Format.Time(nextGift)
				else "Bonus"
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
		if profile and profile.Carrying then
			local def = Creatures.Get(profile.Carrying.CreatureId)
			local left = (profile.Carrying.SecondsLeft or 0) - sinceSync
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

		-- Vengeance disponible
		local revengeInfo = profile and profile.Revenge
		local revengeLeft = if revengeInfo then revengeInfo.SecondsLeft - sinceSync else 0
		if revengeInfo and revengeLeft > 0 then
			revengeTarget = revengeInfo.ThiefUserId
			revenge.Instance.Visible = true
			revenge:SetText(
				string.format(
					"⚔️ VENGEANCE sur %s (gratuit) • %s",
					revengeInfo.ThiefName,
					Format.Time(revengeLeft)
				)
			)
			revengeScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.05
		else
			revengeTarget = nil
			revenge.Instance.Visible = false
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
