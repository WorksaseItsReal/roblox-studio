--[[
	Upgrades
	========
	Améliorations de base achetées avec l'argent du jeu (conservées après un rebirth).
	Le coût du niveau N (1-indexé) = BaseCost x Growth^(N-1).
]]

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number,
	Growth: number,
	LevelText: (level: number) -> string,
}

local Upgrades = {}

Upgrades.List = {
	{
		Id = "Slots",
		Name = "Emplacements",
		Description = "+1 emplacement de créature par niveau.",
		MaxLevel = 10,
		BaseCost = 1_000,
		Growth = 2.6,
		LevelText = function(level: number): string
			return string.format("+%d emplacement(s)", level)
		end,
	},
	{
		Id = "Barrier",
		Name = "Barrière renforcée",
		Description = "+10 s de durée de barrière par niveau.",
		MaxLevel = 6,
		BaseCost = 2_500,
		Growth = 3,
		LevelText = function(level: number): string
			return string.format("+%d s", level * 10)
		end,
	},
	{
		Id = "Alarm",
		Name = "Alarme anti-vol",
		Description = "Niv.1 : alerte d'intrusion. Niv.2 : intrus surligné. Niv.3 : voleurs ralentis.",
		MaxLevel = 3,
		BaseCost = 5_000,
		Growth = 10,
		LevelText = function(level: number): string
			return if level == 0 then "Aucune" else ("Niveau " .. level)
		end,
	},
} :: { Upgrade }

Upgrades.ById = {} :: { [string]: Upgrade }
for _, upgrade in Upgrades.List do
	Upgrades.ById[upgrade.Id] = upgrade
end

function Upgrades.Get(id: string): Upgrade?
	return Upgrades.ById[id]
end

-- Coût pour passer du niveau "currentLevel" au suivant (nil si niveau max)
function Upgrades.GetCost(id: string, currentLevel: number): number?
	local upgrade = Upgrades.ById[id]
	if not upgrade or currentLevel >= upgrade.MaxLevel then
		return nil
	end
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ currentLevel)
end

return Upgrades
