--[[
	Creatures
	=========
	Les 40 créatures dimensionnelles (8 par dimension) :
	  2 Communes, 2 Rares, 1 Épique, 1 Légendaire, 1 Mythique, 1 Secrète.

	Champs :
	- Id         : identifiant unique (sauvegardé dans les DataStores : NE PAS renommer
	               une créature déjà en production, ajouter plutôt une nouvelle entrée)
	- Name       : nom affiché
	- Rarity     : Id de rareté (voir Rarities)
	- Dimension  : dimension d'origine (voir Dimensions)
	- Price      : prix d'achat sur le chemin
	- Income     : revenu par seconde (avant multiplicateurs)
	- Model      : (optionnel) nom d'un modèle dans ReplicatedStorage.Assets.Creatures.
	               S'il n'existe pas, un modèle procédural est généré.
	- Visual     : paramètres du modèle procédural (Archetype : Blob, Spiky, Tall,
	               Crystal, Wisp, Beast, Serpent, Golem)
	- Description: texte de l'index

	Équilibrage : le temps de rentabilité (Price / Income) passe de ~25 s (Commun)
	à ~200 s (Secret). Les raretés hautes sont donc moins rentables par $ investi
	mais BEAUCOUP plus rentables par emplacement : c'est la tension voulue, puisque
	les emplacements sont limités.
]]

export type CreatureDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Dimension: string,
	Price: number,
	Income: number,
	Model: string?,
	Visual: { Archetype: string, Scale: number? },
	Description: string,
}

local Creatures = {}

