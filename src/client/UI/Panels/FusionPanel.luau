--[[
	FusionPanel : paires de créatures identiques non mutées + chances de mutation affichées.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local FusionPanel = {}
FusionPanel.Title = "Portail de fusion"
FusionPanel.Icon = "🌀"
FusionPanel.Color = "Purple"

function FusionPanel.Create(content: Frame, ctx)
	-- En-tête : règle + chances de mutation (transparence du tirage)
	local info = UIKit.Inset({ Size = UDim2.new(1, 0, 0, 96), Parent = content })
	UIKit.Text({
		Text = "2 créatures identiques non mutées ➜ 1 créature MUTÉE (revenus x2 à x5)",
		TextSize = 18,
		TextWrapped = false,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 26),
		Parent = info,
	})
	UIKit.Body({
		Text = "Tiens-toi près du portail de fusion de ta base.",
		Position = UDim2.fromOffset(16, 32),
		Size = UDim2.new(1, -32, 0, 20),
		Parent = info,
	})
	local odds = Widgets.Row({ Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 30), Parent = info }, 8)
	for order, mutation in Mutations.List do
		UIKit.Pill(
			string.format(
				"%s x%d • %s",
				mutation.Name,
				mutation.Multiplier,
				Format.Percent(mutation.Weight / Mutations.TotalWeight)
			),
			mutation.Color,
			{ Parent = odds, LayoutOrder = order, TextSize = 14 }
		)
	end

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.5, -8, 0, 104), {
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 1, -108),
	})

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		UIKit.ClearChildren(grid)

		local stolen = {}
		for _, uid in profile.BeingStolen or {} do
			stolen[uid] = true
		end
		local groups: { [string]: { string } } = {}
		for _, entry in profile.Creatures do
			if entry.Mutation == Mutations.None and not stolen[entry.Uid] then
				groups[entry.Id] = groups[entry.Id] or {}
				table.insert(groups[entry.Id], entry.Uid)
			end
		end

		local count = 0
		for creatureId, uids in groups do
			local def = Creatures.Get(creatureId)
			if #uids < 2 or not def then
				continue
			end
			count += 1
			local rarity = Rarities.Get(def.Rarity)
			local color = if rarity then rarity.Color else Theme.Text
			local card = UIKit.Card(
				{ LayoutOrder = -(if rarity then rarity.Tier else 0) * 100 + count, Parent = grid },
				color,
				0.4
			)
			UIKit.IconCircle(Theme.DimensionIcons[def.Dimension] or "🐾", color, 66, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Parent = card,
			})
			UIKit.Text({
				Text = def.Name,
				TextSize = 20,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(90, 12),
				Size = UDim2.new(1, -100, 0, 26),
				Parent = card,
			})
			UIKit.Pill(string.format("x%d en stock", #uids), color, {
				Position = UDim2.fromOffset(90, 44),
				TextSize = 14,
				Parent = card,
			})
			UIKit.Button({
				Text = "Fusionner",
				Color = "Purple",
				TextSize = 16,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -8),
				Size = UDim2.fromOffset(120, 44),
				ZIndex = 2,
				Parent = card,
				OnClick = function()
					ctx.Net.Request("FuseCreatures", uids[1], uids[2])
				end,
			})
		end

		grid.Visible = count > 0
		local empty = content:FindFirstChild("Empty")
		if count == 0 and not empty then
			local message = Widgets.Empty(
				content,
				"🌀",
				"Aucune paire disponible.\nIl te faut 2 exemplaires NON mutés de la même créature."
			)
			message.Position = UDim2.fromOffset(0, 120)
		elseif count > 0 and empty then
			empty:Destroy()
		end
	end

	return self
end

return FusionPanel
