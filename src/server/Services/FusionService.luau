--[[
	FusionService
	=============
	Portail de fusion : 2 créatures IDENTIQUES et non mutées -> 1 créature mutée
	(multiplicateur x2 à x5, voir Config/Mutations). Le joueur doit se tenir près
	du portail de fusion de SA base. La 2e créature disparaît, son emplacement
	est libéré.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Guard = require(script.Parent.Parent.Lib.Guard)

local FusionService = {}

local Services
local rng = Random.new()

local function findEntry(data, uid: string)
	for index, entry in data.Creatures do
		if entry.Uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

local function fuse(player: Player, uidA: string, uidB: string): (boolean, string?, any)
	if uidA == uidB then
		return false, "Choisis deux créatures différentes."
	end
	local plot = Services.PlotService.GetPlot(player)
	local root = Services.CharacterService.GetRootPart(player)
	if not plot or not root then
		return false, "Tu dois être dans ta base."
	end
	if (root.Position - plot.FusionPortal.Position).Magnitude > GameConfig.Fusion.MaxDistance then
		return false, "Approche-toi de ton portail de fusion."
	end

	local data = Services.DataService.GetData(player)
	local a = findEntry(data, uidA)
	local b, indexB = findEntry(data, uidB)
	if not a or not b or not indexB then
		return false, "Créature introuvable."
	end
	for _, uid in { uidA, uidB } do
		if Services.StealService.IsBeingCarried(player, uid) or Services.ShopService.IsWalking(player, uid) then
			return false, "Une de ces créatures n'est pas dans ta base."
		end
	end
	if a.Id ~= b.Id then
		return false, "Il faut deux créatures identiques."
	end
	if a.Mutation ~= Mutations.None or b.Mutation ~= Mutations.None then
		return false, "Les créatures déjà mutées ne peuvent plus fusionner."
	end

	local mutation = Mutations.Roll(rng)
	table.remove(data.Creatures, indexB)
	a.Mutation = mutation.Id
	data.Stats.Fusions += 1
	Services.QuestService.RecordEvent(player, "Fuse", 1)

	Services.PlotService.RemoveCreatureModel(player, uidB)
	Services.PlotService.AddCreatureModel(player, uidA)
	Services.IncomeService.Recalculate(player)
	Services.SyncService.Push(player)
	Services.DataService.SaveSoon(player)
	Services.NotificationService.Effect(nil, "Fusion", {
		Position = plot.FusionPortal.Position,
		Color = mutation.Color,
	})

	local def = Creatures.Get(a.Id)
	local name = if def then def.Name else a.Id
	Services.NotificationService.Effect(
		player,
		"Celebrate",
		{ Color = mutation.Color, Text = mutation.Name .. " x" .. mutation.Multiplier }
	)
	if mutation.Multiplier >= 3 then
		Services.NotificationService.Feed(
			string.format("%s a fusionné un %s %s (x%d)", player.DisplayName, name, mutation.Name, mutation.Multiplier),
			mutation.Color,
			"🌀"
		)
	end
	if mutation.Multiplier >= 4 then
		Services.NotificationService.Announce(
			"Fusion " .. mutation.Name .. " !",
			player.DisplayName .. " a obtenu " .. name .. " " .. mutation.Name .. " (x" .. mutation.Multiplier .. ")",
			mutation.Color
		)
	end
	return true,
		string.format("Fusion réussie : %s %s (revenus x%d) !", name, mutation.Name, mutation.Multiplier),
		{
			Uid = uidA,
			Mutation = mutation.Id,
		}
end

function FusionService.Init(services)
	Services = services
end

function FusionService.Start()
	Guard.BindFunction("FuseCreatures", { Args = { Guard.T.Uid(), Guard.T.Uid() } }, fuse)
end

return FusionService
