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

local HUD = require(script.Parent.Parent.UI.HUD)
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
	-- Carte blanche en haut, sous la pilule d'événement : le bas de l'écran reste libre
	-- pour le bandeau de vol, la vengeance et la barrière (utilisés pendant le tutoriel).
	-- Assez étroite pour ne jamais toucher le fil d'actualité (en haut à droite).
	local card = UIKit.New("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 15,
		Parent = root,
	})
	UIKit.Corner(card, 16)
	UIKit.Stroke(card, 3)
	UIKit.Padding(card, 14, 18, 16, 16)
	UIKit.IconCircle("🧭", Theme.Brand, 52, { Parent = card })
	local column = UIKit.New("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.new(1, -66, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	UIKit.List(column, Enum.FillDirection.Vertical, 4)
	-- Étape (violet de marque) + « Passer » discret
	local header = UIKit.New("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
		Parent = column,
	})
	local stepLabel = UIKit.Label({
		Name = "Step",
		Text = "Tutoriel",
		TextSize = 15,
		TextColor3 = Theme.Brand,
		TextWrapped = false,
		Size = UDim2.new(1, -90, 1, 0),
		Parent = header,
	})
	local skipButton = UIKit.New("TextButton", {
		Name = "Skip",
		Text = "Passer",
		Font = Theme.Font,
		TextSize = 15,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Parent = header,
	})
	local textLabel = UIKit.Label({
		Name = "Text",
		Text = "",
		TextSize = 17,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = column,
	})
	-- Bouton « Suivant » sous le texte, à droite (seulement pour les étapes qui en ont un)
	local actions = UIKit.New("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 3,
		Parent = column,
	})
	local nextButton

	-- Mise en évidence du bouton de barrière : anneau doré autour du vrai bouton
	local highlight = UIKit.New("Frame", {
		Name = "BarrierHighlight",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 18, 1, 18),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 8,
	})
	UIKit.Corner(highlight, 20)
	UIKit.Stroke(highlight, 4, Theme.Gold)
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
		HUD.SetBarrierHint(false)
		targetPart:Destroy()
		characterConnection:Disconnect()
		if playerAttachment then
			playerAttachment:Destroy()
		end
	end

	local function showStep()
		local step = steps[index]
		stepStarted = os.clock()
		stepLabel.Text = string.format("Tutoriel · %d / %d", index, #steps)
		textLabel.Text = step.Text
		actions.Visible = step.Button ~= nil
		if step.Button then
			nextButton:SetText(step.Button)
		end
		-- Étape de la barrière : le HUD affiche le bouton même hors de la base
		local barrier = HUD.SetBarrierHint(step.HighlightBarrier == true)
		highlight.Parent = if step.HighlightBarrier then barrier else nil
		highlight.Visible = step.HighlightBarrier == true
		UIKit.Pop(card, 0.9)
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
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(170, 44),
		Parent = actions,
		OnClick = advance,
	})
	skipButton.Activated:Connect(function()
		if UIKit.OnClick then
			UIKit.OnClick()
		end
		ctx.Net.Invoke("CompleteTutorial", "Skip")
		cleanup()
	end)

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
	TweenService:Create(card, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.5, 0, 0, 56),
	}):Play()
end

return TutorialController
