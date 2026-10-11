--[[
	UIController
	============
	Construit toute l'interface (ScreenGui "RiftUI") :
	- un cadre racine mis à l'échelle selon la taille de l'écran (UIScale), pour
	  que la même interface soit lisible sur PC, tablette et téléphone ;
	- HUD, fil d'actualité, notifications ;
	- une fenêtre unique (corps blanc, en-tête violet de marque, bouton fermer) qui
	  affiche un panneau à la fois, avec animation d'ouverture.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local Notifications = require(script.Parent.Notifications)
local Feed = require(script.Parent.Feed)

local Panels = script.Parent.Panels
local PANEL_MODULES = {
	Inventory = require(Panels.InventoryPanel),
	Fusion = require(Panels.FusionPanel),
	Base = require(Panels.BasePanel),
	Index = require(Panels.IndexPanel),
	Rebirth = require(Panels.RebirthPanel),
	Shortcut = require(Panels.ShortcutPanel),
	Daily = require(Panels.DailyPanel),
	Leaderboard = require(Panels.LeaderboardPanel),
	Shop = require(Panels.ShopPanel),
	Quests = require(Panels.QuestsPanel),
	Gifts = require(Panels.GiftsPanel),
	Codes = require(Panels.CodesPanel),
}

local UIController = {}

-- Accès aux modules de panneaux (le HUD s'en sert pour ses pastilles rouges)
UIController.Panels = PANEL_MODULES

-- Taille de la fenêtre ; un panneau peut demander une hauteur différente (Panel.Height)
local WINDOW_SIZE = Vector2.new(760, 520)
-- Marges du contenu dans la fenêtre (grille de 8 px)
local CONTENT_SIDE = 20
local CONTENT_TOP = UIKit.HeaderHeight + 16
local CONTENT_BOTTOM = 20

local overlay: TextButton
local window: TextButton
local windowScale: UIScale
local headerIcon: TextLabel
local titleLabel: TextLabel
local panels: { [string]: { Frame: Frame, Instance: any } } = {}
local openName: string? = nil
-- Hauteur utile de l'écran (unités d'interface) et échelle finale de la fenêtre
-- (< 1 sur les petits écrans pour qu'elle tienne en hauteur)
local availableHeight = Theme.ReferenceSize.Y
local windowFit = 1

local function fitFor(height: number): number
	-- 16 : petite marge pour l'ombre portée sous la fenêtre
	return math.min(1, (availableHeight - 16) / height)
end

function UIController.IsOpen(name: string): boolean
	return openName == name
end

function UIController.IsAnyOpen(): boolean
	return openName ~= nil
end

function UIController.Close()
	if openName and panels[openName] then
		panels[openName].Frame.Visible = false
	end
	openName = nil
	window.Visible = false
	overlay.Visible = false
	Feed.SetVisible(true)
end

function UIController.Open(name: string, arg: any?)
	local panel = panels[name]
	local module = PANEL_MODULES[name]
	if not panel or not module then
		return
	end
	if openName and openName ~= name and panels[openName] then
		panels[openName].Frame.Visible = false
	end
	local wasOpen = openName ~= nil
	openName = name
	HUD.SetDrawerOpen(false)

	-- En-tête : même violet de marque pour toutes les fenêtres, icône + titre du panneau
	titleLabel.Text = module.Title
	headerIcon.Text = module.Icon or "⭐"

	-- Hauteur propre au panneau (les panneaux courts n'ont pas de grand vide)
	local height = module.Height or WINDOW_SIZE.Y
	window.Size = UDim2.fromOffset(WINDOW_SIZE.X, height)
	windowFit = fitFor(height)
	windowScale.Scale = windowFit

	panel.Frame.Visible = true
	window.Visible = true
	overlay.Visible = true
	Feed.SetVisible(false)
	if not wasOpen then
		windowScale.Scale = 0.8 * windowFit
		TweenService:Create(windowScale, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = windowFit }):Play()
	end
	if panel.Instance.OnOpen then
		panel.Instance.OnOpen(arg)
	end
	panel.Instance.Refresh()
end

function UIController.Toggle(name: string)
	if openName == name then
		UIController.Close()
	else
		UIController.Open(name)
	end
end

local function refreshOpen()
	if openName and panels[openName] then
		panels[openName].Instance.Refresh()
	end
end

-- Hauteur de la barre Roblox du haut (boutons menu / chat), en pixels écran
local function topInset(): number
	local ok, inset = pcall(function()
		return (GuiService:GetGuiInset())
	end)
	return if ok and typeof(inset) == "Vector2" then inset.Y else 36
end

--[[
	Bouton de saut des contrôles tactiles de Roblox (coin bas droit, mêmes règles que
	le PlayerModule) : largeur depuis le bord droit et hauteur depuis le bas de la zone
	à laisser libre, en pixels écran. nil sans écran tactile.
]]
local function jumpButtonZone(viewport: Vector2): Vector2?
	if not UserInputService.TouchEnabled then
		return nil
	end
	local small = math.min(viewport.X, viewport.Y) <= 500
	local size = if small then 70 else 120
	return Vector2.new(size * 1.5 - 10, if small then size + 20 else size * 1.75)
end

--[[
	Échelle de l'interface selon la taille de l'écran, pour que la même interface
	soit lisible sur PC, tablette et téléphone. Sur les écrans peu hauts (téléphone
	en paysage), disposition compacte : l'interface est calculée pour une hauteur de
	référence plus petite, donc affichée plus grande.
]]
local function setupLayout(root: Frame, padding: UIPadding)
	local scale = UIKit.New("UIScale", { Parent = root })
	local function update()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Theme.ReferenceSize
		local compact = viewport.Y < Theme.CompactBelowHeight
		local referenceHeight = if compact then Theme.CompactReferenceHeight else Theme.ReferenceSize.Y
		local ratio = math.min(viewport.X / Theme.ReferenceSize.X, viewport.Y / referenceHeight)
		local value = math.clamp(ratio, 0.5, 1.3)
		scale.Scale = value
		-- Le cadre racine est agrandi d'autant pour toujours couvrir tout l'écran
		root.Size = UDim2.fromScale(1 / value, 1 / value)

		-- Hauteur utile (unités de l'interface) : la fenêtre rétrécit si elle ne tient pas
		availableHeight = viewport.Y / value - padding.PaddingTop.Offset - padding.PaddingBottom.Offset
		if window then
			window.Position = if compact then UDim2.new(0.5, 0, 0.5, 2) else UDim2.new(0.5, 0, 0.5, 10)
			if openName then
				windowFit = fitFor(window.Size.Y.Offset)
				windowScale.Scale = windowFit
			end
		end

		-- L'argent passe sous les boutons Roblox du haut
		HUD.ApplyLayout({
			Compact = compact,
			LeftOffset = math.max(8, math.ceil(topInset() / value) - padding.PaddingTop.Offset + 8),
		})

		-- Zone du bouton de saut tactile en unités d'interface, depuis le bord du contenu
		local jump = jumpButtonZone(viewport)
		local jumpWidth = if jump then math.ceil(jump.X / value - padding.PaddingRight.Offset + 12) else 0
		local jumpHeight = if jump then math.ceil(jump.Y / value - padding.PaddingBottom.Offset + 12) else 0

		-- Toasts en bas à droite (le côté droit du HUD est libre) ; jamais sur le bouton
		-- de saut tactile : à sa gauche sur téléphone, au-dessus sur tablette
		local toastRight = 16
		local toastBottom = 16
		if jump then
			if compact then
				toastRight = math.max(toastRight, jumpWidth)
			else
				toastBottom = math.max(toastBottom, jumpHeight)
			end
		end
		Notifications.ApplyLayout({ Compact = compact, RightOffset = toastRight, BottomOffset = toastBottom })
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return update
end

local function buildWindow(root: Frame)
	overlay = UIKit.New("TextButton", {
		Name = "Overlay",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.45,
		-- Déborde de la marge de sécurité du cadre racine pour couvrir tout l'écran
		Position = UDim2.fromOffset(-60, -120),
		Size = UDim2.new(1, 120, 1, 240),
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	overlay.Activated:Connect(UIController.Close)

	local chrome = UIKit.Window({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		Visible = false,
		ZIndex = 21,
		Parent = root,
	}, { OnClose = UIController.Close })
	window = chrome.Instance
	headerIcon = chrome.Icon
	titleLabel = chrome.Title
	windowScale = UIKit.New("UIScale", { Parent = window })
end

function UIController.Start(ctx)
	local screen = UIKit.New("ScreenGui", {
		Name = "RiftUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local root = UIKit.New("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screen,
	})
	-- Marge de sécurité (encoche des téléphones, barre Roblox en haut)
	local padding = UIKit.Padding(root, 44, 8, 8, 8)
	local updateLayout = setupLayout(root, padding)

	ctx.UI = UIController
	ctx.Root = root
	ctx.Toast = Notifications.Toast
	ctx.Net.Toast = Notifications.Toast

	HUD.Create(root, ctx)
	Feed.Create(root)
	buildWindow(root)
	Notifications.Create(root)
	updateLayout()

	for name, module in PANEL_MODULES do
		local frame = UIKit.New("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(CONTENT_SIDE, CONTENT_TOP),
			Size = UDim2.new(1, -2 * CONTENT_SIDE, 1, -(CONTENT_TOP + CONTENT_BOTTOM)),
			Visible = false,
			ZIndex = 23,
			Parent = window,
		})
		panels[name] = { Frame = frame, Instance = module.Create(frame, ctx) }
	end

	-- Rafraîchissements
	ctx.State.ProfileChanged:Connect(refreshOpen)
	ctx.State.GameStateChanged:Connect(function()
		if openName == "Shop" or openName == "Index" then
			refreshOpen()
		end
	end)
	-- L'argent change chaque seconde : rafraîchissement limité aux panneaux concernés
	local lastMoneyRefresh = 0
	ctx.State.MoneyChanged:Connect(function()
		if os.clock() - lastMoneyRefresh < 0.5 then
			return
		end
		lastMoneyRefresh = os.clock()
		if openName == "Base" or openName == "Rebirth" or openName == "Shortcut" then
			refreshOpen()
		end
	end)
	ctx.State.OpenPanelRequested:Connect(function(name: string, arg: any)
		UIController.Open(name, arg)
	end)

	-- Comptes à rebours : le panneau ouvert peut définir Tick() (appelé chaque seconde)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		local panel = openName and panels[openName]
		if panel and panel.Instance.Tick then
			panel.Instance.Tick()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Escape then
			return
		end
		if openName then
			UIController.Close()
		else
			HUD.SetDrawerOpen(false)
		end
	end)
end

return UIController
