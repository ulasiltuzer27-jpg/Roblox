--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

local function treasure(rarity, mutation)
	return { uid = rarity .. mutation, rarity = rarity, mutation = mutation, crate = "wood", foundAt = 0 }
end

local function context(overrides)
	local base = { upgrades = {}, rebirths = 0, zone = "hub", doubleIncome = false, eventMultiplier = 1 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

describe("Economy", function()
	it("hazine geliri nadirlik x mutasyon", function()
		expect.equal(Economy.treasureIncome(treasure("common", "normal")), 1)
		expect.equal(Economy.treasureIncome(treasure("rare", "gold")), 16 * 2.5)
		expect.equal(Economy.treasureIncome(treasure("secret", "prism")), 7500 * 150)
	end)

	it("satış değeri gelirin sabit katı", function()
		expect.equal(Economy.treasureValue(treasure("epic", "normal")), 70 * Config.Rarities.SellSeconds)
	end)

	it("çarpanlar çarpımsal birleşir", function()
		local multiplier = Economy.incomeMultiplier(context({
			upgrades = { income = 5 }, -- +%40
			rebirths = 2, -- x1.5
			doubleIncome = true, -- x2
		}))
		expect.near(multiplier, 1.4 * 1.5 * 2, 1e-9)
	end)

	it("bölge bonusu gelire yansır", function()
		local hub = Economy.incomeMultiplier(context({ zone = "hub" }))
		local void = Economy.incomeMultiplier(context({ zone = "void_vault" }))
		expect.near(void / hub, 1 + Config.Zones.get("void_vault").incomeBonus, 1e-9)
	end)

	it("boş kasa gelir üretmez", function()
		expect.equal(Economy.incomePerSecond({}, context()), 0)
	end)

	it("yerleştirilen hazineler toplanır", function()
		local placed = { treasure("common", "normal"), treasure("rare", "gold") }
		expect.equal(Economy.incomePerSecond(placed, context()), 1 + 40)
	end)

	it("slot sayısı yükseltme ve gamepass ile artar, tavanı aşmaz", function()
		expect.equal(Economy.slotCount({}, false), Config.Balance.Vault.baseSlots)
		expect.equal(Economy.slotCount({ slots = 3 }, false), Config.Balance.Vault.baseSlots + 3)
		expect.equal(
			Economy.slotCount({ slots = 3 }, true),
			Config.Balance.Vault.baseSlots + 3 + Config.Balance.Vault.extraSlotsGamepass
		)
		expect.equal(Economy.slotCount({ slots = 99 }, true), Config.Balance.Vault.maxSlots)
	end)

	it("çevrimdışı kazanç tavanlı ve verimi düşük", function()
		local rate = 10
		local eightHours = 8 * 3600
		local expected = rate * eightHours * Config.Balance.Offline.efficiency
		expect.equal(Economy.offlineEarnings(rate, eightHours, false), expected)
		-- 3 gün çevrimdışı kalsan da 8 saatten fazlası yazılmaz.
		expect.equal(Economy.offlineEarnings(rate, 3 * 86400, false), expected)
	end)

	it("Otomatik Toplama çevrimdışı tavanı büyütür", function()
		local rate = 10
		local withPass = Economy.offlineEarnings(rate, 86400, true)
		local without = Economy.offlineEarnings(rate, 86400, false)
		expect.near(withPass / without, 12 / 8, 1e-9)
	end)

	it("negatif süre para basmaz", function()
		expect.equal(Economy.offlineEarnings(10, -500, false), 0)
	end)

	it("servet = coin + birikim + hazine değeri", function()
		local profile = {
			coins = 1000,
			stash = 500,
			treasures = { a = treasure("common", "normal"), b = treasure("rare", "normal") },
		}
		local expected = 1000 + 500 + Config.Rarities.SellSeconds * (1 + 16)
		expect.equal(Economy.netWorth(profile), expected)
	end)

	it("yükseltme maliyeti üstel artar ve tavanda satın alınamaz", function()
		local first = Economy.upgradeCost("income", 0)
		local second = Economy.upgradeCost("income", 1)
		expect.greater(second, first)
		local maxLevel = Config.Upgrades.get("income").maxLevel
		expect.falsy(Economy.canAffordUpgrade(math.huge, "income", maxLevel), "tavan seviyesi")
		expect.truthy(Economy.canAffordUpgrade(math.huge, "income", maxLevel - 1))
	end)

	it("event indirimi sandık fiyatını düşürür", function()
		local full = Economy.crateCost("iron", 0)
		local discounted = Economy.crateCost("iron", 0.25)
		expect.equal(full, Config.Crates.get("iron").cost)
		expect.near(discounted, full * 0.75, 1)
	end)

	it("rebirth eşiği her seferinde büyür", function()
		expect.falsy(Economy.canRebirth(Config.Rebirth.requirement(0) - 1, 0))
		expect.truthy(Economy.canRebirth(Config.Rebirth.requirement(0), 0))
		expect.greater(Config.Rebirth.requirement(1), Config.Rebirth.requirement(0))
	end)

	it("şans çarpanı kaynakları birleştirir", function()
		local luck = Economy.luckMultiplier({
			upgrades = { luck = 5 }, -- +%20
			vip = true, -- x1.1
			boostMultiplier = 2, -- iksir
			eventLuck = 1.5, -- Şanslı Sandıklar
		})
		expect.near(luck, 1.2 * 1.1 * 2 * 1.5, 1e-9)
	end)

	it("boost yokken şans çarpanı bozulmaz", function()
		local luck = Economy.luckMultiplier({ upgrades = {}, vip = false, boostMultiplier = 0, eventLuck = 0 })
		expect.equal(luck, 1)
	end)
end)

return true
