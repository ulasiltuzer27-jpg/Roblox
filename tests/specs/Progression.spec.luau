--!nonstrict
-- Uçtan uca ilerleme simülasyonu. Tek tek doğru olan sayıların bir arada
-- da anlamlı olduğunu doğruluyor: yeni oyuncunun ilk 10 dakikası, soygun
-- ödülünün gelire oranı, rebirth'e giden yol.
--
-- Denge değiştiğinde en önce burası kırılır; kırılması "yanlış" demek değil,
-- "kararı yeniden ver" demek.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Heist = require(ReplicatedStorage.Shared.Core.Heist)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

local function newProfile()
	return {
		coins = Config.Balance.Economy.startingCoins,
		stash = 0,
		treasures = {},
		placed = {},
		upgrades = {},
		defenses = {},
		rebirths = 0,
		zone = "hub",
	}
end

local function incomeContext(profile)
	return {
		upgrades = profile.upgrades,
		rebirths = profile.rebirths,
		zone = profile.zone,
		doubleIncome = false,
		eventMultiplier = 1,
	}
end

local function placedTreasures(profile)
	local placed = {}
	for _, uid in profile.placed do
		table.insert(placed, profile.treasures[uid])
	end
	return placed
end

local function incomePerSecond(profile)
	return Economy.incomePerSecond(placedTreasures(profile), incomeContext(profile))
end

local function treasureCount(profile): number
	local count = 0
	for _ in profile.treasures do
		count += 1
	end
	return count
end

-- Envanter dolunca oyuncu yerleştirilmemişleri satar (sunucu da bunu
-- zorluyor: dolu envanterle sandık açılamıyor).
local function sellLoose(profile)
	local placedSet = {}
	for _, uid in profile.placed do
		placedSet[uid] = true
	end
	for uid, treasure in profile.treasures do
		if not placedSet[uid] then
			profile.coins += Economy.treasureValue(treasure)
			profile.treasures[uid] = nil
		end
	end
end

-- Sunucudaki davranışın aynısı: boş yuva varsa yerleştir, yuva doluysa
-- en zayıf hazineyi daha iyisiyle değiştir.
local function openCrate(profile, crateId, rng, counter, slots)
	local treasure = Loot.roll(crateId, { luck = 1, mutationLuck = 1 }, rng, tostring(counter), 0)
	profile.treasures[treasure.uid] = treasure

	if #profile.placed < slots then
		table.insert(profile.placed, treasure.uid)
		return treasure
	end

	local worstIndex, worstIncome = nil, math.huge
	for index, uid in profile.placed do
		local income = Economy.treasureIncome(profile.treasures[uid])
		if income < worstIncome then
			worstIndex, worstIncome = index, income
		end
	end
	if worstIndex and Economy.treasureIncome(treasure) > worstIncome then
		profile.placed[worstIndex] = treasure.uid
	end

	if treasureCount(profile) >= Config.Balance.Crates.maxInventoryTreasures then
		sellLoose(profile)
	end
	return treasure
end

-- Basit oyuncu: parası yettikçe en pahalı açabildiği sandığı alır ve açar.
local function simulate(seconds: number, seed: number)
	local profile = newProfile()
	local rng = Rng.new(seed)
	local counter = 0
	local slots = Economy.slotCount(profile.upgrades, false)

	-- Başlangıç sandıkları
	for crateId, amount in Config.Balance.Economy.starterCrates do
		for _ = 1, amount do
			counter += 1
			openCrate(profile, crateId, rng, counter, slots)
		end
	end

	local affordable = { "iron", "wood" }
	for _ = 1, seconds do
		profile.coins += incomePerSecond(profile)

		for _, crateId in affordable do
			local cost = Economy.crateCost(crateId, 0)
			if profile.coins >= cost and Config.Zones.isUnlocked(Config.Crates.get(crateId).zone, profile.rebirths) then
				profile.coins -= cost
				counter += 1
				openCrate(profile, crateId, rng, counter, slots)
				break
			end
		end
	end

	return profile, counter
end

