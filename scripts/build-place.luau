--[[
	build-place.luau  (exécuté avec Lune, PAS dans Roblox)
	======================================================
	Prend le .rbxl produit par Rojo et y ajoute la map procédurale (MapBuilder),
	pour qu'elle soit visible dès l'ouverture dans Studio (mode édition).

	Usage :
	  rojo build default.project.json -o build/rojo.rbxl
	  lune run scripts/build-place.luau build/rojo.rbxl StealARift.rbxl
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local input = process.args[1] or "build/rojo.rbxl"
local output = process.args[2] or "StealARift.rbxl"

local game = roblox.deserializePlace(fs.readFile(input))
local workspace = game:GetService("Workspace")

-- Environnement "Roblox" minimal pour exécuter MapBuilder hors Studio
local env = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Font = roblox.Font,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	math = math,
	table = table,
	string = string,
	print = print,
	warn = warn,
	error = error,
	assert = assert,
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	select = select,
	pcall = pcall,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
}

local source = fs.readFile("src/server/Lib/MapBuilder.luau")
local MapBuilder = luau.load(source, { debugName = "MapBuilder", environment = env })()

local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
end
local map = MapBuilder.Build(workspace)

-- Ambiance par défaut : plein jour franc, couleurs vives (docs/ART_DIRECTION.md).
-- Le client (RiftVisualController) n'y ajoute qu'une légère teinte par dimension.
local lighting = game:GetService("Lighting")
lighting.ClockTime = 13
lighting.Brightness = 3
lighting.GlobalShadows = true
-- "Future" : éclairage le plus beau (lumières dynamiques, néons). Roblox réduit
-- automatiquement la qualité sur les appareils modestes.
pcall(function()
	lighting.Technology = roblox.Enum.Technology.Future
end)
lighting.EnvironmentDiffuseScale = 1
-- Reflets du ciel atténués : les plastiques lisses gardent leur couleur franche
lighting.EnvironmentSpecularScale = 0.5
lighting.Ambient = roblox.Color3.fromRGB(112, 98, 92)
lighting.OutdoorAmbient = roblox.Color3.fromRGB(162, 153, 149)
local function effect(className, name, props)
	local existing = lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local instance = roblox.Instance.new(className)
	instance.Name = name
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = lighting
end
-- Bloom discret (seuil haut : seuls les néons brillent)
effect("BloomEffect", "RiftBloom", { Intensity = 0.6, Size = 24, Threshold = 1.8 })
effect("ColorCorrectionEffect", "RiftColorCorrection", {
	Saturation = 0.2,
	Contrast = 0.08,
	TintColor = roblox.Color3.fromRGB(255, 247, 240),
})
effect("SunRaysEffect", "SunRays", { Intensity = 0.04, Spread = 0.6 })
-- Atmosphère légère : ciel bleu net, pas de brume laiteuse
effect("Atmosphere", "Atmosphere", {
	Density = 0.18,
	Offset = 0.1,
	Haze = 0.3,
	Glare = 0.1,
	Color = roblox.Color3.fromRGB(199, 220, 255),
	Decay = roblox.Color3.fromRGB(106, 132, 180),
})

fs.writeFile(output, roblox.serializePlace(game))
local count = #map:GetDescendants()
print(string.format("OK : %s (%d instances dans la map)", output, count))
