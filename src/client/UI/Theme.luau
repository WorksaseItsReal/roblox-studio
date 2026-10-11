--[[
	Theme
	=====
	Jetons de design de l'interface v3 « propre » (voir docs/ART_DIRECTION.md, section 2) :
	- Fredoka One partout, en casse normale ; Luckiest Guy (DisplayFont) réservée au
	  montant d'argent du HUD et aux gros textes de célébration.
	- Contours à l'encre bleu nuit (jamais de noir pur).
	- Fenêtres blanches à en-tête violet de marque, cartes claires, texte foncé sans
	  contour dans les fenêtres.
	- La couleur porte un SENS : vert = acheter / réclamer / argent, bleu = navigation,
	  rouge = danger / vol / fermer, or = récompenses / revenus, gris = indisponible,
	  violet de marque = en-têtes, sélection, onglets actifs.
	Modifiez ici pour changer le style global.
]]

local Theme = {}

---------------------------------------------------------------------------
-- Polices
---------------------------------------------------------------------------
Theme.Font = Enum.Font.FredokaOne -- tout le texte de l'interface
Theme.BodyFont = Theme.Font -- (alias : descriptions)
Theme.DisplayFont = Enum.Font.LuckiestGuy -- argent du HUD et célébrations UNIQUEMENT

---------------------------------------------------------------------------
-- Couleurs de base
---------------------------------------------------------------------------
-- Encre : tous les contours (cadres et textes blancs)
Theme.Ink = Color3.fromRGB(28, 31, 58)

-- Textes
Theme.Text = Color3.fromRGB(255, 255, 255) -- sur fond coloré ou sur le monde (avec contour encre)
Theme.TextDark = Color3.fromRGB(31, 37, 68) -- DANS les fenêtres (sans contour)
Theme.TextMuted = Color3.fromRGB(110, 118, 150) -- descriptions, informations secondaires

-- Surfaces
Theme.WindowTop = Color3.fromRGB(255, 255, 255)
Theme.WindowBottom = Color3.fromRGB(241, 244, 250)
Theme.Card = Color3.fromRGB(244, 246, 251)
Theme.CardStroke = Color3.fromRGB(217, 223, 234)
Theme.Well = Color3.fromRGB(232, 236, 245) -- fond des jauges et des zones creusées
Theme.Chip = Color3.fromRGB(232, 236, 246) -- étiquette d'information neutre
Theme.Hud = Theme.Ink -- pilules sombres semi-transparentes du HUD (événement, fil)
Theme.HudTransparency = 0.3

-- Couleurs à sens
Theme.Brand = Color3.fromRGB(122, 92, 255)
Theme.BrandDark = Color3.fromRGB(91, 63, 224)
Theme.Money = Color3.fromRGB(47, 203, 85) -- acheter, réclamer, argent
Theme.MoneyDark = Color3.fromRGB(31, 165, 68)
Theme.MoneyText = Color3.fromRGB(22, 150, 62) -- prix et gains écrits sur fond clair
Theme.Info = Color3.fromRGB(61, 139, 255) -- navigation
Theme.Danger = Color3.fromRGB(255, 77, 77) -- vol, barrière, fermer
Theme.DangerText = Color3.fromRGB(220, 50, 60) -- texte rouge sur fond clair
Theme.Gold = Color3.fromRGB(255, 201, 60) -- cadeaux, revenus par seconde
Theme.GoldText = Color3.fromRGB(196, 128, 0) -- texte or sur fond clair
Theme.Warning = Color3.fromRGB(255, 160, 40)
Theme.Disabled = Color3.fromRGB(201, 207, 219)

-- Revenus par seconde : or (comme les étiquettes des créatures)
Theme.Income = Theme.Gold

---------------------------------------------------------------------------
-- Boutons : { haut, bas, rebord } (dégradé léger, rebord inférieur plus foncé).
-- Light = true : bouton clair (texte foncé sans contour).
---------------------------------------------------------------------------
Theme.Palette = {
	Green = { Color3.fromRGB(66, 216, 104), Color3.fromRGB(40, 192, 78), Color3.fromRGB(24, 138, 56) },
	Blue = { Color3.fromRGB(92, 162, 255), Color3.fromRGB(58, 130, 246), Color3.fromRGB(36, 90, 192) },
	Red = { Color3.fromRGB(255, 108, 108), Color3.fromRGB(244, 68, 68), Color3.fromRGB(182, 38, 52) },
	Gold = { Color3.fromRGB(255, 216, 96), Color3.fromRGB(252, 190, 44), Color3.fromRGB(204, 138, 16) },
	Gray = { Color3.fromRGB(214, 219, 230), Color3.fromRGB(198, 204, 217), Color3.fromRGB(158, 166, 186) },
	Brand = { Color3.fromRGB(134, 106, 255), Color3.fromRGB(106, 76, 238), Color3.fromRGB(70, 46, 180) },
	White = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(239, 242, 249),
		Color3.fromRGB(196, 204, 222),
		Light = true,
	},
	-- Statut (plus un bouton) : plat, sans contour ni relief, texte gris-bleu
	Status = {
		Color3.fromRGB(232, 236, 246),
		Color3.fromRGB(232, 236, 246),
		Color3.fromRGB(232, 236, 246),
		Light = true,
		Flat = true,
	},
}

-- Hauteur du rebord inférieur des boutons et des tuiles (effet 3D)
Theme.LipDepth = 4

-- Icônes (emoji, rendus en couleur par Roblox)
Theme.DimensionIcons = {
	Lava = "🔥",
	Void = "🌌",
	Ice = "❄️",
	Candy = "🍭",
	Cyber = "🤖",
}

Theme.KindIcons = {
	Info = "💬",
	Success = "✅",
	Error = "❌",
	Warning = "⚠️",
	Steal = "🚨",
}

-- Liseré gauche des notifications selon leur type
Theme.KindColors = {
	Info = Theme.Info,
	Success = Theme.Money,
	Error = Theme.Danger,
	Warning = Theme.Warning,
	Steal = Theme.Danger,
}

-- Taille de référence de l'écran (l'UI est mise à l'échelle à partir de là)
Theme.ReferenceSize = Vector2.new(1280, 760)
-- Écrans peu hauts (téléphone en paysage) : disposition compacte, interface plus grande
Theme.CompactBelowHeight = 560
Theme.CompactReferenceHeight = 600

function Theme.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Theme.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

--[[
	Version franche d'une couleur : saturation et luminosité remontées (pas de pastel
	délavé). Les gris restent gris.
]]
function Theme.Vivid(color: Color3): Color3
	local hue, saturation, value = color:ToHSV()
	if saturation < 0.15 then
		return color
	end
	return Color3.fromHSV(hue, math.max(saturation, 0.75), math.max(value, 0.9))
end

-- Dégradé de bouton { haut, bas, rebord } dérivé d'une couleur quelconque
function Theme.PaletteFrom(color: Color3): { Color3 }
	return { Theme.Lighten(color, 0.14), color, Theme.Darken(color, 0.3) }
end

-- Couleur du rebord 3D sous un dégradé { haut, bas, rebord? }
function Theme.Lip(palette: { Color3 }): Color3
	return palette[3] or Theme.Darken(palette[2], 0.3)
end

-- Fond très clair teinté d'une couleur (cartes mises en avant)
function Theme.Tint(color: Color3, amount: number?): Color3
	return Theme.Card:Lerp(color, amount or 0.14)
end

return Theme
