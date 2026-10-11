--[[
	InventoryPanel : créatures possédées, en cartes, avec revente (double clic pour confirmer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local InventoryPanel = {}
InventoryPanel.Title = "Mes créatures"
InventoryPanel.Icon = "🐾"

function InventoryPanel.Create(content: Frame, ctx)
	-- Barre du haut : emplacements, revenus, accès à la fusion
	local top = Widgets.Row({ Size = UDim2.new(1, -170, 0, 40), Parent = content }, 8)
	local slotsChip = UIKit.Chip("📦 0 / 8", { LayoutOrder = 1, Parent = top })
	local incomePill = UIKit.Pill("💰 $0/s", Theme.Gold, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 36),
		TextSize = 17,
		Parent = top,
	})
	UIKit.Button({
		Text = "🌀 Fusion",
		Color = "Blue",
		TextSize = 19,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, -2),
		Size = UDim2.fromOffset(150, 44),
		Parent = content,
		OnClick = function()
			ctx.UI.Open("Fusion")
		end,
	})

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.5, -6, 0, 124), UIKit.ScrollArea(52))

	local focusUid: string? = nil
	local confirmUid: string? = nil
	local self = {} :: any

	function self.OnOpen(uid: any)
		focusUid = if type(uid) == "string" then uid else nil
	end

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		Widgets.SetPillText(slotsChip, string.format("📦 %d / %d", #profile.Creatures, profile.MaxSlots))
		Widgets.SetPillText(incomePill, "💰 " .. Format.Income(profile.IncomePerSecond))
		UIKit.ClearChildren(grid)

		local stolen = {}
		for _, uid in profile.BeingStolen or {} do
			stolen[uid] = true
		end
		local entries = table.clone(profile.Creatures)
		table.sort(entries, function(a, b)
			if a.Uid == focusUid then
				return true
			elseif b.Uid == focusUid then
				return false
			end
			return Economy.GetCreatureIncome(a) > Economy.GetCreatureIncome(b)
		end)

		if #entries == 0 then
			-- L'état vide occupe toute la largeur : on le place hors de la grille
			grid.Visible = false
			if not content:FindFirstChild("Empty") then
				local empty = Widgets.Empty(
					content,
					"🐾",
					"Aucune créature pour l'instant.\nAchète-en sur le tapis de la Rift !"
				)
				empty.Position = UDim2.fromOffset(0, 80)
			end
			return
		end
		grid.Visible = true
		local empty = content:FindFirstChild("Empty")
		if empty then
			empty:Destroy()
		end

		for order, entry in entries do
			local def = Creatures.Get(entry.Id)
			if not def then
				continue
			end
			local mutation = Mutations.Get(entry.Mutation)

			-- Créature choisie dans le monde : carte sélectionnée (violet de marque)
			local card =
				UIKit.Card({ LayoutOrder = order, Parent = grid }, if entry.Uid == focusUid then Theme.Brand else nil)
			local tile = Widgets.RarityTile(Theme.DimensionIcons[def.Dimension] or "🐾", def.Rarity, 72, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0),
				Parent = card,
			})
			if stolen[entry.Uid] then
				-- Ruban rouge sur l'icône : cette créature est en train d'être volée
				UIKit.Pill("En vol", Theme.Danger, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.fromOffset(0, 22),
					TextSize = 13,
					ZIndex = 3,
					Parent = tile,
				})
			end
			UIKit.Label({
				Text = def.Name,
				TextSize = 19,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(100, 12),
				Size = UDim2.new(1, -112, 0, 24),
				Parent = card,
			})
			-- Rareté + mutation
			local tags = Widgets.Row(
				{ Position = UDim2.fromOffset(100, 40), Size = UDim2.new(1, -112, 0, 24), Parent = card },
				6
			)
			Widgets.RarityTag(def.Rarity, { LayoutOrder = 1, Parent = tags })
			if mutation then
				Widgets.MutationTag(mutation, { LayoutOrder = 2, Parent = tags })
			end
			UIKit.Label({
				Text = Format.Income(Economy.GetCreatureIncome(entry)),
				TextSize = 19,
				TextColor3 = Theme.GoldText,
				TextWrapped = false,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 100, 1, -15),
				Size = UDim2.new(1, -250, 0, 26),
				Fit = true,
				Parent = card,
			})

			local confirming = confirmUid == entry.Uid
			UIKit.Button({
				Text = if confirming then "Sûr ?" else "Vendre " .. Format.Money(Economy.GetSellValue(entry)),
				Color = if confirming then "Red" else "Green",
				TextSize = 15,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -12),
				Size = UDim2.fromOffset(126, 40),
				ZIndex = 2,
				Parent = card,
				OnClick = function()
					if confirmUid ~= entry.Uid then
						confirmUid = entry.Uid
						self.Refresh()
						task.delay(3, function()
							if confirmUid == entry.Uid then
								confirmUid = nil
								self.Refresh()
							end
						end)
						return
					end
					confirmUid = nil
					ctx.Net.Request("SellCreature", entry.Uid)
				end,
			})
		end
	end

	return self
end

return InventoryPanel
