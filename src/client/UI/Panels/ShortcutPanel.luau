--[[
	ShortcutPanel : déblocage et utilisation du portail de raccourci.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local ShortcutPanel = {}
ShortcutPanel.Title = "Portail de raccourci"
ShortcutPanel.Icon = "🌠"

function ShortcutPanel.Create(content: Frame, ctx)
	-- Écran de déblocage
	local locked = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.IconCircle(
		"🌠",
		Theme.Info,
		104,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Parent = locked }
	)
	UIKit.Label({
		Text = "Téléporte-toi devant la base d'un adversaire !",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 140),
		Size = UDim2.new(1, -20, 0, 32),
		Fit = true,
		Parent = locked,
	})
	UIKit.Body({
		Text = string.format(
			"Chaque voyage coûte au moins %s (ou 30 s de tes revenus). Recharge : %s. Le propriétaire est prévenu de ton arrivée.",
			Format.Money(GameConfig.Shortcut.UseCostBase),
			Format.Time(GameConfig.Shortcut.Cooldown)
		),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(72, 180),
		Size = UDim2.new(1, -144, 0, 44),
		Parent = locked,
	})
	local unlockButton = UIKit.Button({
		Text = "🔓 Débloquer · " .. Format.Money(GameConfig.Shortcut.UnlockCost),
		Color = "Green",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 248),
		Size = UDim2.fromOffset(340, 56),
		Radius = 14,
		Parent = locked,
		OnClick = function()
			ctx.Net.Request("UnlockShortcut")
		end,
	})

	-- Écran d'utilisation
	local unlocked = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = content }
	)
	local top = Widgets.Row({ Size = UDim2.new(1, 0, 0, 40), Parent = unlocked }, 8)
	local costChip = UIKit.Chip("💸 Coût", { LayoutOrder = 1, Parent = top })
	local cooldownChip = UIKit.Chip("✅ Prêt", { LayoutOrder = 2, Parent = top })
	local list = UIKit.ScrollList(unlocked, UIKit.ScrollArea(52))

	local self = {} :: any
	local cards: { { Button: any, Income: TextLabel, Player: Player } } = {}
	local signature: string? = nil

	local function eligiblePlayers(): { Player }
		local result = {}
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer and other:GetAttribute("PlotId") then
				table.insert(result, other)
			end
		end
		return result
	end

	-- Les cartes ne sont reconstruites que si la liste des joueurs change : détruire
	-- un bouton entre l'appui et le relâchement ferait perdre le clic.
	local function rebuildIfNeeded()
		local others = eligiblePlayers()
		local ids = {}
		for _, other in others do
			table.insert(ids, tostring(other.UserId))
		end
		local newSignature = table.concat(ids, ",")
		if newSignature == signature then
			return
		end
		signature = newSignature
		UIKit.ClearChildren(list)
		table.clear(cards)
		for index, other in others do
			local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 80), LayoutOrder = index, Parent = list })
			Widgets.Avatar(
				other.UserId,
				56,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Parent = card }
			)
			UIKit.Label({
				Text = other.DisplayName,
				TextSize = 19,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(86, 14),
				Size = UDim2.new(1, -260, 0, 24),
				Parent = card,
			})
			local income = UIKit.Label({
				Text = "",
				TextSize = 16,
				TextColor3 = Theme.GoldText,
				TextWrapped = false,
				Position = UDim2.fromOffset(86, 42),
				Size = UDim2.new(1, -260, 0, 22),
				Parent = card,
			})
			local go = UIKit.Button({
				Text = "🌀 Y aller",
				Color = "Blue",
				TextSize = 18,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(150, 46),
				ZIndex = 2,
				Parent = card,
				OnClick = function()
					if ctx.Net.Request("UseShortcut", other.UserId).Ok then
						ctx.UI.Close()
					end
				end,
			})
			table.insert(cards, { Button = go, Income = income, Player = other })
		end
		if #others == 0 then
			Widgets.Empty(list, "🏝️", "Aucun autre joueur avec une base sur ce serveur.")
		end
	end

	function self.Refresh()
		local profile = ctx.State.Profile
		if not profile then
			return
		end
		locked.Visible = not profile.ShortcutUnlocked
		unlocked.Visible = profile.ShortcutUnlocked
		if not profile.ShortcutUnlocked then
			unlockButton:SetEnabled(ctx.State.GetMoney() >= GameConfig.Shortcut.UnlockCost)
			return
		end

		rebuildIfNeeded()
		local cooldown = (profile.ShortcutReadyAt or 0) - workspace:GetServerTimeNow()
		Widgets.SetPillText(
			costChip,
			"💸 " .. Format.Money(Economy.GetShortcutUseCost(ctx.State.GetIncome())) .. " / voyage"
		)
		Widgets.SetPillText(
			cooldownChip,
			if cooldown > 0 then "⏳ Recharge " .. Format.Time(cooldown) else "✅ Prêt !"
		)
		for _, card in cards do
			card.Income.Text = "💰 " .. Format.Income(card.Player:GetAttribute("IncomePerSecond") or 0)
			card.Button:SetEnabled(cooldown <= 0)
		end
	end

	-- Comptes à rebours rafraîchis chaque seconde (léger : pas de reconstruction)
	self.Tick = self.Refresh

	return self
end

return ShortcutPanel
