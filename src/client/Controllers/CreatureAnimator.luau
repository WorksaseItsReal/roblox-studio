--[[
	CreatureAnimator
	================
	Donne de la vie aux créatures posées dans les bases : léger rebond, petit
	balancement et "respiration". Purement local et limité aux créatures proches
	de la caméra (coût négligeable même avec 8 bases pleines).

	Le serveur place chaque modèle une seule fois et ne le déplace plus : on
	mémorise sa position de départ et on l'anime autour.
]]

local RunService = game:GetService("RunService")

local CreatureAnimator = {}

local ANIMATION_RADIUS = 110

type Entry = { Model: Model, Base: CFrame, Seed: number }

local entries: { [Model]: Entry } = {}

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	-- Attend que le modèle soit complet (PrimaryPart répliqué)
	task.defer(function()
		if model.Parent and model.PrimaryPart then
			entries[model] = { Model = model, Base = model:GetPivot(), Seed = math.random() * 10 }
		end
	end)
end

local function watchFolder(folder: Instance)
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(function(child)
		entries[child :: any] = nil
	end)
	for _, child in folder:GetChildren() do
		track(child)
	end
end

function CreatureAnimator.Start()
	local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		local folder = plot:WaitForChild("Creatures", 10)
		if folder then
			watchFolder(folder)
		end
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local t = os.clock()
		for model, entry in entries do
			if model.Parent == nil then
				entries[model] = nil
				continue
			end
			if (entry.Base.Position - cameraPosition).Magnitude < ANIMATION_RADIUS then
				local s = entry.Seed
				local bob = math.abs(math.sin(t * 2.2 + s)) * 0.35
				local sway = math.sin(t * 1.3 + s) * 0.08
				model:PivotTo(entry.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, math.sin(t * 2.2 + s) * 0.03))
			end
		end
	end)
end

return CreatureAnimator
