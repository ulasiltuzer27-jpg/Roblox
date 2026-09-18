--!nonstrict
-- Sandık satın alma ve açma. Zar sunucuda atılır; istemci yalnızca
-- sonucu animasyonla gösterir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local Validate = require(ReplicatedStorage.Shared.Core.Validate)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local Contexts = require(ServerScriptService.Server.Services.Contexts)
local DataService = require(ServerScriptService.Server.Services.DataService)
local EventService = require(ServerScriptService.Server.Services.EventService)
local NetService = require(ServerScriptService.Server.Services.NetService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local CRATES = Config.Balance.Crates

local CrateService = {}

CrateService.Opened = Signal.new() -- (player, treasure)

-- Sunucu ömrü boyunca tek akış; tohum başlangıçta rastgele.
local rng = Rng.new(math.floor(os.time() % 100000) * 7919 + math.floor(os.clock() * 1000) % 7919)

local function nextUid(profile, userId: number): string
	profile.uidCounter = (profile.uidCounter or 0) + 1
	return `{userId}-{profile.uidCounter}`
end

local function countTreasures(profile): number
	local count = 0
	for _ in profile.treasures do
		count += 1
	end
	return count
end

local function queuedCrates(profile): number
	local count = 0
	for _, amount in profile.crates do
		count += amount
	end
	return count
end

function CrateService.buy(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local crateId = Validate.oneOf(payload and payload.crateId, Config.Crates.ById)
	if not crateId then
		return false, "Böyle bir sandık yok."
	end
	local amount = Validate.integer(payload.amount, 1, CRATES.bulkOpenLimit)
	if not amount then
		return false, "Geçersiz adet."
	end
	local crate = Config.Crates.get(crateId)

	if not Config.Zones.isUnlocked(crate.zone, profile.rebirths) then
		return false, `{Config.Zones.get(crate.zone).name} bölgesi henüz kilitli.`
	end
	if queuedCrates(profile) + amount > CRATES.maxQueued then
		return false, "Envanterinde çok fazla açılmamış sandık var."
	end

	if crate.currency == "tokens" then
		local cost = crate.cost * amount
		if profile.tokens < cost then
			return false, `{cost} jeton gerekiyor.`
		end
		profile.tokens -= cost
	else
		local unit = Economy.crateCost(crateId, EventService.effects().crateDiscount)
		local cost = unit * amount
		if profile.coins < cost then
			return false, "Yeterli coinin yok."
		end
		profile.coins -= cost
	end

	profile.crates[crateId] = (profile.crates[crateId] or 0) + amount
	SyncService.markDirty(player)
	return true, { crateId = crateId, amount = amount }
end

function CrateService.open(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local crateId = Validate.oneOf(payload and payload.crateId, Config.Crates.ById)
	if not crateId then
		return false, "Böyle bir sandık yok."
	end

	local owned = profile.crates[crateId] or 0
	if owned <= 0 then
		return false, "Bu sandıktan yok."
	end
	if countTreasures(profile) >= CRATES.maxInventoryTreasures then
		return false, "Envanterin dolu. Birkaç hazine sat."
	end

	local amount = Validate.integer(payload.amount, 1, math.min(owned, CRATES.bulkOpenLimit))
	if not amount then
		return false, "Geçersiz adet."
	end
	local context = {
		luck = Contexts.luck(player, profile),
		mutationLuck = Contexts.mutationLuck(player, profile),
	}

	local results = {}
	for _ = 1, amount do
		local treasure = Loot.roll(crateId, context, rng, nextUid(profile, player.UserId), os.time())
		profile.treasures[treasure.uid] = treasure
		profile.stats.cratesOpened += 1

		local placed = VaultService.autoPlace(player, profile, treasure.uid)
		table.insert(results, { treasure = treasure, placed = placed })

		if Loot.shouldAnnounce(treasure) then
			NotificationService.announce(
				`🎉 {Format.escapeRichText(player.DisplayName)} {Loot.displayName(treasure)} buldu!`,
				Config.Mutations.get(treasure.mutation).color,
				true
			)
		end
		CrateService.Opened:fire(player, treasure)
	end

	profile.crates[crateId] = owned - amount
	if profile.crates[crateId] <= 0 then
		profile.crates[crateId] = nil
	end

	SyncService.markDirty(player)
	NetService.push(player, "CrateResult", { crateId = crateId, results = results })
	return true, { results = results }
end

return CrateService
