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

-- Éléments repositionnés selon la taille de l'écran (voir HUD.ApplyLayout)
local layoutRefs: {
	LeftColumn: Frame?,
	Menu: Frame?,
	Rail: Frame?,
	RailList: UIListLayout?,
	RailGrid: UIGridLayout?,
} =
	{}

-- Pile du bas de l'écran (barrière, bandeau de vol, vengeance)
local BOTTOM_MARGIN = 12
local BARRIER_HEIGHT = 74
local STACK_GAP = 8
local TILE = 84 -- côté des tuiles du menu et du rail

local MENU = {
	{ Panel = "Inventory", Text = "Créatures", Icon = "🐾", Color = "Blue" },
	{ Panel = "Fusion", Text = "Fusion", Icon = "🌀", Color = "Purple" },
	{ Panel = "Base", Text = "Base", Icon = "🏰", Color = "Orange" },
	{ Panel = "Index", Text = "Index", Icon = "📖", Color = "Teal" },
	{ Panel = "Quests", Text = "Quêtes", Icon = "📜", Color = "Gold" },
	{ Panel = "Rebirth", Text = "Rebirth", Icon = "🔁", Color = "Pink" },
	{ Panel = "Shortcut", Text = "Portail", Icon = "🌠", Color = "Cyan" },
	{ Panel = "Leaderboard", Text = "Top", Icon = "🏆", Color = "Royal" },
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

	-------------------------------------------------- Argent (gros chiffre vert, contour noir)
	-- Colonne de gauche : descend sous les boutons Roblox du haut (HUD.ApplyLayout)
	local leftColumn = UIKit.New("Frame", {
		Name = "LeftColumn",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromOffset(440, 176),
		Parent = root,
	})
	local moneyHolder = UIKit.New("Frame", {
		Name = "Money",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(410, 92),
		Parent = leftColumn,
	})
	UIKit.Text({
		Name = "Icon",
		Text = "💵",
		TextSize = 46,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(60, 58),
		Stroke = 0,
		Parent = moneyHolder,
	})
	local moneyLabel = UIKit.Text({
		Name = "Amount",
		Text = "$0",
		TextSize = 48,
		TextWrapped = false,
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -64, 0, 56),
		Stroke = 5,
		Fit = true,
		Parent = moneyHolder,
	})
	UIKit.Gradient(moneyLabel, Color3.fromRGB(200, 255, 190), Color3.fromRGB(70, 240, 80))
	local incomeLabel = UIKit.Text({
		Name = "Income",
		Text = "+$0/s",
		TextSize = 24,
		TextColor3 = Theme.Income,
		TextWrapped = false,
		Position = UDim2.fromOffset(66, 54),
		Size = UDim2.new(1, -66, 0, 30),
		Stroke = 3.2,
		Parent = moneyHolder,
	})
	local moneyScale = UIKit.New("UIScale", { Parent = moneyLabel })

	-- Étiquettes sous l'argent
	local statsRow = UIKit.New("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 96),
		Size = UDim2.fromOffset(420, 30),
		Parent = leftColumn,
	})
	UIKit.List(statsRow, Enum.FillDirection.Horizontal, 8)
	local rebirthPill = UIKit.Pill(
		"🔁 Rebirth 0",
		Color3.fromRGB(255, 70, 180),
		{ Parent = statsRow, LayoutOrder = 1, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)
	local stealsPill = UIKit.Pill(
		"🦹 Vols 0",
		Theme.Danger,
		{ Parent = statsRow, LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), TextSize = 16 }
	)
	local boostRow = UIKit.New("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 134),
		Size = UDim2.fromOffset(420, 30),
		Parent = leftColumn,
	})
	UIKit.List(boostRow, Enum.FillDirection.Horizontal, 8)
	local friendsPill = UIKit.Pill(
		"👥 +0%",
		Theme.Info,
		{ Parent = boostRow, LayoutOrder = 1, Size = UDim2.fromOffset(0, 30), TextSize = 16, Visible = false }
	)
	local boostPill = UIKit.Pill(
		"💸 x2",
		Color3.fromRGB(40, 200, 60),
		{ Parent = boostRow, LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), TextSize = 16, Visible = false }
	)

	-------------------------------------------------- Dimension (bandeau du haut)
	local dimHolder = UIKit.New("Frame", {
		Name = "Dimension",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(430, 146),
		Parent = root,
	})
	local lavaColor = Color3.fromRGB(255, 110, 30)
	local dimPlate = UIKit.Plate({
		Position = UDim2.fromOffset(38, 8),
		Size = UDim2.new(1, -38, 0, 92),
		Parent = dimHolder,
	}, Theme.PaletteFrom(lavaColor), 6, 18)
	local dimIcon = UIKit.IconCircle("🔥", lavaColor, 98, { Parent = dimHolder, ZIndex = 5 })
	local dimTitle = UIKit.Text({
		Name = "Title",
		Text = "DIMENSION LAVE",
		TextSize = 30,
		TextWrapped = false,
		Position = UDim2.fromOffset(68, 5),
		Size = UDim2.new(1, -80, 0, 36),
		Stroke = 3.6,
		Fit = true,
		ZIndex = 3,
		Parent = dimPlate.Face,
	})
	-- Barre du temps restant : remplie de la couleur de la PROCHAINE dimension
	local dimTimer = UIKit.ProgressBar({
		Position = UDim2.fromOffset(68, 44),
		Size = UDim2.new(1, -84, 0, 30),
		ZIndex = 3,
		Parent = dimPlate.Face,
	}, Theme.Gold)
	-- Chance + tempête sous le bandeau
	local eventRow = UIKit.New("Frame", {
		Name = "Events",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(38, 108),
		Size = UDim2.new(1, -38, 0, 34),
		Parent = dimHolder,
	})
	UIKit.List(eventRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local luckPill = UIKit.Pill("🍀 Chance x2", Color3.fromRGB(40, 200, 60), {
		Parent = eventRow,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 32),
		TextSize = 17,
		Visible = false,
	})
	local stormPill = UIKit.Pill("🌪️ Tempête", Theme.Magic, {
		Parent = eventRow,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 32),
		TextSize = 17,
		Visible = false,
	})
	local stormScale = UIKit.New("UIScale", { Parent = stormPill })

	-------------------------------------------------- Menu principal (gauche)
	local menu = UIKit.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 72),
		Size = UDim2.fromOffset(180, 452),
		Parent = root,
	})
	UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE, TILE),
		CellPadding = UDim2.fromOffset(12, 8),
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
		Position = UDim2.new(1, -14, 0.5, 10),
		Size = UDim2.fromOffset(TILE, 4 * TILE + 3 * 10),
		Parent = root,
	})
	-- Colonne sur grand écran ; grille 2 x 2 en mode compact (HUD.ApplyLayout)
	layoutRefs.RailList = UIKit.List(rail, Enum.FillDirection.Vertical, 10)
	layoutRefs.RailGrid = UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE, TILE),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local railButtons = {}
	for order, item in RAIL do
		local button = UIKit.IconButton({
			Name = item.Id,
			Icon = item.Icon,
			Text = item.Text,
			Color = item.Color,
			Size = UDim2.fromOffset(TILE, TILE),
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
	layoutRefs.LeftColumn = leftColumn
	layoutRefs.Menu = menu
	layoutRefs.Rail = rail
	local giftCaption = railButtons.Gifts.Face:FindFirstChild("Caption", true) :: TextLabel
	local inviteBadge = badges.Invite
	local inviteText = inviteBadge:FindFirstChild("Text") :: TextLabel
	inviteText.Text = string.format("+%d%%", math.round(GameConfig.Social.FriendBonusPerFriend * 100))
	inviteText.TextSize = 15
	inviteBadge.Size = UDim2.fromOffset(54, 26)
	inviteBadge.Position = UDim2.new(1, -14, 0, 4)
	inviteBadge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
	local inviteGradient = inviteBadge:FindFirstChildOfClass("UIGradient")
	if inviteGradient then
		inviteGradient.Color = ColorSequence.new(Color3.fromRGB(255, 236, 80), Color3.fromRGB(252, 166, 0))
	end
	inviteBadge.Visible = true

	-------------------------------------------------- Bas de l'écran
	-- Empilés de bas en haut, sans trou (voir stackBottom) : barrière, bandeau de vol,
	-- vengeance. Compacts pour laisser voir l'avatar.
	local barrier = UIKit.Button({
		Name = "Barrier",
		Text = "🛡️ ACTIVER LA BARRIÈRE",
		Color = "Red",
		TextSize = 25,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
		Size = UDim2.fromOffset(380, BARRIER_HEIGHT),
		Radius = 16,
		Parent = root,
		OnClick = function()
			ctx.Net.Request("ActivateBarrier")
		end,
	})
	local cooldownFill = UIKit.New("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(0, 1),
		ZIndex = barrier.Label.ZIndex - 1,
		Parent = barrier.Face,
	})
	UIKit.Corner(cooldownFill, 16)

	-------------------------------------------------- Bandeau de vol (titre + détail + chrono)
	local carryPlate = UIKit.Plate({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(BOTTOM_MARGIN + BARRIER_HEIGHT + STACK_GAP)),
		Size = UDim2.fromOffset(440, 64),
		Visible = false,
		Parent = root,
	}, "Red", 5, 16)
	local carryBanner = carryPlate.Instance
	local carryTitle = UIKit.Text({
		Name = "Text",
		Text = "",
		TextSize = 23,
		TextWrapped = false,
		Position = UDim2.fromOffset(16, 3),
		Size = UDim2.new(1, -118, 0, 30),
		Stroke = 3,
		Fit = true,
		ZIndex = 3,
		Parent = carryPlate.Face,
	})
	local carrySub = UIKit.Body({
		Name = "Sub",
		Text = "",
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(18, 32),
		Size = UDim2.new(1, -120, 0, 20),
		Stroke = 1.8,
		ZIndex = 3,
		Parent = carryPlate.Face,
	})
	-- Chrono dans un encart sombre : le chiffre qui compte se lit d'un coup d'œil
	local carryChip = UIKit.New("Frame", {
		Name = "Timer",
		BackgroundColor3 = Theme.Inset,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(88, 44),
		ZIndex = 3,
		Parent = carryPlate.Face,
	})
	UIKit.Corner(carryChip, 10)
	UIKit.Stroke(carryChip, 3)
	local carryTime = UIKit.Text({
		Text = "0:00",
		TextSize = 27,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -8, 1, 0),
		Stroke = 3,
		Fit = true,
		ZIndex = 4,
		Parent = carryChip,
	})
	local carryScale = UIKit.New("UIScale", { Parent = carryBanner })

	-------------------------------------------------- Vengeance
	local revengeTarget: number? = nil
	local revenge = UIKit.Button({
		Name = "Revenge",
		Text = "⚔️ VENGEANCE !",
		Color = "Orange",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(BOTTOM_MARGIN + BARRIER_HEIGHT + STACK_GAP)),
		Size = UDim2.fromOffset(340, 68),
		Radius = 16,
		Parent = root,
		OnClick = function()
			if revengeTarget then
				ctx.Net.Request("UseShortcut", revengeTarget)
			end
		end,
	})
	revenge.Label.Position = UDim2.new(0.5, 0, 0.5, -9)
	local revengeSub = UIKit.Text({
		Name = "Sub",
		Text = "",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 240, 120),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 15),
		Size = UDim2.new(1, -20, 0, 20),
		Stroke = 2.2,
		Fit = true,
		ZIndex = revenge.Label.ZIndex,
		Parent = revenge.Face,
	})
	revenge.Instance.Visible = false
	local revengeScale = revenge.Instance:FindFirstChildOfClass("UIScale") :: UIScale

	-- Empile les éléments visibles au-dessus de la barrière (pas de vide entre eux)
	local function stackBottom()
		local offset = BOTTOM_MARGIN + BARRIER_HEIGHT + STACK_GAP
		if carryBanner.Visible then
			carryBanner.Position = UDim2.new(0.5, 0, 1, -offset)
			offset += carryBanner.Size.Y.Offset + STACK_GAP
		end
		revenge.Instance.Position = UDim2.new(0.5, 0, 1, -offset)
	end

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
		pillText(friendsPill).Text = string.format("👥 Amis +%d%%", math.round(Economy.GetFriendBonus(friends) * 100))
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
				local nextDimension = Dimensions.Get(Dimensions.Next(dimension.Id))
				if dimension.Id ~= currentDimension then
					currentDimension = dimension.Id
					local vivid = Theme.Vivid(dimension.Visual.RiftColor)
					dimPlate:SetColor(Theme.PaletteFrom(vivid))
					dimTitle.Text = "DIMENSION " .. Format.Upper(dimension.Name)
					local glyph = dimIcon:FindFirstChild("Glyph") :: TextLabel
					glyph.Text = Theme.DimensionIcons[dimension.Id] or "🌀"
					local iconGradient = dimIcon:FindFirstChildOfClass("UIGradient")
					if iconGradient then
						iconGradient.Color = ColorSequence.new(Theme.Lighten(vivid, 0.25), Theme.Darken(vivid, 0.1))
					end
					dimTimer:SetColor(if nextDimension then Theme.Vivid(nextDimension.Visual.RiftColor) else Theme.Gold)
					UIKit.Pop(dimHolder)
				end
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
				string.format("💸 x%d • %s", GameConfig.Boosts.MoneyMultiplier, Format.Time(boostLeft))
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
			carryPlate:SetColor("Green")
			carryTitle.Text = "🏃 Ramène-la à ta base !"
			carrySub.Text = if def then def.Name else "Ta prise"
			carryTime.Text = Format.Time(left)
			carryChip.Visible = true
			carryTitle.Size = UDim2.new(1, -118, 0, 30)
			carrySub.Size = UDim2.new(1, -120, 0, 20)
			carryTitle.TextXAlignment = Enum.TextXAlignment.Left
			carrySub.TextXAlignment = Enum.TextXAlignment.Left
			carryScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.03
		elseif profile and profile.BeingStolen and #profile.BeingStolen > 0 then
			carryBanner.Visible = true
			carryPlate:SetColor("Red")
			carryTitle.Text = "🚨 On te vole !"
			carrySub.Text = "Touche le voleur pour récupérer ta créature !"
			carryChip.Visible = false
			carryTitle.Size = UDim2.new(1, -32, 0, 30)
			carrySub.Size = UDim2.new(1, -36, 0, 20)
			carryTitle.TextXAlignment = Enum.TextXAlignment.Center
			carrySub.TextXAlignment = Enum.TextXAlignment.Center
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
			revengeSub.Text =
				string.format("sur %s • gratuit • %s", revengeInfo.ThiefName, Format.Time(revengeLeft))
			revengeScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.05
		else
			revengeTarget = nil
			revenge.Instance.Visible = false
		end
		stackBottom()
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

