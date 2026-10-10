--[[
	InventoryPanel : liste des créatures possédées, revente (double clic pour confirmer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Dimensions = require(Shared.Config.Dimensions)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local InventoryPanel = {}
InventoryPanel.Title = "Mes créatures"

function InventoryPanel.Create(content: Frame, ctx)
	local header = UIKit.Label({ Text = "", TextSize = 18, Size = UDim2.new(1, -110, 0, 28), Parent = content })
	local fusionButton = UIKit.Button("Fusion", Color3.fromRGB(170, 90, 255), function()
		ctx.UI.Open("Fusion")
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 28) })
	fusionButton.Parent = content
	local list = UIKit.ScrollList(content, { Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 1, -36) })

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
		header.Text = string.format(
			"Emplacements : %d / %d   •   Revenu : %s",
			#profile.Creatures,
			profile.MaxSlots,
			Format.Income(profile.IncomePerSecond)
		)

		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })
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
			UIKit.Label({
				Text = "Aucune créature. Achète-en sur le chemin de la Rift (touche E près d'elles) !",
				TextColor3 = Theme.TextDim,
				Size = UDim2.new(1, 0, 0, 50),
				Parent = list,
			})
		end

		for order, entry in entries do
			local def = Creatures.Get(entry.Id)
			if not def then
				continue
			end
			local rarity = Rarities.Get(def.Rarity)
			local dimension = Dimensions.Get(def.Dimension)
			local mutation = Mutations.Get(entry.Mutation)

			local card = UIKit.Card(64, order)
			card.Parent = list
			if entry.Uid == focusUid then
				UIKit.Stroke(card, Theme.Gold, 2)
			end
			UIKit.New("Frame", {
				BackgroundColor3 = if rarity then rarity.Color else Theme.Text,
				Size = UDim2.new(0, 6, 1, 0),
				Parent = card,
			})
			local title = def.Name
			if mutation then
				title = mutation.Name .. " " .. title .. " (x" .. mutation.Multiplier .. ")"
			end
			UIKit.Label({
				Text = title,
				TextColor3 = if mutation then mutation.Color else Theme.Text,
				Position = UDim2.new(0, 14, 0, 0),
				Size = UDim2.new(1, -150, 0, 24),
				Parent = card,
			})
			UIKit.Label({
				Text = string.format(
					"%s • %s • Empl. %d • %s",
					if rarity then rarity.Name else def.Rarity,
					if dimension then dimension.Name else def.Dimension,
					entry.Slot,
					if stolen[entry.Uid] then "EN COURS DE VOL !" else Format.Income(Economy.GetCreatureIncome(entry))
				),
				Font = Theme.BodyFont,
				TextSize = 14,
				TextColor3 = if stolen[entry.Uid] then Theme.Danger else Theme.TextDim,
				Position = UDim2.new(0, 14, 0, 26),
				Size = UDim2.new(1, -150, 0, 20),
				Parent = card,
			})

			local value = Economy.GetSellValue(entry)
			local sellButton
			sellButton = UIKit.Button(
				if confirmUid == entry.Uid then "Confirmer ?" else "Vendre " .. Format.Money(value),
				if confirmUid == entry.Uid then Theme.Danger else Theme.Warning,
				function()
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
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.new(0, 130, 0, 36),
					TextSize = 15,
				}
			)
			sellButton.Parent = card
		end
	end

	return self
end

return InventoryPanel
