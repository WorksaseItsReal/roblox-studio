--[[
	CodesPanel : saisie des codes promotionnels (validés uniquement par le serveur).
]]

local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local CodesPanel = {}
CodesPanel.Title = "Codes"
CodesPanel.Icon = "🔑"
CodesPanel.Color = "Cyan"
CodesPanel.Height = 530

function CodesPanel.Create(content: Frame, ctx)
	UIKit.IconCircle("🔑", Color3.fromRGB(0, 190, 240), 112, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Parent = content,
	})
	UIKit.Text({
		Text = "Entre un code pour recevoir des récompenses !",
		TextSize = 25,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 126),
		Size = UDim2.new(1, -20, 0, 34),
		Stroke = 3,
		Fit = true,
		Parent = content,
	})

	local box = UIKit.Input({
		PlaceholderText = "TON CODE ICI",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -97, 0, 178),
		Size = UDim2.fromOffset(400, 66),
		TextSize = 28,
		Parent = content,
	})

	local status = UIKit.Text({
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 258),
		Size = UDim2.new(1, -20, 0, 30),
		Stroke = 2.4,
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
		status.TextColor3 = if response.Ok then Theme.Money else Color3.fromRGB(255, 110, 110)
		if response.Ok then
			box.Text = ""
		end
	end

	UIKit.Button({
		Text = "✅ VALIDER",
		Color = "Green",
		TextSize = 23,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 207, 0, 175),
		Size = UDim2.fromOffset(180, 74),
		Radius = 14,
		Parent = content,
		OnClick = submit,
	})
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	local info =
		UIKit.Inset({ Position = UDim2.fromOffset(40, 304), Size = UDim2.new(1, -80, 0, 112), Parent = content })
	UIKit.Text({
		Text = "📣 De nouveaux codes à chaque mise à jour !",
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(1, -20, 0, 30),
		Stroke = 2.4,
		Fit = true,
		Parent = info,
	})
	UIKit.Body({
		Text = "Ajoute le jeu en favori ⭐ et rejoins le groupe pour ne rater aucun code ni aucun événement.",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 0, 44),
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
