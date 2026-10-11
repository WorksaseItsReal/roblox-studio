--[[
	StateController
	===============
	Copie locale (lecture seule) de l'état du joueur et du serveur :
	- Profile : instantané envoyé par SyncService (créatures, améliorations...)
	- Money / Income : attributs du Player, mis à jour chaque seconde
	- GameState : dimension, timer, chance (ReplicatedStorage.GameState)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Modules.Remotes)
local Signal = require(Shared.Modules.Signal)
local Net = require(script.Parent.Net)

local StateController = {}

local player = Players.LocalPlayer

StateController.Profile = nil :: any
StateController.ProfileChanged = Signal.new()
StateController.MoneyChanged = Signal.new()
StateController.GameStateChanged = Signal.new()
StateController.GameState = nil :: Folder?
-- Demande d'ouverture d'un panneau (depuis un ProximityPrompt par ex.) : (nom, argument)
StateController.OpenPanelRequested = Signal.new()

function StateController.GetMoney(): number
	return player:GetAttribute("Money") or 0
end

function StateController.GetIncome(): number
	return player:GetAttribute("IncomePerSecond") or 0
end

-- Heure Unix du serveur estimée à partir du dernier instantané
function StateController.GetServerUnixTime(): number
	local profile = StateController.Profile
	if not profile then
		return os.time()
	end
	return profile.ServerUnixTime + (os.clock() - profile.ReceivedAt)
end

function StateController.GetDimension(): string
	local state = StateController.GameState
	return (state and state:GetAttribute("Dimension")) or "Lava"
end

-- Chance achetée (pack de chance) seule
function StateController.GetPurchasedLuck(): number
	local state = StateController.GameState
	if not state then
		return 1
	end
	local endsAt = state:GetAttribute("LuckEndsAt") or 0
	if workspace:GetServerTimeNow() >= endsAt then
		return 1
	end
	return state:GetAttribute("LuckMultiplier") or 1
end

function StateController.IsStormActive(): boolean
	local state = StateController.GameState
	return state ~= nil and state:GetAttribute("StormActive") == true
end

-- Chance effective (pack de chance x tempête), identique au calcul du serveur
function StateController.GetLuck(): number
	local luck = StateController.GetPurchasedLuck()
	if StateController.IsStormActive() then
		luck *= GameConfig.Storm.LuckMultiplier
	end
	return luck
end

local function setProfile(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	snapshot.ReceivedAt = os.clock() -- pour estimer l'heure serveur (récompense quotidienne)
	StateController.Profile = snapshot
	StateController.ProfileChanged:Fire(snapshot)
end

function StateController.Start()
	Remotes.GetEvent("ProfileSync").OnClientEvent:Connect(setProfile)

	for _, attribute in { "Money", "IncomePerSecond" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			StateController.MoneyChanged:Fire()
		end)
	end

	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("GameState")
		StateController.GameState = state :: Folder
		state.AttributeChanged:Connect(function()
			StateController.GameStateChanged:Fire()
		end)
		StateController.GameStateChanged:Fire()
	end)

	-- Premier instantané (le profil peut mettre quelques secondes à charger)
	task.spawn(function()
		for _ = 1, 30 do
			if StateController.Profile then
				return
			end
			local response = Net.Invoke("RequestSync")
			if response.Ok and response.Data then
				setProfile(response.Data)
				return
			end
			task.wait(1)
		end
	end)
end

return StateController
