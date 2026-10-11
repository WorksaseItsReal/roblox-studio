--[[
	CreatureAnimator
	================
	Donne de la vie aux créatures, purement en local et seulement près de la caméra
	(coût négligeable même avec 8 bases pleines) :
	- créatures des bases : petit sautillement + balancement (ou flottement doux pour
	  celles qui planent, attribut "Floating")
	- pièces "Orbit" (étincelles des Secrètes, cristaux du Zéro Absolu) : tournent autour
	- pièces avec l'attribut "Rainbow" (Secret, mutation Prismatique) : teinte qui tourne
	  lentement (un cycle en ~12 s : vivant, jamais criard ni clignotant)
	- clignement des yeux (pièces "Eye" / "Pupil" écrasées, reflets "Shine" masqués :
	  ce sont des boules, Roblox les garde rondes)
	- étiquettes des bases (BillboardGui "Info") : de loin, seules la rareté et le revenu
	  restent affichés (lignes "Name" et "Mutation" masquées) ; un voleur repère les
	  bonnes prises depuis le trottoir sans mur de texte

	Seules les pièces visuelles bougent : Root, et donc l'étiquette et les
	ProximityPrompts qui y sont attachés, reste immobile (le texte ne tremble pas).
	Toutes les pièces sont déplacées en un seul appel workspace:BulkMoveTo, et rien n'est
	animé derrière la caméra.

	Le serveur place chaque créature d'une base une seule fois : la pose de repos de
	chaque pièce est mémorisée relativement à Root. Les créatures du chemin
	(Map.Movers) sont déplacées par ConveyorController : on n'y anime que les
	couleurs et les yeux.
]]

local RunService = game:GetService("RunService")

local CreatureAnimator = {}

local ANIMATION_RADIUS = 85 -- au-delà : rien n'est animé
local HALF_RATE_RADIUS = 35 -- au-delà : une image sur deux
local DETAIL_RADIUS = 55 -- clignements et couleurs animées
local BEHIND_CAMERA = -10 -- studs derrière le plan de la caméra : pas d'animation
-- Étiquette complète en deçà de LABEL_NEAR, rareté + revenu seulement au-delà de LABEL_FAR
-- (entre les deux : inchangée). Assez court pour que, dans une base pleine, les noms des
-- rangées du fond ne se chevauchent pas : de loin on lit d'abord la rareté et le revenu
local LABEL_NEAR = 30
local LABEL_FAR = 34
local ORBIT_SPEED = 0.9 -- radians par seconde
local RAINBOW_SPEED = 0.08 -- tours de roue chromatique par seconde
local BLINK_DURATION = 0.13

local SQUASH_PARTS = { Eye = true, Pupil = true }
local LABEL_DETAILS = { "Name", "Mutation" } -- lignes masquées de loin

type PartInfo = { Part: BasePart, Offset: CFrame, Orbit: boolean }
type EyeInfo = { Part: BasePart, Size: Vector3 }
type RainbowInfo = { Part: BasePart, Hue: number, Saturation: number, Value: number }
type Entry = {
	Model: Model,
	Root: BasePart,
	Moving: boolean, -- créature du chemin : ConveyorController la déplace
	Parts: { [BasePart]: PartInfo },
	Eyes: { [BasePart]: EyeInfo },
	Shines: { [BasePart]: boolean },
	Rainbow: { [BasePart]: RainbowInfo },
	Seed: number,
	Bounce: number, -- amplitude du sautillement (studs)
	Floating: boolean,
	NextBlink: number,
	BlinkEnd: number?,
	Info: BillboardGui?, -- étiquette (créatures des bases seulement)
	Near: boolean?, -- état d'affichage actuel de l'étiquette (nil : à appliquer)
	Connections: { RBXScriptConnection },
}

local entries: { [Model]: Entry } = {}
local frame = 0

-- Enregistre une pièce (sa pose actuelle est la pose de repos répliquée par le serveur)
local function addPart(entry: Entry, part: Instance)
	if part:IsA("BillboardGui") and part.Name == "Info" and not entry.Moving then
		entry.Info = part
		entry.Near = nil
		return
	end
	if not part:IsA("BasePart") or part == entry.Root then
		return
	end
	-- L'anneau de rareté reste posé sur le socle (il ne suit pas le corps)
	if not entry.Moving and part.Name ~= "RarityDisc" then
		entry.Parts[part] = {
			Part = part,
			Offset = entry.Root.CFrame:ToObjectSpace(part.CFrame),
			Orbit = part.Name == "Orbit",
		}
	end
	if SQUASH_PARTS[part.Name] then
		entry.Eyes[part] = { Part = part, Size = part.Size }
	elseif part.Name == "Shine" then
		entry.Shines[part] = true
	end
	if part:GetAttribute("Rainbow") ~= nil then
		local hue, saturation, value = part.Color:ToHSV()
		entry.Rainbow[part] = { Part = part, Hue = hue, Saturation = saturation, Value = value }
	end
end

local function removePart(entry: Entry, part: Instance)
	if part == entry.Info then
		entry.Info = nil
		return
	end
	local basePart = part :: BasePart
	entry.Parts[basePart] = nil
	entry.Eyes[basePart] = nil
	entry.Shines[basePart] = nil
	entry.Rainbow[basePart] = nil
end

local function untrack(model: Instance)
	local entry = entries[model :: Model]
	if entry then
		for _, connection in entry.Connections do
			connection:Disconnect()
		end
		entries[model :: Model] = nil
	end
end

