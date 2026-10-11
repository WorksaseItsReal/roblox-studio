--[[
	ShopService
	===========
	Achat d'une créature sur le chemin et revente.

	Achat (RemoteFunction "BuyCreature", argument : SpawnId) — tout est vérifié
	par le serveur, rien n'est lu depuis le client à part l'identifiant :
	  1. la créature existe encore sur le chemin
	  2. le joueur est vivant et PROCHE de la position calculée par le serveur
	  3. il a un emplacement libre
	  4. il a l'argent (débit + retrait du chemin sans aucune attente = atomique :
	     deux joueurs ne peuvent pas acheter la même créature)
	Ensuite la créature "marche" jusqu'à la base (animation client), puis apparaît
	dans son emplacement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local PathMath = require(Shared.Modules.PathMath)
local CreatureVisuals = require(Shared.Modules.CreatureVisuals)
local Guard = require(script.Parent.Parent.Lib.Guard)

local ShopService = {}

local Services

-- Créatures en chemin vers la base : walking[player][uid] = Model
local walking: { [Player]: { [string]: Model } } = {}

function ShopService.IsWalking(player: Player, uid: string): boolean
	local list = walking[player]
	return list ~= nil and list[uid] ~= nil
end

-- Projection horizontale d'un point sur le chemin principal : distance parcourue
-- jusqu'au point projeté, point projeté et direction du segment
local function projectOnPath(path: PathMath.Path, position: Vector3): (number, Vector3, Vector3)
	local points = path.Points
	local bestGap, bestAlong, bestPoint, bestDirection = math.huge, 0, points[1], Vector3.zAxis
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = segment.Magnitude
		if length > 1e-3 then
			local direction = segment / length
			local t = math.clamp(Vector3.new(position.X - a.X, 0, position.Z - a.Z):Dot(direction), 0, length)
			local projected = a + direction * t
			local gap = Vector3.new(position.X - projected.X, 0, position.Z - projected.Z).Magnitude
			if gap < bestGap then
				bestGap, bestAlong, bestPoint, bestDirection = gap, path.Cumulative[i] + t, projected, direction
			end
		end
	end
	return bestAlong, bestPoint, bestDirection
end

-- Perpendiculaire horizontale à une direction (côté "gauche" du sens de marche)
local function lateralOf(direction: Vector3): Vector3
	local normal = Vector3.new(-direction.Z, 0, direction.X)
	return if normal.Magnitude > 1e-3 then normal.Unit else Vector3.xAxis
end

-- Trajet d'une créature achetée, sans traverser de mur ni d'autre base :
--   tapis -> trottoir du côté de sa base -> le long du trottoir (parallèle au
--   chemin) -> devant l'entrée -> allée de la base -> emplacement.
-- Marche pour toute map : la "voie" est une parallèle au chemin principal, à
-- PathData.LaneOffset studs (sinon aux 2/3 de la distance chemin -> entrée).
local function computeWalkPoints(from: Vector3, plot, slotIndex: number): { Vector3 }
	local path = Services.MapService.GetPath()
	local entrance = plot.Entrance.Position
	local slotTop = Services.PlotService.GetSlotTop(plot, slotIndex).Position
	local points = { from }

	local fromAlong = projectOnPath(path, from)
	local entranceAlong, entranceProjected, entranceDirection = projectOnPath(path, entrance)
	local lateral = Vector3.new(entrance.X - entranceProjected.X, 0, entrance.Z - entranceProjected.Z)
		:Dot(lateralOf(entranceDirection))
	local side = if lateral >= 0 then 1 else -1
	local lane = math.min(Services.MapService.GetLaneOffset() or math.abs(lateral) * 0.68, math.abs(lateral) - 2)
	if lane > 1 then
		local function laneAt(along: number): Vector3
			local position, direction = PathMath.Evaluate(path, along)
			return Vector3.new(position.X, from.Y, position.Z) + lateralOf(direction) * side * lane
		end
		-- Échantillons : point d'achat, coudes du chemin entre les deux, face à l'entrée
		local samples = { fromAlong }
		local forward = entranceAlong >= fromAlong
		local first, last, step = 2, #path.Points - 1, 1
		if not forward then
			first, last, step = #path.Points - 1, 2, -1
		end
		for i = first, last, step do
			local along = path.Cumulative[i]
			if math.abs(along - fromAlong) > 0.5 and math.abs(along - entranceAlong) > 0.5 then
				if (along > fromAlong) == forward and (along < entranceAlong) == forward then
					table.insert(samples, along)
				end
			end
		end
		table.insert(samples, entranceAlong)
		for _, along in samples do
			table.insert(points, laneAt(along))
		end
	end
	table.insert(points, Vector3.new(entrance.X, from.Y, entrance.Z))

	-- Dans la base : on remonte l'allée, puis on rejoint l'emplacement ENTRE deux rangées
	-- de socles (juste devant la sienne, côté entrée) : la créature ne traverse ni les
	-- socles intérieurs ni les créatures qui y sont posées
	local floorCFrame = plot.Floor.CFrame
	local entranceLocal = floorCFrame:PointToObjectSpace(entrance)
	local slotLocal = floorCFrame:PointToObjectSpace(slotTop)
	local slotSize = plot.Slots[slotIndex].Size
	local slotRadius = math.max(slotSize.X, slotSize.Y, slotSize.Z) / 2
	local approachZ = slotLocal.Z - (slotRadius + 1.3)
	local floorTop = plot.Floor.Position.Y + plot.Floor.Size.Y / 2
	local function onFloor(x: number, z: number): Vector3
		local point = floorCFrame:PointToWorldSpace(Vector3.new(x, 0, z))
		return Vector3.new(point.X, floorTop, point.Z)
	end
	table.insert(points, onFloor(entranceLocal.X, approachZ))
	table.insert(points, onFloor(slotLocal.X, approachZ))
	table.insert(points, slotTop)
	return points
end

-- Exposé pour les vérifications hors Roblox (fonction pure, aucun effet de bord)
ShopService.ComputeWalkPoints = computeWalkPoints

local function startWalker(player: Player, entry, from: Vector3)
	local plot = Services.PlotService.GetPlot(player)
	if not plot then
		return
	end
	local points = computeWalkPoints(from, plot, entry.Slot)
	local path = PathMath.Build(points)
	local speed = GameConfig.Rift.WalkToBaseSpeed

	local model = CreatureVisuals.Build(entry.Id, entry.Mutation, { Anchored = true, Billboard = false })
	model.Name = "Walk_" .. player.UserId .. "_" .. entry.Uid
	model:SetAttribute("MoverType", "Walk")
	model:SetAttribute("Speed", speed)
	model:SetAttribute("StartTime", workspace:GetServerTimeNow())
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	PathMath.WriteInlinePath(model, points)
	local hip = model:GetAttribute("HipHeight") or 2
	model:PivotTo(CFrame.new(from + Vector3.new(0, hip, 0)))
	model.Parent = Services.MapService.GetMoversFolder()

	walking[player] = walking[player] or {}
	walking[player][entry.Uid] = model

	task.delay(path.Length / speed, function()
		model:Destroy()
		local list = walking[player]
		if list and list[entry.Uid] == model then
			list[entry.Uid] = nil
		end
		Services.PlotService.AddCreatureModel(player, entry.Uid)
	end)
end

local function buy(player: Player, spawnId: string): (boolean, string?, any)
	local spawn = Services.RiftService.GetSpawn(spawnId)
	if not spawn then
		return false, "Trop tard, elle est déjà partie !"
	end
	local root = Services.CharacterService.GetRootPart(player)
	if not root then
		return false, "Tu dois être en vie pour acheter."
	end

	local position = Services.RiftService.GetSpawnPosition(spawn)
	local allowed = GameConfig.Purchase.MaxBuyDistance + spawn.Speed * GameConfig.Purchase.LatencyAllowanceSeconds
	if (root.Position - position).Magnitude > allowed then
		return false, "Trop loin de la créature."
	end

	local data = Services.DataService.GetData(player)
	local passes = Services.MonetizationService.GetPasses(player)
	local slot = Economy.FindFreeSlot(data, passes)
	if not slot then
		return false, "Ta base est pleine ! Vends, fusionne ou améliore tes emplacements."
	end
	if data.Money < spawn.Price then
		return false, "Pas assez d'argent (" .. Format.Money(spawn.Price) .. ")."
	end

	-- Aucune attente entre les vérifications et ces lignes : opération atomique
	Services.IncomeService.TrySpend(player, spawn.Price)
	Services.RiftService.ConsumeSpawn(spawnId)

	local entry = {
		Uid = Services.DataService.NewUid(data),
		Id = spawn.CreatureId,
		Mutation = Mutations.None,
		Slot = slot,
	}
	table.insert(data.Creatures, entry)
	data.Stats.Bought += 1

	startWalker(player, entry, position)
	Services.IndexService.Discover(player, entry.Id)
	Services.IncomeService.Recalculate(player)
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)

	local def = Creatures.Get(entry.Id)
	local rarity = def and Rarities.Get(def.Rarity)
	Services.QuestService.RecordEvent(player, "Buy", 1)
	if rarity and rarity.Tier >= 2 then
		Services.QuestService.RecordEvent(player, "BuyRare", 1)
	end
	if rarity and rarity.Tier >= 3 then
		Services.NotificationService.Effect(player, "Celebrate", { Color = rarity.Color, Text = rarity.Name .. " !" })
	end
	if rarity and def and rarity.Tier >= 4 then
		Services.NotificationService.Feed(
			string.format("%s a acheté %s (%s)", player.DisplayName, def.Name, rarity.Name),
			rarity.Color,
			"💰"
		)
	end
	if spawn.IsSecret and def then
		Services.NotificationService.Announce(
			player.DisplayName .. " a capturé une Secrète !",
			def.Name .. " rejoint sa base.",
			Color3.fromRGB(20, 255, 200)
		)
	end
	return true,
		(if def then def.Name else "Créature") .. " achetée ! Elle rejoint ta base.",
		{
			Uid = entry.Uid,
			Rarity = rarity and rarity.Id,
		}
