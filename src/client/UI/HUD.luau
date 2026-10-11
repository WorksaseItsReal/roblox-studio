--[[
	HUD
	===
	Peu d'éléments, un style par type d'élément (voir docs/ART_DIRECTION.md, section 2) :
	- Haut gauche : argent (Luckiest Guy, sans cadre) + revenu/s en or ; dessous, une
	                petite ligne (bonus d'amis, boost x2) seulement quand ils sont actifs
	- Haut centre : UNE pilule d'événement sombre (dimension + minuteur, tempête proche,
	                chance)
	- Gauche      : grille 2 x 3 de tuiles blanches identiques ; « Plus » ouvre un tiroir
	                (Fusion, Base, Portail, Classement, Cadeaux, Quotidien, Codes, Inviter).
	                Pastille rouge « ! » sur la tuile concernée (ou sur Plus).
	- Droite      : rien en permanence ; bulle or « Cadeau prêt ! » quand c'est réclamable
	- Bas centre  : uniquement contextuel : barrière (dans sa base ou juste après une
	                alerte), bandeau de vol, vengeance
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
local Remotes = require(Shared.Modules.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

local player = Players.LocalPlayer

local TILE = 72 -- côté des tuiles
local GAP_X = 12
local GAP_Y = 22 -- place du libellé sous chaque tuile
local MENU_SIZE = Vector2.new(2 * TILE + GAP_X, 3 * TILE + 2 * GAP_Y)
local DRAWER_COLUMNS = 4
local DRAWER_PADDING = 14
local DRAWER_SIZE = Vector2.new(
	2 * DRAWER_PADDING + DRAWER_COLUMNS * TILE + (DRAWER_COLUMNS - 1) * GAP_X,
	DRAWER_PADDING + 2 * TILE + 2 * GAP_Y + 4
)
local BOTTOM_MARGIN = 14 -- pile du bas (barrière, bandeau de vol, vengeance)
local STACK_GAP = 12
local ALERT_SECONDS = 20 -- la barrière reste proposée après une alerte d'intrusion ou de vol

local MENU = {
	{ Id = "Shop", Text = "Boutique", Icon = "🛒" },
	{ Id = "Inventory", Text = "Créatures", Icon = "🐾" },
	{ Id = "Index", Text = "Index", Icon = "📖" },
	{ Id = "Quests", Text = "Quêtes", Icon = "📜" },
	{ Id = "Rebirth", Text = "Rebirth", Icon = "🔁" },
	{ Id = "More", Text = "Plus", Icon = "+" },
}

local DRAWER = {
	{ Id = "Fusion", Text = "Fusion", Icon = "🌀" },
	{ Id = "Base", Text = "Base", Icon = "🏰" },
	{ Id = "Shortcut", Text = "Portail", Icon = "🌠" },
	{ Id = "Leaderboard", Text = "Classement", Icon = "🏆" },
	{ Id = "Gifts", Text = "Cadeaux", Icon = "🎁" },
	{ Id = "Daily", Text = "Quotidien", Icon = "📅" },
	{ Id = "Codes", Text = "Codes", Icon = "🔑" },
	{ Id = "Invite", Text = "Inviter", Icon = "👥" },
}

-- Éléments partagés avec ApplyLayout, SetDrawerOpen et le tutoriel
local refs: {
	Money: Frame?,
	Menu: Frame?,
	Drawer: Frame?,
	Catcher: TextButton?,
	MoreIcon: TextLabel?,
	MoreBadge: Frame?,
	Barrier: Frame?,
} =
	{}
local drawerOpen = false
local barrierHint = false
-- Position verticale de la bulle « Cadeau prêt ! » : sous le fil d'actualité, même
-- quand ses 3 pilules font deux lignes
local GIFT_TOP = 236

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

-- Le joueur est-il dans sa base ? (volume du sol, comme MapService.IsInsidePlot)
local function isInsideBase(plot: Instance): boolean
	local floor = plot:FindFirstChild("Floor")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not floor or not floor:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	local localPosition = floor.CFrame:PointToObjectSpace(root.Position)
	local size = floor.Size
	return math.abs(localPosition.X) <= size.X / 2 + 2
		and math.abs(localPosition.Z) <= size.Z / 2 + 2
		and localPosition.Y >= -4
		and localPosition.Y <= 30
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

-- Ouvre ou ferme le tiroir « Plus »
function HUD.SetDrawerOpen(open: boolean)
	local drawer, catcher, moreIcon = refs.Drawer, refs.Catcher, refs.MoreIcon
	if not drawer or not catcher or not moreIcon or drawerOpen == open then
		return
	end
	drawerOpen = open
	drawer.Visible = open
	catcher.Visible = open
	moreIcon.Text = if open then "×" else "+"
	if open and refs.MoreBadge then
		-- Le tiroir ouvert montre lui-même ses pastilles
		refs.MoreBadge.Visible = false
	end
	if open then
		UIKit.Pop(drawer, 0.88)
	end
end

--[[
	Tutoriel : force l'affichage du bouton de barrière (même hors de la base) et
	renvoie son cadre, pour l'entourer.
]]
function HUD.SetBarrierHint(enabled: boolean): Frame?
	barrierHint = enabled
	return refs.Barrier
end

function HUD.Create(root: Frame, ctx)
	local State = ctx.State
	local Panels = ctx.UI.Panels

	-------------------------------------------------- Argent (haut gauche, sans cadre)
	local money = UIKit.New("Frame", {
		Name = "Money",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 16),
		Size = UDim2.fromOffset(420, 100),
		Parent = root,
	})
	UIKit.Text({
		Name = "Icon",
		Text = "💵",
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(50, 46),
		Stroke = 0,
		Parent = money,
	})
	local moneyLabel = UIKit.Text({
		Name = "Amount",
		Text = "$0",
		Font = Theme.DisplayFont,
		TextSize = 46,
		TextWrapped = false,
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -56, 0, 52),
		Stroke = 3.5,
		Fit = true,
		Parent = money,
	})
	UIKit.Gradient(moneyLabel, Color3.fromRGB(160, 248, 140), Theme.Money)
	local incomeLabel = UIKit.Text({
		Name = "Income",
		Text = "+$0/s",
		TextSize = 21,
		TextColor3 = Theme.Gold,
		TextWrapped = false,
		Position = UDim2.fromOffset(58, 50),
		Size = UDim2.new(1, -58, 0, 26),
		Stroke = 2,
		Parent = money,
	})
	-- Bonus actifs (amis, boost x2) : une petite ligne, seulement quand il y en a
	local bonusLabel = UIKit.Text({
		Name = "Bonus",
		Text = "",
		TextSize = 15,
		TextWrapped = false,
		Position = UDim2.fromOffset(59, 76),
		Size = UDim2.new(1, -59, 0, 20),
		Stroke = 1.5,
		Visible = false,
		Parent = money,
	})
	local moneyScale = UIKit.New("UIScale", { Parent = moneyLabel })
	refs.Money = money

	-------------------------------------------------- Pilule d'événement (haut centre)
	local event = UIKit.New("Frame", {
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Hud,
		BackgroundTransparency = Theme.HudTransparency,
		Parent = root,
	})
	UIKit.Round(event)
	UIKit.Padding(event, 0, 8, 0, 18)
	UIKit.List(event, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	-- Texte d'un segment (icône + nom), largeur automatique
	local function segment(order: number): TextLabel
		return UIKit.Text({
			Text = "",
			TextSize = 20,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			Stroke = 0,
			LayoutOrder = order,
			Parent = event,
		})
	end
	-- Minuteur dans une puce claire de largeur fixe : la pilule ne tremble pas chaque
	-- seconde (les chiffres de Fredoka n'ont pas tous la même largeur)
	local function timer(order: number, width: number): (Frame, TextLabel)
		local chip = UIKit.New("Frame", {
			Name = "Timer",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.86,
			Size = UDim2.fromOffset(width, 28),
			LayoutOrder = order,
			Parent = event,
		})
		UIKit.Corner(chip, 9)
		return chip,
			UIKit.Text({
				Text = "",
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				Size = UDim2.fromScale(1, 1),
				Stroke = 0,
				Parent = chip,
			})
	end
	local function divider(order: number): Frame
		return UIKit.New("Frame", {
			Name = "Divider",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(2, 20),
			LayoutOrder = order,
			Parent = event,
		})
	end
	local dimName = segment(1)
	local _, dimTime = timer(2, 54)
	local stormDivider = divider(3)
	local stormName = segment(4)
	local stormChip, stormTime = timer(5, 60)
	local luckDivider = divider(6)
	local luckName = segment(7)
	local luckChip, luckTime = timer(8, 60)

	-------------------------------------------------- Menu (gauche) + tiroir « Plus »
	local menu = UIKit.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 24),
		Size = UDim2.fromOffset(MENU_SIZE.X, MENU_SIZE.Y),
		ZIndex = 5,
		Parent = root,
	})
	local grid = UIKit.New("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = menu,
	})
	UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE, TILE),
		CellPadding = UDim2.fromOffset(GAP_X, GAP_Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	refs.Menu = menu

	-- Clic hors du tiroir : il se referme (sous le menu, pour que les tuiles restent cliquables)
	local catcher = UIKit.New("TextButton", {
		Name = "DrawerCatcher",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-60, -120),
		Size = UDim2.new(1, 120, 1, 240),
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	catcher.Activated:Connect(function()
		HUD.SetDrawerOpen(false)
	end)
	refs.Catcher = catcher

	local badges: { [string]: Frame } = {}
	for order, item in MENU do
		local button = UIKit.IconButton({
			Name = item.Id,
			Icon = item.Icon,
			Text = item.Text,
			LayoutOrder = order,
			Parent = grid,
			OnClick = function()
				if item.Id == "More" then
					HUD.SetDrawerOpen(not drawerOpen)
				else
					HUD.SetDrawerOpen(false)
					ctx.UI.Toggle(item.Id)
				end
			end,
		})
		badges[item.Id] = UIKit.Badge(button)
		if item.Id == "More" then
			-- « + » dessiné dans la police du jeu, couleur de marque (devient « × » ouvert)
			button.Label.TextSize = 50
			button.Label.TextColor3 = Theme.Brand
			button.Label.Position = UDim2.new(0.5, 0, 0.5, -2)
			refs.MoreIcon = button.Label
			refs.MoreBadge = badges.More
		end
	end

	local drawer = UIKit.New("Frame", {
		Name = "Drawer",
		-- Ancré en bas à gauche (il « sort » de Plus) ; ses deux rangées de tuiles sont
		-- alignées sur les deux rangées du bas de la grille
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 16, 0, TILE + GAP_Y - DRAWER_PADDING + DRAWER_SIZE.Y),
		Size = UDim2.fromOffset(DRAWER_SIZE.X, DRAWER_SIZE.Y),
		BackgroundColor3 = Theme.Hud,
		BackgroundTransparency = 0.22,
		Visible = false,
		ZIndex = 6,
		Parent = menu,
	})
	UIKit.Corner(drawer, 20)
	UIKit.Stroke(drawer, 2, Color3.new(1, 1, 1), 0.82)
	UIKit.Padding(drawer, DRAWER_PADDING, DRAWER_PADDING, 0, DRAWER_PADDING)
	UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE, TILE),
		CellPadding = UDim2.fromOffset(GAP_X, GAP_Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = drawer,
	})
	refs.Drawer = drawer
	for order, item in DRAWER do
		local button = UIKit.IconButton({
			Name = item.Id,
			Icon = item.Icon,
			Text = item.Text,
			LayoutOrder = order,
			Parent = drawer,
			OnClick = function()
				HUD.SetDrawerOpen(false)
				if item.Id == "Invite" then
					promptInvite(ctx)
				else
					ctx.UI.Toggle(item.Id)
				end
			end,
		})
		badges[item.Id] = UIKit.Badge(button)
		if item.Id == "Invite" then
			-- Bonus de revenus par ami invité
			UIKit.Pill(string.format("+%d %%", math.round(GameConfig.Social.FriendBonusPerFriend * 100)), Theme.Gold, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 6, 0, 2),
				Size = UDim2.fromOffset(0, 22),
				TextSize = 13,
				ZIndex = button.Face.ZIndex + 5,
				Parent = button.Instance,
			})
		end
	end

	-------------------------------------------------- Bulle « Cadeau prêt ! » (droite)
	local giftTarget = "Daily"
	local giftBubble = UIKit.Button({
		Name = "GiftBubble",
		Text = "🎁 Cadeau prêt !",
		Color = "Gold",
		TextSize = 19,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, GIFT_TOP),
		Size = UDim2.fromOffset(200, 50),
		Radius = UDim.new(0.5, 0),
		Visible = false,
		Parent = root,
		OnClick = function()
			HUD.SetDrawerOpen(false)
			ctx.UI.Open(giftTarget)
		end,
	})

	-------------------------------------------------- Bas de l'écran (contextuel)
	local barrier = UIKit.Button({
		Name = "Barrier",
		Text = "🛡️ Activer la barrière",
		Color = "Red",
		TextSize = 21,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
		Size = UDim2.fromOffset(300, 56),
		Radius = 14,
		Visible = false,
		Parent = root,
		OnClick = function()
			ctx.Net.Request("ActivateBarrier")
		end,
	})
	local cooldownFill = UIKit.New("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.82,
		Size = UDim2.fromScale(0, 1),
		ZIndex = barrier.Label.ZIndex - 1,
		Parent = barrier.Face,
	})
	UIKit.Corner(cooldownFill, 14)
	refs.Barrier = barrier.Instance

	-- Bandeau de vol : titre + détail + chrono
	local carryPlate = UIKit.Plate({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
		Size = UDim2.fromOffset(440, 68),
		Visible = false,
		Parent = root,
	}, "Green", 5, 16)
	local carryBanner = carryPlate.Instance
	local carryTitle = UIKit.Text({
		Name = "Title",
		Text = "",
		TextSize = 21,
		TextWrapped = false,
		Position = UDim2.fromOffset(18, 7),
		Size = UDim2.new(1, -124, 0, 28),
		Stroke = 1.75,
		Fit = true,
		ZIndex = 3,
		Parent = carryPlate.Face,
	})
	local carrySub = UIKit.Text({
		Name = "Sub",
		Text = "",
		TextSize = 15,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(18, 34),
		Size = UDim2.new(1, -124, 0, 20),
		Stroke = 1.25,
		ZIndex = 3,
		Parent = carryPlate.Face,
	})
	-- Chrono dans un encart sombre : le chiffre qui compte se lit d'un coup d'œil
	local carryChip = UIKit.New("Frame", {
		Name = "Timer",
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(88, 42),
		ZIndex = 3,
		Parent = carryPlate.Face,
	})
	UIKit.Corner(carryChip, 10)
	local carryTime = UIKit.Text({
		Text = "0:00",
		TextSize = 25,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		Fit = true,
		ZIndex = 4,
		Parent = carryChip,
	})
	local carryScale = UIKit.New("UIScale", { Parent = carryBanner })

	-- Vengeance : téléportation gratuite chez le voleur (navigation -> bleu)
	local revengeTarget: number? = nil
	local revenge = UIKit.Button({
		Name = "Revenge",
		Text = "⚔️ Vengeance !",
		Color = "Blue",
		TextSize = 21,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
		Size = UDim2.fromOffset(300, 64),
		Radius = 14,
		Visible = false,
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
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 13),
		Size = UDim2.new(1, -24, 0, 18),
		Stroke = 1.25,
		Fit = true,
		ZIndex = revenge.Label.ZIndex,
		Parent = revenge.Face,
	})
	local revengeScale = revenge.Instance:FindFirstChildOfClass("UIScale") :: UIScale

	-- Empile les éléments visibles depuis le bas, sans trou
	local function stackBottom()
		local offset = BOTTOM_MARGIN
		for _, item in { barrier.Instance, carryBanner, revenge.Instance } do
			if item.Visible then
				item.Position = UDim2.new(0.5, 0, 1, -offset)
				offset += item.Size.Y.Offset + STACK_GAP
			end
		end
	end

	-- Alertes récentes (intrus, vol) : la barrière est proposée même hors de la base
	local lastAlertAt = -math.huge
	Remotes.GetEvent("Effect").OnClientEvent:Connect(function(effectType)
		if effectType == "StealAlert" or effectType == "HighlightIntruder" then
			lastAlertAt = os.clock()
		end
	end)
	Remotes.GetEvent("Notify").OnClientEvent:Connect(function(text, kind)
		if kind == "Warning" and type(text) == "string" and string.find(text, "Intrus", 1, true) then
			lastAlertAt = os.clock()
		end
	end)

	-------------------------------------------------- Mises à jour
	local lastMoney = State.GetMoney()
	local function refreshMoney()
		local amount = State.GetMoney()
		moneyLabel.Text = Format.Money(amount)
		incomeLabel.Text = "+" .. Format.Income(State.GetIncome())
		-- Petit rebond quand on gagne une grosse somme d'un coup (récompense, vente...)
		if amount > lastMoney * 1.05 + 10 then
			moneyScale.Scale = 1.15
			TweenService:Create(moneyScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastMoney = amount
	end
	State.MoneyChanged:Connect(refreshMoney)
	refreshMoney()

	local currentDimension = nil
	local function update()
		local now = workspace:GetServerTimeNow()
		local profile = State.Profile
		local sinceSync = if profile then os.clock() - (profile.ReceivedAt or os.clock()) else 0

		-- Pilule d'événement
		local stateFolder = State.GameState
		if stateFolder then
			local dimension = Dimensions.Get(State.GetDimension())
			if dimension then
				if dimension.Id ~= currentDimension then
					currentDimension = dimension.Id
					dimName.Text = string.format("%s %s", Theme.DimensionIcons[dimension.Id] or "🌀", dimension.Name)
					UIKit.Pop(event, 0.9)
				end
				dimTime.Text = Format.Time((stateFolder:GetAttribute("DimensionEndsAt") or now) - now)
			end

			local stormStarts = stateFolder:GetAttribute("StormStartsAt") or 0
			local stormEnds = stateFolder:GetAttribute("StormEndsAt") or 0
			local stormActive = State.IsStormActive()
			local stormSoon = not stormActive and stormStarts > now and stormStarts - now <= 15 * 60
			stormDivider.Visible = stormActive or stormSoon
			stormName.Visible = stormDivider.Visible
			stormChip.Visible = stormDivider.Visible
			stormName.Text = if stormActive then "🌪️ Tempête !" else "🌪️"
			stormName.TextColor3 = if stormActive then Theme.Gold else Theme.Text
			stormTime.TextColor3 = stormName.TextColor3
			stormTime.Text = Format.Time(if stormActive then stormEnds - now else stormStarts - now)

			local purchased = State.GetPurchasedLuck()
			local shownLuck = State.GetLuck() -- inclut la tempête
			luckDivider.Visible = shownLuck > 1
			luckName.Visible = shownLuck > 1
			luckChip.Visible = purchased > 1
			luckName.Text = string.format("🍀 x%g", shownLuck)
			luckTime.Text = Format.Time((stateFolder:GetAttribute("LuckEndsAt") or now) - now)
		end

		-- Bonus actifs sous le revenu
		local boostLeft = if profile then (profile.BoostSecondsLeft or 0) - sinceSync else 0
		local bonuses = {}
		local friends = if profile then profile.FriendCount or 0 else 0
		if friends > 0 then
			table.insert(bonuses, string.format("👥 +%d %%", math.round(Economy.GetFriendBonus(friends) * 100)))
		end
		if boostLeft > 0 then
			table.insert(
				bonuses,
				string.format("⚡ x%d · %s", GameConfig.Boosts.MoneyMultiplier, Format.Time(boostLeft))
			)
		end
		bonusLabel.Visible = #bonuses > 0
		bonusLabel.Text = table.concat(bonuses, "    ")

		-- Pastilles rouges et bulle « Cadeau prêt ! »
		if profile then
			local today = Economy.GetUtcDay(State.GetServerUnixTime())
			local dailyReady = profile.Daily.LastDay ~= today
			local giftsReady = Panels.Gifts.HasClaimable(profile)
			badges.Quests.Visible = Panels.Quests.HasClaimable(profile)
			badges.Index.Visible = indexClaimable(profile)
			badges.Rebirth.Visible = State.GetMoney() >= Economy.GetRebirthCost(profile.Rebirths)
			badges.Gifts.Visible = giftsReady
			badges.Daily.Visible = dailyReady
			badges.More.Visible = (giftsReady or dailyReady) and not drawerOpen
			giftBubble.Instance.Visible = giftsReady or dailyReady
			giftTarget = if dailyReady then "Daily" else "Gifts"
			giftBubble.Instance.Position = UDim2.new(1, -8, 0, GIFT_TOP + math.sin(os.clock() * 3) * 3)
		end

		-- Barrière : seulement dans sa base, juste après une alerte, ou pendant un vol subi
		local plot = findMyPlot()
		local beingStolen = profile ~= nil and profile.BeingStolen ~= nil and #profile.BeingStolen > 0
		barrier.Instance.Visible = plot ~= nil
			and (barrierHint or beingStolen or os.clock() - lastAlertAt < ALERT_SECONDS or isInsideBase(plot))
		if plot then
			if plot:GetAttribute("BarrierActive") then
				-- Statut (plus un bouton) : clair, texte bleu
				local left = (plot:GetAttribute("BarrierEndsAt") or now) - now
				barrier:SetColor("White")
				barrier:SetEnabled(true)
				barrier:SetText("🛡️ Protégée · " .. Format.Time(left))
				barrier.Label.TextColor3 = Theme.Info
				barrier.Enabled = false -- ne réagit plus
				cooldownFill.Size = UDim2.fromScale(0, 1)
			else
				local cooldown = (plot:GetAttribute("BarrierCooldownEndsAt") or 0) - now
				if cooldown > 0 then
					barrier:SetEnabled(false)
					barrier:SetText("⏳ Recharge · " .. Format.Time(cooldown))
					cooldownFill.Size = UDim2.fromScale(math.clamp(cooldown / GameConfig.Barrier.Cooldown, 0, 1), 1)
				else
					barrier:SetColor("Red")
					barrier:SetEnabled(true)
					barrier:SetText("🛡️ Activer la barrière")
					cooldownFill.Size = UDim2.fromScale(0, 1)
				end
			end
		end

		-- Vol en cours
		if profile and profile.Carrying then
			local def = Creatures.Get(profile.Carrying.CreatureId)
			carryBanner.Visible = true
			carryPlate:SetColor("Green")
			carryTitle.Text = "🏃 Ramène-la à ta base !"
			carrySub.Text = if def then def.Name else "Ta prise"
			carryTime.Text = Format.Time((profile.Carrying.SecondsLeft or 0) - sinceSync)
			carryChip.Visible = true
			carryTitle.Size = UDim2.new(1, -124, 0, 28)
			carrySub.Size = UDim2.new(1, -124, 0, 20)
			carryTitle.TextXAlignment = Enum.TextXAlignment.Left
			carrySub.TextXAlignment = Enum.TextXAlignment.Left
			carryScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.02
		elseif beingStolen then
			carryBanner.Visible = true
			carryPlate:SetColor("Red")
			carryTitle.Text = "🚨 On te vole !"
			carrySub.Text = "Touche le voleur pour récupérer ta créature !"
			carryChip.Visible = false
			carryTitle.Size = UDim2.new(1, -36, 0, 28)
			carrySub.Size = UDim2.new(1, -36, 0, 20)
			carryTitle.TextXAlignment = Enum.TextXAlignment.Center
			carrySub.TextXAlignment = Enum.TextXAlignment.Center
			carryScale.Scale = 1 + math.abs(math.sin(os.clock() * 6)) * 0.03
		else
			carryBanner.Visible = false
		end

		-- Vengeance disponible
		local revengeInfo = profile and profile.Revenge
		local revengeLeft = if revengeInfo then revengeInfo.SecondsLeft - sinceSync else 0
		if revengeInfo and revengeLeft > 0 then
			revengeTarget = revengeInfo.ThiefUserId
			revenge.Instance.Visible = true
			revengeSub.Text = string.format("sur %s · gratuit · %s", revengeInfo.ThiefName, Format.Time(revengeLeft))
			revengeScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.03
		else
			revengeTarget = nil
			revenge.Instance.Visible = false
		end
		stackBottom()

		-- Une fenêtre ouverte referme le tiroir
		if drawerOpen and ctx.UI.IsAnyOpen() then
			HUD.SetDrawerOpen(false)
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

--[[
	Disposition selon l'écran (appelée par l'UIController) :
	  Compact    : écran peu haut (téléphone en paysage) -> la grille suit l'argent
	               au lieu d'être centrée verticalement
	  LeftOffset : décalage vertical de l'argent (barre Roblox du haut)
]]
function HUD.ApplyLayout(info: { Compact: boolean, LeftOffset: number })
	local money, menu = refs.Money, refs.Menu
	if not money or not menu then
		return
	end
	money.Position = UDim2.fromOffset(8, info.LeftOffset)
	if info.Compact then
		menu.AnchorPoint = Vector2.zero
		menu.Position = UDim2.fromOffset(8, info.LeftOffset + 116)
	else
		menu.AnchorPoint = Vector2.new(0, 0.5)
		menu.Position = UDim2.new(0, 8, 0.5, 24)
	end
end

return HUD
