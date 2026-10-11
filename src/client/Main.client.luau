--[[
	Steal a Rift — point d'entrée client
	====================================
	Le client ne prend AUCUNE décision de gameplay : il affiche l'état envoyé par
	le serveur, anime les créatures et envoie des demandes (RemoteFunctions)
	que le serveur valide ou refuse.
]]

local Controllers = script.Parent.Controllers
local UI = script.Parent.UI

local Net = require(Controllers.Net)
local StateController = require(Controllers.StateController)
local ConveyorController = require(Controllers.ConveyorController)
local PlotController = require(Controllers.PlotController)
local RiftVisualController = require(Controllers.RiftVisualController)
local CreatureAnimator = require(Controllers.CreatureAnimator)
local EffectsController = require(Controllers.EffectsController)
local UIController = require(UI.UIController)

-- Contexte partagé avec l'interface
local ctx = {
	State = StateController,
	Net = Net,
	UI = nil,
	Toast = nil,
}

StateController.Start()
UIController.Start(ctx)
EffectsController.Start()

-- Ces contrôleurs attendent la map : chacun dans son propre thread
task.spawn(ConveyorController.Start)
task.spawn(PlotController.Start)
task.spawn(RiftVisualController.Start)
task.spawn(CreatureAnimator.Start)
