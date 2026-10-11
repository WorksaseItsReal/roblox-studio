--[[
	JuiceController
	===============
	Tout ce qui rend le jeu "satisfaisant" (purement visuel, côté client) :
	- chiffres "+$12" qui jaillissent de TES créatures (les nombres qui montent)
	- confettis + grand texte au centre lors des moments forts
	- secousse de caméra quand on se fait voler
	- éclair à l'écran
	- fenêtre "Bon retour !" avec les gains hors ligne
	Tout est limité (distance, nombre) pour rester fluide sur mobile.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local SoundController = require(script.Parent.SoundController)

local JuiceController = {}

local player = Players.LocalPlayer
local uiRoot: Frame? = nil
local State

-- Vert des chiffres "+$" dans le monde (un peu plus clair que l'argent du HUD : lisible
-- sur l'herbe comme sur le ciel, avec le contour encre)
local MONEY_POP = Color3.fromRGB(110, 236, 110)

local INCOME_POP_INTERVAL = 3
local INCOME_POP_RANGE = 90
local INCOME_POP_MAX = 14

---------------------------------------------------------------------------
-- Chiffres "+$" au-dessus de ses créatures
---------------------------------------------------------------------------
local function findMyCreaturesFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot:FindFirstChild("Creatures")
		end
	end
	return nil
end

local function popNumber(adornee: BasePart, text: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(190, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = INCOME_POP_RANGE
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	-- Même police que les revenus des étiquettes de créatures (Luckiest Guy, majuscules)
	label.Font = Theme.DisplayFont
	label.TextSize = 30
	label.TextColor3 = color
	label.Text = Format.Upper(text)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Ink
	stroke.Thickness = 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	gui.Parent = adornee

	local info = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, height + 4, 0) }):Play()
	TweenService
		:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
		:Play()
	TweenService
		:Create(stroke, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
		:Play()
	Debris:AddItem(gui, 1.4)
end

local function incomeWave()
	local profile = State.Profile
	local folder = findMyCreaturesFolder()
	local camera = workspace.CurrentCamera
	if not profile or not folder or not camera then
		return
	end
	-- Multiplicateur réel = revenu total / revenu de base (créatures en vol exclues)
	local stolen = {}
	for _, uid in profile.BeingStolen or {} do
		stolen[uid] = true
	end
	local base = Economy.GetBaseIncome(profile, stolen)
	if base <= 0 then
		return
	end
	local multiplier = (profile.IncomePerSecond or base) / base
	local byUid = {}
	for _, entry in profile.Creatures do
		byUid[entry.Uid] = entry
	end

	local candidates = {}
	local cameraPosition = camera.CFrame.Position
	for _, model in folder:GetChildren() do
		local root = model:IsA("Model") and model.PrimaryPart
		local entry = byUid[model.Name]
		if root and entry then
			local distance = (root.Position - cameraPosition).Magnitude
			if distance < INCOME_POP_RANGE then
				table.insert(candidates, { Root = root, Entry = entry, Distance = distance, Model = model })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	for i = 1, math.min(#candidates, INCOME_POP_MAX) do
		local item = candidates[i]
		local amount = Economy.GetCreatureIncome(item.Entry) * multiplier * INCOME_POP_INTERVAL
		local hip = item.Model:GetAttribute("HipHeight") or 2
		-- Décalage aléatoire pour que les chiffres ne sortent pas tous en même temps
		task.delay(math.random() * 0.6, popNumber, item.Root, "+" .. Format.Money(amount), MONEY_POP, hip + 2.5)
	end
	if #candidates > 0 then
		SoundController.Play("Coin", 0.15)
	end
end

---------------------------------------------------------------------------
-- Confettis + grand texte
---------------------------------------------------------------------------
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(190, 110, 255),
}

-- Deux couleurs quasi identiques (le serveur n'envoie que Color et Text)
local function sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.02 and math.abs(a.G - b.G) < 0.02 and math.abs(a.B - b.B) < 0.02
end

-- Dégradé du grand texte (et sa rotation) : arc-en-ciel pour une Secrète, dégradé
-- propre à la mutation s'il existe (Prismatique), sinon la couleur en version vive
local function celebrationGradient(color: Color3): (ColorSequence, number)
	local secret = Rarities.Get("Secret")
	if secret and sameColor(color, secret.Color) then
		return Widgets.Rainbow, 0
	end
	for _, mutation in Mutations.List do
		local gradient = Widgets.MutationGradient(mutation)
		if gradient and sameColor(color, mutation.Color) then
			-- Chaque couleur du dégradé en version franche (pas de pastel)
			local keypoints = {}
			for _, keypoint in gradient.Keypoints do
				table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, Theme.Vivid(keypoint.Value)))
			end
			return ColorSequence.new(keypoints), 0
		end
	end
	local vivid = Theme.Vivid(color)
	return ColorSequence.new(Theme.Lighten(vivid, 0.3), Theme.Darken(vivid, 0.08)), 90
end

local function celebrate(color: Color3, text: string?)
	local root = uiRoot
	if not root then
		return
	end
	local layer = UIKit.New("Frame", {
		Name = "Celebration",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	})
	for i = 1, 42 do
		local confettiColor = if i % 3 == 0
			then Theme.Vivid(color)
			else CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		local piece = UIKit.New("Frame", {
			BackgroundColor3 = confettiColor,
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Position = UDim2.new(math.random(), 0, 0, -30),
			Rotation = math.random(0, 360),
			ZIndex = 50,
			Parent = layer,
		})
		UIKit.Corner(piece, 3)
		local duration = 1.4 + math.random() * 1.2
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 40),
			Rotation = piece.Rotation + math.random(-360, 360),
		}):Play()
	end
	if text and text ~= "" then
		-- Gros texte penché aux couleurs de la rareté, contour encre épais (Luckiest Guy :
		-- réservée aux célébrations et à l'argent du HUD)
		local label = UIKit.Text({
			Text = text,
			Font = Theme.DisplayFont,
			TextSize = 78,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(980, 106),
			Rotation = -3,
			Stroke = 6,
			Fit = true,
			ZIndex = 51,
			Parent = layer,
		})
		-- Cadre ajusté au texte : un dégradé horizontal (arc-en-ciel) couvre tout le mot
		local ok, bounds =
			pcall(TextService.GetTextSize, TextService, label.Text, 78, Theme.DisplayFont, Vector2.new(4000, 200))
		if ok and typeof(bounds) == "Vector2" then
			label.Size = UDim2.fromOffset(math.min(980, math.ceil(bounds.X) + 28), 106)
		end
		local sequence, rotation = celebrationGradient(color)
		UIKit.New("UIGradient", { Color = sequence, Rotation = rotation, Parent = label })
		UIKit.Pop(label, 0.2)
		-- Puis le texte bat deux fois : c'est LE moment fort
		local scale = label:FindFirstChildOfClass("UIScale")
		task.delay(0.35, function()
			if scale and scale.Parent then
				TweenService:Create(
					scale,
					TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
					{ Scale = 1.08 }
				):Play()
			end
		end)
		task.delay(1.6, function()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
	end
	Debris:AddItem(layer, 3)
end

---------------------------------------------------------------------------
-- Secousse de caméra / éclair
---------------------------------------------------------------------------
local function shake(intensity: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed > 0.45 then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local power = intensity * (1 - elapsed / 0.45) * 0.6
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * power, (math.random() - 0.5) * power, 0)
	end)
end

local function flash(color: Color3)
	local root = uiRoot
	if not root then
		return
	end
	local frame = UIKit.New("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.4,
		Position = UDim2.fromOffset(-60, -120),
		Size = UDim2.new(1, 120, 1, 240),
		ZIndex = 49,
		Parent = root,
	})
	TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 0.6)