local function track(model: Instance, moving: boolean)
	if not model:IsA("Model") or entries[model] then
		return
	end
	-- Attend que le modèle soit complet (PrimaryPart répliqué)
	task.defer(function()
		local root = model.PrimaryPart
		if not model.Parent or not root or entries[model] or model:GetAttribute("CreatureId") == nil then
			return
		end
		local hip = model:GetAttribute("HipHeight") or 2
		local entry: Entry = {
			Model = model,
			Root = root,
			Moving = moving,
			Parts = {},
			Eyes = {},
			Shines = {},
			Rainbow = {},
			Seed = math.random() * 10,
			Bounce = 0.16 * hip ^ 0.6,
			Floating = model:GetAttribute("Floating") == true,
			NextBlink = os.clock() + 1 + math.random() * 4,
			Connections = {},
		}
		for _, descendant in model:GetDescendants() do
			addPart(entry, descendant)
		end
		-- Pièces arrivées après coup (streaming) : ajoutées avec leur pose de repos
		table.insert(
			entry.Connections,
			model.DescendantAdded:Connect(function(descendant)
				addPart(entry, descendant)
			end)
		)
		table.insert(
			entry.Connections,
			model.DescendantRemoving:Connect(function(descendant)
				removePart(entry, descendant)
			end)
		)
		entries[model] = entry
	end)
end

local function watchFolder(folder: Instance, moving: boolean)
	folder.ChildAdded:Connect(function(child)
		track(child, moving)
	end)
	folder.ChildRemoved:Connect(untrack)
	for _, child in folder:GetChildren() do
		track(child, moving)
	end
end

-- Pose du corps (relative à Root) : sautillement ou flottement, balancement
local function bodyPose(entry: Entry, t: number): CFrame
	local s = entry.Seed
	if entry.Floating then
		-- Toujours au-dessus de la pose de repos : rien ne s'enfonce dans le socle
		local hover = (math.sin(t * 1.7 + s) * 0.5 + 0.5) * entry.Bounce * 0.9
		return CFrame.new(0, hover, 0) * CFrame.Angles(math.sin(t * 1.1 + s) * 0.05, math.sin(t * 0.8 + s) * 0.1, 0)
	end
	local step = math.sin(t * 2.4 + s)
	local hop = math.abs(step) * entry.Bounce
	return CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(t * 1.3 + s) * 0.08, step * 0.035)
end

local function setBlink(entry: Entry, closed: boolean)
	for part, info in entry.Eyes do
		part.Size = if closed then Vector3.new(info.Size.X, info.Size.Y * 0.12, info.Size.Z) else info.Size
	end
	for part in entry.Shines do
		part.Transparency = if closed then 1 else 0
	end
end

local function updateBlink(entry: Entry, t: number)
	if entry.BlinkEnd then
		if t >= entry.BlinkEnd then
			setBlink(entry, false)
			entry.BlinkEnd = nil
			entry.NextBlink = t + 2.5 + math.random() * 3.5
		end
	elseif t >= entry.NextBlink then
		setBlink(entry, true)
		entry.BlinkEnd = t + BLINK_DURATION
	end
end

-- Étiquette complète de près, rareté + revenu de loin (hystérésis : pas de clignotement)
local function updateLabel(entry: Entry, distance: number)
	local info = entry.Info
	if not info then
		return
	end
	local near = entry.Near
	if near == nil then
		near = distance < (LABEL_NEAR + LABEL_FAR) / 2
	elseif near and distance > LABEL_FAR then
		near = false
	elseif not near and distance < LABEL_NEAR then
		near = true
	end
	if near ~= entry.Near then
		entry.Near = near
		for _, name in LABEL_DETAILS do
			local line = info:FindFirstChild(name)
			if line and line:IsA("GuiObject") then
				line.Visible = near
			end
		end
	end
end

function CreatureAnimator.Start()
	local map = workspace:WaitForChild("Map")
	local plots = map:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		task.spawn(function()
			local folder = plot:WaitForChild("Creatures", 10)
			if folder then
				watchFolder(folder, false)
			end
		end)
	end
	task.spawn(function()
		local movers = map:WaitForChild("Movers", 15)
		if movers then
			watchFolder(movers, true)
		end
	end)

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		frame += 1
		table.clear(parts)
		table.clear(cframes)
		local cameraCFrame = camera.CFrame
		local cameraPosition = cameraCFrame.Position
		local look = cameraCFrame.LookVector
		local t = os.clock()
		for model, entry in entries do
			if model.Parent == nil or entry.Root.Parent == nil then
				untrack(model)
				continue
			end
			local rootCFrame = entry.Root.CFrame
			local offset = rootCFrame.Position - cameraPosition
			local distance = offset.Magnitude
			updateLabel(entry, distance)
			-- Un clignement commencé se termine toujours (même si la caméra s'éloigne)
			if entry.BlinkEnd or distance < DETAIL_RADIUS then
				updateBlink(entry, t)
			end
			if distance > ANIMATION_RADIUS or offset:Dot(look) < BEHIND_CAMERA then
				continue
			end
			if distance < DETAIL_RADIUS then
				for part, info in entry.Rainbow do
					part.Color = Color3.fromHSV((info.Hue + t * RAINBOW_SPEED) % 1, info.Saturation, info.Value)
				end
			end
			if entry.Moving or (distance > HALF_RATE_RADIUS and (frame + math.floor(entry.Seed * 10)) % 2 == 1) then
				continue
			end
			local body = rootCFrame * bodyPose(entry, t)
			local orbit = rootCFrame * CFrame.Angles(0, t * ORBIT_SPEED + entry.Seed, 0)
			for part, info in entry.Parts do
				table.insert(parts, part)
				table.insert(cframes, (if info.Orbit then orbit else body) * info.Offset)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return CreatureAnimator
