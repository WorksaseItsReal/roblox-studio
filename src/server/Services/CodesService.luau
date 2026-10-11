--[[
	CodesService
	============
	Codes promotionnels (config côté serveur : ServerScriptService.Server.Config.Codes).
	Chaque code ne peut être utilisé qu'une fois par joueur (mémorisé dans ses
	données). Rate limiting strict pour empêcher de deviner les codes en masse.
]]

local Codes = require(script.Parent.Parent.Config.Codes)
local Guard = require(script.Parent.Parent.Lib.Guard)

local CodesService = {}

local Services

local function redeem(player: Player, input: string): (boolean, string?)
	local code = Codes.Normalize(input)
	local entry = Codes.List[code]
	if not entry then
		return false, "Code invalide."
	end
	if entry.Expires and os.time() > entry.Expires then
		return false, "Ce code a expiré."
	end
	local data = Services.DataService.GetData(player)
	if data.RedeemedCodes[code] then
		return false, "Tu as déjà utilisé ce code."
	end
	data.RedeemedCodes[code] = true
	local text = Services.RewardService.Grant(player, entry.Reward)
	Services.DataService.SaveSoon(player)
	return true, "Code activé : " .. text
end

function CodesService.Init(services)
	Services = services
end

function CodesService.Start()
	Guard.BindFunction("RedeemCode", { Args = { Guard.T.String(32) } }, redeem)
end

return CodesService
