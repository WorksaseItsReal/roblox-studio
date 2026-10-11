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
GiftsPanel.Icon = "🎁"
GiftsPanel.Height = 532

local GIFTS = GameConfig.Playtime.Gifts
local TYPE_ICONS = { Money = "💰", Boost = "⚡", Creature = "🐾", Bundle = "🎁" }
local TYPE_COLORS = {
	Money = Theme.Money,
	Boost = Theme.Warning,
	Creature = Theme.Brand,
	Bundle = Theme.Gold,
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
	local top = Widgets.Row({ Size = UDim2.new(1, 0, 0, 40), Parent = content }, 8)
	local sessionChip = UIKit.Chip("⏱️ Session : 0:00", { LayoutOrder = 1, Parent = top })
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
		CellSize = UDim2.new(1 / 3, -10, 0, 116),
		CellPadding = UDim2.fromOffset(12, 12),
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
		local icon = UIKit.IconTile(
			TYPE_ICONS[gift.Reward.Type] or "🎁",
			TYPE_COLORS[gift.Reward.Type] or Theme.Gold,
			48,
			{ Position = UDim2.fromOffset(12, 12), Parent = card }
		)
		UIKit.Label({
			Text = gift.Minutes .. " min",
			TextSize = 18,
			TextWrapped = false,
			Position = UDim2.fromOffset(70, 12),
			Size = UDim2.new(1, -80, 0, 22),
			Parent = card,
		})
		-- Argent : montant en vert ; autres récompenses : texte secondaire
		local isMoney = gift.Reward.Type == "Money"
		local preview = UIKit.Label({
			Text = "",
			TextSize = if isMoney then 17 else 15,
			TextColor3 = if isMoney then Theme.MoneyText else Theme.TextMuted,
			TextWrapped = false,
			Position = UDim2.fromOffset(70, 36),
			Size = UDim2.new(1, -80, 0, 22),
			Fit = true,
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "",
			Color = "Green",
			TextSize = 16,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -10),
			Size = UDim2.new(1, -24, 0, 40),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimGift", index)
			end,
		})
		cells[index] = { Card = card, Icon = icon, Preview = preview, Button = button }
	end

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		local gifts = profile and profile.Gifts
		if not gifts then
			return
		end
		local seconds = GiftsPanel.GetSessionSeconds(profile)
		Widgets.SetPillText(sessionChip, "⏱️ Session : " .. Format.Time(seconds))
		local claimed = {}
		for _, index in gifts.Claimed do
			claimed[index] = true
		end
		for index, gift in GIFTS do
			local cell = cells[index]
			cell.Preview.Text = (gifts.Previews and gifts.Previews[index]) or ""
			local unlockAt = gift.Minutes * 60
			local ready = not claimed[index] and seconds >= unlockAt
			-- À ouvrir : carte dorée qui pulse ; déjà ouvert : grisé ; à venir : neutre
			local glyph = cell.Icon:FindFirstChild("Glyph") :: TextLabel
			glyph.TextTransparency = if claimed[index] then 0.45 else 0
			UIKit.SetCardTint(cell.Card, if ready then Theme.Gold elseif claimed[index] then Theme.Disabled else nil)
			UIKit.Pulse(cell.Card, ready, 0.03)
			if claimed[index] then
				cell.Button:SetStatus("✅ Ouvert")
			elseif ready then
				cell.Button:SetText("🎁 Ouvrir !")
				cell.Button:SetEnabled(true)
			else
				cell.Button:SetStatus("🔒 " .. Format.Time(unlockAt - seconds))
			end
		end
	end

	-- Appelé chaque seconde par l'UIController tant que le panneau est ouvert
	self.Tick = self.Refresh

	return self
end

return GiftsPanel
