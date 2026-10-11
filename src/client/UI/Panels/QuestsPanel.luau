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
QuestsPanel.Color = "Orange"

local ICONS = {
	Buy = "🛒",
	BuyRare = "💎",
	Steal = "🦹",
	Fuse = "🌀",
	Barrier = "🛡️",
	Minute = "⏱️",
	Recover = "🛡️",
}
local TIER_NAMES = { "Facile", "Moyenne", "Difficile" }
local TIER_COLORS = { Color3.fromRGB(90, 200, 110), Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 100) }

function QuestsPanel.Create(content: Frame, ctx)
	local timerPill = UIKit.Pill("⏳ Nouvelles quêtes dans 0:00", Color3.fromRGB(120, 100, 220), {
		Size = UDim2.fromOffset(0, 36),
		TextSize = 17,
		Parent = content,
	})

	local list = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 300),
		Parent = content,
	})
	UIKit.List(list, Enum.FillDirection.Vertical, 10)

	local rows = {}
	for index = 1, Quests.PerDay do
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 92), LayoutOrder = index, Parent = list })
		local icon = UIKit.IconCircle("📜", Color3.fromRGB(255, 170, 50), 70, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Parent = card,
		})
		local title = UIKit.Text({
			Text = "",
			TextSize = 21,
			TextWrapped = false,
			Position = UDim2.fromOffset(96, 8),
			Size = UDim2.new(1, -300, 0, 26),
			Parent = card,
		})
		local tierPill = UIKit.Pill("Facile", TIER_COLORS[1], {
			Position = UDim2.new(1, -300, 0, 10),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(0, 24),
			TextSize = 13,
			Parent = card,
		})
		local bar = UIKit.ProgressBar(
			{ Position = UDim2.fromOffset(96, 44), Size = UDim2.new(1, -300, 0, 30), Parent = card },
			Color3.fromRGB(255, 180, 60)
		)
		local reward = UIKit.Text({
			Text = "",
			TextSize = 15,
			TextColor3 = Theme.Money,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 8),
			Size = UDim2.fromOffset(176, 24),
			Parent = card,
		})
		local button = UIKit.Button({
			Text = "Réclamer",
			Color = "Gold",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -8),
			Size = UDim2.fromOffset(176, 48),
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
		Size = UDim2.new(1, 0, 0, 84),
		Parent = content,
	}, Theme.Gold, 0.35)
	UIKit.IconCircle("🏆", Theme.Gold, 64, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Parent = bonusCard,
	})
	UIKit.Text({
		Text = "BONUS : termine les 3 quêtes !",
		TextSize = 21,
		TextWrapped = false,
		Position = UDim2.fromOffset(90, 10),
		Size = UDim2.new(1, -290, 0, 28),
		Parent = bonusCard,
	})
	UIKit.Body({
		Text = "⚡ Argent x2 pendant 15 min + 🐾 créature Épique ou Légendaire",
		TextColor3 = Color3.fromRGB(255, 240, 200),
		Position = UDim2.fromOffset(90, 42),
		Size = UDim2.new(1, -290, 0, 30),
		Parent = bonusCard,
	})
	local bonusButton = UIKit.Button({
		Text = "🎁 Bonus",
		Color = "Gold",
		TextSize = 19,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(176, 56),
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
				local tierGradient = row.Tier:FindFirstChildOfClass("UIGradient")
				if tierGradient then
					local color = TIER_COLORS[quest.Tier] or TIER_COLORS[1]
					tierGradient.Color = ColorSequence.new(Theme.Lighten(color, 0.2), Theme.Darken(color, 0.15))
				end
				row.Bar:SetProgress(quest.Progress / math.max(1, quest.Goal))
				row.Bar:SetText(string.format("%d / %d", quest.Progress, quest.Goal))
				row.Reward.Text = quest.RewardText
				if quest.Claimed then
					row.Button:SetText("✅ Réclamée")
					row.Button:SetEnabled(false)
				elseif quest.Progress >= quest.Goal then
					row.Button:SetText("🎁 Réclamer")
					row.Button:SetEnabled(true)
				else
					row.Button:SetText("En cours...")
					row.Button:SetEnabled(false)
				end
			end
		end
		if quests.BonusClaimed then
			bonusButton:SetText("✅ Reçu")
			bonusButton:SetEnabled(false)
		else
			bonusButton:SetText("🎁 Bonus")
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
