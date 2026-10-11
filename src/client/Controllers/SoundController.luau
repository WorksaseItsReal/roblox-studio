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
	Remotes.GetEvent("Effect").OnClientEvent:Connect(function(effectType)
		if effectType == "Celebrate" or effectType == "OfflineEarnings" then
			SoundController.Play("Celebrate", 0)
		elseif effectType == "Teleport" then
			SoundController.Play("Whoosh")
		elseif effectType == "StealAlert" then
			SoundController.Play("Alarm", 0)
		elseif effectType == "Storm" then
			SoundController.Play("Storm", 0)
		elseif effectType == "Fusion" then
			SoundController.Play("Success")
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
