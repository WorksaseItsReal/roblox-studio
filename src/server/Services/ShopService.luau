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

-- Trajet : position d'achat -> contour de l'anneau -> entrée de la base -> emplacement
local function computeWalkPoints(from: Vector3, plot, slotIndex: number): { Vector3 }
	local points = { from }
	local entrance = plot.Entrance.Position
	local center, radius = Services.MapService.GetRing()

	if radius then
		local outer = radius + 9
		local a0 = math.atan2(from.Z - center.Z, from.X - center.X)
		local a1 = math.atan2(entrance.Z - center.Z, entrance.X - center.X)
		local delta = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi -- plus court chemin
		local steps = math.max(1, math.ceil(math.abs(delta) / (math.pi / 8)))
		for i = 0, steps do
			local angle = a0 + delta * (i / steps)
			table.insert(
				points,
				Vector3.new(center.X + math.cos(angle) * outer, from.Y, center.Z + math.sin(angle) * outer)
			)
		end
	end

	table.insert(points, Vector3.new(entrance.X, from.Y, entrance.Z))
	table.insert(points, Services.PlotService.GetSlotTop(plot, slotIndex).Position)
	return points
end

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
