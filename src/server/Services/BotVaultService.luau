--!nonstrict
-- NPC kasaları. Sunucuda yeterli gerçek hedef yokken soygun döngüsünün
-- durmaması için var; listede açıkça NPC olarak etiketleniyorlar.
-- Kayda yazılmıyorlar: çalınan para yoktan var edilir, bu yüzden birikimleri
-- hırsızın kendi gelirine bağlı ve tavanlı.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Bots = require(ReplicatedStorage.Shared.Core.Bots)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local Contexts = require(ServerScriptService.Server.Services.Contexts)
local DataService = require(ServerScriptService.Server.Services.DataService)

local BOTS = Config.Balance.Bots

local BotVaultService = {}

-- userId -> { profile, name, generatedAt }
local vaults: { [number]: any } = {}
local rng = Rng.new(math.floor(os.clock() * 1000) % 2147483647 + 13)

local function buildProfile(spec)
	return {
		coins = spec.netWorth - spec.stash,
		tokens = 0,
		rebirths = 0,
		zone = "hub",
		crates = {},
		treasures = {},
		placed = {},
		upgrades = {},
		defenses = spec.defenses,
		stash = spec.stash,
		shieldUntil = 0,
		jailUntil = 0,
		lastRobbedAt = 0,
		robbedBy = {},
		boosts = {},
		purchases = {},
		daily = { day = 0, lastClaimAt = 0 },
		tutorial = { step = 1, done = true },
		stats = {
			cratesOpened = 0,
			heistsWon = 0,
			heistsFailed = 0,
			timesRobbed = 0,
			coinsStolen = 0,
			coinsLost = 0,
			biggestSteal = 0,
		},
	}
end

-- Kasalar hırsıza göre ölçekleniyor; belirli aralıklarla tazeleniyor.
local function ensureVaults(player: Player)
	if not BOTS.enabled then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local income = Contexts.incomePerSecond(player, profile)
	for index = 1, BOTS.count do
		local userId = Bots.userIdFor(index)
		local existing = vaults[userId]
		if not existing or os.time() - existing.generatedAt >= BOTS.refreshSeconds then
			local spec = Bots.build(index, income, profile.rebirths, rng)
			vaults[userId] = {
				name = spec.name,
				profile = buildProfile(spec),
				generatedAt = os.time(),
			}
		end
	end
end

-- Gerçek soyulabilir hedef sayısı eşiğin altındaysa NPC kasaları listeye girer.
function BotVaultService.supplement(player: Player, realRobbableCount: number)
	if not BOTS.enabled or realRobbableCount >= BOTS.minRobbableTargets then
		return {}
	end
	ensureVaults(player)

	local entries = {}
	for index = 1, BOTS.count do
		local userId = Bots.userIdFor(index)
		local vault = vaults[userId]
		if vault then
			table.insert(entries, { userId = userId, name = vault.name, profile = vault.profile })
		end
	end
	return entries
end

function BotVaultService.find(userId: number)
	local vault = vaults[userId]
	if not vault then
		return nil
	end
	return {
		userId = userId,
		name = vault.name,
		profile = vault.profile,
		online = false,
		vipLock = false,
		bot = true,
	}
end

-- Soygun sonucu: kayıt yok, sadece bu sunucudaki geçici kasa küçülür.
function BotVaultService.applySteal(userId: number, share: number): number
	local vault = vaults[userId]
	if not vault then
		return 0
	end
	local stolen = math.floor(vault.profile.stash * share)
	vault.profile.stash -= stolen
	vault.profile.lastRobbedAt = os.time()
	vault.profile.shieldUntil = os.time() + Config.Balance.Heist.shieldAfterRobbed
	return stolen
end

return BotVaultService
