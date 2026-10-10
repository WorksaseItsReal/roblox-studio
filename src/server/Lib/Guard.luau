--[[
	Guard
	=====
	Point d'entrée UNIQUE de toutes les RemoteFunctions. Pour chaque appel client :
	 1. rate limiting (RateLimiter)
	 2. profil chargé (sinon refus)
	 3. validation stricte du nombre et du type de chaque argument
	 4. exécution protégée (pcall) du handler
	 5. réponse normalisée { Ok, Message, Data }

	Un handler ne reçoit donc QUE des arguments déjà validés.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local RateLimiter = require(script.Parent.RateLimiter)

local Guard = {}

-- Fonction injectée par Main : renvoie true si le profil du joueur est chargé
Guard.IsReady = function(_player: Player): boolean
	return true
end

---------------------------------------------------------------------------
-- Validateurs : chacun renvoie (ok, valeurNormalisée)
---------------------------------------------------------------------------
export type Validator = (value: any) -> (boolean, any)

Guard.T = {}

function Guard.T.String(maxLength: number): Validator
	return function(value)
		if type(value) ~= "string" or #value == 0 or #value > maxLength then
			return false, nil
		end
		return true, value
	end
end

-- Identifiant de créature possédée : "u" suivi de chiffres
function Guard.T.Uid(): Validator
	return function(value)
		if type(value) ~= "string" or #value > 16 or not value:match("^u%d+$") then
			return false, nil
		end
		return true, value
	end
end

function Guard.T.Integer(min: number, max: number): Validator
	return function(value)
		if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < min or value > max then
			return false, nil
		end
		return true, value
	end
end

-- Valeur appartenant à une liste fermée
function Guard.T.OneOf(allowed: { any }): Validator
	return function(value)
		if table.find(allowed, value) == nil then
			return false, nil
		end
		return true, value
	end
end

---------------------------------------------------------------------------
-- Liaison d'une RemoteFunction
---------------------------------------------------------------------------
export type Spec = {
	Args: { Validator }?,
	RateKey: string?,
	RequireProfile: boolean?,
}

-- handler(player, ...args) -> (ok: boolean, message: string?, data: any?)
function Guard.BindFunction(name: string, spec: Spec, handler: (Player, ...any) -> (boolean, string?, any))
	local remote = Remotes.GetFunction(name)
	local validators = spec.Args or {}
	local rateKey = spec.RateKey or name

	remote.OnServerInvoke = function(player: Player, ...)
		if not RateLimiter.Check(player, rateKey) then
			return { Ok = false, Message = "Doucement ! Réessaie dans un instant." }
		end
		if spec.RequireProfile ~= false and not Guard.IsReady(player) then
			return { Ok = false, Message = "Chargement de ta partie en cours..." }
		end

		-- Nombre d'arguments strict : tout argument en trop est un signal d'abus
		local count = select("#", ...)
		if count > #validators then
			return { Ok = false, Message = "Requête invalide." }
		end
		local args = { ... }
		for i, validate in validators do
			local ok, value = validate(args[i])
			if not ok then
				return { Ok = false, Message = "Requête invalide." }
			end
			args[i] = value
		end

		local success, ok, message, data = pcall(handler, player, table.unpack(args, 1, #validators))
		if not success then
			warn(string.format("[Guard] Erreur dans %s pour %s : %s", name, player.Name, tostring(ok)))
			return { Ok = false, Message = "Erreur serveur, réessaie." }
		end
		return { Ok = ok == true, Message = message, Data = data }
	end
end

return Guard
