--[[
	UIController
	============
	Construit toute l'interface (ScreenGui "RiftUI") :
	- un cadre racine mis à l'échelle selon la taille de l'écran (UIScale), pour
	  que la même interface soit lisible sur PC, tablette et téléphone ;
	- HUD, notifications ;
	- une fenêtre unique (bandeau coloré + icône + bouton fermer) qui affiche un
	  panneau à la fois, avec animation d'ouverture.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Format = require(game:GetService("ReplicatedStorage").Shared.Modules.Format)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local Notifications = require(script.Parent.Notifications)
local Feed = require(script.Parent.Feed)
local RunService = game:GetService("RunService")

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

local WINDOW_SIZE = Vector2.new(780, 560)

local overlay: TextButton
local window: Frame
local windowScale: UIScale
local header: Frame
local headerGradient: UIGradient
local headerIcon: Frame
local titleLabel: TextLabel
local panels: { [string]: { Frame: Frame, Instance: any } } = {}
local openName: string? = nil

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

	-- Bandeau aux couleurs du panneau
	local palette = Theme.Palette[module.Color or "Blue"] or Theme.Palette.Blue
	headerGradient.Color = ColorSequence.new(palette[1], palette[2])
	titleLabel.Text = Format.Upper(module.Title)
	local glyph = headerIcon:FindFirstChild("Glyph") :: TextLabel
	glyph.Text = module.Icon or "⭐"
	local iconGradient = headerIcon:FindFirstChildOfClass("UIGradient")
	if iconGradient then
		iconGradient.Color = ColorSequence.new(Theme.Lighten(palette[1], 0.3), palette[2])
	end

	panel.Frame.Visible = true
	window.Visible = true
	overlay.Visible = true
	Feed.SetVisible(false)
	if not wasOpen then
		windowScale.Scale = 0.7
		TweenService:Create(windowScale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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

-- Échelle de l'interface selon la taille de l'écran
local function setupScaling(root: Frame)
	local scale = UIKit.New("UIScale", { Parent = root })
	local function update()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Theme.ReferenceSize
		local ratio = math.min(viewport.X / Theme.ReferenceSize.X, viewport.Y / Theme.ReferenceSize.Y)
		local value = math.clamp(ratio, 0.5, 1.3)
		scale.Scale = value
		-- Le cadre racine est agrandi d'autant pour toujours couvrir tout l'écran
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

local function buildWindow(root: Frame)
	overlay = UIKit.New("TextButton", {
		Name = "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 6, 24),
		BackgroundTransparency = 0.45,
		-- Déborde de la marge de sécurité du cadre racine pour couvrir tout l'écran
		Position = UDim2.fromOffset(-60, -120),
		Size = UDim2.new(1, 120, 1, 240),
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	overlay.Activated:Connect(UIController.Close)

	window = UIKit.New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 40, 0.5, 30),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 21,
		Parent = root,
	})
	windowScale = UIKit.New("UIScale", { Parent = window })
	UIKit.Corner(window, 26)
	UIKit.Stroke(window, 4.5)
	UIKit.Gradient(window, Theme.PanelTop, Theme.PanelBottom)

	-- Bandeau de titre
	header = UIKit.New("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 74),
		ZIndex = 22,
		Parent = window,
	})
	UIKit.Corner(header, 26)
	UIKit.Stroke(header, 4.5)
	headerGradient = UIKit.Gradient(header, Theme.Palette.Blue[1], Theme.Palette.Blue[2])
	UIKit.New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 22),
		ZIndex = 23,
		Parent = header,
	})
	UIKit.Corner(header:FindFirstChild("Shine") :: Instance, 12)
	headerIcon = UIKit.IconCircle("⭐", Theme.Gold, 84, {
		Position = UDim2.fromOffset(-22, -22),
		ZIndex = 25,
		Parent = header,
	})
	titleLabel = UIKit.Text({
		Text = "",
		TextSize = 34,
		TextWrapped = false,
		Position = UDim2.fromOffset(78, 0),
		Size = UDim2.new(1, -160, 1, 0),
		Stroke = 3.5,
		ZIndex = 24,
		Parent = header,
	})

	local close = UIKit.Button({
		Name = "Close",
		Text = "✕",
		Color = "Red",
		TextSize = 30,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 18, 0, -18),
		Size = UDim2.fromOffset(64, 64),
		ZIndex = 26,
		OnClick = UIController.Close,
		Parent = window,
	})
	close.Face:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	close.Instance:FindFirstChild("Shadow"):FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
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
	UIKit.Padding(root, 44, 8, 8, 8)
	setupScaling(root)

	ctx.UI = UIController
	ctx.Root = root
	ctx.Toast = Notifications.Toast
	ctx.Net.Toast = Notifications.Toast

	HUD.Create(root, ctx)
	Feed.Create(root)
	buildWindow(root)
	Notifications.Create(root)

	for name, module in PANEL_MODULES do
		local frame = UIKit.New("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(22, 92),
			Size = UDim2.new(1, -44, 1, -110),
			Visible = false,
			ZIndex = 22,
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
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			UIController.Close()
		end
	end)
end

return UIController
