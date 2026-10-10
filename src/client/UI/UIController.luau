--[[
	UIController
	============
	Construit toute l'interface (ScreenGui "RiftUI") : HUD, notifications et
	une fenêtre unique qui affiche un panneau à la fois.
	Les panneaux visibles sont rafraîchis quand les données changent.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local Notifications = require(script.Parent.Notifications)

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
}

local UIController = {}

local window: Frame
local titleLabel: TextLabel
local panels: { [string]: { Frame: Frame, Instance: any } } = {}
local openName: string? = nil

function UIController.IsOpen(name: string): boolean
	return openName == name
end

function UIController.Close()
	if openName and panels[openName] then
		panels[openName].Frame.Visible = false
	end
	openName = nil
	window.Visible = false
end

function UIController.Open(name: string, arg: any?)
	local panel = panels[name]
	if not panel then
		return
	end
	if openName and openName ~= name and panels[openName] then
		panels[openName].Frame.Visible = false
	end
	openName = name
	titleLabel.Text = PANEL_MODULES[name].Title
	panel.Frame.Visible = true
	window.Visible = true
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

function UIController.Start(ctx)
	local screen = UIKit.New("ScreenGui", {
		Name = "RiftUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	ctx.UI = UIController
	ctx.Toast = Notifications.Toast
	ctx.Net.Toast = Notifications.Toast

	Notifications.Create(screen)
	HUD.Create(screen, ctx)

	-- Fenêtre des panneaux
	window = UIKit.New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.62, 0.68),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	})
	UIKit.New("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(760, 560), Parent = window })
	UIKit.Corner(window, UDim.new(0, 16))
	UIKit.Stroke(window, Theme.Stroke, 3)

	titleLabel = UIKit.Label({
		Text = "",
		TextSize = 26,
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -80, 0, 36),
		Parent = window,
	})
	local close = UIKit.Button("X", Theme.Danger, UIController.Close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 36, 0, 36),
	})
	close.Parent = window

	for name, module in PANEL_MODULES do
		local frame = UIKit.New("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 16, 0, 52),
			Size = UDim2.new(1, -32, 1, -66),
			Visible = false,
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			UIController.Close()
		end
	end)
end

return UIController
