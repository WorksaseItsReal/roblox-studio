--[[
	Steal a Rift — point d'entrée client
	====================================
	Le client ne prend AUCUNE décision de gameplay : il affiche l'état envoyé par
	le serveur, anime le monde, joue les sons et effets, et envoie des demandes
	(RemoteFunctions) que le serveur valide ou refuse.
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
local SoundController = require(Controllers.SoundController)
local JuiceController = require(Controllers.JuiceController)
local TutorialController = require(Controllers.TutorialController)
local BoardController = require(Controllers.BoardController)
local StandController = require(Controllers.StandController)
local UIController = require(UI.UIController)

-- Contexte partagé avec l'interface (UI, Root et Toast sont remplis par UIController)
local ctx = {
	State = StateController,
	Net = Net,
	UI = nil,
	Root = nil,
	Toast = nil,
}

StateController.Start()
UIController.Start(ctx)
StandController.Start()
SoundController.Start()
EffectsController.Start()
JuiceController.Start(ctx)

-- Ces contrôleurs attendent la map ou le profil : chacun dans son propre thread
task.spawn(ConveyorController.Start)
task.spawn(PlotController.Start)
task.spawn(RiftVisualController.Start)
task.spawn(CreatureAnimator.Start)
task.spawn(BoardController.Start)
task.spawn(TutorialController.Start, ctx)
