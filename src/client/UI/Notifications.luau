--[[
	Notifications
	=============
	- Toasts : cartes blanches à liseré coloré à gauche (vert = succès, rouge = erreur
	  ou vol, bleu = info, orange = avertissement), texte foncé, empilées en bas à droite
	  et qui glissent depuis le bord (Toast)
	- Grande bannière centrale pour les annonces globales (Banner), en file d'attente
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Feed = require(script.Parent.Feed)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Notifications = {}

local toastHolder: Frame
local bannerFrame: Frame
local bannerPlate: UIKit.Plate
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local bannerScale: UIScale
local bannerQueue = {}
local bannerBusy = false
local toastCounter = 0
-- Nombre maximum de toasts à l'écran (moins sur téléphone, voir ApplyLayout)
local maxToasts = 4
-- Largeur de la bannière centrale (le fil d'actualité est masqué pendant l'annonce)
local BANNER_WIDTH = 600

function Notifications.Toast(text: string, kind: string?)
	kind = kind or "Info"
	local color = Theme.KindColors[kind] or Theme.Info
	local isSteal = kind == "Steal"
	local background = if isSteal then Theme.Tint(Theme.Danger, 0.1) else Color3.new(1, 1, 1)
	toastCounter += 1

	-- Le cadre extérieur reste fixe dans la liste ; la carte glisse depuis la droite
	local slot = UIKit.New("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = toastCounter, -- le plus récent en bas
		Parent = toastHolder,
	})
	local card = UIKit.New("Frame", {
		Name = "Card",
		BackgroundColor3 = background,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1.2, 0, 0, 0),
		Parent = slot,
	})
	UIKit.Corner(card, 12)
	UIKit.Stroke(card, 2)
	-- Liseré coloré : bande arrondie à gauche, recouverte à droite par le fond de la carte
	local edge = UIKit.New("Frame", {
		Name = "Edge",
		BackgroundColor3 = color,
		Size = UDim2.new(0, 16, 1, 0),
		Parent = card,
	})
	UIKit.Corner(edge, 12)
	UIKit.New("Frame", {
		Name = "EdgeCover",
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(0, 12, 1, 0),
		Parent = card,
	})
	UIKit.Text({
		Name = "Icon",
		Text = Theme.KindIcons[kind] or "💬",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Stroke = 0,
		ZIndex = 2,
		Parent = card,
	})
	local label = UIKit.Label({
		Name = "Text",
		Text = text,
		TextSize = 17,
		TextWrapped = true,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -64, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = card,
	})
	UIKit.Padding(label, 11, 0, 11, 0)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new() }):Play()

	-- Nombre limité de toasts à l'écran : le plus ancien disparaît
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > maxToasts then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #toasts - maxToasts do
			toasts[i]:Destroy() -- les plus anciens
		end
	end

	task.delay(if isSteal then 7 else 4, function()
		if slot.Parent then
			local out = TweenService:Create(card, TweenInfo.new(0.25), { Position = UDim2.new(1.2, 0, 0, 0) })
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
	bannerSubtitle.Visible = item.Subtitle ~= ""
	bannerPlate:SetColor(Theme.PaletteFrom(Theme.Vivid(item.Color)))
	bannerFrame.Visible = true
	-- L'annonce est le point focal : le fil d'actualité (même bande en haut) s'efface
	Feed.SetVisible(false, "Banner")
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
		Feed.SetVisible(true, "Banner")
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

--[[
	Disposition selon l'écran (appelée par l'UIController) :
	  Compact      : écran peu haut (téléphone) -> toasts et bannière moins larges
	  RightOffset  : écart entre les toasts et le bord droit (bouton de saut tactile)
	  BottomOffset : écart entre les toasts et le bas de l'écran
]]
function Notifications.ApplyLayout(info: { Compact: boolean, RightOffset: number, BottomOffset: number })
	if not toastHolder or not bannerFrame then
		return
	end
	toastHolder.Position = UDim2.new(1, -info.RightOffset, 1, -info.BottomOffset)
	-- Largeur choisie pour ne jamais toucher la pile du bas (barrière, bandeau de vol),
	-- même à gauche du bouton de saut tactile
	toastHolder.Size = if info.Compact then UDim2.fromOffset(240, 300) else UDim2.fromOffset(310, 480)
	-- Téléphone : 2 toasts au plus (au-delà, la pile monterait jusqu'à la bulle « Cadeau prêt »)
	maxToasts = if info.Compact then 2 else 4
	bannerFrame.Size = UDim2.fromOffset(BANNER_WIDTH, 104)
end

function Notifications.Create(root: Frame)
	-- En bas à droite (position ajustée selon l'écran par Notifications.ApplyLayout)
	toastHolder = UIKit.New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(310, 480),
		ZIndex = 30,
		Parent = root,
	})
	UIKit.List(
		toastHolder,
		Enum.FillDirection.Vertical,
		8,
		Enum.HorizontalAlignment.Right,
		Enum.VerticalAlignment.Bottom
	)

	-- Grande bannière centrale (annonces globales) : plaque de la couleur de l'annonce,
	-- sous la pilule d'événement
	bannerPlate = UIKit.Plate({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(BANNER_WIDTH, 104),
		Visible = false,
		ZIndex = 40,
		StrokeThickness = 3,
		Parent = root,
	}, "Brand", 6, 22)
	bannerFrame = bannerPlate.Instance
	bannerScale = UIKit.New("UIScale", { Parent = bannerFrame })
	local content = UIKit.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -48, 1, 0),
		ZIndex = 42,
		Parent = bannerPlate.Face,
	})
	UIKit.List(content, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	bannerTitle = UIKit.Text({
		Name = "Title",
		Text = "",
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 40),
		Stroke = 2,
		Fit = true,
		LayoutOrder = 1,
		ZIndex = 42,
		Parent = content,
	})
	bannerSubtitle = UIKit.Text({
		Name = "Subtitle",
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Stroke = 1.5,
		Fit = true,
		LayoutOrder = 2,
		ZIndex = 42,
		Parent = content,
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
