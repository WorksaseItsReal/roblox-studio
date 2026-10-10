--[[
	LeaderboardCodec
	================
	Les OrderedDataStores n'acceptent que des ENTIERS (int64). Or l'argent total d'un
	joueur peut dépasser 9.2e18 en fin de partie. On stocke donc log10(valeur + 1)
	multiplié par 1e13 : l'ordre est préservé, la précision relative est d'environ
	2e-13 (invisible à l'affichage) et la valeur max (~1e308) tient largement.
]]

local LeaderboardCodec = {}

local SCALE = 1e13

function LeaderboardCodec.Encode(value: number): number
	if value ~= value or value <= 0 then
		return 0
	end
	return math.floor(math.log10(value + 1) * SCALE)
end

function LeaderboardCodec.Decode(encoded: number): number
	if encoded <= 0 then
		return 0
	end
	return 10 ^ (encoded / SCALE) - 1
end

return LeaderboardCodec
