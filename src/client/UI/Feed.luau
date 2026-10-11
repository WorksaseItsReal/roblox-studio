--[[
	Feed
	====
	Fil d'actualité du serveur, en haut à droite : vols, captures rares, fusions,
	vengeances... La preuve sociale ("tout le monde vole, moi aussi !") est un
	moteur d'engagement majeur. Masqué pendant qu'une fenêtre est ouverte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Feed = {}

local MAX_ENTRIES = 4
local LIFETIME = 9

local holder: Frame
local counter = 0

function Feed.Push(text: string, color: Color3, icon: string)
	counter += 1
	local entry = UIKit.New("Frame", {
		Name = "Entry",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = -counter,
		Parent = holder,
	})
	UIKit.Round(entry)
	UIKit.Stroke(entry, 2.5)
	UIKit.Gradient(entry, Color3.fromRGB(70, 56, 140), Color3.fromRGB(38, 28, 84))
	-- Liseré coloré à gauche
	local accent = UIKit.New("Frame", {
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(22, 22),
		Parent = entry,
	})
	UIKit.Round(accent)
	UIKit.Text({
		Text = icon,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		Parent = accent,
	})
	local label = UIKit.Text({
		Text = text,
		TextSize = 15,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Parent = entry,
	})
	UIKit.Pop(entry, 0.6)

	local entries = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = MAX_ENTRIES + 1, #entries do
		entries[i]:Destroy()
	end

	task.delay(LIFETIME, function()
		if entry.Parent then
			TweenService:Create(entry, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			entry:Destroy()
		end
	end)
end

function Feed.SetVisible(visible: boolean)
	holder.Visible = visible
end

function Feed.Create(root: Frame)
	holder = UIKit.New("Frame", {
		Name = "Feed",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 14),
		Size = UDim2.fromOffset(360, 170),
		ZIndex = 10,
		Parent = root,
	})
	UIKit.List(holder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)

	Remotes.GetEvent("Feed").OnClientEvent:Connect(function(text, color, icon)
		if type(text) == "string" then
			Feed.Push(
				text,
				if typeof(color) == "Color3" then color else Theme.Gold,
				if type(icon) == "string" then icon else "📣"
			)
		end
	end)
end

return Feed
