--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local Bots = require(ReplicatedStorage.Shared.Core.Bots)
local Heist = require(ReplicatedStorage.Shared.Core.Heist)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect
local BOTS = Config.Balance.Bots

describe("Bots (NPC kasaları)", function()
	it("yeni oyuncuya bile anlamlı birikim sunar", function()
		expect.equal(Bots.stashFor(0, 1), BOTS.minStash)
	end)

	it("birikim hırsızın gelirine göre ölçeklenir", function()
		local small = Bots.stashFor(10, 1)
		local large = Bots.stashFor(1000, 1)
		expect.greater(large, small)
		expect.equal(large, 1000 * BOTS.stashSeconds)
	end)

	it("birikim tavanı ekonomiyi kaçırmaz", function()
		local capped = Bots.stashFor(1000, 99)
		expect.equal(capped, math.floor(1000 * BOTS.stashSeconds * BOTS.maxStashMultiplier))
	end)

	it("savunmalar listede ilerledikçe ve rebirth ile güçlenir", function()
		local first = Bots.defensesFor(0, 1)
		local last = Bots.defensesFor(0, BOTS.count)
		expect.greater(
			Heist.defenseScore({
				defenses = last,
				defensePowerUpgrade = 0,
				vipLock = false,
				ownerOnline = true,
				eventDefenseMultiplier = 1,
				guardsDisabled = false,
			}),
			Heist.defenseScore({
				defenses = first,
				defensePowerUpgrade = 0,
				vipLock = false,
				ownerOnline = true,
				eventDefenseMultiplier = 1,
				guardsDisabled = false,
			})
		)
	end)

	it("ilk NPC kasasında bekçi ve kapı yok", function()
		local first = Bots.defensesFor(0, 1)
		expect.equal(first.guard, 0)
		expect.equal(first.door, 0)
		expect.greater(first.laser, 0)
	end)

	it("savunma seviyeleri tanımlı tavanı aşmaz", function()
		local maxed = Bots.defensesFor(50, BOTS.count)
		for defenseId, level in maxed do
			expect.between(level, 0, Config.Defenses.get(defenseId).maxLevel, defenseId)
			expect.between(level, 0, BOTS.maxDefenseLevel, defenseId)
		end
	end)

	it("NPC kimlikleri gerçek oyuncularla çakışmaz", function()
		for index = 1, BOTS.count do
			expect.less(Bots.userIdFor(index), 0)
			expect.truthy(Bots.isBot(Bots.userIdFor(index)))
		end
		expect.falsy(Bots.isBot(1))
		expect.falsy(Bots.isBot(123456789))
	end)

	it("üretilen kasa hedef seçimi kurallarını geçer", function()
		local rng = Rng.new(11)
		local bot = Bots.build(1, 25, 0, rng)
		local ok, reason = Heist.canRob({
			userId = 500,
			netWorth = bot.netWorth,
			jailUntil = 0,
			lastHeistAt = 0,
			lastTargetAt = 0,
		}, {
			userId = bot.userId,
			netWorth = bot.netWorth,
			stash = bot.stash,
			shieldUntil = 0,
			lastRobbedAt = 0,
		}, os.time())
		expect.truthy(ok, reason)
	end)

	it("isimler listeden döner", function()
		expect.equal(Bots.nameFor(1), BOTS.names[1])
		expect.equal(Bots.nameFor(#BOTS.names + 1), BOTS.names[1])
	end)
end)

return true
