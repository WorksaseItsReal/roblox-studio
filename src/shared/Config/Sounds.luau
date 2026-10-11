--[[
	Sounds
	======
	Sons du jeu. Les valeurs par défaut utilisent des sons INTÉGRÉS au client
	Roblox (rbxasset://...) pour que le jeu ait du retour sonore sans rien
	publier. Pour un rendu pro, remplace-les par de meilleurs sons :
	  Studio > Toolbox > Audio > filtre "Créateur : Roblox" (sons libres d'usage)
	  puis colle l'Id ici sous la forme "rbxassetid://123456".

	Music : laisse "" pour désactiver, ou mets une musique de la bibliothèque
	Roblox (gratuite et autorisée) : c'est l'élément d'ambiance le plus
	important, à ne pas négliger.
]]

local Sounds = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Speed = 1.2 },
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Speed = 1 },
	Coin = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.12, Speed = 1.6 },
	Success = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Speed = 1.3 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Speed = 0.6 },
	Whoosh = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.5, Speed = 1 },
	Steal = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.6, Speed = 0.9 },
	Alarm = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.7, Speed = 0.6 },
	Announce = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5, Speed = 1.1 },
	Celebrate = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 0.8 },
	Storm = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.8, Speed = 0.5 },
	Music = { Id = "", Volume = 0.25, Speed = 1 },
}

return Sounds
