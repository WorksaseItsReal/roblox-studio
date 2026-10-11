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
ShortcutPanel.Color = "Cyan"

local CYAN = Color3.fromRGB(40, 190, 230)

function ShortcutPanel.Create(content: Frame, ctx)
	-- Écran de déblocage
	local locked = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })
	UIKit.IconCircle(
		"🌠",
		CYAN,
		124,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Parent = locked }
	)
	UIKit.Text({
		Text = "Téléporte-toi devant la base d'un adversaire !",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 144),
		Size = UDim2.new(1, -20, 0, 36),
		Stroke = 3,
		Fit = true,
		Parent = locked,
	})
	UIKit.Body({
		Text = string.format(
			"Chaque voyage coûte au moins %s (ou 30 s de tes revenus). Recharge : %s. Le propriétaire est prévenu de ton arrivée.",
			Format.Money(GameConfig.Shortcut.UseCostBase),
			Format.Time(GameConfig.Shortcut.Cooldown)
		),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(60, 186),
		Size = UDim2.new(1, -120, 0, 48),
		Parent = locked,
	})
	local unlockButton = UIKit.Button({
		Text = "🔓 DÉBLOQUER • " .. Format.Money(GameConfig.Shortcut.UnlockCost),
		Color = "Green",
		TextSize = 26,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 258),
		Size = UDim2.fromOffset(430, 80),
		Radius = 16,
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
	local top = Widgets.Row({ Size = UDim2.new(1, 0, 0, 40), Parent = unlocked }, 10)
	local costPill = UIKit.Pill(
		"💸 Coût",
		Color3.fromRGB(40, 200, 60),
		{ Parent = top, LayoutOrder = 1, Size = UDim2.fromOffset(0, 36), TextSize = 17 }
	)
	local cooldownPill = UIKit.Pill(
		"✅ Prêt",
		Theme.Info,
		{ Parent = top, LayoutOrder = 2, Size = UDim2.fromOffset(0, 36), TextSize = 17 }
	)
	local list = UIKit.ScrollList(unlocked, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52) })

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
			local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 84), LayoutOrder = index, Parent = list })
			Widgets.Avatar(
				other.UserId,
				62,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = card }
			)
			UIKit.Body({
				Text = other.DisplayName,
				TextSize = 22,
				TextColor3 = Theme.Text,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(88, 10),
				Size = UDim2.new(1, -270, 0, 30),
				Stroke = 2,
				Parent = card,
			})
			local income = UIKit.Text({
				Text = "",
				TextSize = 19,
				TextColor3 = Theme.Income,
				TextWrapped = false,
				Position = UDim2.fromOffset(88, 42),
				Size = UDim2.new(1, -270, 0, 26),
				Stroke = 2.2,
				Parent = card,
			})
			local go = UIKit.Button({
				Text = "🌀 Y ALLER",
				Color = "Cyan",
				TextSize = 20,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(160, 58),
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
			costPill,
			"💸 " .. Format.Money(Economy.GetShortcutUseCost(ctx.State.GetIncome())) .. " / voyage"
		)
		Widgets.SetPillText(cooldownPill, if cooldown > 0 then "⏳ " .. Format.Time(cooldown) else "✅ Prêt !")
		for _, card in cards do
			card.Income.Text = "💸 " .. Format.Income(card.Player:GetAttribute("IncomePerSecond") or 0)
			card.Button:SetEnabled(cooldown <= 0)
		end
	end

	-- Comptes à rebours rafraîchis chaque seconde (léger : pas de reconstruction)
	self.Tick = self.Refresh

	return self
end

return ShortcutPanel
