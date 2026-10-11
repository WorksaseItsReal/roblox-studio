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
IndexPanel.Color = "Teal"

local TIERS = {
	{ Id = "Complete", Name = "Collection complète", Icon = "🏅" },
	{ Id = "Perfect", Name = "Parfait (+ Secrète)", Icon = "👑" },
}

function IndexPanel.Create(content: Frame, ctx)
	local selected = Dimensions.Order[1]
	local self = {} :: any

	-- Onglets de dimension
	local tabs = Widgets.Row({ Size = UDim2.new(1, 0, 0, 48), Parent = content }, 8)
	local tabButtons = {}
	for order, dimensionId in Dimensions.Order do
		local dimension = Dimensions.Get(dimensionId)
		tabButtons[dimensionId] = UIKit.Button({
			Text = (Theme.DimensionIcons[dimensionId] or "") .. " " .. (if dimension
				then dimension.Name
				else dimensionId),
			Color = "Dark",
			TextSize = 19,
			Size = UDim2.new(0.2, -7, 0, 46),
			LayoutOrder = order,
			Parent = tabs,
			OnClick = function()
				selected = dimensionId
				self.Refresh()
			end,
		})
	end

	local progress = UIKit.ProgressBar(
		{ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 28), Parent = content },
		Color3.fromRGB(40, 220, 120)
	)

	-- Récompenses
	local rewardRow = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = content,
	})
	local rewards = {}
	for i, tier in TIERS do
		local reward = GameConfig.Index.Rewards[tier.Id]
		local card = UIKit.Card({
			Position = UDim2.new((i - 1) * 0.5, if i == 2 then 6 else 0, 0, 0),
			Size = UDim2.new(0.5, -6, 1, 0),
			Parent = rewardRow,
		})
		UIKit.IconTile(tier.Icon, Theme.Gold, 44, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Parent = card,
		})
		UIKit.Text({
			Text = tier.Name,
			TextSize = 17,
			TextWrapped = false,
			Position = UDim2.fromOffset(60, 5),
			Size = UDim2.new(1, -196, 0, 24),
			Stroke = 2.2,
			Fit = true,
			Parent = card,
		})
		UIKit.Text({
			Text = string.format(
				"+%s • +%d %% revenus",
				Format.Money(reward.Money),
				math.round(reward.IncomeBonus * 100)
			),
			TextSize = 16,
			TextColor3 = Theme.Money,
			TextWrapped = false,
			Position = UDim2.fromOffset(60, 29),
			Size = UDim2.new(1, -196, 0, 22),
			Stroke = 2.2,
			Fit = true,
			Parent = card,
		})
		rewards[tier.Id] = UIKit.Button({
			Text = "RÉCLAMER",
			Color = "Gold",
			TextSize = 17,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(124, 44),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimIndexReward", selected, tier.Id)
			end,
		})
	end

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.25, -9, 0, 132), {
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 1, -158),
	})

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
			if dimensionId == selected and dimension then
				button:SetColor(Theme.PaletteFrom(dimension.Visual.RiftColor))
			else
				button:SetColor("Dark")
			end
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
			local claimed = profile.IndexClaimed[selected .. ":" .. tier.Id]
			local button = rewards[tier.Id]
			button:SetText(if claimed then "✅ REÇU" else "RÉCLAMER")
			button:SetEnabled(not claimed and isComplete(profile, tier.Id))
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
			-- Inconnue : silhouette sombre "???" (la rareté reste visible)
			local card = UIKit.Card(
				{ LayoutOrder = order, Parent = grid },
				if known then nil else Color3.fromRGB(12, 30, 86),
				if known then nil else 0.92
			)
			if known then
				Widgets.RarityTile(Theme.DimensionIcons[def.Dimension] or "🐾", def.Rarity, 56, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 7),
					Parent = card,
				})
			else
				UIKit.IconTile("❓", Color3.fromRGB(40, 54, 96), 56, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 7),
					Parent = card,
				})
			end
			UIKit.Body({
				Text = if known then def.Name else "???",
				TextSize = 17,
				TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(6, 65),
				Size = UDim2.new(1, -12, 0, 21),
				Stroke = 1.8,
				Parent = card,
			})
			-- La rareté reste visible même inconnue (encart sombre : la couleur ressort)
			Widgets.RarityTag(def.Rarity, {
				TextSize = 15,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 87),
				Parent = card,
			})
			UIKit.Text({
				Text = if def.Rarity == "Secret"
					then "✨ Portail doré"
					else "🎲 " .. Format.Percent(Odds.GetCreatureChance(selected, luck, def.Id)),
				TextSize = 16,
				TextColor3 = Theme.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				Position = UDim2.fromOffset(4, 111),
				Size = UDim2.new(1, -8, 0, 19),
				Stroke = 2,
				Fit = true,
				Parent = card,
			})
		end
	end

	return self
end

return IndexPanel
