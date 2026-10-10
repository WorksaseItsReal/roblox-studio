--[[
	FusionPanel : paires de créatures identiques non mutées + chances de mutation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local FusionPanel = {}
FusionPanel.Title = "Portail de fusion"

function FusionPanel.Create(content: Frame, ctx)
	-- Chances affichées (transparence des tirages)
	local oddsParts = {}
	for _, mutation in Mutations.List do
		table.insert(
			oddsParts,
			string.format(
				"%s x%d : %s",
				mutation.Name,
				mutation.Multiplier,
				Format.Percent(mutation.Weight / Mutations.TotalWeight)
			)
		)
	end
	UIKit.Label({
		Text = "Place-toi près du portail de fusion de ta base. 2 créatures identiques (non mutées) = 1 créature mutée.\n"
			.. table.concat(oddsParts, "  •  "),
		Font = Theme.BodyFont,
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, 0, 0, 54),
		Parent = content,
	})
	local list = UIKit.ScrollList(content, { Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 1, -60) })

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })

		local stolen = {}
		for _, uid in profile.BeingStolen or {} do
			stolen[uid] = true
		end
		-- Regroupe les Uids fusionnables par créature
		local groups: { [string]: { string } } = {}
		for _, entry in profile.Creatures do
			if entry.Mutation == Mutations.None and not stolen[entry.Uid] then
				groups[entry.Id] = groups[entry.Id] or {}
				table.insert(groups[entry.Id], entry.Uid)
			end
		end

		local order = 0
		for creatureId, uids in groups do
			if #uids < 2 then
				continue
			end
			local def = Creatures.Get(creatureId)
			if not def then
				continue
			end
			order += 1
			local rarity = Rarities.Get(def.Rarity)
			local card = UIKit.Card(56, -(rarity and rarity.Tier or 0) * 100 + order)
			card.Parent = list
			UIKit.Label({
				Text = string.format("%s  x%d", def.Name, #uids),
				TextColor3 = if rarity then rarity.Color else Theme.Text,
				Size = UDim2.new(1, -140, 1, 0),
				Parent = card,
			})
			local button = UIKit.Button("Fusionner", Color3.fromRGB(170, 90, 255), function()
				ctx.Net.Request("FuseCreatures", uids[1], uids[2])
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 130, 0, 36),
			})
			button.Parent = card
		end

		if order == 0 then
			UIKit.Label({
				Text = "Aucune paire disponible. Il te faut 2 exemplaires NON mutés de la même créature.",
				TextColor3 = Theme.TextDim,
				Size = UDim2.new(1, 0, 0, 50),
				Parent = list,
			})
		end
	end

	return self
end

return FusionPanel
