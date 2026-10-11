--[[
	Codes
	=====
	Codes promotionnels à publier sur TikTok / YouTube / Discord / X : c'est un
	des leviers de viralité les plus efficaces sur Roblox (les joueurs suivent
	tes réseaux pour ne rater aucun code).

	- La clé est le code (insensible à la casse, sans espaces).
	- Expires : timestamp Unix (UTC) après lequel le code ne marche plus, ou nil.
	- Reward  : format commun (voir GameConfig, section Récompenses).

	Astuce : publie un nouveau code à chaque mise à jour et à chaque palier de
	likes / favoris ("100KLIKES"...). Retire les anciens en mettant Expires.

	Ce fichier est côté SERVEUR uniquement (ServerScriptService) : les tricheurs
	ne peuvent pas lire la liste des codes avant leur annonce.
]]

local Codes = {}

Codes.List = {
	RIFT = {
		Reward = { Type = "Money", Base = 1000, IncomeMinutes = 1 },
		Expires = nil,
	},
	LANCEMENT = {
		Reward = { Type = "Boost", Seconds = 900 },
		Expires = nil,
	},
	PORTAIL = {
		Reward = { Type = "Creature", Rarities = { Rare = 75, Epic = 25 } },
		Expires = nil,
	},
}

-- Normalise une saisie : majuscules, sans espaces
function Codes.Normalize(input: string): string
	return (string.upper(input):gsub("%s", ""))
end

return Codes
