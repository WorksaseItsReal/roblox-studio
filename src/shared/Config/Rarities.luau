--[[
	Rarities
	========
	Définition des raretés. "Weight" = poids de base sur le chemin de la Rift
	(avant modificateurs de dimension et de chance). Les Secrètes ont un poids de 0 :
	elles ne sortent QUE des portails instables.

	LuckAffected : le multiplicateur de chance (pack de chance serveur) s'applique
	au poids de cette rareté.
]]

export type Rarity = {
	Id: string,
	Name: string,
	Tier: number,
	Weight: number,
	Color: Color3,
	Scale: number, -- taille du modèle procédural
	LuckAffected: boolean,
}

local Rarities = {}

Rarities.List = {
	{
		Id = "Common",
		Name = "Commun",
		Tier = 1,
		Weight = 62,
		Color = Color3.fromRGB(190, 190, 190),
		Scale = 1,
		LuckAffected = false,
	},
	{
		Id = "Rare",
		Name = "Rare",
		Tier = 2,
		Weight = 26,
		Color = Color3.fromRGB(70, 150, 255),
		Scale = 1.15,
		LuckAffected = false,
	},
	{
		Id = "Epic",
		Name = "Épique",
		Tier = 3,
		Weight = 9,
		Color = Color3.fromRGB(170, 85, 255),
		Scale = 1.3,
		LuckAffected = true,
	},
	{
		Id = "Legendary",
		Name = "Légendaire",
		Tier = 4,
		Weight = 2.5,
		Color = Color3.fromRGB(255, 190, 40),
		Scale = 1.5,
		LuckAffected = true,
	},
	{
		Id = "Mythic",
		Name = "Mythique",
		Tier = 5,
		Weight = 0.5,
		Color = Color3.fromRGB(255, 60, 90),
		Scale = 1.75,
		LuckAffected = true,
	},
	{
		Id = "Secret",
		Name = "Secret",
		Tier = 6,
		Weight = 0, -- jamais sur le chemin normal
		Color = Color3.fromRGB(20, 255, 200),
		Scale = 2.1,
		LuckAffected = false,
	},
} :: { Rarity }

-- Accès rapide par Id
Rarities.ById = {} :: { [string]: Rarity }
for _, rarity in Rarities.List do
	Rarities.ById[rarity.Id] = rarity
end

function Rarities.Get(id: string): Rarity?
	return Rarities.ById[id]
end

return Rarities
