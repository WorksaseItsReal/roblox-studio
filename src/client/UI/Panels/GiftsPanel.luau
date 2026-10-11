--[[
	GiftsPanel : cadeaux de session (débloqués selon le temps de jeu de la session).
	Le temps est compté par le serveur ; ici on ne fait qu'afficher le compte à rebours.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local GiftsPanel = {}
GiftsPanel.Title = "Cadeaux de session"
GiftsPanel.Icon = "⏰"
GiftsPanel.Color = "Pink"

local GIFTS = GameConfig.Playtime.Gifts
local TYPE_ICONS = { Money = "💰", Boost = "⚡", Creature = "🐾", Bundle = "🎁" }
local TYPE_COLORS = {
	Money = Color3.fromRGB(40, 200, 60),
	Boost = Color3.fromRGB(255, 150, 0),
	Creature = Color3.fromRGB(170, 70, 255),
	Bundle = Color3.fromRGB(255, 190, 0),
}

-- Secondes de session estimées à partir du dernier instantané
function GiftsPanel.GetSessionSeconds(profile): number
	local gifts = profile and profile.Gifts
	if not gifts then
		return 0
	end
	return gifts.SessionSeconds + (os.clock() - (profile.ReceivedAt or os.clock()))
end

function GiftsPanel.HasClaimable(profile): boolean
	local gifts = profile and profile.Gifts
	if not gifts then
		return false
	end
	local claimed = {}
	for _, index in gifts.Claimed do
		claimed[index] = true
	end
	local seconds = GiftsPanel.GetSessionSeconds(profile)
	for index, gift in GIFTS do
		if not claimed[index] and seconds >= gift.Minutes * 60 then
			return true
		end
	end
	return false
end

-- Prochain cadeau non débloqué : secondes restantes (nil si tout est débloqué)
function GiftsPanel.NextUnlockIn(profile): number?
	local seconds = GiftsPanel.GetSessionSeconds(profile)
	for _, gift in GIFTS do
		if seconds < gift.Minutes * 60 then
			return gift.Minutes * 60 - seconds
		end
	end
	return nil
end

function GiftsPanel.Create(content: Frame, ctx)
	local top = Widgets.Row({ Size = UDim2.new(1, 0, 0, 40), Parent = content }, 10)
	local sessionPill = UIKit.Pill(
		"⏱️ Session : 0:00",
		Theme.Info,
		{ Parent = top, LayoutOrder = 1, Size = UDim2.fromOffset(0, 36), TextSize = 17 }
	)
	UIKit.Body({
		Text = "Reste connecté pour tout débloquer !",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		LayoutOrder = 2,
		Parent = top,
	})

	local grid = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		Parent = content,
	})
	UIKit.New("UIGridLayout", {
		-- -10 (et non -8) : marge pour que 3 colonnes tiennent malgré les arrondis
		CellSize = UDim2.new(1 / 3, -10, 0, 120),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cells = {}
	for index, gift in GIFTS do
		-- Cadre fixe dans la grille ; la carte, centrée dedans, peut pulser depuis son centre
		local holder = UIKit.New("Frame", { BackgroundTransparency = 1, LayoutOrder = index, Parent = grid })
		local card = UIKit.Card({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Parent = holder,
		})
		local gradient = card:FindFirstChildOfClass("UIGradient") :: UIGradient
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		local icon = UIKit.IconTile(
			TYPE_ICONS[gift.Reward.Type] or "🎁",
			TYPE_COLORS[gift.Reward.Type] or Theme.Gold,
			56,
			{ Position = UDim2.fromOffset(10, 10), Parent = card }
		)
		UIKit.Text({
			Text = gift.Minutes .. " min",
			TextSize = 22,
			TextWrapped = false,
			Position = UDim2.fromOffset(76, 9),
			Size = UDim2.new(1, -86, 0, 26),
			Stroke = 2.6,
			Parent = card,
		})
		-- Argent : gros chiffre vert (code couleur) ; autres récompenses : texte courant
		local isMoney = gift.Reward.Type == "Money"
		local preview = UIKit.Text({
			Text = "",
			Font = if isMoney then Theme.Font else Theme.BodyFont,
			TextColor3 = if isMoney then Theme.Money else Theme.Text,
			TextSize = if isMoney then 21 else 16,
			TextWrapped = not isMoney,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(76, 36),
			Size = UDim2.new(1, -86, 0, 34),
			Stroke = if isMoney then 2.4 else 1.6,
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "",
			Color = "Gold",
			TextSize = 17,
			Position = UDim2.new(0, 10, 1, -52),
			Size = UDim2.new(1, -20, 0, 44),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimGift", index)
			end,
		})
		cells[index] =
			{ Card = card, Gradient = gradient, Stroke = stroke, Icon = icon, Preview = preview, Button = button }
	end

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		local gifts = profile and profile.Gifts
		if not gifts then
			return
		end
		local seconds = GiftsPanel.GetSessionSeconds(profile)
		Widgets.SetPillText(sessionPill, "⏱️ Session : " .. Format.Time(seconds))
		local claimed = {}
		for _, index in gifts.Claimed do
			claimed[index] = true
		end
		for index, gift in GIFTS do
			local cell = cells[index]
			cell.Preview.Text = (gifts.Previews and gifts.Previews[index]) or ""
			local unlockAt = gift.Minutes * 60
			local ready = not claimed[index] and seconds >= unlockAt
			-- À ouvrir : la carte la plus vive (or) et qui pulse ; déjà ouvert : bleu nuit
			-- éteint ; à venir : carte normale avec le compte à rebours
			local glyph = cell.Icon:FindFirstChild("Glyph") :: TextLabel
			glyph.TextTransparency = if claimed[index] then 0.4 else 0
			cell.Stroke.Thickness = if ready then 5 else 3
			UIKit.Pulse(cell.Card, ready, 0.04)
			if claimed[index] then
				cell.Gradient.Color = ColorSequence.new(Theme.Lighten(Theme.Inset, 0.15), Theme.Inset)
				cell.Button:SetText("✅ OUVERT")
				cell.Button:SetEnabled(false)
			elseif ready then
				cell.Gradient.Color = ColorSequence.new(Theme.Palette.Gold[1], Theme.Palette.Gold[2])
				cell.Button:SetText("🎁 OUVRIR !")
				cell.Button:SetColor("Green")
				cell.Button:SetEnabled(true)
			else
				cell.Gradient.Color = ColorSequence.new(Theme.CardTop, Theme.CardBottom)
				cell.Button:SetText("🔒 " .. Format.Time(unlockAt - seconds))
				cell.Button:SetEnabled(false)
			end
		end
	end

	-- Appelé chaque seconde par l'UIController tant que le panneau est ouvert
	self.Tick = self.Refresh

	return self
end

return GiftsPanel
