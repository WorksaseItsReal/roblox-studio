--[[
	Theme
	=====
	Système de design de l'interface (style "simulateur") :
	contours épais sombres, dégradés, boutons 3D, texte arrondi avec contour.
	Modifiez ici pour changer le style global.
]]

local Theme = {}

Theme.Font = Enum.Font.FredokaOne -- titres, boutons, chiffres
Theme.BodyFont = Enum.Font.GothamBold -- descriptions

-- Couleur des contours (texte et cadres)
Theme.Ink = Color3.fromRGB(26, 16, 48)

Theme.Text = Color3.fromRGB(255, 255, 255)
Theme.TextDim = Color3.fromRGB(206, 196, 255)
Theme.TextDark = Color3.fromRGB(40, 30, 70)

-- Fenêtres et cartes (haut -> bas du dégradé)
Theme.PanelTop = Color3.fromRGB(86, 70, 168)
Theme.PanelBottom = Color3.fromRGB(46, 36, 104)
Theme.CardTop = Color3.fromRGB(112, 96, 200)
Theme.CardBottom = Color3.fromRGB(76, 62, 156)
Theme.Inset = Color3.fromRGB(34, 26, 74)

Theme.Money = Color3.fromRGB(120, 255, 120)
Theme.Gold = Color3.fromRGB(255, 214, 70)
Theme.Danger = Color3.fromRGB(255, 80, 90)

-- Palette des boutons : { haut, bas }
Theme.Palette = {
	Green = { Color3.fromRGB(130, 240, 110), Color3.fromRGB(40, 170, 70) },
	Blue = { Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 118, 235) },
	Purple = { Color3.fromRGB(210, 140, 255), Color3.fromRGB(128, 68, 230) },
	Orange = { Color3.fromRGB(255, 196, 96), Color3.fromRGB(240, 118, 30) },
	Red = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(220, 44, 64) },
	Gold = { Color3.fromRGB(255, 236, 120), Color3.fromRGB(245, 168, 26) },
	Pink = { Color3.fromRGB(255, 160, 224), Color3.fromRGB(228, 76, 170) },
	Cyan = { Color3.fromRGB(120, 244, 255), Color3.fromRGB(28, 168, 224) },
	Teal = { Color3.fromRGB(120, 245, 200), Color3.fromRGB(30, 170, 140) },
	Gray = { Color3.fromRGB(178, 172, 200), Color3.fromRGB(104, 98, 132) },
	Dark = { Color3.fromRGB(96, 84, 160), Color3.fromRGB(60, 50, 118) },
}

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

function Theme.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Theme.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Dégradé { haut, bas } dérivé d'une couleur quelconque (raretés, dimensions)
function Theme.PaletteFrom(color: Color3): { Color3 }
	return { Theme.Lighten(color, 0.25), Theme.Darken(color, 0.25) }
end

return Theme
