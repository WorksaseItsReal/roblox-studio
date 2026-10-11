--[[
	Notifications
	=============
	- Toasts empilés à droite, qui glissent depuis le bord (Notify)
	- Grande bannière centrale pour les annonces globales (Announce), en file d'attente
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Notifications = {}

local toastHolder: Frame
local bannerFrame: Frame
local bannerGradient: UIGradient
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local bannerScale: UIScale
local bannerQueue = {}
local bannerBusy = false
local toastCounter = 0

function Notifications.Toast(text: string, kind: string?)
	kind = kind or "Info"
	local palette = Theme.Palette[Theme.KindPalette[kind] or "Blue"]
	toastCounter += 1

	-- Le cadre extérieur reste fixe dans la liste ; l'intérieur glisse depuis la droite
	local slot = UIKit.New("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = toastCounter, -- le plus récent en bas
		Parent = toastHolder,
	})
	local toast = UIKit.New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1.2, 0, 0, 0),
		Parent = slot,
	})
	UIKit.Corner(toast, 18)
	UIKit.Stroke(toast, 3)
	UIKit.Gradient(toast, Color3.fromRGB(80, 66, 156), Color3.fromRGB(44, 34, 98))
	UIKit.Padding(toast, 10, 14, 10, 62)
	UIKit.IconCircle(Theme.KindIcons[kind] or "💬", palette[2], 44, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -54, 0.5, 0),
		Parent = toast,
	})
	UIKit.Text({
		Text = text,
		TextSize = if kind == "Steal" then 19 else 17,
		TextColor3 = if kind == "Steal" then Color3.fromRGB(255, 190, 190) else Theme.Text,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = toast,
	})
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new() }):Play()

	-- Maximum 4 toasts à l'écran
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy() -- le plus ancien
	end

	task.delay(if kind == "Steal" then 7 else 4, function()
		if slot.Parent then
			local out = TweenService:Create(toast, TweenInfo.new(0.25), { Position = UDim2.new(1.2, 0, 0, 0) })
			out:Play()
			out.Completed:Wait()
			slot:Destroy()
		end
	end)
end

local function playNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local item = table.remove(bannerQueue, 1)
	bannerTitle.Text = item.Title
	bannerSubtitle.Text = item.Subtitle
	bannerGradient.Color = ColorSequence.new(Theme.Lighten(item.Color, 0.1), Theme.Darken(item.Color, 0.55))
	bannerFrame.Visible = true
	bannerScale.Scale = 0.3
	TweenService:Create(bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3.6, function()
		local out = TweenService:Create(
			bannerScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0 }
		)
		out:Play()
		out.Completed:Wait()
		bannerFrame.Visible = false
		bannerBusy = false
		playNextBanner()
	end)
end

function Notifications.Banner(title: string, subtitle: string, color: Color3)
	table.insert(bannerQueue, { Title = title, Subtitle = subtitle, Color = color })
	while #bannerQueue > 4 do
		table.remove(bannerQueue, 1)
	end
	playNextBanner()
end

function Notifications.Create(root: Frame)
	-- En bas à droite : ne masque ni le HUD ni le bouton de fermeture des fenêtres
	toastHolder = UIKit.New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -112, 1, -18), -- à gauche du rail de récompenses
		Size = UDim2.fromOffset(340, 520),
		ZIndex = 30,
		Parent = root,
	})
	UIKit.List(
		toastHolder,
		Enum.FillDirection.Vertical,
		10,
		Enum.HorizontalAlignment.Right,
		Enum.VerticalAlignment.Bottom
	)

	bannerFrame = UIKit.New("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(660, 104),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 40,
		Parent = root,
	})
	UIKit.Corner(bannerFrame, 26)
	UIKit.Stroke(bannerFrame, 4)
	bannerGradient = UIKit.Gradient(bannerFrame, Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 60, 10))
	bannerScale = UIKit.New("UIScale", { Parent = bannerFrame })
	bannerTitle = UIKit.Text({
		Text = "",
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextScaled = true,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 48),
		Stroke = 3.5,
		ZIndex = 41,
		Parent = bannerFrame,
	})
	UIKit.New("UITextSizeConstraint", { MaxTextSize = 38, Parent = bannerTitle })
	bannerSubtitle = UIKit.Text({
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 0, 40),
		Stroke = 2,
		ZIndex = 41,
		Parent = bannerFrame,
	})

	Remotes.GetEvent("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Notifications.Toast(text, if type(kind) == "string" then kind else "Info")
		end
	end)
	Remotes.GetEvent("Announce").OnClientEvent:Connect(function(title, subtitle, color)
		if type(title) == "string" then
			Notifications.Banner(
				title,
				if type(subtitle) == "string" then subtitle else "",
				if typeof(color) == "Color3" then color else Theme.Gold
			)
		end
	end)
end

return Notifications
