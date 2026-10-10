--[[
	PlotController
	==============
	Confort côté client pour les bases (le serveur revérifie toujours tout) :
	- rend la barrière de SA base traversable localement (le personnage est
	  simulé par le client, donc la collision locale suffit) ;
	- affiche "Voler" seulement sur les bases des autres (et pas si leur barrière
	  est active), "Gérer" / bouton de barrière / fusion seulement chez soi ;
	- met à jour le panneau au-dessus de chaque entrée (propriétaire + timer).
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

local function refreshPlot(plot: Instance)
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			updatePrompt(descendant, plot)
		end
	end
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

local function updateSigns(plots: Instance)
	local now = workspace:GetServerTimeNow()
	for _, plot in plots:GetChildren() do
		local sign = plot:FindFirstChild("Sign")
		local gui = sign and sign:FindFirstChild("SignGui")
		local label = gui and gui:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			local ownerName = plot:GetAttribute("OwnerName") or ""
			if ownerName == "" then
				label.Text = "Base libre"
				label.TextColor3 = Color3.fromRGB(200, 200, 210)
			elseif plot:GetAttribute("BarrierActive") then
				local left = (plot:GetAttribute("BarrierEndsAt") or now) - now
				label.Text = ownerName .. "  |  BARRIÈRE " .. Format.Time(left)
				label.TextColor3 = Color3.fromRGB(255, 120, 120)
			else
				label.Text = "Base de " .. ownerName
				label.TextColor3 = if isMine(plot) then Color3.fromRGB(120, 255, 150) else Color3.new(1, 1, 1)
			end
		end
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
