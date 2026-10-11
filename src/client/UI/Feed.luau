--[[
	Feed
	====
	Fil d'actualité du serveur, en haut à droite : vols, captures rares, fusions,
	vengeances... La preuve sociale ("tout le monde vole, moi aussi !") est un
	moteur d'engagement majeur. 3 lignes au maximum, en pilules sombres
	semi-transparentes (comme la pilule d'événement), texte blanc. Masqué pendant
	qu'une fenêtre est ouverte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Feed = {}

local MAX_ENTRIES = 3
local LIFETIME = 9
-- Largeur maximale du texte : la pilule la plus large ne touche ni les boutons du haut
-- ni la carte du tutoriel (centrés). La bannière d'annonce, elle, masque le fil.
local MAX_TEXT_WIDTH = 280

local holder: Frame
local counter = 0
-- Raisons de masquer le fil (fenêtre ouverte, bannière d'annonce...)
local hiddenBy: { [string]: true } = {}

function Feed.Push(text: string, color: Color3, icon: string)
	counter += 1
	-- La pilule épouse son texte (une ligne, deux au plus pour un message long)
	local entry = UIKit.New("Frame", {
		Name = "Entry",
		BackgroundColor3 = Theme.Hud,
		BackgroundTransparency = Theme.HudTransparency,
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = -counter,
		Parent = holder,
	})
	UIKit.Corner(entry, 14)
	UIKit.Padding(entry, 5, 14, 5, 10)
	UIKit.List(entry, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	-- Point de la couleur de l'événement (rareté de la créature...)
	local dot = UIKit.New("Frame", {
		Name = "Dot",
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(8, 8),
		LayoutOrder = 1,
		Parent = entry,
	})
	UIKit.Round(dot)
	local iconLabel = UIKit.Text({
		Name = "Icon",
		Text = icon,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromOffset(20, 22),
		Stroke = 0,
		LayoutOrder = 2,
		Parent = entry,
	})
	local label = UIKit.Text({
		Name = "Text",
		Text = text,
		TextSize = 16,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		Stroke = 0,
		LayoutOrder = 3,
		Parent = entry,
	})
	UIKit.Padding(label, 3, 0, 3, 0)
	-- Largeur maximale : au-delà, le texte passe à la ligne (deux lignes au plus)
	UIKit.New("UISizeConstraint", { MaxSize = Vector2.new(MAX_TEXT_WIDTH, 48), Parent = label })
	UIKit.Pop(entry, 0.7)

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
			-- Tout s'efface ensemble (fond, point, icône, texte)
			TweenService:Create(entry, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(dot, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(iconLabel, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			task.wait(0.4)
			entry:Destroy()
		end
	end)
end

--[[
	Affiche ou masque le fil pour une raison donnée ("Window" par défaut) : il n'est
	visible que si plus aucune raison ne le masque (une fenêtre ouverte ET une bannière
	ne se contredisent pas).
]]
function Feed.SetVisible(visible: boolean, reason: string?)
	local key = reason or "Window"
	if visible then
		hiddenBy[key] = nil
	else
		hiddenBy[key] = true
	end
	if holder then
		holder.Visible = next(hiddenBy) == nil
	end
end

function Feed.Create(root: Frame)
	holder = UIKit.New("Frame", {
		Name = "Feed",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(420, 130),
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
