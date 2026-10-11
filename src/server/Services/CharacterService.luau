--[[
	CharacterService
	================
	- Fait apparaître le joueur dans SA base à chaque respawn.
	- Applique la vitesse de marche (gamepass Vitesse, ralentissement en portant
	  une créature volée).
	- Point unique pour les téléportations serveur (barrière, raccourci) afin que
	  l'anti-téléportation du vol ne les confonde pas avec de la triche.
	- Téléportation rapide demandée par le HUD (RemoteFunction "Teleport") :
	  "Rift" = esplanade devant la Rift, "Base" = sa base. Refusée en portant une
	  créature volée, avec une recharge (GameConfig.Movement.TeleportCooldown).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Economy = require(ReplicatedStorage.Shared.Modules.Economy)
local Guard = require(script.Parent.Parent.Lib.Guard)

local CharacterService = {}

local Services
-- Heure (os.clock) de la dernière téléportation rapide de chaque joueur
local lastQuickTeleport: { [Player]: number } = {}

function CharacterService.GetRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function CharacterService.IsAlive(player: Player): boolean
	return CharacterService.GetRootPart(player) ~= nil
end

-- Téléportation serveur (réinitialise le suivi anti-triche du vol)
function CharacterService.TeleportTo(player: Player, target: CFrame)
	local character = player.Character
	if not character or not CharacterService.GetRootPart(player) then
		return
	end
	character:PivotTo(target)
	Services.StealService.ResetTracking(player)
end

function CharacterService.TeleportToPlot(player: Player)
	local plot = Services.PlotService.GetPlot(player)
	if not plot then
		return
	end
	local spawn = plot.Spawn
	CharacterService.TeleportTo(player, CFrame.new(spawn.Position + Vector3.new(0, 4, 0)) * spawn.CFrame.Rotation)
end

--[[
	Point d'arrivée sur l'esplanade de la Rift : la dalle d'apparition centrale de la
	map (CentralSpawn) ; sinon (map faite à la main sans elle), à côté du début du
	chemin, sur le bord, tourné vers le tapis.
]]
local function riftDestination(): CFrame?
	local map = Services.MapService.GetMap()
	local central = map and map:FindFirstChild("CentralSpawn")
	local jitter = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	if central and central:IsA("BasePart") then
		return CFrame.new(central.Position + Vector3.new(0, 4, 0) + jitter) * central.CFrame.Rotation
	end
	local points = Services.MapService.GetPath().Points
	if #points < 2 then
		return nil
	end
	local forward = points[2] - points[1]
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 0.01 then
		return nil
	end
	forward = forward.Unit
	local side = forward:Cross(Vector3.yAxis).Unit
	local position = points[1] + forward * 14 + side * 20 + Vector3.new(0, 4, 0) + jitter
	return CFrame.lookAt(position, position - side)
end

local function quickTeleport(player: Player, destination: string): (boolean, string?)
	if Services.StealService.IsCarrying(player) then
		return false, "Impossible de te téléporter en portant une créature volée !"
	end
	if not CharacterService.IsAlive(player) then
		return false, "Attends de réapparaître."
	end
	local now = os.clock()
	local readyAt = (lastQuickTeleport[player] or -math.huge) + GameConfig.Movement.TeleportCooldown
	if now < readyAt then
		return false, string.format("Patiente encore %d s.", math.ceil(readyAt - now))
	end

	if destination == "Base" then
		local plot = Services.PlotService.GetPlot(player)
		if not plot then
			return false, "Ta base n'est pas encore prête."
		end
		CharacterService.TeleportToPlot(player)
	else
		local target = riftDestination()
		if not target then
			return false, "Esplanade introuvable."
		end
		CharacterService.TeleportTo(player, target)
	end
	lastQuickTeleport[player] = now
	local root = CharacterService.GetRootPart(player)
	if root then
		Services.NotificationService.Effect(player, "Teleport", { Position = root.Position - Vector3.new(0, 3, 0) })
	end
	return true
end

function CharacterService.RefreshSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local passes = Services.MonetizationService.GetPasses(player)
	local carrying, victimAlarm = Services.StealService.GetCarryInfo(player)
	humanoid.WalkSpeed = Economy.GetWalkSpeed(passes, carrying, victimAlarm)
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or character.Parent == nil then
		return
	end
	task.wait() -- laisse Roblox terminer le placement initial
	CharacterService.RefreshSpeed(player)
	CharacterService.TeleportToPlot(player)
end

function CharacterService.Init(services)
	Services = services
end

function CharacterService.Start()
	Guard.BindFunction("Teleport", { Args = { Guard.T.OneOf({ "Base", "Rift" }) } }, quickTeleport)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastQuickTeleport[player] = nil
	end)

	local function setup(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return CharacterService
