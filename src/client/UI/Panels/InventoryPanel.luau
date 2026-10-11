--[[
	InventoryPanel : créatures possédées, en cartes, avec revente (double clic pour confirmer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
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
	local top = Widgets.Row({ Size = UDim2.new(1, -170, 0, 48), Parent = content }, 10)
	local slotsPill = UIKit.Pill(
		"📦 0 / 8",
		Color3.fromRGB(90, 140, 255),
		{ Parent = top, LayoutOrder = 1, Size = UDim2.fromOffset(0, 38), TextSize = 19 }
	)
	local incomePill = UIKit.Pill(
		"💸 $0/s",
		Color3.fromRGB(60, 190, 90),
		{ Parent = top, LayoutOrder = 2, Size = UDim2.fromOffset(0, 38), TextSize = 19 }
	)
	UIKit.Button({
		Text = "🌀 Fusion",
		Color = "Purple",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(160, 50),
		Parent = content,
		OnClick = function()
			ctx.UI.Open("Fusion")
		end,
	})

	local grid = UIKit.ScrollGrid(content, UDim2.new(0.5, -8, 0, 118), {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
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
			local rarity = Rarities.Get(def.Rarity)
			local rarityColor = if rarity then rarity.Color else Theme.Text
			local mutation = Mutations.Get(entry.Mutation)

			local card = UIKit.Card({ LayoutOrder = order, Parent = grid }, rarityColor, 0.4)
			if entry.Uid == focusUid then
				local focusStroke = card:FindFirstChildOfClass("UIStroke")
				if focusStroke then
					focusStroke.Color = Theme.Gold
					focusStroke.Thickness = 4
				end
			end
			UIKit.IconCircle(Theme.DimensionIcons[def.Dimension] or "🐾", rarityColor, 70, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Parent = card,
			})
			UIKit.Text({
				Text = def.Name,
				TextSize = 21,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(94, 10),
				Size = UDim2.new(1, -104, 0, 26),
				Parent = card,
			})
			local pills =
				Widgets.Row({ Position = UDim2.fromOffset(94, 40), Size = UDim2.new(1, -104, 0, 26), Parent = card }, 6)
			UIKit.Pill(
				if rarity then rarity.Name else def.Rarity,
				rarityColor,
				{ Parent = pills, LayoutOrder = 1, TextSize = 14 }
			)
			if mutation then
				UIKit.Pill(
					string.format("%s x%d", mutation.Name, mutation.Multiplier),
					mutation.Color,
					{ Parent = pills, LayoutOrder = 2, TextSize = 14 }
				)
			end
			if stolen[entry.Uid] then
				UIKit.Pill("🚨 EN VOL", Theme.Danger, { Parent = pills, LayoutOrder = 3, TextSize = 14 })
			end
			UIKit.Text({
				Text = Format.Income(Economy.GetCreatureIncome(entry)),
				TextSize = 20,
				TextColor3 = Theme.Money,
				TextWrapped = false,
				Position = UDim2.fromOffset(94, 74),
				Size = UDim2.new(1, -230, 0, 28),
				Parent = card,
			})

			local confirming = confirmUid == entry.Uid
			UIKit.Button({
				Text = if confirming then "Sûr ?" else "Vendre " .. Format.Money(Economy.GetSellValue(entry)),
				Color = if confirming then "Red" else "Orange",
				TextSize = 15,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -8),
				Size = UDim2.fromOffset(124, 42),
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