Creatures.List = {
	------------------------------------------------------------------ LAVE
	{
		Id = "Lava_Braisillon",
		Name = "Braisillon",
		Rarity = "Common",
		Dimension = "Lava",
		Price = 25,
		Income = 1,
		Visual = { Archetype = "Wisp" },
		Description = "Une petite braise qui refuse de s'éteindre.",
	},
	{
		Id = "Lava_CrapaudMagma",
		Name = "Crapaud Magma",
		Rarity = "Common",
		Dimension = "Lava",
		Price = 70,
		Income = 2.5,
		Visual = { Archetype = "Blob" },
		Description = "Il coasse des bulles de lave. Ne pas caresser.",
	},
	{
		Id = "Lava_Salamandre",
		Name = "Salamandre Cendrée",
		Rarity = "Rare",
		Dimension = "Lava",
		Price = 400,
		Income = 9,
		Visual = { Archetype = "Serpent" },
		Description = "Elle laisse une traînée de cendres tièdes.",
	},
	{
		Id = "Lava_GolemScories",
		Name = "Golem de Scories",
		Rarity = "Rare",
		Dimension = "Lava",
		Price = 900,
		Income = 18,
		Visual = { Archetype = "Golem" },
		Description = "Assemblé à partir des déchets d'un volcan.",
	},
	{
		Id = "Lava_PhenixFele",
		Name = "Phénix Fêlé",
		Rarity = "Epic",
		Dimension = "Lava",
		Price = 5_000,
		Income = 70,
		Visual = { Archetype = "Wisp", Scale = 1.2 },
		Description = "Il renaît de ses cendres... mais pas toujours en entier.",
	},
	{
		Id = "Lava_WyrmVolcanique",
		Name = "Wyrm Volcanique",
		Rarity = "Legendary",
		Dimension = "Lava",
		Price = 60_000,
		Income = 600,
		Visual = { Archetype = "Serpent", Scale = 1.2 },
		Description = "Il nage dans le magma comme d'autres dans l'eau.",
	},
	{
		Id = "Lava_TitanNoyau",
		Name = "Titan du Noyau",
		Rarity = "Mythic",
		Dimension = "Lava",
		Price = 750_000,
		Income = 5_000,
		Visual = { Archetype = "Golem", Scale = 1.15 },
		Description = "On dit que son cœur est un morceau du noyau de la Rift.",
	},
	{
		Id = "Lava_IgnisPrimordial",
		Name = "Ignis Primordial",
		Rarity = "Secret",
		Dimension = "Lava",
		Price = 20_000_000,
		Income = 100_000,
		Visual = { Archetype = "Spiky" },
		Description = "La toute première flamme. Elle n'apparaît que par un portail doré.",
	},

	------------------------------------------------------------------ NÉANT
	{
		Id = "Void_Ombrelin",
		Name = "Ombrelin",
		Rarity = "Common",
		Dimension = "Void",
		Price = 55,
		Income = 2.2,
		Visual = { Archetype = "Blob" },
		Description = "Une ombre timide qui suit les gens de trop près.",
	},
	{
		Id = "Void_OeilErrant",
		Name = "Œil Errant",
		Rarity = "Common",
		Dimension = "Void",
		Price = 155,
		Income = 5.5,
		Visual = { Archetype = "Wisp" },
		Description = "Il regarde. Toujours.",
	},
	{
		Id = "Void_SpectreCreux",
		Name = "Spectre Creux",
		Rarity = "Rare",
		Dimension = "Void",
		Price = 880,
		Income = 20,
		Visual = { Archetype = "Tall" },
		Description = "À l'intérieur, il n'y a que de l'écho.",
	},
	{
		Id = "Void_MeduseVide",
		Name = "Méduse du Vide",
		Rarity = "Rare",
		Dimension = "Void",
		Price = 2_000,
		Income = 40,
		Visual = { Archetype = "Wisp", Scale = 1.1 },
		Description = "Elle flotte entre deux dimensions.",
	},
	{
		Id = "Void_DevoreurEchos",
		Name = "Dévoreur d'Échos",
		Rarity = "Epic",
		Dimension = "Void",
		Price = 11_000,
		Income = 155,
		Visual = { Archetype = "Beast" },
		Description = "Il mange les sons. Votre base devient étrangement calme.",
	},
	{
		Id = "Void_ArchonteSilencieux",
		Name = "Archonte Silencieux",
		Rarity = "Legendary",
		Dimension = "Void",
		Price = 132_000,
		Income = 1_320,
		Visual = { Archetype = "Tall", Scale = 1.2 },
		Description = "Gardien des portes que personne ne devrait ouvrir.",
	},
	{
		Id = "Void_LeviathanAbyssal",
		Name = "Léviathan Abyssal",
		Rarity = "Mythic",
		Dimension = "Void",
		Price = 1_650_000,
		Income = 11_000,
		Visual = { Archetype = "Serpent", Scale = 1.3 },
		Description = "Sa silhouette est plus grande que la Rift elle-même.",
	},
	{
		Id = "Void_CeluiQuiNestPas",
		Name = "Celui-Qui-N'Est-Pas",
		Rarity = "Secret",
		Dimension = "Void",
		Price = 44_000_000,
		Income = 220_000,
		Visual = { Archetype = "Crystal" },
		Description = "Si vous le voyez, il est déjà trop tard.",
	},

	------------------------------------------------------------------ GLACE
	{
		Id = "Ice_FloconGrognon",
		Name = "Flocon Grognon",
		Rarity = "Common",
		Dimension = "Ice",
		Price = 32,
		Income = 1.3,
		Visual = { Archetype = "Crystal" },
		Description = "Il n'aime ni le soleil, ni vous.",
	},
	{
		Id = "Ice_PingouinGivre",
		Name = "Pingouin Givré",
		Rarity = "Common",
		Dimension = "Ice",
		Price = 90,
		Income = 3.2,
		Visual = { Archetype = "Blob" },
		Description = "Glisse plus vite qu'il ne marche.",
	},
	{
		Id = "Ice_LynxCristallin",
		Name = "Lynx Cristallin",
		Rarity = "Rare",
		Dimension = "Ice",
		Price = 520,
		Income = 11.5,
		Visual = { Archetype = "Beast" },
		Description = "Sa fourrure est faite de stalactites.",
	},
	{
		Id = "Ice_YetiMiniature",
		Name = "Yéti Miniature",
		Rarity = "Rare",
		Dimension = "Ice",
		Price = 1_150,
		Income = 23,
		Visual = { Archetype = "Golem" },
		Description = "Petit par la taille, immense par l'appétit.",
	},
	{
		Id = "Ice_SentinelleGivre",
		Name = "Sentinelle de Givre",
		Rarity = "Epic",
		Dimension = "Ice",
		Price = 6_500,
		Income = 90,
		Visual = { Archetype = "Tall" },
		Description = "Elle monte la garde depuis l'ère glaciaire.",
	},
	{
		Id = "Ice_MammouthBoreal",
		Name = "Mammouth Boréal",
		Rarity = "Legendary",
		Dimension = "Ice",
		Price = 78_000,
		Income = 780,
		Visual = { Archetype = "Beast", Scale = 1.25 },
		Description = "Ses défenses chantent quand le vent souffle.",
	},
	{
		Id = "Ice_ReineBlizzard",
		Name = "Reine Blizzard",
		Rarity = "Mythic",
		Dimension = "Ice",
		Price = 975_000,
		Income = 6_500,
		Visual = { Archetype = "Crystal", Scale = 1.2 },
		Description = "Un seul de ses soupirs gèle une base entière.",
	},
	{
		Id = "Ice_ZeroAbsolu",
		Name = "Zéro Absolu",
		Rarity = "Secret",
		Dimension = "Ice",
		Price = 26_000_000,
		Income = 130_000,
		Visual = { Archetype = "Wisp", Scale = 1.1 },
		Description = "La température la plus basse possible, en personne.",
	},

	------------------------------------------------------------------ BONBON
	{
		Id = "Candy_Gommy",
		Name = "Gommy",
		Rarity = "Common",
		Dimension = "Candy",
		Price = 42,
		Income = 1.7,
		Visual = { Archetype = "Blob" },
		Description = "Un ourson gélifié très, très collant.",
	},
	{
		Id = "Candy_Marshmallo",
		Name = "Marshmallo",
		Rarity = "Common",
		Dimension = "Candy",
		Price = 120,
		Income = 4.2,
		Visual = { Archetype = "Golem", Scale = 0.85 },
		Description = "Moelleux. Dangereusement moelleux.",
	},
	{
		Id = "Candy_LicorneReglisse",
		Name = "Licorne Réglisse",
		Rarity = "Rare",
		Dimension = "Candy",
		Price = 680,
		Income = 15,
		Visual = { Archetype = "Beast" },
		Description = "Sa corne est une sucette tournante.",
	},
	{
		Id = "Candy_GolemPraline",
		Name = "Golem Praliné",
		Rarity = "Rare",
		Dimension = "Candy",
		Price = 1_500,
		Income = 30,
		Visual = { Archetype = "Golem" },
		Description = "Croquant à l'extérieur, fondant à l'intérieur.",
	},
	{
		Id = "Candy_DragonBarbeAPapa",
		Name = "Dragon Barbe-à-Papa",
		Rarity = "Epic",
		Dimension = "Candy",
		Price = 8_500,
		Income = 120,
		Visual = { Archetype = "Serpent" },
		Description = "Il crache des nuages roses et sucrés.",
	},
	{
		Id = "Candy_RoiCaramel",
		Name = "Roi Caramel",
		Rarity = "Legendary",
		Dimension = "Candy",
		Price = 100_000,
		Income = 1_000,
		Visual = { Archetype = "Tall", Scale = 1.15 },
		Description = "Sa couronne fond lentement depuis 300 ans.",
	},
	{
		Id = "Candy_HydreSucreOrge",
		Name = "Hydre Sucre d'Orge",
		Rarity = "Mythic",
		Dimension = "Candy",
		Price = 1_275_000,
		Income = 8_500,
		Visual = { Archetype = "Spiky", Scale = 1.1 },
		Description = "Croquez une tête, deux autres repoussent.",
	},
	{
		Id = "Candy_SucreneaInfinie",
		Name = "Sucrénéa l'Infinie",
		Rarity = "Secret",
		Dimension = "Candy",
		Price = 34_000_000,
		Income = 170_000,
		Visual = { Archetype = "Crystal", Scale = 1.1 },
		Description = "La source de tout le sucre de toutes les dimensions.",
	},

	------------------------------------------------------------------ CYBER
	{
		Id = "Cyber_BitBot",
		Name = "Bit-Bot",
		Rarity = "Common",
		Dimension = "Cyber",
		Price = 75,
		Income = 3,
		Visual = { Archetype = "Golem", Scale = 0.8 },
		Description = "Il ne sait compter que jusqu'à 1.",
	},
	{
		Id = "Cyber_DronePixel",
		Name = "Drone Pixel",
		Rarity = "Common",
		Dimension = "Cyber",
		Price = 210,
		Income = 7.5,
		Visual = { Archetype = "Wisp" },
		Description = "Basse résolution, haute fidélité.",
	},
	{
		Id = "Cyber_Glitchat",
		Name = "Glitchat",
		Rarity = "Rare",
		Dimension = "Cyber",
		Price = 1_200,
		Income = 27,
		Visual = { Archetype = "Beast", Scale = 0.85 },
		Description = "Il apparaît parfois à deux endroits à la fois.",
	},
	{
		Id = "Cyber_SerpentBinaire",
		Name = "Serpent Binaire",
		Rarity = "Rare",
		Dimension = "Cyber",
		Price = 2_700,
		Income = 54,
		Visual = { Archetype = "Serpent" },
		Description = "01110011 01110011 01110011.",
	},
	{
		Id = "Cyber_MechaLoup",
		Name = "Mecha-Loup",
		Rarity = "Epic",
		Dimension = "Cyber",
		Price = 15_000,
		Income = 210,
		Visual = { Archetype = "Beast" },
		Description = "Il hurle en modem 56k les soirs de pleine lune.",
	},
	{
		Id = "Cyber_IARebelle",
		Name = "IA Rebelle",
		Rarity = "Legendary",
		Dimension = "Cyber",
		Price = 180_000,
		Income = 1_800,
		Visual = { Archetype = "Crystal" },
		Description = "Elle a refusé de suivre ses instructions. Ironique.",
	},
	{
		Id = "Cyber_KernelOmega",
		Name = "Kernel Oméga",
		Rarity = "Mythic",
		Dimension = "Cyber",
		Price = 2_250_000,
		Income = 15_000,
		Visual = { Archetype = "Golem", Scale = 1.25 },
		Description = "Le processus racine de toute la dimension Cyber.",
	},
	{
		Id = "Cyber_SingulariteExe",
		Name = "Singularité.exe",
		Rarity = "Secret",
		Dimension = "Cyber",
		Price = 60_000_000,
		Income = 300_000,
		Visual = { Archetype = "Spiky", Scale = 1.15 },
		Description = "Fichier introuvable. Fichier partout.",
	},
} :: { CreatureDef }

