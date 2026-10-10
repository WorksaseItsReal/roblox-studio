--[[
	Net
	===
	Appel des RemoteFunctions du serveur avec affichage automatique du message
	de réponse (toast vert / rouge). Le client ne fait QUE demander : le serveur
	décide toujours.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local Net = {}

-- Fonction d'affichage injectée par Notifications (évite un require circulaire)
Net.Toast = function(_text: string, _kind: string) end

export type Response = { Ok: boolean, Message: string?, Data: any }

function Net.Invoke(name: string, ...: any): Response
	local remote = Remotes.GetFunction(name)
	local ok, response = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(response) ~= "table" then
		return { Ok = false, Message = "Connexion au serveur impossible." }
	end
	return response
end

-- Invoke + toast du message renvoyé
function Net.Request(name: string, ...: any): Response
	local response = Net.Invoke(name, ...)
	if response.Message and response.Message ~= "" then
		Net.Toast(response.Message, if response.Ok then "Success" else "Error")
	end
	return response
end

return Net
