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
QuestsPanel.Color = "Gold"

local ICONS = {
	Buy = "🛒",
	BuyRare = "💎",
	Steal = "🦹",
	Fuse = "🌀",
	Barrier = "🛡️",
	Minute = "⏱️",
	Recover = "🛡️",
}
-- Couleur de la tuile selon le type de quête (code couleur du jeu : vert = acheter,
-- rouge = vol / barrière, violet = rare / magique, bleu = infos)
local COLORS = {
	Buy = Color3.fromRGB(40, 200, 60),
	BuyRare = Color3.fromRGB(170, 70, 255),
	Steal = Color3.fromRGB(255, 60, 60),
	Fuse = Color3.fromRGB(170, 70, 255),
	Barrier = Color3.fromRGB(255, 60, 60),
	Minute = Color3.fromRGB(40, 140, 255),
	Recover = Color3.fromRGB(0, 180, 230),
}
local TIER_NAMES = { "Facile", "Moyenne", "Difficile" }
local TIER_COLORS = { Color3.fromRGB(40, 200, 60), Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 60) }

function QuestsPanel.Create(content: Frame, ctx)
	local timerPill = UIKit.Pill("⏳ Nouvelles quêtes dans 0:00", Theme.Info, {
		Size = UDim2.fromOffset(0, 36),
		TextSize = 17,
		Parent = content,
	})

	local list = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 302),
		Parent = content,
	})
	UIKit.List(list, Enum.FillDirection.Vertical, 10)

	local rows = {}
	for index = 1, Quests.PerDay do
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 94), LayoutOrder = index, Parent = list })
		local icon = UIKit.IconTile("📜", Theme.Info, 70, {
			Position = UDim2.fromOffset(14, 6),
			Parent = card,
		})
		-- Difficulté : ruban sous l'icône
		local tierPill = UIKit.Pill("Facile", TIER_COLORS[1], {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(49, 78),
			Size = UDim2.fromOffset(0, 24),
			TextSize = 15,
			ZIndex = 2,
			Parent = card,
		})
		local title = UIKit.Body({
			Text = "",
			TextSize = 21,
			TextColor3 = Theme.Text,
			TextWrapped = false,
			Position = UDim2.fromOffset(100, 9),
			Size = UDim2.new(1, -316, 0, 28),
			Stroke = 2,
			Fit = true,
			Parent = card,
		})
		local bar = UIKit.ProgressBar(
			{ Position = UDim2.fromOffset(100, 46), Size = UDim2.new(1, -316, 0, 32), Parent = card },
			Color3.fromRGB(255, 190, 0)
		)
		local reward = UIKit.Text({
			Text = "",
			TextSize = 18,
			TextColor3 = Theme.Money,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 7),
			Size = UDim2.fromOffset(190, 26),
			Stroke = 2.2,
			Fit = true,
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "RÉCLAMER",
			Color = "Gold",
			TextSize = 19,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -9),
			Size = UDim2.fromOffset(190, 50),
			ZIndex = 2,
			Parent = card,
			OnClick = function()
				ctx.Net.Request("ClaimQuest", index)
			end,
		})
		rows[index] =
			{ Card = card, Icon = icon, Title = title, Tier = tierPill, Bar = bar, Reward = reward, Button = button }
	end

	-- Bonus de fin de journée
	local bonusCard = UIKit.Card({
		Position = UDim2.fromOffset(0, 362),
		Size = UDim2.new(1, 0, 0, 86),
		Parent = content,
	}, Color3.fromRGB(255, 176, 0))
	UIKit.IconTile("🏆", Color3.fromRGB(255, 120, 0), 66, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Parent = bonusCard,
	})
	UIKit.Text({
		Text = "BONUS : termine les 3 quêtes !",
		TextSize = 22,
		TextWrapped = false,
		Position = UDim2.fromOffset(96, 9),
		Size = UDim2.new(1, -316, 0, 30),
		Stroke = 2.8,
		Fit = true,
		Parent = bonusCard,
	})
	UIKit.Body({
		Text = "⚡ Argent x2 pendant 15 min + 🐾 créature Épique ou Légendaire",
		TextColor3 = Theme.Text,
		Position = UDim2.fromOffset(96, 40),
		Size = UDim2.new(1, -316, 0, 38),
		TextYAlignment = Enum.TextYAlignment.Top,
		Stroke = 1.6,
		Parent = bonusCard,
	})
	local bonusButton = UIKit.Button({
		Text = "🎁 BONUS",
		Color = "Green",
		TextSize = 21,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(190, 58),
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
			timerPill,
			"⏳ Nouvelles quêtes dans " .. Format.Time(quests.ResetsAt - ctx.State.GetServerUnixTime())
		)
		for index, row in rows do
			local quest = quests.List[index]
			row.Card.Visible = quest ~= nil
			if quest then
				local glyph = row.Icon:FindFirstChild("Glyph") :: TextLabel
				glyph.Text = ICONS[quest.Id] or "📜"
				row.Title.Text = quest.Text
				Widgets.SetPillText(row.Tier, TIER_NAMES[quest.Tier] or "")
				-- Ruban : couleur de la difficulté ; tuile : couleur du type de quête
				local tierColor = Theme.Vivid(TIER_COLORS[quest.Tier] or TIER_COLORS[1])
				local tierGradient = row.Tier:FindFirstChildOfClass("UIGradient")
				if tierGradient then
					tierGradient.Color = ColorSequence.new(Theme.Lighten(tierColor, 0.2), Theme.Darken(tierColor, 0.18))
				end
				local iconColor = COLORS[quest.Id] or Theme.Info
				local iconGradient = row.Icon:FindFirstChildOfClass("UIGradient")
				if iconGradient then
					iconGradient.Color =
						ColorSequence.new(Theme.Lighten(iconColor, 0.32), Theme.Darken(iconColor, 0.15))
				end
				row.Bar:SetProgress(quest.Progress / math.max(1, quest.Goal))
				row.Bar:SetText(string.format("%d / %d", quest.Progress, quest.Goal))
				row.Reward.Text = quest.RewardText
				if quest.Claimed then
					row.Button:SetText("✅ RÉCLAMÉE")
					row.Button:SetEnabled(false)
				elseif quest.Progress >= quest.Goal then
					row.Button:SetText("🎁 RÉCLAMER")
					row.Button:SetEnabled(true)
				else
					row.Button:SetText("EN COURS...")
					row.Button:SetEnabled(false)
				end
			end
		end
		if quests.BonusClaimed then
			bonusButton:SetText("✅ REÇU")
			bonusButton:SetEnabled(false)
		else
			bonusButton:SetText("🎁 BONUS")
			bonusButton:SetEnabled(quests.AllClaimed == true)
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
