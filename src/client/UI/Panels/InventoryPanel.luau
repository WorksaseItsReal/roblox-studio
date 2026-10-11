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
InventoryPanel.Color = "Blue"

function InventoryPanel.Create(content: Frame, ctx)
	local top = Widgets.Row({ Size = UDim2.new(1, -190, 0, 52), Parent = content }, 10)
	local slotsPill = UIKit.Pill(
		"📦 0 / 8",
		Theme.Info,
		{ Parent = top, LayoutOrder = 1, Size = UDim2.fromOffset(0, 38), TextSize = 19 }
	)
	local incomePill = UIKit.Pill(
		"💸 $0/s",
		Color3.fromRGB(255, 190, 0),
		{ Parent = top, LayoutOrder = 2, Size = UDim2.fromOffset(0, 38), TextSize = 19 }
	)
	UIKit.Button({
		Text = "🌀 FUSION",
		Color = "Purple",
		TextSize = 21,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(176, 52),
		Parent = content,
		OnClick = function()
			ctx.UI.Open("Fusion")
		end,
	})

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.5, -8, 0, 124), {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -64),
	})

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
		Widgets.SetPillText(slotsPill, string.format("📦 %d / %d", #profile.Creatures, profile.MaxSlots))
		Widgets.SetPillText(incomePill, "💸 " .. Format.Income(profile.IncomePerSecond))
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
					"Aucune créature pour l'instant.\nAchète-en sur le tapis de la Rift (touche E) !"
				)
				empty.Position = UDim2.fromOffset(0, 90)
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

			local card = UIKit.Card({ LayoutOrder = order, Parent = grid })
			if entry.Uid == focusUid then
				local focusStroke = card:FindFirstChildOfClass("UIStroke")
				if focusStroke then
					focusStroke.Color = Theme.Gold
					focusStroke.Thickness = 4.5
				end
			end
			local tile = Widgets.RarityTile(Theme.DimensionIcons[def.Dimension] or "🐾", def.Rarity, 84, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Parent = card,
			})
			if stolen[entry.Uid] then
				-- Ruban rouge sur l'icône : cette créature est en train d'être volée
				UIKit.Pill("EN VOL", Theme.Danger, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 8),
					Size = UDim2.fromOffset(0, 24),
					TextSize = 15,
					Parent = tile,
				})
			end
			UIKit.Body({
				Text = def.Name,
				TextSize = 21,
				TextColor3 = Theme.Text,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(110, 8),
				Size = UDim2.new(1, -120, 0, 26),
				Stroke = 2,
				Parent = card,
			})
			-- Rareté (encart sombre : la couleur ressort) + mutation
			local tags = Widgets.Row(
				{ Position = UDim2.fromOffset(110, 37), Size = UDim2.new(1, -120, 0, 24), Parent = card },
				6
			)
			Widgets.RarityTag(def.Rarity, { TextSize = 16, LayoutOrder = 1, Parent = tags })
			if mutation then
				UIKit.Pill(
					string.format("%s x%d", mutation.Name, mutation.Multiplier),
					mutation.Color,
					{ Parent = tags, LayoutOrder = 2, Size = UDim2.fromOffset(0, 24), TextSize = 16 }
				)
			end
			UIKit.Text({
				Text = Format.Income(Economy.GetCreatureIncome(entry)),
				TextSize = 25,
				TextColor3 = Theme.Income,
				TextWrapped = false,
				Position = UDim2.fromOffset(110, 74),
				Size = UDim2.new(1, -268, 0, 34),
				Stroke = 2.8,
				Fit = true,
				Parent = card,
			})

			local confirming = confirmUid == entry.Uid
			UIKit.Button({
				Text = if confirming then "SÛR ?" else "Vendre " .. Format.Money(Economy.GetSellValue(entry)),
				Color = if confirming then "Red" else "Orange",
				TextSize = 18,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -10),
				Size = UDim2.fromOffset(142, 48),
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
