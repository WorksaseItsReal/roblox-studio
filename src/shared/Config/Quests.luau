--[[
	Quests
	======
	Quêtes quotidiennes : chaque joueur reçoit 3 quêtes par jour UTC, tirées de
	façon déterministe (même joueur + même jour = mêmes quêtes sur tous les
	serveurs). Terminer les 3 donne un bonus.

	Champs :
	- Id      : identifiant stable (sauvegardé)
	- Text    : texte affiché, %d remplacé par l'objectif
	- Event   : événement serveur qui fait progresser la quête
	            (Buy, BuyRare, Steal, Fuse, Barrier, Minute, Recover)
	- Goals   : objectif selon la difficulté (1 = facile ... 3 = difficile)
	- Weight  : probabilité relative d'être tirée
	- Reward  : récompense (format GameConfig), multipliée par la difficulté
]]

local Quests = {}

Quests.PerDay = 3

Quests.Pool = {
	{
		Id = "Buy",
		Text = "Achète %d créatures",
		Event = "Buy",
		Goals = { 5, 10, 20 },
		Weight = 3,
		Reward = { Type = "Money", Base = 300, IncomeMinutes = 2 },
	},
	{
		Id = "BuyRare",
		Text = "Achète %d créatures Rares ou mieux",
		Event = "BuyRare",
		Goals = { 2, 4, 7 },
		Weight = 2,
		Reward = { Type = "Money", Base = 500, IncomeMinutes = 3 },
	},
	{
		Id = "Steal",
		Text = "Réussis %d vols",
		Event = "Steal",
		Goals = { 1, 2, 4 },
		Weight = 2,
		Reward = { Type = "Money", Base = 800, IncomeMinutes = 4 },
	},
	{
		Id = "Fuse",
		Text = "Fais %d fusions",
		Event = "Fuse",
		Goals = { 1, 2, 3 },
		Weight = 1,
		Reward = { Type = "Money", Base = 600, IncomeMinutes = 3 },
	},
	{
		Id = "Barrier",
		Text = "Active ta barrière %d fois",
		Event = "Barrier",
		Goals = { 2, 3, 5 },
		Weight = 1,
		Reward = { Type = "Money", Base = 250, IncomeMinutes = 2 },
	},
	{
		Id = "Minute",
		Text = "Joue %d minutes",
		Event = "Minute",
		Goals = { 10, 20, 35 },
		Weight = 2,
		Reward = { Type = "Money", Base = 400, IncomeMinutes = 3 },
	},
}

-- Bonus quand les 3 quêtes du jour sont réclamées
Quests.CompletionBonus = {
	Type = "Bundle",
	Rewards = {
		{ Type = "Boost", Seconds = 900 },
		{ Type = "Creature", Rarities = { Epic = 70, Legendary = 30 } },
	},
}

Quests.ById = {}
for _, quest in Quests.Pool do
	Quests.ById[quest.Id] = quest
end

function Quests.Get(id: string)
	return Quests.ById[id]
end

return Quests
