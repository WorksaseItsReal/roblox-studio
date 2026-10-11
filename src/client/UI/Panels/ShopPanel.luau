--[[
	ShopPanel : boutique Robux (gamepasses + effets de serveur) et chances actuelles
	(obligatoire dès qu'un achat Robux influence un tirage aléatoire).
	Le client ne fait qu'OUVRIR la fenêtre d'achat Roblox ; le serveur accorde les effets.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)
local Dimensions = require(Shared.Config.Dimensions)
local Odds = require(Shared.Modules.Odds)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local ShopPanel = {}
ShopPanel.Title = "Boutique"
ShopPanel.Icon = "🛒"

local player = Players.LocalPlayer

-- Icône et couleur (selon le sens) de chaque gamepass
local PASS_STYLE = {
	DoubleMoney = { Icon = "💸", Color = Theme.Money },
	VipSlots = { Icon = "⭐", Color = Theme.Gold },
	LongBarrier = { Icon = "🛡️", Color = Theme.Danger },
	Speed = { Icon = "⚡", Color = Theme.Info },
}

function ShopPanel.Create(content: Frame, ctx)
	local list = UIKit.ScrollList(content, UIKit.ScrollArea(0))
	local chosenDimension = Dimensions.Order[1]
	local self = {} :: any

	local function notConfigured()
		ctx.Toast("Article pas encore configuré (Id = 0 dans Config/Monetization).", "Error")
	end

	-- Carte produit : icône, nom, description (le bouton est ajouté par l'appelant)
	local function productCard(
		parent: Instance,
		order: number,
		height: number,
		icon: string,
		color: Color3,
		name: string,
		description: string,
		textRight: number
	): Frame
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = parent })
		UIKit.IconTile(icon, color, 56, { Position = UDim2.fromOffset(14, 14), Parent = card })
		UIKit.Label({
			Text = name,
			TextSize = 19,
			TextWrapped = false,
			Position = UDim2.fromOffset(84, 14),
			Size = UDim2.new(1, -(84 + textRight), 0, 24),
			Fit = true,
			Parent = card,
		})
		UIKit.Body({
			Text = description,
			TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(84, 40),
			Size = UDim2.new(1, -(84 + textRight), 0, 40),
			Parent = card,
		})
		return card
	end

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		UIKit.ClearChildren(list)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		------------------------------------------------ Gamepasses (grille 2 x 2)
		Widgets.Section(list, "⭐ Gamepasses", nextOrder())
		local passGrid = UIKit.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		UIKit.New("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 152),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = passGrid,
		})
		for passOrder, key in Monetization.PassOrder do
			local pass = Monetization.GamePasses[key]
			local style = PASS_STYLE[key] or { Icon = "⭐", Color = Theme.Gold }
			local owned = profile.Passes[key] == true
			local card = productCard(passGrid, passOrder, 152, style.Icon, style.Color, pass.Name, pass.Description, 14)
			local button = UIKit.Button({
				Text = if owned then "✅ Possédé" else "R$ Acheter",
				Color = "Green",
				TextSize = 18,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 14, 1, -14),
				Size = UDim2.new(1, -28, 0, 44),
				ZIndex = 2,
				Parent = card,
				OnClick = function()
					if pass.Id == 0 then
						notConfigured()
						return
					end
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end,
			})
			if owned then
				button:SetStatus("✅ Possédé")
			end
		end

		------------------------------------------------ Effets de serveur
		Widgets.Section(list, "⚡ Effets de serveur", nextOrder())

		local force = Monetization.Products.ForceDimension
		local forceCard = productCard(list, nextOrder(), 150, "🌀", Theme.Brand, force.Name, force.Description, 214)
		-- Choix de la dimension (sélection : violet de marque)
		local picker = Widgets.Row(
			{ Position = UDim2.fromOffset(84, 92), Size = UDim2.new(1, -298, 0, 44), Parent = forceCard },
			8
		)
		for i, dimensionId in Dimensions.Order do
			UIKit.Button({
				Text = Theme.DimensionIcons[dimensionId] or "?",
				Color = if dimensionId == chosenDimension then "Brand" else "White",
				TextSize = 22,
				Size = UDim2.fromOffset(52, 44),
				LayoutOrder = i,
				ZIndex = 2,
				Fit = false,
				Parent = picker,
				OnClick = function()
					chosenDimension = dimensionId
					self.Refresh()
				end,
			})
		end
		local chosen = Dimensions.Get(chosenDimension)
		UIKit.Button({
			Text = "R$ Forcer " .. (if chosen then chosen.Name else ""),
			Color = "Green",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(186, 52),
			ZIndex = 2,
			Parent = forceCard,
			OnClick = function()
				if force.Id == 0 then
					notConfigured()
					return
				end
				ctx.Net.Invoke("SetDimensionChoice", chosenDimension)
				MarketplaceService:PromptProductPurchase(player, force.Id)
			end,
		})

		local luck = Monetization.Products.LuckBoost
		local luckCard = productCard(list, nextOrder(), 96, "🍀", Theme.Money, luck.Name, luck.Description, 214)
		UIKit.Button({
			Text = "R$ Acheter",
			Color = "Green",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(186, 52),
			ZIndex = 2,
			Parent = luckCard,
			OnClick = function()
				if luck.Id == 0 then
					notConfigured()
					return
				end
				MarketplaceService:PromptProductPurchase(player, luck.Id)
			end,
		})

		------------------------------------------------ Chances (transparence)
		local dimensionId = ctx.State.GetDimension()
		local dimension = Dimensions.Get(dimensionId)
		local currentLuck = ctx.State.GetLuck()
		Widgets.Section(
			list,
			"🎲 Chances actuelles · " .. (if dimension then dimension.Name else dimensionId),
			nextOrder()
		)
		local now = Odds.GetRarityChances(dimensionId, currentLuck)
		local boosted = Odds.GetRarityChances(dimensionId, currentLuck * luck.Multiplier)
		local oddsCard = UIKit.Card({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		UIKit.List(oddsCard, Enum.FillDirection.Vertical, 10)
		UIKit.Padding(oddsCard, 14, 16, 14, 16)
		for i, item in now do
			local line = UIKit.New(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, Parent = oddsCard }
			)
			Widgets.RarityTag(item.Rarity.Id, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Parent = line,
			})
			local bar = UIKit.ProgressBar(
				{ Position = UDim2.fromOffset(120, 1), Size = UDim2.new(1, -260, 0, 24), Parent = line },
				item.Rarity.Color
			)
			bar:SetProgress(math.max(item.Chance, 0.02))
			bar:SetText(Format.Percent(item.Chance))
			UIKit.Label({
				Text = "🍀 " .. Format.Percent(boosted[i] and boosted[i].Chance or item.Chance),
				TextSize = 16,
				TextColor3 = Theme.MoneyText,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextWrapped = false,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(124, 26),
				Fit = true,
				Parent = line,
			})
		end
		UIKit.Body({
			Text = "🍀 = avec le pack de chance. Les Secrètes n'apparaissent que par les portails instables dorés.",
			TextSize = 15,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end

	return self
end

return ShopPanel
