--[[
	TutorialController
	==================
	Tutoriel des premières minutes (le moment qui décide si un joueur reste) :
	  1. Acheter une créature sur le tapis   (flèche vers la créature la plus proche)
	  2. Aller voir sa base                  (flèche vers sa base)
	  3. Comprendre la barrière              (le bouton est mis en évidence)
	  4. Comprendre le vol                   (flèche vers la base d'un adversaire)
	Une flèche lumineuse (Beam) relie le joueur à la cible ; une bulle explique.
	La fin est validée par le serveur (TutorialService) qui donne la récompense.
	Les joueurs expérimentés (3 achats ou plus) le passent automatiquement.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local TutorialController = {}

local player = Players.LocalPlayer

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function actionText(): string
	return if isTouchOnly() then "touche le bouton qui apparaît" else "appuie sur [E]"
end

local function getMap(): Instance?
	return workspace:FindFirstChild("Map")
end

local function myPlot(): Instance?
	local map = getMap()
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Argent du joueur (branché dans Start)
local getMoney: () -> number = function()
	return math.huge
end

-- Créature du tapis la plus proche que le joueur peut s'offrir
-- (sinon la plus proche tout court : il en passera une abordable bientôt)
local function nearestConveyorCreature(): Vector3?
	local map = getMap()
	local movers = map and map:FindFirstChild("Movers")
	local position = rootPosition()
	if not movers or not position then
		return nil
	end
	local money = getMoney()
	local best, bestDistance = nil, math.huge
	local fallback, fallbackDistance = nil, math.huge
	for _, model in movers:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("MoverType") == "Conveyor" and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - position).Magnitude
			local price = model:GetAttribute("Price")
			if type(price) == "number" and price <= money then
				if distance < bestDistance then
					best, bestDistance = model.PrimaryPart.Position, distance
				end
			elseif distance < fallbackDistance then
				fallback, fallbackDistance = model.PrimaryPart.Position, distance
			end
		end
	end
	return best or fallback
end

local function myPlotPosition(): Vector3?
	local plot = myPlot()
	local spawn = plot and plot:FindFirstChild("Spawn")
	return if spawn and spawn:IsA("BasePart") then spawn.Position else nil
end

-- Entrée de la base adverse la plus proche
local function enemyPlotPosition(): Vector3?
	local map = getMap()
	local plots = map and map:FindFirstChild("Plots")
	local position = rootPosition()
	if not plots or not position then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, plot in plots:GetChildren() do
		local owner = plot:GetAttribute("OwnerUserId")
		local entrance = plot:FindFirstChild("Entrance")
		if owner and owner ~= 0 and owner ~= player.UserId and entrance and entrance:IsA("BasePart") then
			local distance = (entrance.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = entrance.Position, distance
			end
		end
	end
	return best
end

function TutorialController.Start(ctx)
	local State = ctx.State
	getMoney = State.GetMoney

	-- Attend le premier instantané du profil
	while not State.Profile do
		task.wait(0.5)
	end
	local profile = State.Profile
	if profile.TutorialDone then
		return
	end
	if profile.Stats.Bought >= 3 then
		-- Joueur déjà lancé : tutoriel validé d'office, récompense affichée (toast)
		ctx.Net.Request("CompleteTutorial", "Done")
		return
	end

	local steps = {
		{
			Text = "Les créatures sortent de la Rift ! Approche-toi du tapis et "
				.. actionText()
				.. " pour en acheter une.",
			Target = nearestConveyorCreature,
			Done = function(p)
				return p.Stats.Bought >= 1
			end,
		},
		{
			Text = "Bravo ! Elle part dans TA base et te rapporte de l'argent chaque seconde. Va la voir !",
			Target = myPlotPosition,
			Done = function()
				local position, target = rootPosition(), myPlotPosition()
				return position ~= nil and target ~= nil and (position - target).Magnitude < 35
			end,
			Timeout = 30,
		},
		{
			Text = "Attention, les autres joueurs peuvent te VOLER ! Active ta barrière (bouton rouge) quand un voleur approche.",
			HighlightBarrier = true,
			Button = "Compris !",
		},
		{
			Text = "À toi de jouer : entre dans une base adverse, "
				.. actionText()
				.. " longtemps sur une créature et ramène-la chez toi !",
			Target = enemyPlotPosition,
			Button = "C'est parti ! 🎁",
			Final = true,
		},
	}

	---------------------------------------------------------------- Interface
	local root = ctx.Root
	-- En haut, sous le bandeau de dimension : le bas de l'écran reste libre pour
	-- le bandeau de vol, la vengeance et la barrière (utilisés pendant le tutoriel)
	local plate = UIKit.Plate({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(690, 116),
		ZIndex = 15,
		StrokeThickness = 4,
		Parent = root,
	}, "Blue", 6, 20)
	local card = plate.Instance
	local face = plate.Face
	UIKit.IconCircle("🧭", Theme.Gold, 84, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -18, 0.5, 0),
		ZIndex = 19,
		Parent = card,
	})
	-- Ruban "TUTORIEL x / y" à cheval sur le bord haut
	local stepPill = UIKit.Pill("TUTORIEL", Color3.fromRGB(255, 176, 0), {
		Name = "Step",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(84, 0),
		Size = UDim2.fromOffset(0, 28),
		TextSize = 16,
		ZIndex = 19,
		Parent = card,
	})
	local stepLabel = stepPill:FindFirstChild("Text") :: TextLabel
	stepLabel.ZIndex = 20
	local textLabel = UIKit.Body({
		Text = "",
		TextSize = 19,
		TextColor3 = Theme.Text,
		TextYAlignment = Enum.TextYAlignment.Center,
		Position = UDim2.fromOffset(84, 16),
		Size = UDim2.new(1, -278, 1, -24),
		Stroke = 1.8,
		ZIndex = 17,
		Parent = face,
	})
	local nextButton
	local skipButton

	-- Mise en évidence du bouton de barrière
	local highlight = UIKit.New("Frame", {
		Name = "BarrierHighlight",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.fromOffset(400, 92),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 14,
		Parent = root,
	})
	UIKit.Corner(highlight, 22)
	UIKit.Stroke(highlight, 6, Theme.Gold)
	local highlightScale = UIKit.New("UIScale", { Parent = highlight })

	---------------------------------------------------------------- Flèche dans le monde
	local targetPart = Instance.new("Part")
	targetPart.Name = "TutorialTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = workspace
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(90, 90)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Parent = targetPart
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Theme.Font
	arrow.TextScaled = true
	arrow.Text = "⬇️"
	arrow.Parent = marker

	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 140, 40))
	beam.LightEmission = 1
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Segments = 12
	beam.CurveSize0 = 6
	beam.CurveSize1 = -6
	beam.Transparency = NumberSequence.new(0.15)
	beam.Attachment1 = targetAttachment
	beam.Parent = targetPart

	local playerAttachment: Attachment? = nil
	local function attachToCharacter()
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local attachment = hrp:FindFirstChild("TutorialAttachment") or Instance.new("Attachment")
			attachment.Name = "TutorialAttachment"
			attachment.Parent = hrp
			playerAttachment = attachment :: Attachment
			beam.Attachment0 = playerAttachment
		end
	end
	attachToCharacter()
	local characterConnection = player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		attachToCharacter()
	end)

	---------------------------------------------------------------- Déroulement
	local index = 1
	local stepStarted = os.clock()
	local finished = false
	local heartbeatConnection: RBXScriptConnection? = nil

	local function cleanup()
		finished = true
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
		end
		card:Destroy()
		highlight:Destroy()
		targetPart:Destroy()
		characterConnection:Disconnect()
		if playerAttachment then
			playerAttachment:Destroy()
		end
	end

	local function showStep()
		local step = steps[index]
		stepStarted = os.clock()
		stepLabel.Text = string.format("TUTORIEL • %d / %d", index, #steps)
		textLabel.Text = step.Text
		-- Sans bouton "Suivant", le texte prend la place libérée
		textLabel.Size = UDim2.new(1, if step.Button then -278 else -206, 1, -24)
		highlight.Visible = step.HighlightBarrier == true
		nextButton.Instance.Visible = step.Button ~= nil
		if step.Button then
			nextButton:SetText(step.Button)
		end
		UIKit.Pop(card, 0.85)
	end

	local function advance()
		local step = steps[index]
		if step.Final then
			ctx.Net.Request("CompleteTutorial", "Done")
			cleanup()
			return
		end
		index += 1
		showStep()
	end

	nextButton = UIKit.Button({
		Text = "Suivant",
		Color = "Green",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(170, 54),
		ZIndex = 18,
		Parent = face,
		OnClick = advance,
	})
	skipButton = UIKit.Button({
		Text = "Passer",
		Color = "Dark",
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -8),
		Size = UDim2.fromOffset(100, 34),
		Radius = 10,
		ZIndex = 18,
		Parent = face,
		OnClick = function()
			ctx.Net.Invoke("CompleteTutorial", "Skip")
			cleanup()
		end,
	})
	local _ = skipButton

	showStep()

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if finished then
			return
		end
		local step = steps[index]
		-- Cible de la flèche
		local target = step.Target and step.Target()
		if target then
			targetPart.Position = target
			beam.Enabled = playerAttachment ~= nil
			marker.Enabled = true
			marker.StudsOffsetWorldSpace = Vector3.new(0, 6 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
		else
			beam.Enabled = false
			marker.Enabled = false
		end
		if step.HighlightBarrier then
			highlightScale.Scale = 1 + math.abs(math.sin(os.clock() * 4)) * 0.05
		end
		-- Étape terminée ?
		local currentProfile = State.Profile
		local done = step.Done and currentProfile and step.Done(currentProfile)
		local timedOut = step.Timeout and os.clock() - stepStarted > step.Timeout
		if done or timedOut then
			advance()
		end
	end)

	-- Petite animation d'attention sur la carte
	TweenService:Create(card, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.5, 0, 0, 174),
	}):Play()
end

return TutorialController
