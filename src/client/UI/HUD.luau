--[[
	HUD
	===
	Disposition façon Grow a Garden, style v3 « propre » (voir docs/ART_DIRECTION.md) :
	- Haut centre  : LES 3 gros boutons du jeu, identiques : Rift (téléportation sur
	                 l'esplanade où sortent les créatures), Ma base (téléportation chez soi),
	                 Boutique. Dessous, une petite pilule d'événement (dimension + minuteur,
	                 tempête proche, chance).
	- Haut gauche  : le Sac (ouvre les créatures).
	- Gauche       : colonne de tuiles identiques : Index, Quêtes, Rebirth, Plus (tiroir :
	                 Fusion, Base, Portail, Classement, Cadeaux, Quotidien, Codes, Inviter).
	                 Pastille rouge « ! » sur la tuile concernée (ou sur Plus).
	- Bas gauche   : l'argent (gros chiffre Luckiest Guy) et le revenu/s dessous. Sur écran
	                 tactile : en haut à gauche, à côté du Sac (le bas gauche est la zone du
	                 joystick de Roblox).
	- Droite       : fil d'actualité ; bulle or « Cadeau prêt ! » quand c'est réclamable.
	- Bas centre   : uniquement contextuel : barrière (dans sa base ou juste après une
	                 alerte), bandeau de vol, vengeance.
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
local COLUMN_HEIGHT = 4 * TILE + 3 * GAP_Y
local DRAWER_COLUMNS = 4
local DRAWER_PADDING = 14
local DRAWER_SIZE = Vector2.new(
	2 * DRAWER_PADDING + DRAWER_COLUMNS * TILE + (DRAWER_COLUMNS - 1) * GAP_X,
	DRAWER_PADDING + 2 * TILE + 2 * GAP_Y + 4
)
-- Boutons du haut (plus hauts sur téléphone : cibles tactiles confortables)
local TOP_TOP = 4
local TOP_GAP = 12
local TOP_SIZE = Vector2.new(164, 64)
local TOP_SIZE_COMPACT = Vector2.new(172, 72)
local EVENT_HEIGHT = 34
local BOTTOM_MARGIN = 14 -- pile du bas (barrière, bandeau de vol, vengeance)
local STACK_GAP = 12
local ALERT_SECONDS = 20 -- la barrière reste proposée après une alerte d'intrusion ou de vol
-- Position verticale de la bulle « Cadeau prêt ! » : sous le fil d'actualité, même
-- quand ses 3 pilules font deux lignes
local GIFT_TOP = 236

local TOP = {
	{ Id = "Rift", Text = "Rift", Icon = "🌀" },
	{ Id = "Base", Text = "Ma base", Icon = "🏠" },
	{ Id = "Shop", Text = "Boutique", Icon = "🛒" },
}

local COLUMN = {
	{ Id = "Index", Text = "Index", Icon = "📖" },
	{ Id = "Quests", Text = "Quêtes", Icon = "📜" },
	{ Id = "Rebirth", Text = "Rebirth", Icon = "🔁" },
	{ Id = "More", Text = "Plus", Icon = "+" },
}

local DRAWER = {
	{ Id = "Fusion", Text = "Fusion", Icon = "⚗️" },
	{ Id = "Base", Text = "Améliorer", Icon = "🛠️" },
	{ Id = "Shortcut", Text = "Portail", Icon = "🌠" },
	{ Id = "Leaderboard", Text = "Classement", Icon = "🏆" },
	{ Id = "Gifts", Text = "Cadeaux", Icon = "🎁" },
	{ Id = "Daily", Text = "Quotidien", Icon = "📅" },
	{ Id = "Codes", Text = "Codes", Icon = "🔑" },
	{ Id = "Invite", Text = "Inviter", Icon = "👥" },
}

-- Éléments partagés avec ApplyLayout, SetDrawerOpen et le tutoriel
local refs: {
	Top: Frame?,
	TopButtons: { [string]: Frame },
	Event: Frame?,
	TopAnchor: Frame?,
	Bag: Frame?,
	Money: Frame?,
	MoneyList: UIListLayout?,
	Column: Frame?,
	Drawer: Frame?,
	Catcher: TextButton?,
	MoreIcon: TextLabel?,
	MoreBadge: Frame?,
	Barrier: Frame?,
} =
	{ TopButtons = {} }
local drawerOpen = false
local barrierHint = false
-- Bas de la pile du haut (boutons + pilule d'événement), en unités d'interface
local topStackBottom = TOP_TOP + TOP_SIZE.Y + 8 + EVENT_HEIGHT

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

-- Tutoriel : cadre d'un des 3 boutons du haut ("Rift", "Base", "Shop"), pour l'entourer
function HUD.GetTopButton(id: string): Frame?
	return refs.TopButtons[id]
end

--[[
	Point d'ancrage centré juste sous la pile du haut (boutons + pilule d'événement) :
	le tutoriel y accroche sa carte, qui suit ainsi la disposition (téléphone, PC).
]]
function HUD.GetTopAnchor(): Frame?
	return refs.TopAnchor
end

-- Bas de la pile du haut, en unités d'interface (bannière d'annonce dessous)
function HUD.GetTopStackBottom(): number
	return topStackBottom
end

--[[
	Gros bouton du haut : dégradé bleu (navigation), rebord, contour encre, pastille
	blanche avec l'icône et libellé blanc à contour, le groupe centré. Les 3 sont
	identiques.
]]
local function topButton(item, order: number, parent: Instance, onClick: () -> (), onBlocked: () -> ())
	local button = UIKit.Button({
		Name = item.Id,
		Text = item.Text,
		Color = "Blue",
		TextSize = 21,
		Size = UDim2.fromOffset(TOP_SIZE.X, TOP_SIZE.Y),
		Radius = 16,
		Depth = 5,
		StrokeThickness = 3,
		Fit = false,
		LayoutOrder = order,
		Parent = parent,
		OnClick = onClick,
		OnBlocked = onBlocked,
	})
	-- Icône + libellé centrés ensemble, quelle que soit la longueur du libellé
	local content = UIKit.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = button.Face.ZIndex + 1,
		Parent = button.Face,
	})
	UIKit.List(content, Enum.FillDirection.Horizontal, 7, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local badge = UIKit.New("Frame", {
		Name = "IconBadge",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(40, 40),
		LayoutOrder = 1,
		ZIndex = content.ZIndex,
		Parent = content,
	})
	UIKit.Round(badge)
	UIKit.Stroke(badge, 2.5)
	UIKit.Text({
		Name = "Glyph",
		Text = item.Icon,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		ZIndex = badge.ZIndex + 1,
		Parent = badge,
	})
	local label = button.Label
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 30)
	label.LayoutOrder = 2
	label.ZIndex = content.ZIndex
	label.Parent = content
	-- Recharge de la téléportation : voile qui se retire de gauche à droite
	local cooldown = UIKit.New("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.7,
		Size = UDim2.fromScale(0, 1),
		Visible = false,
		ZIndex = button.Face.ZIndex + 3,
		Parent = button.Face,
	})
	UIKit.Corner(cooldown, 16)
	return button, cooldown
