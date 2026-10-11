--[[
	CodesPanel : saisie des codes promotionnels (validés uniquement par le serveur).
]]

local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local CodesPanel = {}
CodesPanel.Title = "Codes"
CodesPanel.Icon = "🔑"
CodesPanel.Height = 452

function CodesPanel.Create(content: Frame, ctx)
	UIKit.IconCircle("🔑", Theme.Gold, 80, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Parent = content,
	})
	UIKit.Label({
		Text = "Entre un code pour recevoir des récompenses !",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 98),
		Size = UDim2.new(1, -20, 0, 28),
		Fit = true,
		Parent = content,
	})

	-- Champ + bouton côte à côte, centrés
	local form = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 142),
		Size = UDim2.fromOffset(536, 56),
		Parent = content,
	})
	local box = UIKit.Input({
		PlaceholderText = "Ton code ici",
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(372, 52),
		TextSize = 22,
		Parent = form,
	})

	local status = UIKit.Label({
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 210),
		Size = UDim2.new(1, -20, 0, 24),
		Fit = true,
		Parent = content,
	})

	local function submit()
		local code = box.Text
		if code == "" then
			return
		end
		local response = ctx.Net.Request("RedeemCode", code)
		status.Text = response.Message or ""
		status.TextColor3 = if response.Ok then Theme.MoneyText else Theme.DangerText
		if response.Ok then
			box.Text = ""
		end
	end

	UIKit.Button({
		Text = "Valider",
		Color = "Green",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(148, 56),
		Radius = 14,
		Parent = form,
		OnClick = submit,
	})
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	local info = UIKit.Card({ Position = UDim2.fromOffset(40, 250), Size = UDim2.new(1, -80, 0, 96), Parent = content })
	UIKit.Label({
		Text = "📣 De nouveaux codes à chaque mise à jour !",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 24),
		Fit = true,
		Parent = info,
	})
	UIKit.Body({
		Text = "Ajoute le jeu en favori ⭐ et rejoins le groupe pour ne rater aucun code ni aucun événement.",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(24, 44),
		Size = UDim2.new(1, -48, 0, 40),
		Parent = info,
	})

	local self = {} :: any
	function self.Refresh() end
	function self.OnOpen()
		status.Text = ""
	end
	return self
end

return CodesPanel
