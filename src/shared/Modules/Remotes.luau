--[[
	Remotes
	=======
	Liste centralisée des RemoteFunctions / RemoteEvents.
	- Le SERVEUR les crée au démarrage (Remotes.SetupServer).
	- Le CLIENT les attend (Remotes.GetFunction / GetEvent).

	Règle de sécurité : le client n'invoque que des RemoteFunctions (le serveur
	répond toujours via une table { Ok, Message, Data }) et le serveur ne fait
	JAMAIS d'InvokeClient (un client malveillant pourrait bloquer le thread).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- Client -> Serveur (requête / réponse)
Remotes.FunctionNames = {
	"BuyCreature",
	"SellCreature",
	"FuseCreatures",
	"ActivateBarrier",
	"BuyUpgrade",
	"Rebirth",
	"ClaimDaily",
	"ClaimIndexReward",
	"UnlockShortcut",
	"UseShortcut",
	"SetDimensionChoice",
	"GetLeaderboard",
	"RequestSync",
	"ClaimQuest",
	"ClaimQuestBonus",
	"ClaimGift",
	"RedeemCode",
	"CompleteTutorial",
	"Teleport", -- téléportation rapide : "Rift" (esplanade) ou "Base" (sa base)
}

-- Serveur -> Client
Remotes.EventNames = {
	"ProfileSync", -- instantané des données du joueur
	"Notify", -- toast (texte, type)
	"Announce", -- grande annonce globale
	"LeaderboardUpdated", -- nouveau classement
	"Effect", -- effets visuels (fusion, téléportation, intrus...)
	"Feed", -- fil d'actualité du serveur (vols, captures rares...)
}

local FOLDER_NAME = "Remotes"

export type Response = {
	Ok: boolean,
	Message: string?,
	Data: any,
}

function Remotes.SetupServer()
	assert(RunService:IsServer(), "SetupServer est réservé au serveur")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.FunctionNames do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Remotes.EventNames do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(folder, "Remotes.SetupServer() doit être appelé avant")
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.GetFunction(name: string): RemoteFunction
	assert(table.find(Remotes.FunctionNames, name), "RemoteFunction inconnue : " .. name)
	local folder = getFolder()
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	return remote :: RemoteFunction
end

function Remotes.GetEvent(name: string): RemoteEvent
	assert(table.find(Remotes.EventNames, name), "RemoteEvent inconnu : " .. name)
	local folder = getFolder()
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	return remote :: RemoteEvent
end

return Remotes
