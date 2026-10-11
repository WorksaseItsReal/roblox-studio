--[[
	Theme
	=====
	Système de design de l'interface (style « Steal a … », voir docs/ART_DIRECTION.md) :
	couleurs vives et saturées, contours NOIRS épais, gros textes ronds (Luckiest Guy),
	boutons 3D avec rebord inférieur plus foncé.
	Code couleur constant : vert = argent / acheter, or = récompenses,
	rouge = danger / vol / barrière, bleu = navigation / infos, violet = rare / magique.
	Modifiez ici pour changer le style global.
]]

local Theme = {}

Theme.Font = Enum.Font.LuckiestGuy -- titres, boutons, montants, grands chiffres
Theme.BodyFont = Enum.Font.FredokaOne -- textes courants, descriptions, étiquettes

-- Contour de TOUT (texte et cadres) : noir pur
Theme.Ink = Color3.fromRGB(0, 0, 0)

Theme.Text = Color3.fromRGB(255, 255, 255)
Theme.TextDim = Color3.fromRGB(225, 235, 255)
Theme.TextDark = Color3.fromRGB(16, 40, 104)

-- Fenêtres et cartes (haut -> bas du dégradé)
Theme.PanelTop = Color3.fromRGB(66, 160, 255)
Theme.PanelBottom = Color3.fromRGB(30, 92, 220)
Theme.CardTop = Color3.fromRGB(110, 190, 255)
Theme.CardBottom = Color3.fromRGB(60, 130, 240)
Theme.Inset = Color3.fromRGB(18, 52, 140)

Theme.Money = Color3.fromRGB(80, 255, 90) -- argent, prix, gains
Theme.Gold = Color3.fromRGB(255, 215, 40) -- récompenses, revenus par seconde
Theme.Danger = Color3.fromRGB(255, 60, 60) -- vol, barrière, alertes
Theme.Info = Color3.fromRGB(40, 140, 255) -- navigation, infos
Theme.Magic = Color3.fromRGB(170, 70, 255) -- rare, magique (rebirth, fusion)

-- Revenus par seconde : jaune-or (comme les étiquettes des créatures)
Theme.Income = Theme.Gold

-- Palette des boutons : { haut, bas } (le rebord 3D est dérivé du bas)
Theme.Palette = {
	Green = { Color3.fromRGB(125, 240, 70), Color3.fromRGB(30, 178, 45) },
	Blue = { Color3.fromRGB(80, 186, 255), Color3.fromRGB(22, 104, 236) },
	Purple = { Color3.fromRGB(204, 120, 255), Color3.fromRGB(128, 44, 226) },
	Orange = { Color3.fromRGB(255, 186, 60), Color3.fromRGB(246, 112, 14) },
	Red = { Color3.fromRGB(255, 96, 96), Color3.fromRGB(222, 24, 40) },
	Gold = { Color3.fromRGB(255, 236, 80), Color3.fromRGB(252, 166, 0) },
	Pink = { Color3.fromRGB(255, 124, 206), Color3.fromRGB(226, 42, 150) },
	Cyan = { Color3.fromRGB(90, 232, 255), Color3.fromRGB(0, 164, 226) },
	Teal = { Color3.fromRGB(80, 236, 186), Color3.fromRGB(0, 170, 134) },
	Royal = { Color3.fromRGB(122, 124, 255), Color3.fromRGB(66, 46, 230) },
	Gray = { Color3.fromRGB(206, 212, 224), Color3.fromRGB(128, 136, 154) },
	Dark = { Color3.fromRGB(62, 104, 200), Color3.fromRGB(26, 56, 142) },
}

-- Assombrissement du rebord inférieur des boutons (effet 3D)
Theme.LipDarken = 0.42

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

Theme.KindPalette = {
	Info = "Blue",
	Success = "Green",
	Error = "Red",
	Warning = "Orange",
	Steal = "Red",
}

-- Taille de référence de l'écran (l'UI est mise à l'échelle à partir de là)
Theme.ReferenceSize = Vector2.new(1280, 760)
-- Écrans peu hauts (téléphone en paysage) : disposition compacte, interface plus grande
Theme.CompactBelowHeight = 560
Theme.CompactReferenceHeight = 640

function Theme.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Theme.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

--[[
	Version franche d'une couleur : saturation et luminosité remontées (zéro pastel
	délavé, ex. la Glace bleu bébé devient un cyan vif). Les gris restent gris.
]]
function Theme.Vivid(color: Color3): Color3
	local hue, saturation, value = color:ToHSV()
	if saturation < 0.15 then
		return color
	end
	return Color3.fromHSV(hue, math.max(saturation, 0.8), math.max(value, 0.9))
end

-- Dégradé { haut, bas } vif dérivé d'une couleur quelconque (raretés, dimensions)
function Theme.PaletteFrom(color: Color3): { Color3 }
	local vivid = Theme.Vivid(color)
	return { Theme.Lighten(vivid, 0.3), Theme.Darken(vivid, 0.12) }
end

-- Couleur du rebord 3D sous un dégradé { haut, bas }
function Theme.Lip(palette: { Color3 }): Color3
	return Theme.Darken(palette[2], Theme.LipDarken)
end

return Theme
