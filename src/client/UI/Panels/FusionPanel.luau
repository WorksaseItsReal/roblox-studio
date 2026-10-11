--[[
	FusionPanel : paires de créatures identiques non mutées + chances de mutation affichées.
	Les créatures possédées en un seul exemplaire apparaissent aussi (grisées, "1 / 2") :
	le joueur voit ce qu'il lui manque pour sa prochaine fusion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local FusionPanel = {}
FusionPanel.Title = "Portail de fusion"
FusionPanel.Icon = "🌀"

-- Signe "+" ou "=" de la formule
local function formulaSign(parent: Instance, text: string, x: number)
	UIKit.Label({
		Text = text,
		TextSize = 28,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(x, 14),
		Size = UDim2.fromOffset(24, 48),
		Parent = parent,
	})
end

function FusionPanel.Create(content: Frame, ctx)
	-- En-tête : la formule en images, la règle, et les chances de mutation (transparence)
	local info = UIKit.Card({ Size = UDim2.new(1, 0, 0, 104), Parent = content })
	UIKit.IconTile("🐾", Theme.Info, 48, { Position = UDim2.fromOffset(16, 14), Parent = info })
	formulaSign(info, "+", 66)
	UIKit.IconTile("🐾", Theme.Info, 48, { Position = UDim2.fromOffset(92, 14), Parent = info })
	formulaSign(info, "=", 142)
	local result = UIKit.IconTile("✨", Theme.Brand, 48, { Position = UDim2.fromOffset(168, 14), Parent = info })
	local resultGradient = result:FindFirstChildOfClass("UIGradient")
	if resultGradient then
		resultGradient.Color = Widgets.Rainbow
		resultGradient.Rotation = 45
	end
	UIKit.Label({
		Text = "2 identiques = 1 créature mutée !",
		TextSize = 20,
		TextWrapped = false,
		Position = UDim2.fromOffset(236, 14),
		Size = UDim2.new(1, -252, 0, 24),
		Fit = true,
		Parent = info,
	})
	UIKit.Body({
		Text = "Revenus x2 à x5. Au portail de fusion de ta base.",
		TextSize = 15,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(236, 40),
		Size = UDim2.new(1, -252, 0, 20),
		Parent = info,
	})
	local odds = Widgets.Row({ Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 0, 24), Parent = info }, 6)
	UIKit.Body({
		Text = "Chances :",
		TextSize = 15,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = 0,
		Parent = odds,
	})
	for order, mutation in Mutations.List do
		local tag = Widgets.MutationTag(mutation, { LayoutOrder = order, Parent = odds })
		Widgets.SetPillText(
			tag,
			string.format(
				"%s x%d · %d %%",
				mutation.Name,
				mutation.Multiplier,
				math.round(mutation.Weight / Mutations.TotalWeight * 100)
			)
		)
	end

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.5, -6, 0, 104), UIKit.ScrollArea(116))

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
			if not def then
				continue
			end
			count += 1
			local ready = #uids >= 2
			local rarity = Rarities.Get(def.Rarity)
			local tier = if rarity then rarity.Tier else 0
			-- Paires prêtes d'abord (les plus rares en tête), puis les exemplaires seuls (grisés)
			local card = UIKit.Card({
				LayoutOrder = (if ready then 0 else 1000) - tier * 100 + count,
				Parent = grid,
			}, if ready then nil else Theme.Disabled, if ready then nil else 0.5)
			Widgets.RarityTile(Theme.DimensionIcons[def.Dimension] or "🐾", def.Rarity, 72, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0),
				Parent = card,
			})
			UIKit.Label({
				Text = def.Name,
				TextSize = 19,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(100, 10),
				Size = UDim2.new(1, -112, 0, 24),
				Parent = card,
			})
			Widgets.RarityTag(def.Rarity, { Position = UDim2.fromOffset(100, 38), Parent = card })
			UIKit.Label({
				Text = string.format("📦 %d / 2", math.min(#uids, 2)),
				TextSize = 17,
				TextColor3 = if ready then Theme.TextDark else Theme.TextMuted,
				TextWrapped = false,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 100, 1, -12),
				Size = UDim2.fromOffset(90, 26),
				Parent = card,
			})
			local button = UIKit.Button({
				Text = if ready then "Fusionner" else "Encore 1 !",
				Color = "Green",
				TextSize = 17,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -12),
				Size = UDim2.fromOffset(132, 40),
				ZIndex = 2,
				Parent = card,
				OnClick = function()
					if #uids >= 2 then
						ctx.Net.Request("FuseCreatures", uids[1], uids[2])
					end
				end,
			})
			if not ready then
				button:SetStatus("Encore 1 !")
			end
		end

		grid.Visible = count > 0
		local empty = content:FindFirstChild("Empty")
		if count == 0 and not empty then
			local message = Widgets.Empty(
				content,
				"🌀",
				"Aucune créature à fusionner.\nIl te faut 2 exemplaires non mutés de la même créature."
			)
			message.Position = UDim2.fromOffset(0, 124)
		elseif count > 0 and empty then
			empty:Destroy()
		end
	end

	return self
end

return FusionPanel
