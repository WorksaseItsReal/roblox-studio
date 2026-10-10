--[[
	MonetizationService
	===================
	Gamepasses (Argent x2, Emplacements VIP, Barrière longue, Vitesse x1.5) et
	produits développeur (Forcer une dimension, Pack de chance).

	- Possession des passes vérifiée côté serveur (UserOwnsGamePassAsync), mise en
	  cache dans les données (si l'API Roblox échoue, le cache fait foi).
	- ProcessReceipt est IDEMPOTENT : chaque PurchaseId est mémorisé dans le profil
	  et la vente n'est confirmée qu'après une sauvegarde réussie.
	- Les achats sont INITIÉS par le client (MarketplaceService:Prompt...) mais
	  seul le serveur accorde les effets.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Monetization = require(Shared.Config.Monetization)
local Dimensions = require(Shared.Config.Dimensions)
local Guard = require(script.Parent.Parent.Lib.Guard)

local MonetizationService = {}

local Services

-- Choix de dimension avant l'achat "Forcer une dimension" : [UserId] = {Dimension, At}
local dimensionChoices: { [number]: { Dimension: string, At: number } } = {}

-- Ensemble des passes effectifs du joueur
function MonetizationService.GetPasses(player: Player): { [string]: boolean }
	local passes = {}
	local data = Services.DataService.GetData(player)
	if data then
		for key in Monetization.GamePasses do
			if data.OwnedPasses[key] then
				passes[key] = true
			end
		end
	end
	if RunService:IsStudio() and GameConfig.Debug.GrantAllPassesInStudio then
		for key in Monetization.GamePasses do
			passes[key] = true
		end
	end
	return passes
end

-- Recalcule tout ce qui dépend des passes
local function applyPassEffects(player: Player)
	Services.IncomeService.Recalculate(player)
	Services.PlotService.RefreshSlotPads(player)
	Services.CharacterService.RefreshSpeed(player)
	Services.SyncService.Push(player)
end

local function refreshOwnership(player: Player)
	local data = Services.DataService.GetData(player)
	if not data then
		return
	end
	local changed = false
	for key, pass in Monetization.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			-- En cas d'erreur API, on garde la valeur en cache
			if ok and (owns == true) ~= (data.OwnedPasses[key] == true) then
				data.OwnedPasses[key] = if owns then true else nil
				changed = true
			end
		end
	end
	if changed then
		applyPassEffects(player)
	end
end

---------------------------------------------------------------------------
-- Produits développeur
---------------------------------------------------------------------------
local productHandlers: { [string]: (Player) -> () } = {
	ForceDimension = function(player: Player)
		local choice = dimensionChoices[player.UserId]
		dimensionChoices[player.UserId] = nil
		local target = if choice and os.clock() - choice.At < 120 then choice.Dimension else nil
		Services.RiftService.ForceDimension(target, player)
	end,
	LuckBoost = function(player: Player)
		local product = Monetization.Products.LuckBoost
		Services.RiftService.AddLuck(product.DurationSeconds, product.Multiplier, product.MaxStackSeconds, player)
	end,
}

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local data = player and Services.DataService.GetData(player)
	if not player or not data then
		-- Roblox réessaiera plus tard (prochaine connexion)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receipts = data.ProcessedReceipts
	if table.find(receipts, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = Monetization.GetProductKeyById(receiptInfo.ProductId)
	local handler = key and productHandlers[key]
	if not handler then
		warn("[MonetizationService] Produit inconnu : " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(handler, player)
	if not ok then
		warn("[MonetizationService] Erreur produit : " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(receipts, receiptInfo.PurchaseId)
	while #receipts > GameConfig.Data.MaxReceiptHistory do
		table.remove(receipts, 1)
	end
	-- Confirmé seulement si le reçu est bien sauvegardé
	if not Services.DataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Services.NotificationService.Notify(player, "Merci pour ton achat !", "Success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init(services)
	Services = services
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			local key = Monetization.GetPassKeyById(passId)
			local data = Services.DataService.GetData(player)
			if key and data then
				data.OwnedPasses[key] = true
				applyPassEffects(player)
				Services.DataService.SaveSoon(player)
				Services.NotificationService.Notify(
					player,
					Monetization.GamePasses[key].Name .. " activé !",
					"Success"
				)
			end
		end
	)

	Services.DataService.ProfileLoaded:Connect(function(player: Player)
		refreshOwnership(player)
	end)

	Guard.BindFunction(
		"SetDimensionChoice",
		{ Args = { Guard.T.OneOf(Dimensions.Order) } },
		function(player: Player, dimensionId: string)
			dimensionChoices[player.UserId] = { Dimension = dimensionId, At = os.clock() }
			return true
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		dimensionChoices[player.UserId] = nil
	end)
end

return MonetizationService
