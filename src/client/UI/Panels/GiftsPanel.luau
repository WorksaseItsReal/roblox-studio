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
local READY = Color3.fromRGB(255, 190, 40)
local LOCKED = Color3.fromRGB(110, 96, 190)
local DONE = Color3.fromRGB(70, 200, 100)

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
		Color3.fromRGB(230, 90, 170),
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
		CellSize = UDim2.new(1 / 3, -10, 0, 118),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cells = {}
	for index, gift in GIFTS do
		local card = UIKit.Card({ LayoutOrder = index, Parent = grid })
		local gradient = card:FindFirstChildOfClass("UIGradient") :: UIGradient
		local icon = UIKit.IconCircle(TYPE_ICONS[gift.Reward.Type] or "🎁", READY, 54, {
			Position = UDim2.fromOffset(10, 10),
			Parent = card,
		})
		UIKit.Text({
			Text = gift.Minutes .. " min",
			TextSize = 20,
			TextWrapped = false,
			Position = UDim2.fromOffset(74, 8),
			Size = UDim2.new(1, -84, 0, 24),
			Parent = card,
		})
		local preview = UIKit.Body({
			Text = "",
			TextColor3 = Color3.fromRGB(240, 235, 255),
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(74, 34),
			Size = UDim2.new(1, -84, 0, 34),
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "",
			Color = "Gold",
			TextSize = 16,
			Position = UDim2.new(0, 10, 1, -50),
			Size = UDim2.new(1, -20, 0, 42),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimGift", index)
			end,
		})
		cells[index] = { Gradient = gradient, Icon = icon, Preview = preview, Button = button }
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
			local color
			if claimed[index] then
				color = DONE
				cell.Button:SetText("✅ Ouvert")
				cell.Button:SetEnabled(false)
			elseif seconds >= unlockAt then
				color = READY
				cell.Button:SetText("🎁 OUVRIR")
				cell.Button:SetColor("Gold")
				cell.Button:SetEnabled(true)
			else
				color = LOCKED
				cell.Button:SetText("🔒 " .. Format.Time(unlockAt - seconds))
				cell.Button:SetEnabled(false)
			end
			cell.Gradient.Color = ColorSequence.new(Theme.Lighten(color, 0.15), Theme.Darken(color, 0.35))
		end
	end

	-- Appelé chaque seconde par l'UIController tant que le panneau est ouvert
	self.Tick = self.Refresh

	return self
end

return GiftsPanel
