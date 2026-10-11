--[[
	IndexPanel : collection par dimension, récompenses, et chances EXACTES
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
local Widgets = require(script.Parent.Parent.Widgets)

local IndexPanel = {}
IndexPanel.Title = "Index des créatures"
IndexPanel.Icon = "📖"

local TIERS = {
	{ Id = "Complete", Name = "Collection complète", Icon = "🏅" },
	{ Id = "Perfect", Name = "Parfait (+ Secrète)", Icon = "👑" },
}

function IndexPanel.Create(content: Frame, ctx)
	local selected = Dimensions.Order[1]
	local self = {} :: any

	-- Onglets de dimension (onglet actif : violet de marque)
	local tabs = Widgets.Row({ Size = UDim2.new(1, 0, 0, 44), Parent = content }, 8)
	local tabButtons = {}
	for order, dimensionId in Dimensions.Order do
		local dimension = Dimensions.Get(dimensionId)
		tabButtons[dimensionId] = UIKit.Button({
			Text = (Theme.DimensionIcons[dimensionId] or "") .. " " .. (if dimension
				then dimension.Name
				else dimensionId),
			Color = "White",
			TextSize = 18,
			Size = UDim2.new(1 / #Dimensions.Order, -7, 0, 44),
			LayoutOrder = order,
			Parent = tabs,
			OnClick = function()
				selected = dimensionId
				self.Refresh()
			end,
		})
	end

	local progress = UIKit.ProgressBar(
		{ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 26), Parent = content },
		Theme.Money
	)

	-- Récompenses de collection
	local rewards = {}
	for i, tier in TIERS do
		local reward = GameConfig.Index.Rewards[tier.Id]
		local card = UIKit.Card({
			Position = UDim2.new((i - 1) * 0.5, if i == 2 then 6 else 0, 0, 94),
			Size = UDim2.new(0.5, -6, 0, 60),
			Parent = content,
		})
		UIKit.IconTile(tier.Icon, Theme.Gold, 40, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Parent = card,
		})
		UIKit.Label({
			Text = tier.Name,
			TextSize = 16,
			TextWrapped = false,
			Position = UDim2.fromOffset(60, 8),
			Size = UDim2.new(1, -188, 0, 22),
			Fit = true,
			Parent = card,
		})
		UIKit.Label({
			Text = string.format(
				"+%s · +%d %% revenus",
				Format.Money(reward.Money),
				math.round(reward.IncomeBonus * 100)
			),
			TextSize = 14,
			TextColor3 = Theme.MoneyText,
			TextWrapped = false,
			Position = UDim2.fromOffset(60, 30),
			Size = UDim2.new(1, -188, 0, 20),
			Fit = true,
			Parent = card,
		})
		rewards[tier.Id] = UIKit.Button({
			Text = "Réclamer",
			Color = "Green",
			TextSize = 16,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(116, 40),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimIndexReward", selected, tier.Id)
			end,
		})
	end

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.25, -9, 0, 120), UIKit.ScrollArea(166))

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
			button:SetColor(if dimensionId == selected then "Brand" else "White")
		end

		local defs = Creatures.ByDimension[selected] or {}
		local found = 0
		for _, def in defs do
			if profile.Index[def.Id] then
				found += 1
			end
		end
		progress:SetProgress(found / math.max(1, #defs))
		progress:SetText(string.format("%d / %d découvertes", found, #defs))

		for _, tier in TIERS do
			local button = rewards[tier.Id]
			if profile.IndexClaimed[selected .. ":" .. tier.Id] then
				button:SetStatus("✅ Reçu")
			elseif isComplete(profile, tier.Id) then
				button:SetText("Réclamer")
				button:SetEnabled(true)
			else
				button:SetStatus("🔒 Incomplet")
			end
		end

		UIKit.ClearChildren(grid)
		local luck = ctx.State.GetLuck()
		local sorted = table.clone(defs)
		table.sort(sorted, function(a, b)
			local ra, rb = Rarities.Get(a.Rarity), Rarities.Get(b.Rarity)
			return (ra and ra.Tier or 0) < (rb and rb.Tier or 0)
		end)
		for order, def in sorted do
			local known = profile.Index[def.Id] == true
			-- Inconnue : carte grisée, "???" (la rareté reste visible)
			local card = UIKit.Card(
				{ LayoutOrder = order, Parent = grid },
				if known then nil else Theme.Disabled,
				if known then nil else 0.6
			)
			if known then
				Widgets.RarityTile(Theme.DimensionIcons[def.Dimension] or "🐾", def.Rarity, 52, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 8),
					Parent = card,
				})
			else
				-- Silhouette inconnue : tuile ardoise et « ? » blanc (jamais confondue avec une
				-- créature Commune, grise elle aussi)
				local unknown = UIKit.IconTile("", Theme.TextMuted, 52, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 8),
					Parent = card,
				})
				UIKit.Text({
					Text = "?",
					TextSize = 34,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false,
					Size = UDim2.fromScale(1, 1),
					Stroke = 2,
					ZIndex = unknown.ZIndex + 1,
					Parent = unknown,
				})
			end
			UIKit.Label({
				Text = if known then def.Name else "???",
				TextSize = 15,
				TextColor3 = if known then Theme.TextDark else Theme.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 64),
				Size = UDim2.new(1, -16, 0, 20),
				Parent = card,
			})
			-- Rareté (toujours visible) + chance d'apparition
			local row = Widgets.Row({
				Position = UDim2.fromOffset(6, 88),
				Size = UDim2.new(1, -12, 0, 24),
				Parent = card,
			}, 6, Enum.HorizontalAlignment.Center)
			Widgets.RarityTag(def.Rarity, { TextSize = 13, LayoutOrder = 1, Parent = row })
			UIKit.Body({
				Text = if def.Rarity == "Secret"
					then "Portail doré"
					else Format.Percent(Odds.GetCreatureChance(selected, luck, def.Id)),
				TextSize = 13,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 22),
				LayoutOrder = 2,
				Parent = row,
			})
		end
	end

	return self
end

return IndexPanel
