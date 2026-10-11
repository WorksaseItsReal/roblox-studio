--[[
	BaseDefenseService
	==================
	Barrière (verrou de base) + alarme anti-vol.

	Barrière :
	- Activée par le propriétaire (bouton dans la base ou UI). Durée = 60 s
	  + améliorations + gamepass, puis recharge.
	- La VRAIE protection est côté serveur : StealService refuse tout vol tant que
	  la barrière est active. Le mur physique n'est qu'un obstacle (un tricheur
	  peut toujours traverser un mur en local, il ne pourra pas voler) ; on le
	  voit sous forme de faisceaux laser rouges en travers de l'entrée.
	- Le propriétaire traverse sa propre barrière : son client la rend non
	  collidable localement (PlotController).
	- À l'activation, les intrus présents dans la base sont expulsés devant l'entrée.

	Alarme (amélioration, 3 niveaux) : voir GameConfig.Alarm.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Modules.Economy)
local Format = require(Shared.Modules.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local BaseDefenseService = {}

local Services

local activeTokens: { [any]: any } = {}
-- intruders[plot][player] = true tant que l'intrus est dans la base
local intruders: { [any]: { [Player]: boolean } } = {}
local lastAlert: { [string]: number } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function BaseDefenseService.IsBarrierActive(plot): boolean
	return plot.Model:GetAttribute("BarrierActive") == true
end

local LENS_ON = Color3.fromRGB(255, 28, 40)
local LENS_OFF = Color3.fromRGB(90, 24, 30)

-- Lentilles des émetteurs (pièces « LaserLens » de la base, optionnelles) : rouge
-- vif seulement quand la base est verrouillée (rouge = danger), éteintes sinon
local function setLenses(plot, active: boolean)
	for _, child in plot.Model:GetChildren() do
		if child.Name == "LaserLens" and child:IsA("BasePart") then
			child.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
			child.Color = if active then LENS_ON else LENS_OFF
		end
	end
end

-- La pièce Barrier est le mur LOGIQUE (collision). Le visuel, ce sont les lasers
-- rouges du dossier Plot.Lasers (attribut optionnel ActiveTransparency par pièce) ;
-- une map manuelle sans lasers affiche la barrière elle-même.
-- Les lasers ne passent en néon que pendant le verrouillage (docs/ART_DIRECTION.md :
-- néon rare) ; cachés, ils restent en SmoothPlastic.
local function setBarrierVisual(plot, active: boolean)
	plot.Barrier.CanCollide = active
	setLenses(plot, active)
	local lasers = plot.Model:FindFirstChild("Lasers")
	if not lasers then
		plot.Barrier.Transparency = if active then 0.35 else 1
		return
	end
	plot.Barrier.Transparency = 1
	for _, laser in lasers:GetDescendants() do
		if laser:IsA("BasePart") then
			local shown = laser:GetAttribute("ActiveTransparency")
			laser.Transparency = if active then (if type(shown) == "number" then shown else 0) else 1
			laser.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end
-- Exposé pour les aperçus de la map hors Roblox (base verrouillée simulée)
BaseDefenseService.SetBarrierVisual = setBarrierVisual

local function deactivate(plot)
	activeTokens[plot] = nil
	plot.Model:SetAttribute("BarrierActive", false)
	setBarrierVisual(plot, false)
	if plot.Owner then
		Services.NotificationService.Notify(plot.Owner, "Ta barrière est tombée !", "Warning")
	end
end

-- Base libérée (le propriétaire part)
function BaseDefenseService.ResetPlot(plot)
	activeTokens[plot] = nil
	intruders[plot] = nil
	plot.Model:SetAttribute("BarrierActive", false)
	plot.Model:SetAttribute("BarrierEndsAt", 0)
	plot.Model:SetAttribute("BarrierCooldownEndsAt", 0)
	setBarrierVisual(plot, false)
end

-- Renvoie hors de la base tout joueur autre que le propriétaire. Appelé à l'activation
-- puis en continu tant que la barrière est active : les murs se franchissent en
-- grimpant (pyramide de joueurs, buissons), seule la vérification serveur fait foi.
local function expelIntruders(plot, owner: Player?)
	local exit = CFrame.new(plot.ShortcutLanding.Position + Vector3.new(0, 4, 0)) * plot.ShortcutLanding.CFrame.Rotation
	for _, other in Players:GetPlayers() do
		if other ~= owner then
			local root = Services.CharacterService.GetRootPart(other)
			if root and Services.MapService.IsInsidePlot(plot, root.Position) then
				Services.CharacterService.TeleportTo(other, exit)
				Services.NotificationService.Notify(
					other,
					if owner
						then "La barrière de " .. owner.DisplayName .. " t'a expulsé !"
						else "Cette base est protégée par une barrière !",
					"Warning"
				)
			end
		end
	end
end

local function activate(player: Player): (boolean, string?)
	local plot = Services.PlotService.GetPlot(player)
	local data = Services.DataService.GetData(player)
	if not plot or not data then
		return false, "Tu n'as pas de base."
	end
	if BaseDefenseService.IsBarrierActive(plot) then
		return false, "Ta barrière est déjà active."
	end
	local t = serverNow()
	local cooldownEndsAt = plot.Model:GetAttribute("BarrierCooldownEndsAt") or 0
	if t < cooldownEndsAt then
		return false, "Barrière en recharge : " .. Format.Time(cooldownEndsAt - t)
	end

	local duration = Economy.GetBarrierDuration(data, Services.MonetizationService.GetPasses(player))
	local endsAt = t + duration
	plot.Model:SetAttribute("BarrierActive", true)
	plot.Model:SetAttribute("BarrierEndsAt", endsAt)
	plot.Model:SetAttribute("BarrierCooldownEndsAt", endsAt + GameConfig.Barrier.Cooldown)
	setBarrierVisual(plot, true)

	expelIntruders(plot, player)

	local token = {}
	activeTokens[plot] = token
	task.delay(duration, function()
		if activeTokens[plot] == token then
			deactivate(plot)
		end
	end)
	Services.QuestService.RecordEvent(player, "Barrier", 1)
	return true, "Barrière activée pour " .. Format.Time(duration) .. " !"
end

---------------------------------------------------------------------------
-- Alarme
---------------------------------------------------------------------------
local function scanIntruders()
	for _, plot in Services.MapService.GetPlots() do
		local owner: Player? = plot.Owner
		-- Barrière active : personne d'autre que le propriétaire ne reste dedans
		-- (indépendant de l'amélioration Alarme)
		if BaseDefenseService.IsBarrierActive(plot) then
			expelIntruders(plot, owner)
		end
		local data = owner and Services.DataService.GetData(owner)
		local level = if data then data.Upgrades.Alarm else 0
		if not owner or level <= 0 then
			intruders[plot] = nil
			continue
		end
		local inside = intruders[plot] or {}
		intruders[plot] = inside
		for _, other in Players:GetPlayers() do
			if other == owner then
				continue
			end
			local root = Services.CharacterService.GetRootPart(other)
			local isInside = root ~= nil and Services.MapService.IsInsidePlot(plot, root.Position)
			if isInside and not inside[other] then
				inside[other] = true
				local key = owner.UserId .. ":" .. other.UserId
				if os.clock() - (lastAlert[key] or -math.huge) > 10 then
					lastAlert[key] = os.clock()
					Services.NotificationService.Notify(
						owner,
						"Intrus : " .. other.DisplayName .. " est entré dans ta base !",
						"Warning"
					)
					if level >= 2 then
						Services.NotificationService.Effect(owner, "HighlightIntruder", {
							UserId = other.UserId,
							Duration = GameConfig.Alarm.HighlightSeconds,
						})
					end
				end
			elseif not isInside then
				inside[other] = nil
			end
		end
	end
end

function BaseDefenseService.Init(services)
	Services = services
end

function BaseDefenseService.Start()
	Guard.BindFunction("ActivateBarrier", {}, activate)

	-- Bouton physique dans chaque base. État visuel de départ cohérent (lasers cachés,
	-- lentilles éteintes) même pour une map faite à la main
	for _, plot in Services.MapService.GetPlots() do
		setBarrierVisual(plot, false)
		local prompt = plot.LockButton:FindFirstChild("LockPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player: Player)
				if plot.Owner ~= player or not RateLimiter.Check(player, "ActivateBarrier") then
					return
				end
				local ok, message = activate(player)
				Services.NotificationService.Notify(player, message or "", if ok then "Success" else "Error")
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, inside in intruders do
			inside[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.Alarm.ScanIntervalSeconds)
			local ok, err = pcall(scanIntruders)
			if not ok then
				warn("[BaseDefenseService] " .. tostring(err))
			end
		end
	end)
end

return BaseDefenseService
