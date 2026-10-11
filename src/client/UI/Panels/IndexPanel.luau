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
	{ Id = "Perfect", Name = "Parfait (avec Secrète)", Icon = "👑" },
}

function IndexPanel.Create(content: Frame, ctx)
	local selected = Dimensions.Order[1]
	local self = {} :: any

	-- Onglets de dimension
	local tabs = Widgets.Row({ Size = UDim2.new(1, 0, 0, 52), Parent = content }, 8)
	local tabButtons = {}
	for order, dimensionId in Dimensions.Order do
		local dimension = Dimensions.Get(dimensionId)
		tabButtons[dimensionId] = UIKit.Button({
			Text = (Theme.DimensionIcons[dimensionId] or "") .. " " .. (if dimension
				then dimension.Name
				else dimensionId),
			Color = "Dark",
			TextSize = 17,
			Size = UDim2.new(0.2, -7, 0, 50),
			LayoutOrder = order,
			Parent = tabs,
			OnClick = function()
				selected = dimensionId
				self.Refresh()
			end,
		})
	end

	local progress = UIKit.ProgressBar(
		{ Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 30), Parent = content },
		Color3.fromRGB(80, 220, 180)
	)

	-- Récompenses
	local rewardRow = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 102),
		Size = UDim2.new(1, 0, 0, 64),
		Parent = content,
	})
	local rewards = {}
	for i, tier in TIERS do
		local reward = GameConfig.Index.Rewards[tier.Id]
		local card = UIKit.Card({
			Position = UDim2.new((i - 1) * 0.5, if i == 2 then 6 else 0, 0, 0),
			Size = UDim2.new(0.5, -6, 1, 0),
			Parent = rewardRow,
		}, Theme.Gold, 0.25)
		UIKit.Text({
			Text = tier.Icon .. " " .. tier.Name,
			TextSize = 16,
			TextWrapped = false,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -140, 0, 24),
			Parent = card,
		})
		UIKit.Text({
			Text = string.format(
				"+%s • +%d %% revenus",
				Format.Money(reward.Money),
				math.round(reward.IncomeBonus * 100)
			),
			TextSize = 15,
			TextColor3 = Theme.Money,
			TextWrapped = false,
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -140, 0, 22),
			Parent = card,
		})
		rewards[tier.Id] = UIKit.Button({
			Text = "Réclamer",
			Color = "Gold",
			TextSize = 16,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(118, 46),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimIndexReward", selected, tier.Id)
			end,
		})
	end

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.25, -9, 0, 122), {
		Position = UDim2.fromOffset(0, 174),
		Size = UDim2.new(1, 0, 1, -174),
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
			button:SetText(if claimed then "✅ Reçu" else "Réclamer")
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
			local rarity = Rarities.Get(def.Rarity)
			local color = if rarity then rarity.Color else Theme.Text
			local known = profile.Index[def.Id] == true
			local card = UIKit.Card(
				{ LayoutOrder = order, Parent = grid },
				if known then color else Theme.Inset,
				if known then 0.45 else 0.6
			)
			UIKit.IconCircle(
				if known then (Theme.DimensionIcons[def.Dimension] or "🐾") else "❓",
				if known then color else Theme.Palette.Gray[2],
				46,
				{
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 6),
					Parent = card,
				}
			)
			UIKit.Text({
				Text = if known then def.Name else "???",
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(6, 54),
				Size = UDim2.new(1, -12, 0, 20),
				Parent = card,
			})
			local pill = UIKit.Pill(if rarity then rarity.Name else def.Rarity, color, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 76),
				Size = UDim2.fromOffset(0, 20),
				TextSize = 12,
				Parent = card,
			})
			pill.ZIndex = 2
			UIKit.Text({
				Text = if def.Rarity == "Secret"
					then "✨ Portail doré"
					else "🎲 " .. Format.Percent(Odds.GetCreatureChance(selected, luck, def.Id)),
				TextSize = 13,
				TextColor3 = Theme.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				Position = UDim2.fromOffset(4, 99),
				Size = UDim2.new(1, -8, 0, 18),
				Parent = card,
			})
		end
	end

	return self
end

return IndexPanel
