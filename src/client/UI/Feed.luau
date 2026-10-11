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

local MAX_ENTRIES = 3
local LIFETIME = 9

local holder: Frame
local counter = 0

function Feed.Push(text: string, color: Color3, icon: string)
	counter += 1
	-- Hauteur automatique : une ligne, ou deux si le message est long (jamais coupé
	-- au milieu d'un nom)
	local entry = UIKit.New("Frame", {
		Name = "Entry",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 36),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -counter,
		Parent = holder,
	})
	UIKit.Corner(entry, 10)
	local entryStroke = UIKit.Stroke(entry, 2.5)
	UIKit.Gradient(entry, Color3.fromRGB(40, 104, 220), Color3.fromRGB(18, 52, 140))
	-- Pastille carrée de la couleur de l'événement, avec son icône
	local accent = UIKit.New("Frame", {
		Name = "Accent",
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Parent = entry,
	})
	UIKit.Corner(accent, 7)
	local accentStroke = UIKit.Stroke(accent, 2)
	local iconLabel = UIKit.Text({
		Text = icon,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		Stroke = 0,
		Parent = accent,
	})
	local label = UIKit.Body({
		Text = text,
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -48, 0, 36),
		AutomaticSize = Enum.AutomaticSize.Y,
		Stroke = 1.5,
		Parent = entry,
	})
	UIKit.Padding(label, 7, 0, 7, 0)
	-- Deux lignes au maximum
	UIKit.New("UISizeConstraint", { MaxSize = Vector2.new(10000, 56), Parent = label })
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
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
			local fade = TweenInfo.new(0.4)
			-- Tout s'efface ensemble (fond, contours, icône, texte)
			TweenService:Create(entry, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(entryStroke, fade, { Transparency = 1 }):Play()
			TweenService:Create(accent, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(accentStroke, fade, { Transparency = 1 }):Play()
			TweenService:Create(iconLabel, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			if labelStroke then
				TweenService:Create(labelStroke, fade, { Transparency = 1 }):Play()
			end
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
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(380, 170),
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
