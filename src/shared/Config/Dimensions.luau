--[[
	Dimensions
	==========
	Les 5 dimensions de la Rift. Toutes les 5 minutes (GameConfig.Rift), la Rift passe
	à la dimension suivante dans "Order".

	Pour chaque dimension :
	- RarityMultipliers : multiplie le poids de base de chaque rareté
	- SpawnIntervalMultiplier : < 1 = plus de spawns
	- WalkSpeedMultiplier : vitesse des créatures sur le chemin (< 1 = plus de temps pour acheter)
	- Visual : couleurs utilisées par le client (faille, éclairage, brouillard)
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
			Ambient = Color3.fromRGB(110, 60, 40),
			FogColor = Color3.fromRGB(120, 45, 20),
			Tint = Color3.fromRGB(255, 225, 205),
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
			Ambient = Color3.fromRGB(50, 35, 80),
			FogColor = Color3.fromRGB(25, 10, 45),
			Tint = Color3.fromRGB(215, 200, 255),
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
			Ambient = Color3.fromRGB(110, 140, 170),
			FogColor = Color3.fromRGB(190, 225, 255),
			Tint = Color3.fromRGB(215, 240, 255),
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
			Ambient = Color3.fromRGB(150, 110, 140),
			FogColor = Color3.fromRGB(255, 190, 230),
			Tint = Color3.fromRGB(255, 230, 245),
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
			Ambient = Color3.fromRGB(40, 90, 80),
			FogColor = Color3.fromRGB(10, 40, 40),
			Tint = Color3.fromRGB(205, 255, 235),
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
