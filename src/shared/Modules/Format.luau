--[[
	Format
	======
	Formatage des nombres, de l'argent et des durées pour l'UI.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 15 -> "15", 2.5 -> "2.5"
function Format.Number(value: number): string
	if value ~= value then -- NaN
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)

	local text
	if value < 1000 then
		-- Garde une décimale pour les petits revenus (ex : 2.5/s)
		if value % 1 == 0 then
			text = tostring(math.floor(value))
		else
			text = string.format("%.1f", value):gsub("%.0$", "")
		end
	else
		local index = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
		local scaled = value / (1000 ^ index)
		local formatted
		if scaled >= 100 then
			formatted = string.format("%d", math.floor(scaled))
		elseif scaled >= 10 then
			formatted = string.format("%.1f", math.floor(scaled * 10) / 10)
		else
			formatted = string.format("%.2f", math.floor(scaled * 100) / 100)
		end
		-- Retire les zéros inutiles : "1.50" -> "1.5", "2.00" -> "2"
		formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
		text = formatted .. SUFFIXES[index + 1]
	end

	return if negative then "-" .. text else text
end

function Format.Money(value: number): string
	return "$" .. Format.Number(value)
end

function Format.Income(value: number): string
	return "$" .. Format.Number(value) .. "/s"
end

-- 65 -> "1:05", 3725 -> "1h 02m"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 0.125 -> "12.5 %", 0.00042 -> "0.042 %"
function Format.Percent(ratio: number): string
	local percent = ratio * 100
	if percent >= 10 then
		return string.format("%.1f %%", percent)
	elseif percent >= 1 then
		return string.format("%.2f %%", percent)
	elseif percent >= 0.01 then
		return string.format("%.3f %%", percent)
	elseif percent > 0 then
		return string.format("%.5f %%", percent)
	end
	return "0 %"
end

-- Majuscules qui gèrent les accents français (string.upper ne traite que l'ASCII)
local ACCENTS = {
	["é"] = "É",
	["è"] = "È",
	["ê"] = "Ê",
	["ë"] = "Ë",
	["à"] = "À",
	["â"] = "Â",
	["ä"] = "Ä",
	["î"] = "Î",
	["ï"] = "Ï",
	["ô"] = "Ô",
	["ö"] = "Ö",
	["ù"] = "Ù",
	["û"] = "Û",
	["ü"] = "Ü",
	["ç"] = "Ç",
	["œ"] = "Œ",
	["æ"] = "Æ",
}
function Format.Upper(text: string): string
	local upper = string.upper(text)
	for lower, capital in ACCENTS do
		upper = string.gsub(upper, lower, capital)
	end
	return upper
end

return Format