end

function HUD.Create(root: Frame, ctx)
	local State = ctx.State
	local Panels = ctx.UI.Panels

	-------------------------------------------------- Boutons du haut (le cœur du HUD)
	local top = UIKit.New("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_TOP),
		Size = UDim2.fromOffset(3 * TOP_SIZE.X + 2 * TOP_GAP, TOP_SIZE.Y),
		Parent = root,
	})
	UIKit.List(top, Enum.FillDirection.Horizontal, TOP_GAP, Enum.HorizontalAlignment.Center)
	refs.Top = top

	-- Téléportations : une à la fois, puis recharge (le serveur a le dernier mot)
	local teleportPending = false
	local teleportReadyAt = 0
	local function teleport(destination: string)
		if teleportPending or os.clock() < teleportReadyAt then
			return
		end
		teleportPending = true
		local response = ctx.Net.Request("Teleport", destination)
		teleportPending = false
		if response.Ok then
			teleportReadyAt = os.clock() + GameConfig.Movement.TeleportCooldown
		end
	end
	local function refuseWhileCarrying()
		ctx.Toast("Impossible de te téléporter en portant une créature volée !", "Error")
	end

	local teleportButtons = {}
	local cooldownFills = {}
	for order, item in TOP do
		local button, cooldown = topButton(item, order, top, function()
			HUD.SetDrawerOpen(false)
			if item.Id == "Shop" then
				ctx.UI.Toggle("Shop")
			else
				teleport(item.Id)
			end
		end, refuseWhileCarrying)
		refs.TopButtons[item.Id] = button.Instance
		if item.Id ~= "Shop" then
			table.insert(teleportButtons, button)
			table.insert(cooldownFills, cooldown)
		end
	end

	-------------------------------------------------- Pilule d'événement (sous les boutons)
	local event = UIKit.New("Frame", {
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_TOP + TOP_SIZE.Y + 8),
		Size = UDim2.fromOffset(0, EVENT_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Hud,
		BackgroundTransparency = Theme.HudTransparency,
		Parent = root,
	})
	UIKit.Round(event)
	UIKit.Padding(event, 0, 6, 0, 14)
	UIKit.List(event, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	refs.Event = event
	-- Texte d'un segment (icône + nom), largeur automatique
	local function segment(order: number): TextLabel
		return UIKit.Text({
			Text = "",
			TextSize = 17,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
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
			Size = UDim2.fromOffset(width, 24),
			LayoutOrder = order,
			Parent = event,
		})
		UIKit.Corner(chip, 8)
		return chip,
			UIKit.Text({
				Text = "",
				TextSize = 16,
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
			Size = UDim2.fromOffset(2, 16),
			LayoutOrder = order,
			Parent = event,
		})
	end
	local dimName = segment(1)
	local _, dimTime = timer(2, 48)
	local stormDivider = divider(3)
	local stormName = segment(4)
	local stormChip, stormTime = timer(5, 52)
	local luckDivider = divider(6)
	local luckName = segment(7)
	local luckChip, luckTime = timer(8, 52)

	-- Ancre du tutoriel, centrée sous la pilule
	refs.TopAnchor = UIKit.New("Frame", {
		Name = "TopAnchor",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, topStackBottom + 12),
		Size = UDim2.fromOffset(0, 0),
		Parent = root,
	})

	-------------------------------------------------- Sac (haut gauche)
	local bag = UIKit.IconButton({
		Name = "Bag",
		Icon = "🎒",
		Text = "Sac",
		Parent = root,
		OnClick = function()
			HUD.SetDrawerOpen(false)
			ctx.UI.Toggle("Inventory")
		end,
	})
	bag.Instance.Position = UDim2.fromOffset(8, 16)
	refs.Bag = bag.Instance

	-------------------------------------------------- Argent (bas gauche, sans cadre)
	local money = UIKit.New("Frame", {
		Name = "Money",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(400, 104),
		Parent = root,
	})
	refs.MoneyList =
		UIKit.List(money, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
	local amountRow = UIKit.New("Frame", {
		Name = "AmountRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 1,
		Parent = money,
	})
	UIKit.Text({
		Name = "Icon",
		Text = "💵",
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(52, 48),
		Stroke = 0,
		Parent = amountRow,
	})
	local moneyLabel = UIKit.Text({
		Name = "Amount",
		Text = "$0",
		Font = Theme.DisplayFont,
		TextSize = 50,
		TextWrapped = false,
		Position = UDim2.fromOffset(58, 0),
		Size = UDim2.new(1, -58, 1, 0),
		Stroke = 3.5,
		Fit = true,
		Parent = amountRow,
	})
	UIKit.Gradient(moneyLabel, Color3.fromRGB(160, 248, 140), Theme.Money)
	local incomeLabel = UIKit.Text({
		Name = "Income",
		Text = "+$0/s",
		TextSize = 21,
		TextColor3 = Theme.Gold,
		TextWrapped = false,
		Size = UDim2.new(1, -60, 0, 26),
		Stroke = 2,
		LayoutOrder = 2,
		Parent = money,
	})
	UIKit.Padding(incomeLabel, 0, 0, 0, 60)
	-- Bonus actifs (amis, boost x2) : une petite ligne, seulement quand il y en a
	local bonusLabel = UIKit.Text({
		Name = "Bonus",
		Text = "",
		TextSize = 15,
		TextWrapped = false,
		Size = UDim2.new(1, -61, 0, 20),
		Stroke = 1.5,
		Visible = false,
		LayoutOrder = 3,
		Parent = money,
	})
	UIKit.Padding(bonusLabel, 0, 0, 0, 61)
	local moneyScale = UIKit.New("UIScale", { Parent = moneyLabel })
	refs.Money = money

	-------------------------------------------------- Colonne de gauche + tiroir « Plus »
	local column = UIKit.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(TILE, COLUMN_HEIGHT),
		ZIndex = 5,
		Parent = root,
	})
	local grid = UIKit.New("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = column,
	})
	UIKit.List(grid, Enum.FillDirection.Vertical, GAP_Y)
	refs.Column = column

	-- Clic hors du tiroir : il se referme (sous la colonne, pour que les tuiles restent cliquables)
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
	for order, item in COLUMN do
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

	-- Tiroir : il « sort » de Plus, ses deux rangées alignées sur Rebirth et Plus
	local drawer = UIKit.New("Frame", {
		Name = "Drawer",
		Position = UDim2.new(1, 16, 1, -(2 * TILE + GAP_Y + DRAWER_PADDING)),
		Size = UDim2.fromOffset(DRAWER_SIZE.X, DRAWER_SIZE.Y),
		BackgroundColor3 = Theme.Hud,
		BackgroundTransparency = 0.22,
		Visible = false,
		ZIndex = 6,
		Parent = column,
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

		-- Téléportations : impossibles en portant une créature volée, puis recharge
		local carrying = profile ~= nil and profile.Carrying ~= nil
		local cooldownLeft = math.max(0, teleportReadyAt - os.clock())
		for index, button in teleportButtons do
			button:SetEnabled(not carrying)
			local fill = cooldownFills[index]
			fill.Visible = cooldownLeft > 0 and not carrying
			fill.Size = UDim2.fromScale(cooldownLeft / GameConfig.Movement.TeleportCooldown, 1)
		end

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
	  Compact    : écran peu haut (téléphone en paysage) -> boutons du haut plus hauts
	  Touch      : écran tactile -> l'argent passe en haut à gauche, à côté du Sac : le
	               bas gauche est la zone du joystick de Roblox (idem sur un écran peu
	               haut : la colonne de gauche y descend jusqu'en bas)
	  LeftOffset : haut de la colonne de gauche (sous la barre Roblox du haut)
	Renvoie le bas de la pile du haut (bannière d'annonce, tutoriel dessous).
]]
function HUD.ApplyLayout(info: { Compact: boolean, Touch: boolean, LeftOffset: number }): number
	local top, event, anchor, bag = refs.Top, refs.Event, refs.TopAnchor, refs.Bag
	local money, moneyList, column = refs.Money, refs.MoneyList, refs.Column
	if not top or not event or not anchor or not bag or not money or not moneyList or not column then
		return topStackBottom
	end
	local size = if info.Compact then TOP_SIZE_COMPACT else TOP_SIZE
	top.Size = UDim2.fromOffset(3 * size.X + 2 * TOP_GAP, size.Y)
	for _, button in refs.TopButtons do
		button.Size = UDim2.fromOffset(size.X, size.Y)
	end
	event.Position = UDim2.new(0.5, 0, 0, TOP_TOP + size.Y + 8)
	topStackBottom = TOP_TOP + size.Y + 8 + EVENT_HEIGHT
	anchor.Position = UDim2.new(0.5, 0, 0, topStackBottom + 12)

	bag.Position = UDim2.fromOffset(8, info.LeftOffset)
	if info.Touch or info.Compact then
		-- À droite du Sac, au-dessus de la zone du joystick
		money.AnchorPoint = Vector2.zero
		money.Position = UDim2.fromOffset(TILE + 22, info.LeftOffset - 6)
		-- Assez étroit pour ne jamais toucher le bouton Rift (le montant rétrécit)
		money.Size = UDim2.fromOffset(260, 104)
		moneyList.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		money.AnchorPoint = Vector2.new(0, 1)
		money.Position = UDim2.new(0, 8, 1, -8)
		money.Size = UDim2.fromOffset(400, 104)
		moneyList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	-- Colonne : sous le Sac sur téléphone, centrée verticalement ailleurs
	if info.Compact then
		column.AnchorPoint = Vector2.zero
		column.Position = UDim2.fromOffset(8, info.LeftOffset + TILE + GAP_Y + 14)
	else
		column.AnchorPoint = Vector2.new(0, 0.5)
		column.Position = UDim2.new(0, 8, 0.5, 10)
	end
	return topStackBottom
end

return HUD
