--[[
	Mutations
	=========
	Obtenues au Portail de fusion : 2 créatures IDENTIQUES (même Id, non mutées)
	=> 1 créature mutée. Le tirage utilise "Weight" (les chances sont affichées
	dans l'UI de fusion : transparence sur les tirages aléatoires).

	Espérance du multiplicateur = (50x2 + 30x3 + 15x4 + 5x5) / 100 = 2.75
	=> une fusion est toujours au moins neutre en revenu (2 créatures x1 = x2)
	ET libère un emplacement.
]]

export type Mutation = {
	Id: string,
	Name: string,
	Multiplier: number,
	Weight: number,
	Color: Color3,
	LightBrightness: number,
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
		LightBrightness = 1,
	},
	{
		Id = "Prismatic",
		Name = "Prismatique",
		Multiplier = 3,
		Weight = 30,
		Color = Color3.fromRGB(120, 255, 255),
		LightBrightness = 1.5,
	},
	{
		Id = "Abyssal",
		Name = "Abyssal",
		Multiplier = 4,
		Weight = 15,
		Color = Color3.fromRGB(150, 40, 255),
		LightBrightness = 2,
	},
	{
		Id = "Celestial",
		Name = "Céleste",
		Multiplier = 5,
		Weight = 5,
		Color = Color3.fromRGB(255, 240, 150),
		LightBrightness = 3,
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
