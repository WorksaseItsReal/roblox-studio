--[[
	Theme
	=====
	Couleurs et polices de l'interface. Modifiez ici pour changer le style global.
]]

local Theme = {
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamBold,

	Background = Color3.fromRGB(22, 20, 36),
	Surface = Color3.fromRGB(36, 33, 58),
	SurfaceLight = Color3.fromRGB(52, 48, 82),
	Stroke = Color3.fromRGB(120, 90, 255),
	Text = Color3.fromRGB(245, 245, 255),
	TextDim = Color3.fromRGB(170, 165, 200),

	Primary = Color3.fromRGB(120, 90, 255),
	Success = Color3.fromRGB(70, 200, 110),
	Danger = Color3.fromRGB(235, 80, 90),
	Warning = Color3.fromRGB(255, 180, 50),
	Money = Color3.fromRGB(110, 255, 120),
	Gold = Color3.fromRGB(255, 210, 70),
	Disabled = Color3.fromRGB(80, 78, 100),

	Corner = UDim.new(0, 12),
}

return Theme
