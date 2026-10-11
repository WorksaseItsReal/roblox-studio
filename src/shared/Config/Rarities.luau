--[[
	Rarities
	========
	Définition des raretés. "Weight" = poids de base sur le chemin de la Rift
	(avant modificateurs de dimension et de chance). Les Secrètes ont un poids de 0 :
	elles ne sortent QUE des portails instables.

	LuckAffected : le multiplicateur de chance (pack de chance serveur) s'applique
	au poids de cette rareté.

	Couleurs : voir docs/ART_DIRECTION.md (tableau des raretés). Secret s'affiche en
	arc-en-ciel (Rainbow, couleurs dans Rarities.RainbowColors) ; Color reste sa
	couleur de repli pour les effets à une seule couleur (colonne de lumière,
	annonces, confettis).
]]

export type Rarity = {
	Id: string,
	Name: string,
	Tier: number,
	Weight: number,
	Color: Color3, -- couleur de référence (textes, disque au sol, effets)
	Rainbow: boolean?, -- affichage arc-en-ciel (Secret) : voir Rarities.RainbowColors
	Scale: number, -- taille du modèle procédural
	LuckAffected: boolean,
}

local Rarities = {}

-- Couleurs de l'arc-en-ciel de la rareté Secrète (dégradé des étiquettes, disque, aura),
-- réparties régulièrement de gauche à droite
Rarities.RainbowColors = {
	Color3.fromRGB(255, 64, 64),
	Color3.fromRGB(255, 190, 30),
	Color3.fromRGB(80, 235, 80),
	Color3.fromRGB(30, 200, 255),
	Color3.fromRGB(150, 80, 255),
	Color3.fromRGB(255, 70, 200),
}

Rarities.List = {
	{
		Id = "Common",
		Name = "Commun",
		Tier = 1,
		Weight = 62,
		Color = Color3.fromRGB(200, 200, 200),
		Scale = 1.15,
		LuckAffected = false,
	},
	{
		Id = "Rare",
		Name = "Rare",
		Tier = 2,
		Weight = 26,
		Color = Color3.fromRGB(40, 140, 255),
		Scale = 1.3,
		LuckAffected = false,
	},
	{
		Id = "Epic",
		Name = "Épique",
		Tier = 3,
		Weight = 9,
		Color = Color3.fromRGB(170, 70, 255),
		Scale = 1.45,
		LuckAffected = true,
	},
	{
		Id = "Legendary",
		Name = "Légendaire",
		Tier = 4,
		Weight = 2.5,
		Color = Color3.fromRGB(255, 190, 0),
		Scale = 1.62,
		LuckAffected = true,
	},
	{
		Id = "Mythic",
		Name = "Mythique",
		Tier = 5,
		Weight = 0.5,
		Color = Color3.fromRGB(255, 40, 70),
		Scale = 1.85,
		LuckAffected = true,
	},
	{
		Id = "Secret",
		Name = "Secret",
		Tier = 6,
		Weight = 0, -- jamais sur le chemin normal
		Color = Color3.fromRGB(20, 255, 200), -- repli : l'affichage est arc-en-ciel
		Rainbow = true,
		Scale = 2.15,
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