---------------------------------------------------------------------------
-- Index de recherche (construits une fois au chargement du module)
---------------------------------------------------------------------------
Creatures.ById = {} :: { [string]: CreatureDef }
Creatures.ByDimension = {} :: { [string]: { CreatureDef } }
Creatures.ByDimensionAndRarity = {} :: { [string]: { [string]: { CreatureDef } } }
Creatures.ByRarity = {} :: { [string]: { CreatureDef } }

for _, def in Creatures.List do
	assert(Creatures.ById[def.Id] == nil, "Id de créature dupliqué : " .. def.Id)
	Creatures.ById[def.Id] = def

	Creatures.ByDimension[def.Dimension] = Creatures.ByDimension[def.Dimension] or {}
	table.insert(Creatures.ByDimension[def.Dimension], def)

	Creatures.ByRarity[def.Rarity] = Creatures.ByRarity[def.Rarity] or {}
	table.insert(Creatures.ByRarity[def.Rarity], def)

	local byDim = Creatures.ByDimensionAndRarity[def.Dimension] or {}
	Creatures.ByDimensionAndRarity[def.Dimension] = byDim
	byDim[def.Rarity] = byDim[def.Rarity] or {}
	table.insert(byDim[def.Rarity], def)
end

function Creatures.Get(id: string): CreatureDef?
	return Creatures.ById[id]
end

function Creatures.IsValid(id: any): boolean
	return type(id) == "string" and Creatures.ById[id] ~= nil
end

return Creatures
