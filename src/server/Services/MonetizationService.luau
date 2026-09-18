--!nonstrict
-- Gamepass sahipliği ve developer product satın almaları.
-- Asset ID'ler Config/Monetization içinde; 0 bırakılan ürünler sessizce pas geçilir.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)

local MonetizationService = {}

local passByAssetId: { [number]: string } = {}
local productByAssetId: { [number]: string } = {}

local function refreshPasses(player: Player)
	local runtime = DataService.runtime(player)
	for _, pass in Config.Monetization.Gamepasses do
		if pass.assetId == 0 then
			runtime.gamepasses[pass.id] = false
			continue
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.assetId)
		end)
		runtime.gamepasses[pass.id] = ok and owns or false
	end
	runtime.gamepassesReady = true
end

-- Gelir hesabı gamepass sahipliğini bekliyor (kısa, tavanlı bir bekleme).
function MonetizationService.waitForPasses(player: Player, timeout: number?): boolean
	local runtime = DataService.runtime(player)
	local deadline = os.clock() + (timeout or 5)
	while not runtime.gamepassesReady and os.clock() < deadline do
		task.wait(0.1)
		if not player.Parent then
			return false
		end
	end
	return runtime.gamepassesReady == true
end

function MonetizationService.hasPass(player: Player, passId: string): boolean
	return DataService.runtime(player).gamepasses[passId] == true
end

-- Ürün ödüllerini profile uygular. Sandık/boost/kalkan hepsi burada.
function MonetizationService.applyReward(player: Player, productId: string): boolean
	local profile = DataService.get(player)
	local reward = Config.Monetization.ProductRewards[productId]
	if not profile or not reward then
		return false
	end

	if reward.coins then
		profile.coins += reward.coins
	end
	if reward.crates then
		for crateId, amount in reward.crates do
			profile.crates[crateId] = (profile.crates[crateId] or 0) + amount
		end
	end
	if reward.boost then
		profile.boosts[reward.boost] = {
			multiplier = reward.multiplier,
			expiresAt = os.time() + reward.seconds,
		}
	end
	if reward.shieldSeconds then
		profile.shieldUntil = math.max(profile.shieldUntil, os.time()) + reward.shieldSeconds
	end
	if reward.incomeSeconds then
		-- "Süre Atlama": IncomeService'in bir sonraki tikinde hesaplanan gelir
		-- oranıyla çarpılsın diye işaret bırakıyoruz.
		profile.pendingTimeSkip = (profile.pendingTimeSkip or 0) + reward.incomeSeconds
	end

	local product = Config.Monetization.ProductById[productId]
	if product and product.oneTime then
		profile.purchases[productId] = true
	end
	return true
end

function MonetizationService.ownsOneTime(player: Player, productId: string): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.purchases[productId] == true
end

local function processReceipt(receiptInfo)
	local productId = productByAssetId[receiptInfo.ProductId]
	if not productId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Aynı makbuzu iki kez işlememek için makbuz kimliğini saklıyoruz.
	profile.receipts = profile.receipts or {}
	if profile.receipts[tostring(receiptInfo.PurchaseId)] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not MonetizationService.applyReward(player, productId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.receipts[tostring(receiptInfo.PurchaseId)] = os.time()
	DataService.save(player)

	local product = Config.Monetization.ProductById[productId]
	NotificationService.toast(player, `{product.name} hesabına eklendi!`, "good")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	for _, pass in Config.Monetization.Gamepasses do
		if pass.assetId ~= 0 then
			passByAssetId[pass.assetId] = pass.id
		end
	end
	for _, product in Config.Monetization.Products do
		if product.assetId ~= 0 then
			productByAssetId[product.assetId] = product.id
		end
	end

	DataService.Loaded:connect(function(player)
		task.spawn(refreshPasses, player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, assetId, purchased)
		if not purchased then
			return
		end
		local passId = passByAssetId[assetId]
		if passId then
			DataService.runtime(player).gamepasses[passId] = true
			NotificationService.toast(player, `{Config.Monetization.GamepassById[passId].name} aktif!`, "good")
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
