--[[
	PlotController
	==============
	Confort côté client pour les bases (le serveur revérifie toujours tout) :
	- rend la barrière de SA base traversable localement (le personnage est
	  simulé par le client, donc la collision locale suffit) ;
	- affiche "Voler" seulement sur les bases des autres (et pas si leur barrière
	  est active), "Gérer" / bouton de barrière / fusion seulement chez soi ;
	- met à jour le panneau au-dessus de chaque entrée (« Base de {nom} » en
	  Fredoka One, casse normale + pastille d'état : verrouillée avec le temps
	  restant, ou « Ta base ») et l'étiquette du bouton de verrouillage (prêt /
	  actif / recharge).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Format = require(game:GetService("ReplicatedStorage").Shared.Modules.Format)
local StateController = require(script.Parent.StateController)

local PlotController = {}

local player = Players.LocalPlayer

local function isMine(plot: Instance): boolean
	return plot:GetAttribute("OwnerUserId") == player.UserId
end

local function updatePrompt(prompt: ProximityPrompt, plot: Instance)
	local mine = isMine(plot)
	local hasOwner = (plot:GetAttribute("OwnerUserId") or 0) ~= 0
	if prompt.Name == "StealPrompt" then
		local carrying = StateController.Profile and StateController.Profile.Carrying ~= nil
		prompt.Enabled = hasOwner and not mine and not plot:GetAttribute("BarrierActive") and not carrying
	elseif prompt.Name == "ManagePrompt" or prompt.Name == "LockPrompt" or prompt.Name == "FusionPrompt" then
		prompt.Enabled = mine
	end
end

-- Étiquettes flottantes du bouton de verrouillage et du portail de fusion :
-- utiles seulement au propriétaire
local function refreshLabels(plot: Instance)
	for _, name in { "LockButton", "FusionPortal" } do
		local part = plot:FindFirstChild(name)
		local label = part and part:FindFirstChild("Label")
		if label and label:IsA("BillboardGui") then
			label.Enabled = isMine(plot)
		end
	end
end

local function refreshPlot(plot: Instance)
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			updatePrompt(descendant, plot)
		end
	end
	refreshLabels(plot)
	local barrier = plot:FindFirstChild("Barrier")
	if barrier and barrier:IsA("BasePart") and isMine(plot) then
		barrier.CanCollide = false
	end
end

local function setupPlot(plot: Instance)
	plot.AttributeChanged:Connect(function()
		refreshPlot(plot)
	end)
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			updatePrompt(descendant, plot)
		end
	end)
	local barrier = plot:FindFirstChild("Barrier")
	if barrier and barrier:IsA("BasePart") then
		-- Le serveur réactive la collision : on la recoupe localement chez soi
		barrier:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if barrier.CanCollide and isMine(plot) then
				barrier.CanCollide = false
			end
		end)
	end
	refreshPlot(plot)
end

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(201, 207, 219)
local DANGER = Color3.fromRGB(255, 77, 77)
-- Textes de la pastille d'état (fond encre) : rouge et or éclaircis pour rester lisibles
local DANGER_ON_INK = Color3.fromRGB(255, 120, 120)
local GOLD_ON_INK = Color3.fromRGB(255, 201, 60)
-- Titre seul (pleine hauteur) ou titre + pastille d'état en dessous
local TITLE_FULL = { UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.92, 0.76) }
local TITLE_TOP = { UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.92, 0.54) }

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function setText(label: TextLabel, text: string, color: Color3)
	if label.Text ~= text then
		label.Text = text
	end
	if label.TextColor3 ~= color then
		label.TextColor3 = color
	end
end

local function updateSign(plot: Instance, now: number)
	local sign = plot:FindFirstChild("Sign")
	if not sign then
		return
	end
	local ownerName = plot:GetAttribute("OwnerName") or ""
	-- Casse normale (docs/ART_DIRECTION.md) : le pseudo est affiché tel quel
	local titleText, titleColor = "Base de " .. ownerName, WHITE
	local statusText, statusColor = "", WHITE
	if ownerName == "" then
		titleText = "Base libre"
	elseif plot:GetAttribute("BarrierActive") then
		local left = numberAttribute(plot, "BarrierEndsAt", now) - now
		statusText, statusColor = "🔒 Verrouillée " .. Format.Time(left), DANGER_ON_INK
	elseif isMine(plot) then
		statusText, statusColor = "★ Ta base ★", GOLD_ON_INK
	end
	-- Le panneau peut avoir une face avant (SignGui) et une face arrière
	for _, gui in sign:GetChildren() do
		local title = gui:IsA("SurfaceGui") and gui:FindFirstChild("Text", true)
		if title and title:IsA("TextLabel") then
			local status = gui:FindFirstChild("Status", true)
			if status and status:IsA("TextLabel") then
				setText(title, titleText, titleColor)
				setText(status, statusText, statusColor)
				local layout = if statusText == "" then TITLE_FULL else TITLE_TOP
				title.Position = layout[1]
				title.Size = layout[2]
				-- La pastille (fond encre) n'apparaît que s'il y a un état à afficher
				local pill = status.Parent
				if pill and pill:IsA("GuiObject") and pill.Name == "StatusPill" then
					pill.Visible = statusText ~= ""
				end
			elseif statusText ~= "" then
				-- Panneau d'une map manuelle sans ligne d'état : l'état remplace le titre
				setText(title, statusText, statusColor)
			else
				setText(title, titleText, titleColor)
			end
		end
	end
end

local function updateLockLabel(plot: Instance, now: number)
	local button = plot:FindFirstChild("LockButton")
	local gui = button and button:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild("Text", true)
	if not label or not label:IsA("TextLabel") then
		return
	end
	if plot:GetAttribute("BarrierActive") then
		setText(label, "🔒 " .. Format.Time(numberAttribute(plot, "BarrierEndsAt", now) - now), DANGER)
		return
	end
	local cooldown = numberAttribute(plot, "BarrierCooldownEndsAt", 0) - now
	if cooldown > 0 then
		setText(label, "⏳ " .. Format.Time(cooldown), MUTED)
	else
		setText(label, "🔒 Verrouiller", WHITE)
	end
end

local function updateSigns(plots: Instance)
	local now = workspace:GetServerTimeNow()
	for _, plot in plots:GetChildren() do
		updateSign(plot, now)
		updateLockLabel(plot, now)
	end
end

function PlotController.Start()
	local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		setupPlot(plot)
	end
	plots.ChildAdded:Connect(setupPlot)

	-- Le fait de porter une créature change la visibilité des prompts "Voler"
	StateController.ProfileChanged:Connect(function()
		for _, plot in plots:GetChildren() do
			refreshPlot(plot)
		end
	end)

	-- Prompts gérés côté client : ouverture des panneaux
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "ManagePrompt" then
			local model = prompt:FindFirstAncestorOfClass("Model")
			StateController.OpenPanelRequested:Fire("Inventory", model and model:GetAttribute("Uid"))
		elseif prompt.Name == "FusionPrompt" then
			StateController.OpenPanelRequested:Fire("Fusion")
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			updateSigns(plots)
		end
	end)
end

return PlotController
