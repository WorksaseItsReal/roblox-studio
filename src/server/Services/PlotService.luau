--[[
	PlotService
	===========
	Attribution des bases et affichage des créatures dans les emplacements.

	- Un joueur reçoit la première base libre dès que son profil est chargé.
	- Chaque créature possédée est un Model dans Plot.Creatures, nommé par son Uid.
	- Chaque modèle porte 2 ProximityPrompts :
	    StealPrompt  -> traité par le SERVEUR (StealService), masqué côté client
	                    pour le propriétaire
	    ManagePrompt -> traité par le CLIENT (ouvre l'inventaire), masqué pour les autres
	  Le masquage client n'est que du confort : le serveur revérifie tout.
	- Socles : seuls ceux que le joueur a débloqués sont visibles (blancs, anneau
	  couleur d'équipe) ; les autres restent invisibles et traversables.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local CreatureVisuals = require(Shared.Modules.CreatureVisuals)
local Economy = require(Shared.Modules.Economy)

local PlotService = {}

local Services

type PlotRecord = any

local plotByPlayer: { [Player]: PlotRecord } = {}

local function getPlotColor(plot: PlotRecord): Color3
	local color = plot.Model:GetAttribute("PlotColor")
	return if typeof(color) == "Color3" then color else plot.Barrier.Color
end

-- Socle débloqué : blanc (Plastic), anneau fin couleur d'équipe (SmoothPlastic, pas
-- de néon). Verrouillé : INVISIBLE et traversable (docs/ART_DIRECTION.md : plus de
-- rangées de socles gris façon « parking ») ; il apparaît quand le joueur le débloque
local PAD_COLOR = Color3.fromRGB(248, 248, 250)
local function setSlotLook(slot: BasePart, unlocked: boolean, color: Color3)
	if unlocked then
		slot.Color = PAD_COLOR
		slot.Material = Enum.Material.Plastic
		slot.Transparency = 0
		-- CanQuery ne se règle que si CanCollide est faux : on le rétablit d'abord
		slot.CanQuery = true
		slot.CanCollide = true
	else
		slot.Transparency = 1
		slot.CanCollide = false
		slot.CanQuery = false
	end
	local ring = slot:FindFirstChild("SlotRing")
	if ring and ring:IsA("BasePart") then
		ring.Color = color
		ring.Material = Enum.Material.SmoothPlastic
		ring.Transparency = if unlocked then 0 else 1
	end
end
-- Exposé pour les aperçus de la map hors Roblox (aucun service requis)
PlotService.SetSlotLook = setSlotLook

-- Dessus d'un emplacement, orienté comme la base (face à l'entrée).
-- Fonctionne quelle que soit la forme du socle (bloc, cylindre couché...).
function PlotService.GetSlotTop(plot: PlotRecord, slotIndex: number): CFrame
	local slot = plot.Slots[slotIndex]
	local cf, size = slot.CFrame, slot.Size
	local halfHeight = (
		math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z
	) / 2
	return CFrame.new(slot.Position + Vector3.new(0, halfHeight, 0)) * plot.Floor.CFrame.Rotation
end

function PlotService.GetPlot(player: Player): PlotRecord?
	return plotByPlayer[player]
end

function PlotService.GetPlotById(id: number): PlotRecord?
	for _, plot in Services.MapService.GetPlots() do
		if plot.Id == id then
			return plot
		end
	end
	return nil
end

function PlotService.GetCreatureModel(player: Player, uid: string): Model?
	local plot = plotByPlayer[player]
	if not plot then
		return nil
	end
	local model = plot.CreaturesFolder:FindFirstChild(uid)
	return if model and model:IsA("Model") then model else nil
end

---------------------------------------------------------------------------
-- Modèles de créatures
---------------------------------------------------------------------------
local function findEntry(data, uid: string)
	for _, entry in data.Creatures do
		if entry.Uid == uid then
			return entry
		end
	end
	return nil
end

function PlotService.RemoveCreatureModel(player: Player, uid: string)
	local model = PlotService.GetCreatureModel(player, uid)
	if model then
		model:Destroy()
	end
end

-- Crée (ou recrée) le modèle d'une créature si elle est toujours possédée
function PlotService.AddCreatureModel(player: Player, uid: string)
	local plot = plotByPlayer[player]
	local data = Services.DataService.GetData(player)
	if not plot or not data then
		return
	end
	local entry = findEntry(data, uid)
	if not entry or not plot.Slots[entry.Slot] then
		return
	end
	-- En cours de vol : la créature est sur le dos du voleur, pas dans la base
	if Services.StealService.IsBeingCarried(player, uid) then
		return
	end
	-- En cours de trajet depuis le chemin : elle apparaîtra à son arrivée
	if Services.ShopService.IsWalking(player, uid) then
		return
	end

	PlotService.RemoveCreatureModel(player, uid)

	local def = Creatures.Get(entry.Id)
	if not def then
		return
	end
	local model = CreatureVisuals.Build(entry.Id, entry.Mutation, { Anchored = true, Billboard = true })
	model.Name = uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Slot", entry.Slot)

	local hipHeight = model:GetAttribute("HipHeight") or 2
	model:PivotTo(PlotService.GetSlotTop(plot, entry.Slot) * CFrame.new(0, hipHeight, 0))

	local root = model.PrimaryPart :: BasePart
	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Voler"
	steal.ObjectText = def.Name
	steal.HoldDuration = GameConfig.Steal.HoldDuration
	steal.MaxActivationDistance = 10
	steal.RequiresLineOfSight = false
	steal.KeyboardKeyCode = Enum.KeyCode.E
	steal.Parent = root

	local manage = Instance.new("ProximityPrompt")
	manage.Name = "ManagePrompt"
	manage.ActionText = "Gérer"
	manage.ObjectText = def.Name
	manage.HoldDuration = 0
	manage.MaxActivationDistance = 10
	manage.RequiresLineOfSight = false
	manage.KeyboardKeyCode = Enum.KeyCode.F
	manage.Parent = root

	steal.Triggered:Connect(function(thief: Player)
		Services.StealService.TryStartSteal(thief, plot, uid)
	end)

	model.Parent = plot.CreaturesFolder
end

-- Reconstruit toute la base du joueur depuis ses données
function PlotService.RenderAll(player: Player)
	local plot = plotByPlayer[player]
	local data = Services.DataService.GetData(player)
	if not plot or not data then
		return
	end
	plot.CreaturesFolder:ClearAllChildren()
	for _, entry in data.Creatures do
		PlotService.AddCreatureModel(player, entry.Uid)
	end
	PlotService.RefreshSlotPads(player)
end

-- Montre les emplacements débloqués, cache les autres. Un emplacement occupé reste
-- toujours visible, même au-delà du maximum (pass « Emplacements VIP » retiré,
-- emplacement réattribué par la réparation des données) : sinon la créature
-- flotterait au-dessus d'un socle invisible
function PlotService.RefreshSlotPads(player: Player)
	local plot = plotByPlayer[player]
	local data = Services.DataService.GetData(player)
	if not plot or not data then
		return
	end
	local maxSlots = Economy.GetMaxSlots(data, Services.MonetizationService.GetPasses(player))
	local occupied: { [number]: boolean } = {}
	for _, entry in data.Creatures do
		if type(entry.Slot) == "number" then
			occupied[entry.Slot] = true
		end
	end
	local color = getPlotColor(plot)
	for index, slot in plot.Slots do
		setSlotLook(slot, index <= maxSlots or occupied[index] == true, color)
	end
end

---------------------------------------------------------------------------
-- Attribution
---------------------------------------------------------------------------
local function resetPlotVisuals(plot: PlotRecord)
	plot.CreaturesFolder:ClearAllChildren()
	for _, slot in plot.Slots do
		setSlotLook(slot, false, getPlotColor(plot))
	end
end

local function assignPlot(player: Player)
	for _, plot in Services.MapService.GetPlots() do
		if plot.Owner == nil then
			plot.Owner = player
			plotByPlayer[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.Model:SetAttribute("OwnerName", player.DisplayName)
			player:SetAttribute("PlotId", plot.Id)
			PlotService.RenderAll(player)
			Services.CharacterService.TeleportToPlot(player)
			return
		end
	end
	player:Kick("Serveur plein : aucune base disponible. Rejoins un autre serveur !")
end

local function releasePlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Model:SetAttribute("OwnerName", "")
	Services.BaseDefenseService.ResetPlot(plot)
	resetPlotVisuals(plot)
end

function PlotService.Init(services)
	Services = services
end

function PlotService.Start()
	Services.DataService.ProfileLoaded:Connect(function(player: Player)
		assignPlot(player)
	end)
	Services.DataService.ProfileReleasing:Connect(function(player: Player)
		releasePlot(player)
	end)
	-- Filet de sécurité si le profil n'a jamais chargé
	Players.PlayerRemoving:Connect(function(player: Player)
		if plotByPlayer[player] then
			releasePlot(player)
		end
	end)
	for _, plot in Services.MapService.GetPlots() do
		resetPlotVisuals(plot)
	end
end

return PlotService
