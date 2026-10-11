--[[
	StormSchedule
	=============
	Calendrier de la "Tempête de la Rift", calculé uniquement à partir de l'heure
	UTC : tous les serveurs du monde ont la tempête au même moment, sans aucune
	communication entre eux. Fonction pure (testable hors Roblox).
]]

local StormSchedule = {}

export type StormConfig = {
	IntervalMinutes: number,
	OffsetMinutes: number,
	DurationSeconds: number,
}

export type StormState = {
	Active: boolean,
	StartsAt: number, -- début de la tempête en cours, ou de la prochaine
	EndsAt: number,
}

function StormSchedule.Get(now: number, config: StormConfig): StormState
	local period = config.IntervalMinutes * 60
	local offset = config.OffsetMinutes * 60
	local cycleStart = math.floor((now - offset) / period) * period + offset
	if now < cycleStart + config.DurationSeconds then
		return { Active = true, StartsAt = cycleStart, EndsAt = cycleStart + config.DurationSeconds }
	end
	local nextStart = cycleStart + period
	return { Active = false, StartsAt = nextStart, EndsAt = nextStart + config.DurationSeconds }
end

return StormSchedule
