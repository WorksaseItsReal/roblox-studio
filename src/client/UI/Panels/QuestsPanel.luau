--[[
	QuestsPanel : 3 quêtes quotidiennes + bonus si les 3 sont réclamées.
	Progression et récompenses calculées par le serveur (instantané Quests).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Modules.Format)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local Widgets = require(script.Parent.Parent.Widgets)

local QuestsPanel = {}
QuestsPanel.Title = "Quêtes du jour"
QuestsPanel.Icon = "📜"
QuestsPanel.Height = 556

local ICONS = {
	Buy = "🛒",
	BuyRare = "💎",
	Steal = "🦹",
	Fuse = "⚗️",
	Barrier = "🛡️",
	Minute = "⏱️",
	Recover = "🛡️",
}
-- Couleur de la tuile selon le type de quête (code couleur du jeu : vert = acheter,
-- rouge = vol / barrière, violet = rare / fusion, bleu = infos)
local COLORS = {
	Buy = Theme.Money,
	BuyRare = Theme.Brand,
	Steal = Theme.Danger,
	Fuse = Theme.Brand,
	Barrier = Theme.Danger,
	Minute = Theme.Info,
	Recover = Theme.Info,
}
local TIER_NAMES = { "Facile", "Moyenne", "Difficile" }
local TIER_COLORS = { Theme.Money, Theme.Warning, Theme.Danger }

function QuestsPanel.Create(content: Frame, ctx)
	local timerChip = UIKit.Chip("⏳ Nouvelles quêtes dans 0:00", { Parent = content })

	local list = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 308),
		Parent = content,
	})
	UIKit.List(list, Enum.FillDirection.Vertical, 10)

	local rows = {}
	for index = 1, Quests.PerDay do
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 96), LayoutOrder = index, Parent = list })
		local icon = UIKit.IconTile("📜", Theme.Info, 56, {
			Position = UDim2.fromOffset(16, 10),
			Parent = card,
		})
		-- Difficulté : ruban sous l'icône
		local tierPill = UIKit.Pill("Facile", TIER_COLORS[1], {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(44, 74),
			Size = UDim2.fromOffset(0, 22),
			TextSize = 13,
			ZIndex = 2,
			Parent = card,
		})
		local title = UIKit.Label({
			Text = "",
			TextSize = 19,
			TextWrapped = false,
			Position = UDim2.fromOffset(92, 14),
			Size = UDim2.new(1, -310, 0, 24),
			Fit = true,
			Parent = card,
		})
		local bar = UIKit.ProgressBar(
			{ Position = UDim2.fromOffset(92, 50), Size = UDim2.new(1, -310, 0, 26), Parent = card },
			Theme.Gold
		)
		local reward = UIKit.Label({
			Text = "",
			TextSize = 17,
			TextColor3 = Theme.MoneyText,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 10),
			Size = UDim2.fromOffset(184, 22),
			Fit = true,
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "Réclamer",
			Color = "Green",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -12),
			Size = UDim2.fromOffset(184, 46),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimQuest", index)
			end,
		})
		rows[index] =
			{ Card = card, Icon = icon, Title = title, Tier = tierPill, Bar = bar, Reward = reward, Button = button }
	end

	-- Bonus de fin de journée (carte dorée : c'est une récompense)
	local bonusCard = UIKit.Card({
		Position = UDim2.fromOffset(0, 372),
		Size = UDim2.new(1, 0, 0, 84),
		Parent = content,
	}, Theme.Gold)
	UIKit.IconTile("🏆", Theme.Gold, 56, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Parent = bonusCard,
	})
	UIKit.Label({
		Text = "Bonus : termine les 3 quêtes !",
		TextSize = 19,
		TextWrapped = false,
		Position = UDim2.fromOffset(92, 14),
		Size = UDim2.new(1, -310, 0, 24),
		Fit = true,
		Parent = bonusCard,
	})
	UIKit.Body({
		Text = "⚡ Argent x2 pendant 15 min + 🐾 créature Épique ou Légendaire",
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(92, 42),
		Size = UDim2.new(1, -310, 0, 38),
		Parent = bonusCard,
	})
	local bonusButton = UIKit.Button({
		Text = "🎁 Bonus",
		Color = "Green",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(184, 46),
		ZIndex = 2,
		Parent = bonusCard,
		OnClick = function()
			ctx.Net.Request("ClaimQuestBonus")
		end,
	})

	local self = {} :: any

	function self.Refresh()
		local profile = ctx.State.Profile
		local quests = profile and profile.Quests
		if not quests then
			return
		end
		Widgets.SetPillText(
			timerChip,
			"⏳ Nouvelles quêtes dans " .. Format.Time(quests.ResetsAt - ctx.State.GetServerUnixTime())
		)
		for index, row in rows do
			local quest = quests.List[index]
			row.Card.Visible = quest ~= nil
			if quest then
				local glyph = row.Icon:FindFirstChild("Glyph") :: TextLabel
				glyph.Text = ICONS[quest.Id] or "📜"
				row.Title.Text = quest.Text
				-- Ruban : couleur de la difficulté ; tuile : couleur du type de quête
				Widgets.SetPillText(row.Tier, TIER_NAMES[quest.Tier] or "")
				Widgets.SetPillColor(row.Tier, TIER_COLORS[quest.Tier] or TIER_COLORS[1])
				local iconColor = COLORS[quest.Id] or Theme.Info
				local iconGradient = row.Icon:FindFirstChildOfClass("UIGradient")
				if iconGradient then
					iconGradient.Color = ColorSequence.new(Theme.Lighten(iconColor, 0.3), iconColor)
				end
				row.Bar:SetProgress(quest.Progress / math.max(1, quest.Goal))
				row.Bar:SetText(string.format("%d / %d", quest.Progress, quest.Goal))
				row.Reward.Text = quest.RewardText
				local ready = not quest.Claimed and quest.Progress >= quest.Goal
				-- Quête à réclamer : carte dorée (récompense)
				UIKit.SetCardTint(row.Card, if ready then Theme.Gold else nil)
				if quest.Claimed then
					row.Button:SetStatus("✅ Réclamée")
				elseif ready then
					row.Button:SetText("🎁 Réclamer")
					row.Button:SetEnabled(true)
				else
					row.Button:SetStatus("En cours...")
				end
			end
		end
		if quests.BonusClaimed then
			bonusButton:SetStatus("✅ Reçu")
		elseif quests.AllClaimed then
			bonusButton:SetText("🎁 Bonus")
			bonusButton:SetEnabled(true)
		else
			bonusButton:SetStatus("🔒 Verrouillé")
		end
	end

	-- Comptes à rebours rafraîchis chaque seconde
	self.Tick = self.Refresh

	return self
end

-- Vrai si quelque chose est à réclamer (pastille rouge sur le bouton du menu)
function QuestsPanel.HasClaimable(profile): boolean
	local quests = profile and profile.Quests
	if not quests then
		return false
	end
	for _, quest in quests.List do
		if not quest.Claimed and quest.Progress >= quest.Goal then
			return true
		end
	end
	return quests.AllClaimed == true and not quests.BonusClaimed
end

return QuestsPanel
