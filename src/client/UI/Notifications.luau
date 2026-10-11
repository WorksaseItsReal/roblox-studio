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
local bannerPlate: UIKit.Plate
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local bannerScale: UIScale
local bannerQueue = {}
local bannerBusy = false
local toastCounter = 0
-- Nombre maximum de toasts à l'écran (moins sur téléphone, voir ApplyLayout)
local maxToasts = 4

function Notifications.Toast(text: string, kind: string?)
	kind = kind or "Info"
	local palette = Theme.Palette[Theme.KindPalette[kind] or "Blue"]
	local isSteal = kind == "Steal"
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
	-- Carte de la couleur du message (vert = succès, rouge = erreur / vol...)
	local toast = UIKit.New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1.2, 0, 0, 0),
		Parent = slot,
	})
	UIKit.Corner(toast, 16)
	UIKit.Stroke(toast, 3.5)
	UIKit.Gradient(toast, palette[1], palette[2])
	UIKit.Padding(toast, 12, 14, 14, 66)
	UIKit.IconCircle(Theme.KindIcons[kind] or "💬", Color3.fromRGB(236, 244, 255), 46, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -56, 0.5, 0),
		Parent = toast,
	})
	UIKit.Text({
		Text = text,
		Font = if isSteal then Theme.Font else Theme.BodyFont,
		TextSize = if isSteal then 19 else 18,
		TextColor3 = Theme.Text,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 22),
		Stroke = if isSteal then 2.4 else 1.8,
		Parent = toast,
	})
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new() }):Play()

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
	bannerPlate:SetColor(Theme.PaletteFrom(item.Color))
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

--[[
	Disposition selon l'écran (appelée par l'UIController) :
	  Compact      : écran peu haut (téléphone) -> toasts et bannière moins larges
	  RightOffset  : écart entre les toasts et le bord droit (rail, bouton de saut tactile)
	  BottomOffset : écart entre les toasts et le bas de l'écran
]]
function Notifications.ApplyLayout(info: { Compact: boolean, RightOffset: number, BottomOffset: number })
	if not toastHolder or not bannerFrame then
		return
	end
	toastHolder.Position = UDim2.new(1, -info.RightOffset, 1, -info.BottomOffset)
	-- Largeurs choisies pour ne jamais toucher la pile du bas (bandeau de vol compris)
	toastHolder.Size = if info.Compact then UDim2.fromOffset(240, 340) else UDim2.fromOffset(280, 520)
	maxToasts = if info.Compact then 3 else 4
	-- La bannière ne déborde pas sur le rail de récompenses (en haut à droite en compact)
	bannerFrame.Size = UDim2.fromOffset(if info.Compact then 620 else 700, 118)
end

function Notifications.Create(root: Frame)
	-- En bas à droite : ne masque ni le HUD ni le bouton de fermeture des fenêtres
	-- (position ajustée selon l'écran par Notifications.ApplyLayout)
	toastHolder = UIKit.New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		-- À gauche du rail de récompenses, sans toucher la pile du bas (barrière, vol)
		Position = UDim2.new(1, -110, 1, -16),
		Size = UDim2.fromOffset(280, 520),
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

	-- Grande bannière centrale (annonces globales) : plaque 3D de la couleur de l'annonce
	bannerPlate = UIKit.Plate({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 158),
		Size = UDim2.fromOffset(700, 118),
		Visible = false,
		ZIndex = 40,
		StrokeThickness = 4.5,
		Parent = root,
	}, "Purple", 7, 24)
	bannerFrame = bannerPlate.Instance
	bannerScale = UIKit.New("UIScale", { Parent = bannerFrame })
	bannerTitle = UIKit.Text({
		Name = "Title",
		Text = "",
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -36, 0, 50),
		Stroke = 4.5,
		Fit = true,
		ZIndex = 42,
		Parent = bannerPlate.Face,
	})
	bannerSubtitle = UIKit.Body({
		Text = "",
		TextSize = 19,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(24, 58),
		Size = UDim2.new(1, -48, 0, 44),
		Stroke = 2,
		ZIndex = 42,
		Parent = bannerPlate.Face,
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