end

local function sell(player: Player, uid: string): (boolean, string?, any)
	local data = Services.DataService.GetData(player)
	local index = nil
	for i, entry in data.Creatures do
		if entry.Uid == uid then
			index = i
			break
		end
	end
	if not index then
		return false, "Créature introuvable."
	end
	if Services.StealService.IsBeingCarried(player, uid) then
		return false, "Impossible : un voleur l'emporte !"
	end
	if ShopService.IsWalking(player, uid) then
		return false, "Attends qu'elle arrive dans ta base."
	end

	local entry = table.remove(data.Creatures, index)
	local value = Economy.GetSellValue(entry)
	Services.IncomeService.AddMoney(player, value, false)
	Services.PlotService.RemoveCreatureModel(player, uid)
	Services.IncomeService.Recalculate(player)
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)

	local def = Creatures.Get(entry.Id)
	return true, string.format("%s vendue pour %s", if def then def.Name else "Créature", Format.Money(value))
end

function ShopService.Init(services)
	Services = services
end

function ShopService.Start()
	Guard.BindFunction("BuyCreature", { Args = { Guard.T.String(16) } }, buy)
	Guard.BindFunction("SellCreature", { Args = { Guard.T.Uid() } }, sell)

	Players.PlayerRemoving:Connect(function(player: Player)
		local list = walking[player]
		walking[player] = nil
		if list then
			for _, model in list do
				model:Destroy()
			end
		end
	end)
end

return ShopService
