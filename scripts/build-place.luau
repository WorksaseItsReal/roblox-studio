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

-- Petits réglages d'ambiance par défaut
local lighting = game:GetService("Lighting")
lighting.ClockTime = 15
lighting.Brightness = 2

fs.writeFile(output, roblox.serializePlace(game))
local count = #map:GetDescendants()
print(string.format("OK : %s (%d instances dans la map)", output, count))
