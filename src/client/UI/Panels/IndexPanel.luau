--[[
	IndexPanel : collection par dimension, récompenses, et chances exactes
	d'apparition (dimension sélectionnée, chance serveur actuelle).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Dimensions = require(Shared.Config.Dimensions)
local Odds = require(Shared.Modules.Odds)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local IndexPanel = {}
IndexPanel.Title = "Index des créatures"

local TIER_TEXT = { Complete = "Complet", Perfect = "Parfait (avec Secrète)" }

function IndexPanel.Create(content: Frame, ctx)
	local selected = Dimensions.Order[1]
	local self = {} :: any

	local tabs = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = content })
	UIKit.List(tabs, Enum.FillDirection.Horizontal, 6)
	local tabButtons = {}
	for order, dimensionId in Dimensions.Order do
		local dimension = Dimensions.Get(dimensionId)
		local button = UIKit.Button(if dimension then dimension.Name else dimensionId, Theme.SurfaceLight, function()
			selected = dimensionId
			self.Refresh()
		end, { Size = UDim2.new(0.2, -5, 1, 0), LayoutOrder = order, TextSize = 15 })
		button.Parent = tabs
		tabButtons[dimensionId] = button
	end

	local list = UIKit.ScrollList(content, { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42) })

	local function isComplete(profile, tier: string): boolean
		for _, def in Creatures.ByDimension[selected] or {} do
			if (tier == "Perfect" or def.Rarity ~= "Secret") and not profile.Index[def.Id] then
				return false
			end
		end
		return true
	end

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		for dimensionId, button in tabButtons do
			local dimension = Dimensions.Get(dimensionId)
			button.BackgroundColor3 = if dimensionId == selected and dimension
				then dimension.Visual.RiftColor
				else Theme.SurfaceLight
		end
		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })

		local defs = Creatures.ByDimension[selected] or {}
		local found = 0
		for _, def in defs do
			if profile.Index[def.Id] then
				found += 1
			end
		end
		local luck = ctx.State.GetLuck()
		local dimension = Dimensions.Get(selected)
		UIKit.Label({
			Text = string.format(
				"%d / %d découvertes  •  Chances par apparition en dimension %s (chance x%g)",
				found,
				#defs,
				if dimension then dimension.Name else selected,
				luck
			),
			Font = Theme.BodyFont,
			TextSize = 14,
			TextColor3 = Theme.TextDim,
			LayoutOrder = 0,
			Parent = list,
		})

		-- Récompenses
		for order, tier in { "Complete", "Perfect" } do
			local reward = GameConfig.Index.Rewards[tier]
			local claimed = profile.IndexClaimed[selected .. ":" .. tier]
			local complete = isComplete(profile, tier)
			local card = UIKit.Card(48, order)
			card.Parent = list
			UIKit.Label({
				Text = string.format(
					"%s : +%s et +%d %% de revenus",
					TIER_TEXT[tier],
					Format.Money(reward.Money),
					math.round(reward.IncomeBonus * 100)
				),
				TextSize = 15,
				Size = UDim2.new(1, -140, 1, 0),
				Parent = card,
			})
			local button = UIKit.Button(if claimed then "Réclamé" else "Réclamer", Theme.Gold, function()
				ctx.Net.Request("ClaimIndexReward", selected, tier)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 32),
			})
			UIKit.SetButtonEnabled(button, complete and not claimed, Theme.Gold)
			button.Parent = card
		end

		-- Créatures
		for order, def in defs do
			local rarity = Rarities.Get(def.Rarity)
			local known = profile.Index[def.Id] == true
			local chance = Odds.GetCreatureChance(selected, luck, def.Id)
			local card = UIKit.Card(52, 10 + (rarity and rarity.Tier or 0) * 10 + order)
			card.Parent = list
			UIKit.Label({
				Text = if known then def.Name else "???",
				TextColor3 = if rarity then rarity.Color else Theme.Text,
				Size = UDim2.new(0.5, 0, 0, 22),
				Parent = card,
			})
			UIKit.Label({
				Text = string.format(
					"%s  •  %s  •  %s",
					if rarity then rarity.Name else def.Rarity,
					if known then Format.Income(def.Income) else "?",
					if known then Format.Money(def.Price) else "?"
				),
				Font = Theme.BodyFont,
				TextSize = 13,
				TextColor3 = Theme.TextDim,
				Position = UDim2.new(0, 0, 0, 22),
				Size = UDim2.new(0.7, 0, 0, 18),
				Parent = card,
			})
			UIKit.Label({
				Text = if def.Rarity == "Secret" then "Portail doré" else Format.Percent(chance),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 16,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 8),
				Size = UDim2.new(0.3, 0, 0, 22),
				Parent = card,
			})
		end
	end

	return self
end

return IndexPanel
