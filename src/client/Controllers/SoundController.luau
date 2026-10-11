--[[
	SoundController
	===============
	Retour sonore de tout le jeu (configuré dans Shared.Config.Sounds) :
	clics, achats, alertes de vol, annonces, célébrations, tempête, musique.
	Les sons sont joués localement (SoundService) : aucun coût réseau.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local Sounds = require(Shared.Config.Sounds)
local Remotes = require(Shared.Modules.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local SoundController = {}

local lastPlayed: { [string]: number } = {}

-- variation : petite variation aléatoire de hauteur (évite l'effet "mitraillette")
function SoundController.Play(name: string, variation: number?)
	local def = Sounds[name]
	if not def or def.Id == "" then
		return
	end
	-- Anti-spam : pas deux fois le même son en moins de 50 ms
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.05 then
		return
	end
	lastPlayed[name] = now
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	local jitter = variation or 0.06
	sound.PlaybackSpeed = def.Speed * (1 + (math.random() * 2 - 1) * jitter)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- Effets diffusés à tout le serveur (fusion, téléportation) : on ne les entend
-- que s'ils ont lieu près de la caméra
local HEARING_RADIUS = 90

local function isNear(payload: any): boolean
	local position = type(payload) == "table" and payload.Position
	local camera = workspace.CurrentCamera
	if typeof(position) ~= "Vector3" or not camera then
		return false
	end
	return (camera.CFrame.Position - position).Magnitude <= HEARING_RADIUS
end

local KIND_SOUNDS = {
	Success = "Success",
	Error = "Error",
	Warning = "Whoosh",
	Steal = "Alarm",
	Info = "Click",
}

function SoundController.Start()
	UIKit.OnClick = function()
		SoundController.Play("Click", 0.1)
	end

	Remotes.GetEvent("Notify").OnClientEvent:Connect(function(_text, kind)
		local name = KIND_SOUNDS[kind]
		if name then
			SoundController.Play(name)
		end
	end)
	Remotes.GetEvent("Announce").OnClientEvent:Connect(function()
		SoundController.Play("Announce", 0)
	end)
	Remotes.GetEvent("Effect").OnClientEvent:Connect(function(effectType, payload)
		if effectType == "Celebrate" or effectType == "OfflineEarnings" then
			SoundController.Play("Celebrate", 0)
		elseif effectType == "Teleport" then
			if isNear(payload) then
				SoundController.Play("Whoosh")
			end
		elseif effectType == "StealAlert" then
			SoundController.Play("Alarm", 0)
		elseif effectType == "Storm" then
			-- Uniquement au début de la tempête (la fin est annoncée sans fracas)
			if type(payload) == "table" and payload.Active then
				SoundController.Play("Storm", 0)
			end
		elseif effectType == "Fusion" then
			if isNear(payload) then
				SoundController.Play("Success")
			end
		end
	end)

	-- Musique d'ambiance (si configurée)
	local music = Sounds.Music
	if music and music.Id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.SoundId = music.Id
		sound.Volume = music.Volume
		sound.Looped = true
		sound.Parent = SoundService
		sound:Play()
	end
end

return SoundController
