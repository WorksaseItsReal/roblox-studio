--[[
	TutorialService
	===============
	Le tutoriel est guidé côté client (flèches, bulles). Le serveur ne fait que
	valider sa fin (le joueur a vraiment acheté une créature) et donner la
	récompense, une seule fois par compte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Guard = require(script.Parent.Parent.Lib.Guard)

local TutorialService = {}

local Services

local function complete(player: Player): (boolean, string?)
	local data = Services.DataService.GetData(player)
	if data.TutorialDone then
		return false, nil
	end
	if data.Stats.Bought < 1 and #data.Creatures == 0 then
		return false, "Achète d'abord ta première créature !"
	end
	data.TutorialDone = true
	local text = Services.RewardService.Grant(player, GameConfig.Tutorial.Reward)
	return true, "Tutoriel terminé ! " .. text
end

-- Le joueur peut aussi passer le tutoriel (sans récompense)
function TutorialService.Skip(player: Player)
	local data = Services.DataService.GetData(player)
	if data then
		data.TutorialDone = true
		Services.SyncService.Push(player)
	end
end

function TutorialService.Init(services)
	Services = services
end

function TutorialService.Start()
	Guard.BindFunction("CompleteTutorial", { Args = { Guard.T.OneOf({ "Done", "Skip" }) } }, function(player, mode)
		if mode == "Skip" then
			TutorialService.Skip(player)
			return true, nil
		end
		return complete(player)
	end)
end

return TutorialService
