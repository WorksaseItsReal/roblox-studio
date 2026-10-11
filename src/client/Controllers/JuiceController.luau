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
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Remotes = require(Shared.Modules.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local SoundController = require(script.Parent.SoundController)

local JuiceController = {}

local player = Players.LocalPlayer
local uiRoot: Frame? = nil
local State

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
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = INCOME_POP_RANGE
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font
	label.TextSize = 26
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Ink
	stroke.Thickness = 2.5
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
		task.delay(math.random() * 0.6, popNumber, item.Root, "+" .. Format.Money(amount), Theme.Money, hip + 2.5)
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
		local confettiColor = if i % 3 == 0 then color else CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
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
		local label = UIKit.Text({
			Text = text,
			TextSize = 64,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			Size = UDim2.fromOffset(900, 90),
			Stroke = 5,
			ZIndex = 51,
			Parent = layer,
		})
		UIKit.Gradient(label, Theme.Lighten(color, 0.6), color)
		UIKit.Pop(label, 0.2)
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
	local card = UIKit.New("Frame", {
		Name = "OfflinePopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(520, 300),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 60,
		Parent = root,
	})
	UIKit.Corner(card, 26)
	UIKit.Stroke(card, 4.5)
	UIKit.Gradient(card, Theme.PanelTop, Theme.PanelBottom)
	UIKit.IconCircle("💤", Theme.Gold, 96, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		ZIndex = 61,
		Parent = card,
	})
	UIKit.Text({
		Text = "BON RETOUR !",
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 44),
		Stroke = 3.5,
		ZIndex = 61,
		Parent = card,
	})
	UIKit.Body({
		Text = "Pendant ton absence (" .. Format.Time(seconds) .. "), tes créatures ont travaillé :",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 17,
		Position = UDim2.fromOffset(20, 104),
		Size = UDim2.new(1, -40, 0, 24),
		ZIndex = 61,
		Parent = card,
	})
	local amountLabel = UIKit.Text({
		Text = "+" .. Format.Money(amount),
		TextSize = 56,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, 66),
		Stroke = 4,
		ZIndex = 61,
		Parent = card,
	})
	UIKit.Gradient(amountLabel, Color3.fromRGB(230, 255, 220), Color3.fromRGB(90, 235, 90))
	UIKit.Button({
		Text = "💰 RÉCUPÉRER",
		Color = "Green",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(300, 68),
		ZIndex = 62,
		Parent = card,
		OnClick = function()
			celebrate(Theme.Money, nil)
			card:Destroy()
		end,
	})
	UIKit.Pop(card, 0.5)
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
