--[[
	StandController
	===============
	Stands du marché sur l'esplanade de la Rift (Map.Stands, façon Grow a Garden) :
	le ProximityPrompt de chaque comptoir porte l'attribut Panel ("Shop", "Index"...).
	Le déclencher ouvre la fenêtre correspondante via StateController.OpenPanelRequested
	(écoutée par UIController).

	Marche pour tout prompt de la map qui porte cet attribut (map faite à la main
	comprise). Purement client : ouvrir une fenêtre ne demande rien au serveur, qui
	revalide de toute façon chaque achat.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")

local StateController = require(script.Parent.StateController)

local StandController = {}

function StandController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local panel = prompt:GetAttribute("Panel")
		if type(panel) == "string" and panel ~= "" then
			StateController.OpenPanelRequested:Fire(panel)
		end
	end)
end

return StandController
