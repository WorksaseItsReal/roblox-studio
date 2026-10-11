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
FusionPanel.Color = "Purple"

-- Signe "+" ou "=" de la formule
local function formulaSign(parent: Instance, text: string, x: number)
	UIKit.Text({
		Text = text,
		TextSize = 34,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(x, 8),
		Size = UDim2.fromOffset(30, 52),
		Stroke = 3.5,
		Parent = parent,
	})
end

function FusionPanel.Create(content: Frame, ctx)
	-- En-tête : la formule en images, la règle, et les chances de mutation (transparence)
	local info = UIKit.Inset({ Size = UDim2.new(1, 0, 0, 112), Parent = content })
	UIKit.IconTile("🐾", Theme.Info, 52, { Position = UDim2.fromOffset(14, 8), Parent = info })
	formulaSign(info, "+", 66)
	UIKit.IconTile("🐾", Theme.Info, 52, { Position = UDim2.fromOffset(96, 8), Parent = info })
	formulaSign(info, "=", 148)
	local result = UIKit.IconTile("🌀", Theme.Magic, 52, { Position = UDim2.fromOffset(178, 8), Parent = info })
	local resultGradient = result:FindFirstChildOfClass("UIGradient")
	if resultGradient then
		resultGradient.Color = Widgets.Rainbow
		resultGradient.Rotation = 45
	end
	UIKit.Text({
		Text = "2 identiques = 1 créature MUTÉE !",
		TextSize = 24,
		TextWrapped = false,
		Position = UDim2.fromOffset(248, 8),
		Size = UDim2.new(1, -262, 0, 30),
		Stroke = 2.8,
		Fit = true,
		Parent = info,
	})
	UIKit.Body({
		Text = "Revenus x2 à x5. Non mutées, près du portail de fusion de ta base.",
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(250, 38),
		Size = UDim2.new(1, -264, 0, 22),
		Parent = info,
	})
	local odds = Widgets.Row({ Position = UDim2.fromOffset(14, 72), Size = UDim2.new(1, -28, 0, 28), Parent = info }, 8)
	for order, mutation in Mutations.List do
		UIKit.Pill(
			string.format(
				"%s x%d • %d %%",
				mutation.Name,
				mutation.Multiplier,
				math.round(mutation.Weight / Mutations.TotalWeight * 100)
			),
			mutation.Color,
			{ Parent = odds, LayoutOrder = order, Size = UDim2.fromOffset(0, 28), TextSize = 16 }
		)
	end

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.5, -8, 0, 112), {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 1, -122),
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
			if not def then
				continue
			end
			count += 1
			local ready = #uids >= 2
			local rarity = Rarities.Get(def.Rarity)
			local tier = if rarity then rarity.Tier else 0
			-- Paires prêtes d'abord (les plus rares en tête), puis les exemplaires seuls
			local card = UIKit.Card({
				LayoutOrder = (if ready then 0 else 1000) - tier * 100 + count,
				Parent = grid,
			}, if ready then nil else Theme.Inset, if ready then nil else 0.6)
			Widgets.RarityTile(Theme.DimensionIcons[def.Dimension] or "🐾", def.Rarity, 78, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Parent = card,
			})
			UIKit.Body({
				Text = def.Name,
				TextSize = 20,
				TextColor3 = Theme.Text,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(102, 9),
				Size = UDim2.new(1, -112, 0, 26),
				Stroke = 2,
				Parent = card,
			})
			Widgets.RarityTag(def.Rarity, { TextSize = 16, Position = UDim2.fromOffset(102, 38), Parent = card })
			UIKit.Pill(
				string.format("📦 %d / 2", math.min(#uids, 2)),
				if ready then Theme.Info else Color3.fromRGB(255, 150, 0),
				{
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 102, 1, -12),
					Size = UDim2.fromOffset(0, 28),
					TextSize = 16,
					Parent = card,
				}
			)
			local button = UIKit.Button({
				Text = if ready then "FUSIONNER" else "ENCORE 1 !",
				Color = "Purple",
				TextSize = 18,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -10),
				Size = UDim2.fromOffset(150, 50),
				ZIndex = 2,
				Parent = card,
				OnClick = function()
					if #uids >= 2 then
						ctx.Net.Request("FuseCreatures", uids[1], uids[2])
					end
				end,
			})
			button:SetEnabled(ready)
		end

		grid.Visible = count > 0
		local empty = content:FindFirstChild("Empty")
		if count == 0 and not empty then
			local message = Widgets.Empty(
				content,
				"🌀",
				"Aucune créature à fusionner.\nIl te faut 2 exemplaires NON mutés de la même créature."
			)
			message.Position = UDim2.fromOffset(0, 130)
		elseif count > 0 and empty then
			empty:Destroy()
		end
	end

	return self
end

return FusionPanel
