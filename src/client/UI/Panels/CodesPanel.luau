--[[
	CodesPanel : saisie des codes promotionnels (validés uniquement par le serveur).
]]

local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local CodesPanel = {}
CodesPanel.Title = "Codes"
CodesPanel.Icon = "🔑"
CodesPanel.Color = "Cyan"

function CodesPanel.Create(content: Frame, ctx)
	UIKit.IconCircle("🔑", Color3.fromRGB(40, 190, 230), 110, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Parent = content,
	})
	UIKit.Text({
		Text = "Entre un code pour recevoir des récompenses !",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = content,
	})

	local box = UIKit.Input({
		PlaceholderText = "TON CODE ICI",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -95, 0, 176),
		Size = UDim2.fromOffset(400, 64),
		TextSize = 28,
		Parent = content,
	})

	local status = UIKit.Text({
		Text = "",
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 256),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = content,
	})

	local function submit()
		local code = box.Text
		if code == "" then
			return
		end
		local response = ctx.Net.Request("RedeemCode", code)
		status.Text = response.Message or ""
		status.TextColor3 = if response.Ok then Theme.Money else Color3.fromRGB(255, 140, 140)
		if response.Ok then
			box.Text = ""
		end
	end

	UIKit.Button({
		Text = "✔ VALIDER",
		Color = "Green",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 215, 0, 172),
		Size = UDim2.fromOffset(170, 70),
		Parent = content,
		OnClick = submit,
	})
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	local info =
		UIKit.Inset({ Position = UDim2.fromOffset(40, 300), Size = UDim2.new(1, -80, 0, 110), Parent = content })
	UIKit.Text({
		Text = "📣 De nouveaux codes à chaque mise à jour !",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(1, -20, 0, 28),
		Parent = info,
	})
	UIKit.Body({
		Text = "Ajoute le jeu en favori ⭐ et rejoins le groupe pour ne rater aucun code ni aucun événement.",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		Position = UDim2.fromOffset(20, 50),
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
