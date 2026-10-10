--[[
	RateLimiter
	===========
	Token bucket par joueur et par action. Chaque action dispose de "Burst" jetons
	qui se régénèrent à "Rate" jetons par seconde (voir GameConfig.RateLimits).
	Un client qui spamme une RemoteFunction est simplement ignoré.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local RateLimiter = {}

type Bucket = { Tokens: number, Last: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

-- Renvoie true si l'action est autorisée (et consomme un jeton)
function RateLimiter.Check(player: Player, key: string): boolean
	local config = GameConfig.RateLimits[key] or GameConfig.RateLimits.Default
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { Tokens = config.Burst, Last = now }
		playerBuckets[key] = bucket
	end

	-- Régénération proportionnelle au temps écoulé
	bucket.Tokens = math.min(config.Burst, bucket.Tokens + (now - bucket.Last) * config.Rate)
	bucket.Last = now

	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function RateLimiter.Clear(player: Player)
	buckets[player] = nil
end

return RateLimiter