describe("İlerleme simülasyonu", function()
	it("ilk dakikada gelir akmaya başlar", function()
		local profile = simulate(60, 4242)
		expect.greater(incomePerSecond(profile), 0, "1. dakika geliri")
		expect.greater(#profile.placed, 0, "yerleştirilmiş hazine")
	end)

	it("başlangıç sandıkları yuvaları hemen doldurmaz", function()
		-- 3 ücretsiz sandık, 6 yuva: oyuncunun doldurması gereken boşluk kalsın.
		local profile = newProfile()
		local rng = Rng.new(7)
		local slots = Economy.slotCount(profile.upgrades, false)
		local counter = 0
		for crateId, amount in Config.Balance.Economy.starterCrates do
			for _ = 1, amount do
				counter += 1
				openCrate(profile, crateId, rng, counter, slots)
			end
		end
		expect.between(#profile.placed, 1, slots - 1, "başlangıç doluluğu")
	end)

	it("10 dakikada gelir belirgin şekilde büyür", function()
		local early = simulate(60, 99)
		local later = simulate(600, 99)
		expect.greater(incomePerSecond(later), incomePerSecond(early) * 2, "10 dakikalık büyüme")
	end)

	it("10 dakikada yuvalar dolar", function()
		local profile = simulate(600, 1234)
		expect.equal(#profile.placed, Economy.slotCount(profile.upgrades, false))
	end)

	it("tipik oyuncu ilk 10 dakikada rebirth'e ulaşmaz", function()
		-- Hedef: oyuncu rebirth'ten önce temel döngüyü (soygun dahil) görsün.
		-- Tek tohum şanslı gidebileceği için ortancaya bakıyoruz.
		local worths = {}
		for seed = 1, 11 do
			table.insert(worths, Economy.netWorth(simulate(600, seed * 137)))
		end
		table.sort(worths)
		local median = worths[math.ceil(#worths / 2)]
		expect.falsy(Economy.canRebirth(median, 0), `10 dakikalık ortanca servet {median}`)
	end)

	it("yirmi dakikada ortanca oyuncu rebirth'e ulaşır", function()
		local worths = {}
		for seed = 1, 11 do
			table.insert(worths, Economy.netWorth(simulate(1200, seed * 137)))
		end
		table.sort(worths)
		local median = worths[math.ceil(#worths / 2)]
		expect.truthy(Economy.canRebirth(median, 0), `20 dakikalık ortanca servet {median}`)
	end)

	it("bir saatte rebirth her tohumda erişilebilir", function()
		-- Şansı kötü giden oyuncu da tıkanıp kalmasın.
		for seed = 1, 5 do
			local profile = simulate(3600, seed * 991)
			expect.truthy(
				Economy.canRebirth(Economy.netWorth(profile), 0),
				`tohum {seed}: bir saatte rebirth gelmeli`
			)
		end
	end)

	it("soygun ödülü birkaç dakikalık gelire denk", function()
		local profile = simulate(600, 31)
		local rate = incomePerSecond(profile)
		local stash = rate * 1800 -- yarım saatlik birikim biriktirmiş bir hedef

		local share = Heist.stealShare({
			carryUpgrade = 0,
			perfect = false,
			defenseScore = 0,
			ownerOnline = true,
			eventShareMultiplier = 1,
		})
		local payout = Heist.payout(stash, share)

		-- Kazanç anlamlı olmalı ama bir soygun günü bitirmemeli.
		expect.greater(payout / rate, 120, "en az 2 dakikalık gelir")
		expect.less(payout / rate, 900, "en fazla 15 dakikalık gelir")
	end)

	it("iyi savunulan kasa soygunu değersizleştirmez", function()
		local strongDefense = Heist.defenseScore({
			defenses = { laser = 8, trap = 8, sensor = 8, guard = 8, door = 6 },
			defensePowerUpgrade = 20,
			vipLock = true,
			ownerOnline = true,
			eventDefenseMultiplier = 1,
			guardsDisabled = false,
		})
		local share = Heist.stealShare({
			carryUpgrade = 0,
			perfect = false,
			defenseScore = strongDefense,
			ownerOnline = true,
			eventShareMultiplier = 1,
		})
		-- En güçlü savunma bile payı yarıdan fazla kısamaz.
		expect.greater(share, Config.Balance.Heist.baseStealShare * 0.5 - 1e-9)
	end)

	it("farklı tohumlar benzer tempo üretir", function()
		-- Şans kötü gitse bile oyuncu takılıp kalmasın.
		local rates = {}
		for seed = 1, 6 do
			table.insert(rates, incomePerSecond(simulate(600, seed * 137)))
		end
		table.sort(rates)
		local slowest, fastest = rates[1], rates[#rates]
		expect.greater(slowest, 0)
		expect.less(fastest / slowest, 12, "tohumlar arası fark")
	end)
end)

return true
