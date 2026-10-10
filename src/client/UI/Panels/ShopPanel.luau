--[[
	ShopPanel : boutique Robux (gamepasses + produits) et affichage des chances
	actuelles (obligatoire dès qu'un achat Robux influence un tirage aléatoire).
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

local ShopPanel = {}
ShopPanel.Title = "Boutique"

local player = Players.LocalPlayer

function ShopPanel.Create(content: Frame, ctx)
	local list = UIKit.ScrollList(content)
	local chosenDimension = Dimensions.Order[1]
	local self = {} :: any

	local function section(text: string, order: number)
		UIKit.Label({ Text = text, TextSize = 20, TextColor3 = Theme.Gold, LayoutOrder = order, Parent = list })
	end

	local function notConfigured()
		ctx.Toast("Cet article n'est pas encore configuré (Id = 0 dans Config/Monetization).", "Error")
	end

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		UIKit.ClearChildren(list, { "UIListLayout", "UIPadding" })
		local order = 0
		local function nextOrder()
			order += 1
			return order
		end

		section("Gamepasses", nextOrder())
		for _, key in Monetization.PassOrder do
			local pass = Monetization.GamePasses[key]
			local owned = profile.Passes[key] == true
			local card = UIKit.Card(60, nextOrder())
			card.Parent = list
			UIKit.Label({ Text = pass.Name, Size = UDim2.new(1, -140, 0, 24), Parent = card })
			UIKit.Label({
				Text = pass.Description,
				Font = Theme.BodyFont,
				TextSize = 13,
				TextColor3 = Theme.TextDim,
				Position = UDim2.new(0, 0, 0, 24),
				Size = UDim2.new(1, -140, 0, 20),
				Parent = card,
			})
			local button = UIKit.Button(if owned then "Possédé" else "Acheter", Theme.Success, function()
				if pass.Id == 0 then
					notConfigured()
					return
				end
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 36),
			})
			UIKit.SetButtonEnabled(button, not owned, Theme.Success)
			button.Parent = card
		end

		section("Effets de serveur", nextOrder())

		-- Forcer une dimension (avec choix)
		local forceCard = UIKit.Card(104, nextOrder())
		forceCard.Parent = list
		local force = Monetization.Products.ForceDimension
		UIKit.Label({ Text = force.Name, Size = UDim2.new(1, -140, 0, 24), Parent = forceCard })
		UIKit.Label({
			Text = force.Description,
			Font = Theme.BodyFont,
			TextSize = 13,
			TextColor3 = Theme.TextDim,
			Position = UDim2.new(0, 0, 0, 24),
			Size = UDim2.new(1, -140, 0, 20),
			Parent = forceCard,
		})
		local picker = UIKit.New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 52),
			Size = UDim2.new(1, -140, 0, 30),
			Parent = forceCard,
		})
		UIKit.List(picker, Enum.FillDirection.Horizontal, 4)
		for i, dimensionId in Dimensions.Order do
			local dimension = Dimensions.Get(dimensionId)
			local selected = dimensionId == chosenDimension
			local pick = UIKit.Button(
				if dimension then dimension.Name else dimensionId,
				if selected and dimension then dimension.Visual.RiftColor else Theme.Surface,
				function()
					chosenDimension = dimensionId
					self.Refresh()
				end,
				{ Size = UDim2.new(0.2, -4, 1, 0), LayoutOrder = i, TextSize = 13 }
			)
			pick.Parent = picker
		end
		local forceButton = UIKit.Button("Acheter", Theme.Primary, function()
			if force.Id == 0 then
				notConfigured()
				return
			end
			ctx.Net.Invoke("SetDimensionChoice", chosenDimension)
			MarketplaceService:PromptProductPurchase(player, force.Id)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 36) })
		forceButton.Parent = forceCard

		-- Pack de chance
		local luckCard = UIKit.Card(60, nextOrder())
		luckCard.Parent = list
		local luck = Monetization.Products.LuckBoost
		UIKit.Label({ Text = luck.Name, Size = UDim2.new(1, -140, 0, 24), Parent = luckCard })
		UIKit.Label({
			Text = luck.Description,
			Font = Theme.BodyFont,
			TextSize = 13,
			TextColor3 = Theme.TextDim,
			Position = UDim2.new(0, 0, 0, 24),
			Size = UDim2.new(1, -140, 0, 20),
			Parent = luckCard,
		})
		local luckButton = UIKit.Button("Acheter", Theme.Primary, function()
			if luck.Id == 0 then
				notConfigured()
				return
			end
			MarketplaceService:PromptProductPurchase(player, luck.Id)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 36) })
		luckButton.Parent = luckCard

		-- Transparence des chances
		local dimensionId = ctx.State.GetDimension()
		local dimension = Dimensions.Get(dimensionId)
		local currentLuck = ctx.State.GetLuck()
		section("Chances d'apparition (" .. (if dimension then dimension.Name else dimensionId) .. ")", nextOrder())
		local now = Odds.GetRarityChances(dimensionId, currentLuck)
		local boosted = Odds.GetRarityChances(dimensionId, currentLuck * luck.Multiplier)
		for i, item in now do
			local card = UIKit.Card(34, nextOrder())
			card.Parent = list
			UIKit.Label({
				Text = string.format(
					"%s : %s   (avec pack de chance : %s)",
					item.Rarity.Name,
					Format.Percent(item.Chance),
					Format.Percent(boosted[i] and boosted[i].Chance or item.Chance)
				),
				TextSize = 15,
				TextColor3 = item.Rarity.Color,
				Size = UDim2.fromScale(1, 1),
				Parent = card,
			})
		end
		UIKit.Label({
			Text = "Les Secrètes n'apparaissent que par les portails instables dorés (le pack de chance ne les affecte pas).",
			Font = Theme.BodyFont,
			TextSize = 13,
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end

	return self
end

return ShopPanel
