--[[
	Notifications
	=============
	- Toasts empilés en haut à droite (Notify)
	- Grande bannière centrale pour les annonces globales (Announce), en file d'attente
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Notifications = {}

local KIND_COLORS = {
	Info = Theme.Primary,
	Success = Theme.Success,
	Error = Theme.Danger,
	Warning = Theme.Warning,
	Steal = Color3.fromRGB(255, 40, 60),
}

local toastHolder: Frame
local bannerFrame: Frame
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local bannerQueue = {}
local bannerBusy = false

function Notifications.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "Info"] or Theme.Primary
	local toast = UIKit.New("Frame", {
		BackgroundColor3 = Theme.Surface,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	UIKit.Corner(toast, UDim.new(0, 10))
	UIKit.Stroke(toast, color, 2)
	UIKit.Padding(toast, 10)
	UIKit.Label({
		Text = text,
		TextSize = if kind == "Steal" then 20 else 17,
		TextColor3 = if kind == "Steal" then color else Theme.Text,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = toast,
	})
	-- Maximum 5 toasts à l'écran
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(if kind == "Steal" then 7 else 4, function()
		if toast.Parent then
			toast:Destroy()
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
	bannerTitle.TextColor3 = item.Color
	bannerSubtitle.Text = item.Subtitle
	bannerFrame.Visible = true
	bannerFrame.Position = UDim2.new(0.5, 0, 0, -120)
	TweenService
		:Create(bannerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 110) })
		:Play()
	task.delay(3.5, function()
		local out = TweenService:Create(bannerFrame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -120) })
		out:Play()
		out.Completed:Wait()
		bannerFrame.Visible = false
		bannerBusy = false
		playNextBanner()
	end)
end

function Notifications.Banner(title: string, subtitle: string, color: Color3)
	table.insert(bannerQueue, { Title = title, Subtitle = subtitle, Color = color })
	-- On ne garde pas une file infinie
	while #bannerQueue > 4 do
		table.remove(bannerQueue, 1)
	end
	playNextBanner()
end

function Notifications.Create(screen: ScreenGui)
	toastHolder = UIKit.New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 90),
		Size = UDim2.new(0.3, 0, 0.6, 0),
		Parent = screen,
	})
	UIKit.New(
		"UISizeConstraint",
		{ MinSize = Vector2.new(220, 0), MaxSize = Vector2.new(360, math.huge), Parent = toastHolder }
	)
	UIKit.List(toastHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)

	bannerFrame = UIKit.New("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.new(0.6, 0, 0, 84),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	UIKit.New("UISizeConstraint", { MaxSize = Vector2.new(640, 84), Parent = bannerFrame })
	UIKit.Corner(bannerFrame, UDim.new(0, 14))
	UIKit.Stroke(bannerFrame, Theme.Gold, 3)
	bannerTitle = UIKit.Label({
		Text = "",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 6),
		ZIndex = 21,
		Parent = bannerFrame,
	})
	bannerSubtitle = UIKit.Label({
		Text = "",
		Font = Theme.BodyFont,
		TextSize = 16,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 48),
		ZIndex = 21,
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