--[[
	Disposition selon l'écran (appelée par l'UIController) :
	  Compact    : écran peu haut (téléphone en paysage) -> menu en 3 colonnes sous
	               l'argent, rail de récompenses en grille 2 x 2 en haut à droite, sous
	               le fil d'actualité (le coin bas droit reste libre pour le bouton de
	               saut tactile de Roblox)
	  LeftOffset : décalage vertical de la colonne de gauche (barre Roblox du haut)
]]
function HUD.ApplyLayout(info: { Compact: boolean, LeftOffset: number })
	local leftColumn, menu, rail = layoutRefs.LeftColumn, layoutRefs.Menu, layoutRefs.Rail
	local railList, railGrid = layoutRefs.RailList, layoutRefs.RailGrid
	if not leftColumn or not menu or not rail or not railList or not railGrid then
		return
	end
	leftColumn.Position = UDim2.fromOffset(0, info.LeftOffset)
	if info.Compact then
		menu.AnchorPoint = Vector2.zero
		menu.Position = UDim2.fromOffset(14, info.LeftOffset + 176)
		menu.Size = UDim2.fromOffset(3 * TILE + 2 * 12, 3 * TILE + 2 * 8)
		railList.Parent = nil
		railGrid.Parent = rail
		rail.AnchorPoint = Vector2.new(1, 0)
		rail.Position = UDim2.new(1, -14, 0, 200)
		rail.Size = UDim2.fromOffset(2 * TILE + 10, 2 * TILE + 10)
	else
		menu.AnchorPoint = Vector2.new(0, 0.5)
		menu.Position = UDim2.new(0, 14, 0.5, 66 + info.LeftOffset)
		menu.Size = UDim2.fromOffset(2 * TILE + 12, 5 * TILE + 4 * 8)
		railGrid.Parent = nil
		railList.Parent = rail
		rail.AnchorPoint = Vector2.new(1, 0.5)
		rail.Position = UDim2.new(1, -14, 0.5, 10)
		rail.Size = UDim2.fromOffset(TILE, 4 * TILE + 3 * 10)
	end
end

return HUD
