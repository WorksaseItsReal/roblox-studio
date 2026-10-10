--[[
	CharacterService
	================
	- Fait apparaître le joueur dans SA base à chaque respawn.
	- Applique la vitesse de marche (gamepass Vitesse, ralentissement en portant
	  une créature volée).
	- Point unique pour les téléportations serveur (barrière, raccourci) afin que
	  l'anti-téléportation du vol ne les confonde pas avec de la triche.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Modules.Economy)

local CharacterService = {}

local Services

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
