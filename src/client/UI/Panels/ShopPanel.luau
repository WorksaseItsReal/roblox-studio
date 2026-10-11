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
ShopPanel.Color = "Green"

local player = Players.LocalPlayer

local PASS_STYLE = {
	DoubleMoney = { Icon = "💸", Color = Color3.fromRGB(70, 200, 90) },
	VipSlots = { Icon = "⭐", Color = Color3.fromRGB(255, 190, 40) },
	LongBarrier = { Icon = "🛡️", Color = Color3.fromRGB(255, 90, 100) },
	Speed = { Icon = "⚡", Color = Color3.fromRGB(80, 170, 255) },
}

function ShopPanel.Create(content: Frame, ctx)
	local list = UIKit.ScrollList(content)
	local chosenDimension = Dimensions.Order[1]
	local self = {} :: any

	local function notConfigured()
		ctx.Toast("Article pas encore configuré (Id = 0 dans Config/Monetization).", "Error")
	end

	local function productCard(
		order: number,
		height: number,
		icon: string,
		color: Color3,
		name: string,
		description: string
	)
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = list }, color, 0.3)
		UIKit.IconCircle(icon, color, 76, { Position = UDim2.fromOffset(14, 14), Parent = card })
		UIKit.Text({
			Text = name,
			TextSize = 22,
			TextWrapped = false,
			Position = UDim2.fromOffset(104, 12),
			Size = UDim2.new(1, -290, 0, 28),
			Parent = card,
		})
		UIKit.Body({
			Text = description,
			TextColor3 = Color3.fromRGB(232, 226, 255),
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(104, 42),
			Size = UDim2.new(1, -290, 0, 40),
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

		------------------------------------------------ Gamepasses (grille 2x2)
		Widgets.Section(list, "⭐ GAMEPASSES", nextOrder())
		local passGrid = UIKit.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		UIKit.New("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 164),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = passGrid,
		})
		for passOrder, key in Monetization.PassOrder do
			local pass = Monetization.GamePasses[key]
			local style = PASS_STYLE[key] or { Icon = "⭐", Color = Theme.Gold }
			local owned = profile.Passes[key] == true
			local card = UIKit.Card({ LayoutOrder = passOrder, Parent = passGrid }, style.Color, 0.35)
			UIKit.IconCircle(style.Icon, style.Color, 64, { Position = UDim2.fromOffset(12, 12), Parent = card })
			UIKit.Text({
				Text = pass.Name,
				TextSize = 21,
				TextWrapped = false,
				Position = UDim2.fromOffset(86, 14),
				Size = UDim2.new(1, -96, 0, 26),
				Parent = card,
			})
			UIKit.Body({
				Text = pass.Description,
				TextColor3 = Color3.fromRGB(232, 226, 255),
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(86, 42),
				Size = UDim2.new(1, -96, 0, 38),
				Parent = card,
			})
			local button = UIKit.Button({
				Text = if owned then "✅ Possédé" else "R$ Acheter",
				Color = "Green",
				TextSize = 19,
				Position = UDim2.new(0, 12, 1, -62),
				Size = UDim2.new(1, -24, 0, 52),
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
			button:SetEnabled(not owned)
		end

		------------------------------------------------ Effets de serveur
		Widgets.Section(list, "⚡ EFFETS DE SERVEUR", nextOrder())

		local force = Monetization.Products.ForceDimension
		local forceCard =
			productCard(nextOrder(), 158, "🌀", Color3.fromRGB(170, 90, 255), force.Name, force.Description)
		local picker = Widgets.Row(
			{ Position = UDim2.fromOffset(104, 100), Size = UDim2.new(1, -290, 0, 46), Parent = forceCard },
			6
		)
		for i, dimensionId in Dimensions.Order do
			local dimension = Dimensions.Get(dimensionId)
			local pick = UIKit.Button({
				Text = Theme.DimensionIcons[dimensionId] or "?",
				Color = if dimensionId == chosenDimension and dimension
					then Theme.PaletteFrom(dimension.Visual.RiftColor)
					else "Dark",
				TextSize = 22,
				Size = UDim2.fromOffset(54, 44),
				LayoutOrder = i,
				ZIndex = 2,
				Parent = picker,
				OnClick = function()
					chosenDimension = dimensionId
					self.Refresh()
				end,
			})
			local _ = pick
		end
		UIKit.Button({
			Text = "R$ Forcer "
				.. (if Dimensions.Get(chosenDimension) then (Dimensions.Get(chosenDimension) :: any).Name else ""),
			Color = "Purple",
			TextSize = 17,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(170, 60),
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
		local luckCard = productCard(nextOrder(), 108, "🍀", Color3.fromRGB(70, 200, 90), luck.Name, luck.Description)
		UIKit.Button({
			Text = "R$ Acheter",
			Color = "Green",
			TextSize = 19,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(170, 60),
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
			"🎲 CHANCES ACTUELLES • " .. Format.Upper(if dimension then dimension.Name else dimensionId),
			nextOrder()
		)
		local now = Odds.GetRarityChances(dimensionId, currentLuck)
		local boosted = Odds.GetRarityChances(dimensionId, currentLuck * luck.Multiplier)
		local oddsBox = UIKit.Inset({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		UIKit.List(oddsBox, Enum.FillDirection.Vertical, 8)
		UIKit.Padding(oddsBox, 12)
		for i, item in now do
			local line = UIKit.New(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, Parent = oddsBox }
			)
			UIKit.Pill(item.Rarity.Name, item.Rarity.Color, { Size = UDim2.fromOffset(0, 28), Parent = line })
			local bar = UIKit.ProgressBar(
				{ Position = UDim2.fromOffset(130, 1), Size = UDim2.new(1, -330, 0, 28), Parent = line },
				item.Rarity.Color
			)
			bar:SetProgress(math.max(item.Chance, 0.02))
			bar:SetText(Format.Percent(item.Chance))
			UIKit.Text({
				Text = "🍀 " .. Format.Percent(boosted[i] and boosted[i].Chance or item.Chance),
				TextSize = 16,
				TextColor3 = Theme.Money,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextWrapped = false,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(180, 30),
				Parent = line,
			})
		end
		UIKit.Body({
			Text = "🍀 = avec le pack de chance. Les Secrètes n'apparaissent que par les portails instables dorés.",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end

	return self
end

return ShopPanel
