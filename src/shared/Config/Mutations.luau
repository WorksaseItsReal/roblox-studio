--[[
	Mutations
	=========
	Obtenues au Portail de fusion : 2 créatures IDENTIQUES (même Id, non mutées)
	=> 1 créature mutée. Le tirage utilise "Weight" (les chances sont affichées
	dans l'UI de fusion : transparence sur les tirages aléatoires).

	Espérance du multiplicateur = (50x2 + 30x3 + 15x4 + 5x5) / 100 = 2.75
	=> une fusion est toujours au moins neutre en revenu (2 créatures x1 = x2)
	ET libère un emplacement.

	Champs visuels (CreatureVisuals) : une mutation remplace les couleurs de la
	créature (Body / Belly / Limb, mélangées à hauteur de Mix), donne sa couleur aux
	accents (Accent, en plastique plein) et ajoute un effet propre (Effect). Chacune doit
	se lire de loin sans surcharger la créature (docs/ART_DIRECTION.md, section 4) :
	  Instable    : couleurs d'origine, deux éclairs jaunes qui jaillissent de la tête
	  Prismatique : corps arc-en-ciel animé (vif mais pas criard), sans pièce en plus
	  Abyssal     : bioluminescence des grands fonds (bleu nuit, taches cyan lumineuses,
	                leurre de baudroie), distinct du violet du Néant et des Épiques
	  Céleste     : statue d'or, auréole lumineuse et ailes d'ange blanches
	LightBrightness : lumière douce posée sous la créature (une seule par créature).
]]

export type Mutation = {
	Id: string,
	Name: string,
	Multiplier: number,
	Weight: number,
	Color: Color3, -- couleur de la mutation (textes, lumière, particules)
	GradientColors: { Color3 }?, -- dégradé de l'étiquette, de gauche à droite (sinon dérivé de Color)
	LightBrightness: number,
	Body: Color3?, -- couleurs qui remplacent celles de la créature (nil : inchangée)
	Belly: Color3?,
	Limb: Color3?,
	Mix: number, -- part des couleurs de la mutation dans le mélange (0..1)
	Accent: Color3, -- couleur des accents (plastique plein ; lueurs Abyssales, auréole Céleste)
	Effect: string, -- effet propre : "Shards" | "Prism" | "Abyss" | "Halo"
}

local Mutations = {}

-- Valeur sauvegardée pour une créature non mutée
Mutations.None = "None"

Mutations.List = {
	{
		Id = "Unstable",
		Name = "Instable",
		Multiplier = 2,
		Weight = 50,
		Color = Color3.fromRGB(255, 120, 40),
		LightBrightness = 0.8,
		Mix = 0,
		Accent = Color3.fromRGB(255, 200, 40),
		Effect = "Shards",
	},
	{
		Id = "Prismatic",
		Name = "Prismatique",
		Multiplier = 3,
		Weight = 30,
		Color = Color3.fromRGB(90, 220, 255),
		GradientColors = {
			Color3.fromRGB(255, 70, 190),
			Color3.fromRGB(0, 225, 255),
			Color3.fromRGB(255, 230, 0),
			Color3.fromRGB(150, 90, 255),
		},
		LightBrightness = 1,
		Mix = 0, -- le corps devient arc-en-ciel (CreatureVisuals)
		Accent = Color3.fromRGB(255, 255, 255),
		Effect = "Prism",
	},
	{
		Id = "Abyssal",
		Name = "Abyssal",
		Multiplier = 4,
		Weight = 15,
		Color = Color3.fromRGB(0, 225, 200),
		LightBrightness = 1.2,
		Body = Color3.fromRGB(18, 30, 62),
		Belly = Color3.fromRGB(16, 104, 124),
		Limb = Color3.fromRGB(10, 16, 38),
		Mix = 0.85,
		Accent = Color3.fromRGB(40, 255, 225),
		Effect = "Abyss",
	},
	{
		Id = "Celestial",
		Name = "Céleste",
		Multiplier = 5,
		Weight = 5,
		Color = Color3.fromRGB(255, 214, 60),
		LightBrightness = 1.5,
		-- Or chaud : un jaune pur vire au kaki dans l'ombre
		Body = Color3.fromRGB(255, 196, 62),
		Belly = Color3.fromRGB(255, 248, 232),
		Limb = Color3.fromRGB(240, 148, 34),
		Mix = 0.9,
		Accent = Color3.fromRGB(255, 212, 76),
		Effect = "Halo",
	},
} :: { Mutation }

Mutations.ById = {} :: { [string]: Mutation }
local totalWeight = 0
for _, mutation in Mutations.List do
	Mutations.ById[mutation.Id] = mutation
	totalWeight += mutation.Weight
end
Mutations.TotalWeight = totalWeight

function Mutations.Get(id: string?): Mutation?
	if id == nil or id == Mutations.None then
		return nil
	end
	return Mutations.ById[id]
end

function Mutations.GetMultiplier(id: string?): number
	local mutation = Mutations.Get(id)
	return if mutation then mutation.Multiplier else 1
end

-- Tirage pondéré (serveur uniquement : le Random passé en paramètre est serveur)
function Mutations.Roll(rng: Random): Mutation
	local roll = rng:NextNumber() * totalWeight
	for _, mutation in Mutations.List do
		roll -= mutation.Weight
		if roll <= 0 then
			return mutation
		end
	end
	return Mutations.List[1]
end

return Mutations
