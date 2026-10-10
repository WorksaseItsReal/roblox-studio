--[[
	Monetization
	============
	Remplacez les Id = 0 par les vrais identifiants après avoir créé les Game Passes
	et Developer Products dans le Creator Dashboard (Monetization > Passes / Developer
	Products). Tant qu'un Id vaut 0, l'achat correspondant est désactivé proprement.

	Les produits développeur sont des effets SERVEUR (tout le serveur en profite) :
	- ForceDimension : change immédiatement la dimension de la Rift (le joueur peut
	  choisir la dimension avant l'achat)
	- LuckBoost : chance x2 pour TOUT le serveur pendant 10 min (cumulable en durée).
	  Le chemin de la Rift étant partagé, une chance "personnelle" n'aurait aucun sens.
]]

local Monetization = {}

Monetization.GamePasses = {
	DoubleMoney = {
		Id = 0,
		Name = "Argent x2",
		Description = "Double tous tes revenus, pour toujours.",
	},
	VipSlots = {
		Id = 0,
		Name = "Emplacements VIP",
		Description = "+3 emplacements de créatures dans ta base.",
	},
	LongBarrier = {
		Id = 0,
		Name = "Barrière longue",
		Description = "+30 s de durée de barrière.",
	},
	Speed = {
		Id = 0,
		Name = "Vitesse x1.5",
		Description = "Cours 50 % plus vite.",
	},
}

-- Ordre d'affichage dans la boutique
Monetization.PassOrder = { "DoubleMoney", "VipSlots", "LongBarrier", "Speed" }

Monetization.Products = {
	ForceDimension = {
		Id = 0,
		Name = "Forcer une dimension",
		Description = "Change immédiatement la dimension de la Rift pour tout le serveur.",
	},
	LuckBoost = {
		Id = 0,
		Name = "Pack de chance",
		Description = "Chance x2 (Épique et +) pour tout le serveur pendant 10 minutes.",
		DurationSeconds = 600,
		Multiplier = 2,
		MaxStackSeconds = 3600, -- plafond de cumul
	},
}

Monetization.ProductOrder = { "ForceDimension", "LuckBoost" }

-- Recherche inverse Id -> clé
function Monetization.GetPassKeyById(passId: number): string?
	for key, pass in Monetization.GamePasses do
		if pass.Id ~= 0 and pass.Id == passId then
			return key
		end
	end
	return nil
end

function Monetization.GetProductKeyById(productId: number): string?
	for key, product in Monetization.Products do
		if product.Id ~= 0 and product.Id == productId then
			return key
		end
	end
	return nil
end

return Monetization