end

---------------------------------------------------------------------------
-- Fenêtre "Bon retour !" (gains hors ligne)
---------------------------------------------------------------------------
local function showOfflinePopup(amount: number, seconds: number)
	local root = uiRoot
	if not root then
		return
	end
	-- Fond assombri : la fenêtre est la seule chose à regarder
	local backdrop = UIKit.New("TextButton", {
		Name = "OfflineBackdrop",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.45,
		Position = UDim2.fromOffset(-60, -120),
		Size = UDim2.new(1, 120, 1, 240),
		ZIndex = 59,
		Parent = root,
	})
	local collected = false
	local popup
	local function collect()
		if collected then
			return
		end
		collected = true
		celebrate(Theme.Money, nil)
		backdrop:Destroy()
		popup.Instance:Destroy()
	end
	-- Même fenêtre que les panneaux : corps blanc, en-tête violet, bouton fermer
	popup = UIKit.Window({
		Name = "OfflinePopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 330),
		ZIndex = 60,
		Parent = root,
	}, { Title = "Bon retour !", Icon = "💤", OnClose = collect })
	local card = popup.Instance
	UIKit.Body({
		Text = "Pendant ton absence (" .. Format.Time(seconds) .. "), tes créatures ont travaillé :",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(32, 80),
		Size = UDim2.new(1, -64, 0, 44),
		ZIndex = 63,
		Parent = card,
	})
	-- Gros montant (célébration : Luckiest Guy) dans une carte claire
	local amountCard = UIKit.Card({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(400, 92),
		ZIndex = 63,
		Parent = card,
	}, Theme.Money, 0.6)
	local amountLabel = UIKit.Text({
		Text = "+" .. Format.Money(amount),
		Font = Theme.DisplayFont,
		TextSize = 60,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 1, -16),
		Stroke = 4,
		Fit = true,
		ZIndex = 64,
		Parent = amountCard,
	})
	UIKit.Gradient(amountLabel, Color3.fromRGB(160, 248, 140), Theme.Money)
	UIKit.Button({
		Text = "💰 Récupérer",
		Color = "Green",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(300, 58),
		Radius = 14,
		ZIndex = 63,
		Parent = card,
		OnClick = collect,
	})
	backdrop.Activated:Connect(collect)
	UIKit.Pop(card, 0.6)
end

---------------------------------------------------------------------------
function JuiceController.Start(ctx)
	State = ctx.State
	uiRoot = ctx.Root

	Remotes.GetEvent("Effect").OnClientEvent:Connect(function(effectType, payload)
		if type(payload) ~= "table" then
			return
		end
		if effectType == "Celebrate" then
			celebrate(if typeof(payload.Color) == "Color3" then payload.Color else Theme.Gold, payload.Text)
		elseif effectType == "Shake" then
			shake(tonumber(payload.Intensity) or 1)
			flash(Color3.fromRGB(255, 40, 60))
		elseif effectType == "StealAlert" then
			shake(0.7)
			flash(Color3.fromRGB(255, 40, 60))
		elseif effectType == "OfflineEarnings" then
			showOfflinePopup(tonumber(payload.Amount) or 0, tonumber(payload.Seconds) or 0)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(INCOME_POP_INTERVAL)
			local ok, err = pcall(incomeWave)
			if not ok then
				warn("[JuiceController] " .. tostring(err))
			end
		end
	end)
end

return JuiceController
