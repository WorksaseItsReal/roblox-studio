--[[
	NotificationService
	===================
	Envoi de messages aux clients :
	- Notify   : petit toast pour UN joueur (Info, Success, Error, Warning, Steal)
	- Announce : grande bannière pour TOUT le serveur (dimension, vols épiques...)
	- Effect   : effet visuel joué côté client (fusion, téléportation, intrus...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local NotificationService = {}

local notifyEvent: RemoteEvent
local announceEvent: RemoteEvent
local effectEvent: RemoteEvent
local feedEvent: RemoteEvent

export type Kind = "Info" | "Success" | "Error" | "Warning" | "Steal"

function NotificationService.Notify(player: Player, text: string, kind: Kind?)
	notifyEvent:FireClient(player, text, kind or "Info")
end

function NotificationService.Announce(title: string, subtitle: string?, color: Color3?)
	announceEvent:FireAllClients(title, subtitle or "", color or Color3.new(1, 1, 1))
end

function NotificationService.Effect(player: Player?, effectType: string, payload: { [string]: any })
	if player then
		effectEvent:FireClient(player, effectType, payload)
	else
		effectEvent:FireAllClients(effectType, payload)
	end
end

-- Fil d'actualité visible par tout le serveur (preuve sociale : "X a volé Y à Z")
function NotificationService.Feed(text: string, color: Color3?, icon: string?)
	feedEvent:FireAllClients(text, color or Color3.new(1, 1, 1), icon or "📣")
end

function NotificationService.Init(_services)
	notifyEvent = Remotes.GetEvent("Notify")
	announceEvent = Remotes.GetEvent("Announce")
	effectEvent = Remotes.GetEvent("Effect")
	feedEvent = Remotes.GetEvent("Feed")
end

function NotificationService.Start() end

return NotificationService
