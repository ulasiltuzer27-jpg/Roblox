--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local Heist = require(ReplicatedStorage.Shared.Core.Heist)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect
local HEIST = Config.Balance.Heist

local function defenseContext(overrides)
	local base = {
		defenses = {},
		defensePowerUpgrade = 0,
		vipLock = false,
		ownerOnline = true,
		eventDefenseMultiplier = 1,
		guardsDisabled = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function shareContext(overrides)
	local base = {
		carryUpgrade = 0,
		perfect = false,
		defenseScore = 0,
		ownerOnline = true,
		eventShareMultiplier = 1,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function thief(overrides)
	local base = { userId = 1, netWorth = 100000, jailUntil = 0, lastHeistAt = 0, lastTargetAt = 0 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function target(overrides)
	local base = { userId = 2, netWorth = 100000, stash = 50000, shieldUntil = 0, lastRobbedAt = 0 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

describe("Heist - savunma puanı", function()
	it("savunmasız kasanın puanı sıfır", function()
		expect.equal(Heist.defenseScore(defenseContext()), 0)
	end)

	it("seviye arttıkça puan artar", function()
		local low = Heist.defenseScore(defenseContext({ defenses = { laser = 2 } }))
		local high = Heist.defenseScore(defenseContext({ defenses = { laser = 6 } }))
		expect.greater(high, low)
	end)

	it("Bekçi Grevi eventinde bekçiler puana katılmaz", function()
		local normal = Heist.defenseScore(defenseContext({ defenses = { guard = 5 } }))
		local strike = Heist.defenseScore(defenseContext({ defenses = { guard = 5 }, guardsDisabled = true }))
		expect.greater(normal, 0)
		expect.equal(strike, 0)
	end)

	it("VIP Kilit ve çevrimdışı bonusu çarpan olarak biner", function()
		local base = Heist.defenseScore(defenseContext({ defenses = { laser = 4 } }))
		local vip = Heist.defenseScore(defenseContext({ defenses = { laser = 4 }, vipLock = true }))
		local offline = Heist.defenseScore(defenseContext({ defenses = { laser = 4 }, ownerOnline = false }))
		expect.near(vip / base, 1.35, 1e-9)
		expect.near(offline / base, 1 + HEIST.offlineDefenseBonus, 1e-9)
	end)
end)

describe("Heist - çalınan pay", function()
	it("savunmasız kasada taban pay uygulanır", function()
		expect.near(Heist.stealShare(shareContext()), HEIST.baseStealShare, 1e-9)
	end)

	it("mükemmel soygun payı artırır", function()
		local normal = Heist.stealShare(shareContext())
		local perfect = Heist.stealShare(shareContext({ perfect = true }))
		expect.near(perfect - normal, HEIST.perfectBonus, 1e-9)
	end)

	it("savunma payı düşürür ama tavanı var", function()
		local weak = Heist.stealShare(shareContext({ defenseScore = 50 }))
		local strong = Heist.stealShare(shareContext({ defenseScore = 400 }))
		local absurd = Heist.stealShare(shareContext({ defenseScore = 100000 }))
		expect.less(strong, weak)
		-- Savunma payı en fazla yarı yarıya kısabilir; soygun hiçbir zaman anlamsızlaşmaz.
		expect.near(absurd, HEIST.baseStealShare * (1 - HEIST.defenseShareCap), 1e-9)
	end)

	it("çevrimdışı savunanın kaybı yarıya iner", function()
		local online = Heist.stealShare(shareContext())
		local offline = Heist.stealShare(shareContext({ ownerOnline = false }))
		expect.near(offline / online, HEIST.offlineDefenderShareMultiplier, 1e-9)
	end)

	it("pay hiçbir koşulda tavanı geçmez", function()
		local maxed = Heist.stealShare(shareContext({
			carryUpgrade = Config.Upgrades.get("carry").maxLevel,
			perfect = true,
			eventShareMultiplier = 2,
		}))
		expect.between(maxed, 0.01, HEIST.maxStealShareBoosted)
	end)

	it("Kasa Fırtınası olmadan normal tavan geçerli", function()
		local maxed = Heist.stealShare(shareContext({
			carryUpgrade = Config.Upgrades.get("carry").maxLevel,
			perfect = true,
		}))
		expect.between(maxed, 0.01, HEIST.maxStealShare)
	end)
end)

describe("Heist - alarm", function()
	it("kaynak varken dolar, yokken düşer", function()
		local alarm = Heist.stepAlarm(0, 40, 1)
		expect.near(alarm, 40, 1e-9)
		alarm = Heist.stepAlarm(alarm, 0, 1)
		expect.near(alarm, 40 - HEIST.alarmDecayPerSecond, 1e-9)
	end)

	it("alarm 0 ile kapasite arasında kalır", function()
		expect.equal(Heist.stepAlarm(0, 0, 10), 0)
		expect.equal(Heist.stepAlarm(90, 500, 1), HEIST.alarmCapacity)
	end)

	it("kapasiteye ulaşınca yakalanırsın", function()
		expect.falsy(Heist.isCaught(HEIST.alarmCapacity - 0.01))
		expect.truthy(Heist.isCaught(HEIST.alarmCapacity))
	end)

	it("stealth yükseltmesi alarmı yavaşlatır ama sıfırlamaz", function()
		expect.equal(Heist.stealthFactor(0), 1)
		expect.less(Heist.stealthFactor(10), 1)
		expect.greater(Heist.stealthFactor(Config.Upgrades.get("stealth").maxLevel), 0.35)
	end)

	it("mükemmel soygun eşiği alarmın dörtte biri", function()
		expect.truthy(Heist.isPerfect(HEIST.alarmCapacity * HEIST.perfectAlarmThreshold))
		expect.falsy(Heist.isPerfect(HEIST.alarmCapacity * HEIST.perfectAlarmThreshold + 1))
	end)
end)

describe("Heist - hedef seçimi", function()
	it("uygun hedefe girilebilir", function()
		local ok, reason = Heist.canRob(thief(), target(), 1000)
		expect.truthy(ok, reason)
		expect.equal(reason, "ok")
	end)

	it("kendi kasanı soyamazsın", function()
		local ok, reason = Heist.canRob(thief({ userId = 5 }), target({ userId = 5 }), 1000)
		expect.falsy(ok)
		expect.equal(reason, "self")
	end)

	it("hapisteyken soygun yok", function()
		local _, reason = Heist.canRob(thief({ jailUntil = 2000 }), target(), 1000)
		expect.equal(reason, "jailed")
	end)

	it("kilitli kasaya girilemez", function()
		local _, reason = Heist.canRob(thief(), target({ shieldUntil = 2000 }), 1000)
		expect.equal(reason, "shielded")
	end)

	it("aynı kasaya arka arkaya girilemez", function()
		local _, reason = Heist.canRob(thief({ lastTargetAt = 900 }), target(), 1000)
		expect.equal(reason, "same_target")
	end)

	it("az önce soyulan kasa korunur", function()
		local _, reason = Heist.canRob(thief(), target({ lastRobbedAt = 980 }), 1000)
		expect.equal(reason, "vault_cooldown")
	end)

	it("boş kasa hedef olmaz", function()
		local _, reason = Heist.canRob(thief(), target({ stash = 0 }), 1000)
		expect.equal(reason, "empty")
	end)

	it("yeni oyuncular korunur", function()
		local _, reason = Heist.canRob(
			thief({ netWorth = 1000 }),
			target({ netWorth = HEIST.newbieProtectionNetWorth - 1 }),
			1000
		)
		expect.equal(reason, "newbie")
	end)

	it("kendinden çok fakir kasa avlanamaz", function()
		local _, reason = Heist.canRob(thief({ netWorth = 1000000 }), target({ netWorth = 100000 }), 1000)
		expect.equal(reason, "too_poor")
	end)

	it("yukarı doğru soygun serbest", function()
		local ok = Heist.canRob(thief({ netWorth = 10000 }), target({ netWorth = 5000000 }), 1000)
		expect.truthy(ok, "zengin hedefe girilebilmeli")
	end)

	it("her ret sebebinin bir metni var", function()
		for _, reason in { "self", "jailed", "cooldown", "same_target", "shielded", "vault_cooldown", "empty", "newbie", "too_poor", "ok" } do
			expect.truthy(Heist.ReasonText[reason], reason)
		end
	end)
end)

describe("Heist - ödüller", function()
	it("pay kadar coin alınır", function()
		expect.equal(Heist.payout(10000, 0.25), 2500)
		expect.equal(Heist.payout(0, 0.5), 0)
		expect.equal(Heist.payout(-100, 0.5), 0)
	end)

	it("yakalanan hırsız tazminat bırakır", function()
		expect.equal(Heist.caughtBounty(10000), math.floor(10000 * HEIST.caughtBountyShare))
	end)

	it("VIP hapis süresini yarıya indirir", function()
		expect.equal(Heist.jailSeconds(false), HEIST.jailSeconds)
		expect.equal(Heist.jailSeconds(true), HEIST.jailSeconds * HEIST.vipJailMultiplier)
	end)
end)

return true
