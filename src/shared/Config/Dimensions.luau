--[[
	Dimensions
	==========
	Les 5 dimensions de la Rift. Toutes les 5 minutes (GameConfig.Rift), la Rift passe
	à la dimension suivante dans "Order".

	Pour chaque dimension :
	- RarityMultipliers : multiplie le poids de base de chaque rareté
	- SpawnIntervalMultiplier : < 1 = plus de spawns
	- WalkSpeedMultiplier : vitesse des créatures sur le chemin (< 1 = plus de temps pour acheter)
	- Visual : couleurs utilisées par le client. RiftColor / RiftAccent colorent la
	  Rift (vortex, cristaux, fissures, liseré de l'estrade) et l'interface ;
	  Ambient (Lighting.Ambient), FogColor (nuance de l'atmosphère, mélangée au ciel
	  clair) et Tint (teinte de l'image) restent TRÈS légers, quasi neutres
	  (docs/ART_DIRECTION.md) : le monde garde ses matériaux et ses couleurs
	- Palette / Material : utilisés par les modèles procéduraux des créatures
]]

export type Dimension = {
	Id: string,
	Name: string,
	Description: string,
	RarityMultipliers: { [string]: number },
	SpawnIntervalMultiplier: number,
	WalkSpeedMultiplier: number,
	Visual: {
		RiftColor: Color3,
		RiftAccent: Color3,
		Ambient: Color3,
		FogColor: Color3,
		Tint: Color3,
	},
	Palette: { Color3 },
	Material: Enum.Material,
	AccentMaterial: Enum.Material,
}

local Dimensions = {}

Dimensions.Order = { "Lava", "Void", "Ice", "Candy", "Cyber" }

Dimensions.ById = {
	Lava = {
		Id = "Lava",
		Name = "Lave",
		Description = "Plus de créatures communes : idéal pour démarrer.",
		RarityMultipliers = { Common = 1.2 },
		SpawnIntervalMultiplier = 1,
		WalkSpeedMultiplier = 1,
		Visual = {
			RiftColor = Color3.fromRGB(255, 90, 20),
			RiftAccent = Color3.fromRGB(255, 200, 60),
			Ambient = Color3.fromRGB(110, 104, 100),
			FogColor = Color3.fromRGB(255, 176, 128),
			Tint = Color3.fromRGB(255, 250, 245),
		},
		Palette = {
			Color3.fromRGB(255, 100, 30),
			Color3.fromRGB(60, 30, 25),
			Color3.fromRGB(255, 210, 70),
		},
		Material = Enum.Material.Basalt,
		AccentMaterial = Enum.Material.Neon,
	},
	Void = {
		Id = "Void",
		Name = "Néant",
		Description = "Légendaires et Mythiques plus fréquents, mais créatures rapides.",
		RarityMultipliers = { Common = 0.9, Legendary = 1.8, Mythic = 1.5 },
		SpawnIntervalMultiplier = 1,
		WalkSpeedMultiplier = 1.15,
		Visual = {
			RiftColor = Color3.fromRGB(120, 40, 255),
			RiftAccent = Color3.fromRGB(240, 240, 255),
			Ambient = Color3.fromRGB(104, 102, 114),
			FogColor = Color3.fromRGB(184, 156, 255),
			Tint = Color3.fromRGB(251, 249, 255),
		},
		Palette = {
			Color3.fromRGB(35, 20, 60),
			Color3.fromRGB(130, 60, 255),
			Color3.fromRGB(235, 235, 255),
		},
		Material = Enum.Material.Slate,
		AccentMaterial = Enum.Material.Neon,
	},
	Ice = {
		Id = "Ice",
		Name = "Glace",
		Description = "Plus de Rares, et les créatures avancent lentement.",
		RarityMultipliers = { Rare = 1.5 },
		SpawnIntervalMultiplier = 1,
		WalkSpeedMultiplier = 0.75,
		Visual = {
			RiftColor = Color3.fromRGB(110, 220, 255),
			RiftAccent = Color3.fromRGB(255, 255, 255),
			Ambient = Color3.fromRGB(102, 107, 116),
			FogColor = Color3.fromRGB(170, 222, 255),
			Tint = Color3.fromRGB(247, 251, 255),
		},
		Palette = {
			Color3.fromRGB(170, 230, 255),
			Color3.fromRGB(240, 250, 255),
			Color3.fromRGB(60, 140, 220),
		},
		Material = Enum.Material.Ice,
		AccentMaterial = Enum.Material.Glass,
	},
	Candy = {
		Id = "Candy",
		Name = "Bonbon",
		Description = "Plus d'Épiques et des spawns plus rapprochés.",
		RarityMultipliers = { Common = 1.1, Epic = 1.6 },
		SpawnIntervalMultiplier = 0.9,
		WalkSpeedMultiplier = 1,
		Visual = {
			RiftColor = Color3.fromRGB(255, 120, 200),
			RiftAccent = Color3.fromRGB(120, 255, 230),
			Ambient = Color3.fromRGB(112, 104, 110),
			FogColor = Color3.fromRGB(255, 184, 226),
			Tint = Color3.fromRGB(255, 249, 252),
		},
		Palette = {
			Color3.fromRGB(255, 140, 205),
			Color3.fromRGB(130, 240, 220),
			Color3.fromRGB(255, 240, 150),
		},
		Material = Enum.Material.SmoothPlastic,
		AccentMaterial = Enum.Material.Neon,
	},
	Cyber = {
		Id = "Cyber",
		Name = "Cyber",
		Description = "Mythiques x2 et beaucoup plus de spawns.",
		RarityMultipliers = { Epic = 1.2, Mythic = 2 },
		SpawnIntervalMultiplier = 0.8,
		WalkSpeedMultiplier = 1,
		Visual = {
			RiftColor = Color3.fromRGB(0, 255, 140),
			RiftAccent = Color3.fromRGB(0, 170, 255),
			Ambient = Color3.fromRGB(100, 109, 107),
			FogColor = Color3.fromRGB(150, 245, 210),
			Tint = Color3.fromRGB(247, 255, 251),
		},
		Palette = {
			Color3.fromRGB(30, 35, 45),
			Color3.fromRGB(0, 255, 150),
			Color3.fromRGB(0, 170, 255),
		},
		Material = Enum.Material.DiamondPlate,
		AccentMaterial = Enum.Material.Neon,
	},
} :: { [string]: Dimension }

function Dimensions.Get(id: string): Dimension?
	return Dimensions.ById[id]
end

function Dimensions.IsValid(id: any): boolean
	return type(id) == "string" and Dimensions.ById[id] ~= nil
end

-- Dimension suivante dans la rotation
function Dimensions.Next(id: string): string
	local index = table.find(Dimensions.Order, id) or 0
	return Dimensions.Order[(index % #Dimensions.Order) + 1]
end

return Dimensions
