--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

local function sumChances(crateId, luck)
	local total = 0
	for _, rarity in Config.Rarities.List do
		total += Loot.rarityChance(crateId, rarity.id, luck)
	end
	return total
end

describe("Loot", function()
	it("nadirlik ihtimalleri toplamı 1", function()
		expect.near(sumChances("wood", 1), 1, 1e-9)
		expect.near(sumChances("void", 2.5), 1, 1e-9)
	end)

	it("sandıkta olmayan nadirliğin şansı sıfır", function()
		expect.equal(Loot.rarityChance("wood", "secret", 5), 0)
	end)

	it("şans arttıkça üst kademeler artar, sıradan azalır", function()
		local baseLegendary = Loot.rarityChance("iron", "legendary", 1)
		local luckyLegendary = Loot.rarityChance("iron", "legendary", 2)
		expect.greater(luckyLegendary, baseLegendary, "efsanevi şansı")

		local baseCommon = Loot.rarityChance("iron", "common", 1)
		local luckyCommon = Loot.rarityChance("iron", "common", 2)
		expect.less(luckyCommon, baseCommon, "sıradan şansı")
	end)

	it("şans, alt iki kademenin ağırlığını bükmez", function()
		-- Tasarım kararı: luck yalnızca Nadir ve üstünü etkiler.
		local weightsBase = Loot.weightsFor("iron", 1)
		local weightsLucky = Loot.weightsFor("iron", 3)
		expect.equal(weightsBase.common, weightsLucky.common)
		expect.equal(weightsBase.uncommon, weightsLucky.uncommon)
	end)

	it("mutasyon ihtimalleri toplamı 1 ve Prizma nadir kalır", function()
		local total = 0
		for _, mutation in Config.Mutations.List do
			total += Loot.mutationChance(mutation.id, 1)
		end
		expect.near(total, 1, 1e-9)
		expect.near(Loot.mutationChance("prism", 1), 0.0002, 1e-9, "prizma şansı")
	end)

	it("mutasyon şansı eventte artar ama normal ağırlığı sabit kalır", function()
		local normalWeights = Loot.mutationWeights(1)
		local eventWeights = Loot.mutationWeights(2)
		expect.equal(normalWeights.normal, eventWeights.normal)
		expect.equal(eventWeights.prism, normalWeights.prism * 2)
		expect.greater(Loot.mutationChance("prism", 2), Loot.mutationChance("prism", 1))
	end)

	it("aynı tohum aynı hazineyi verir", function()
		local context = { luck = 1.4, mutationLuck = 1 }
		local first = Loot.roll("iron", context, Rng.new(4242), "a", 0)
		local second = Loot.roll("iron", context, Rng.new(4242), "b", 0)
		expect.equal(first.rarity, second.rarity)
		expect.equal(first.mutation, second.mutation)
	end)

	it("üretilen hazineler hep geçerli tanımlara işaret eder", function()
		local rng = Rng.new(1)
		local context = { luck = 1, mutationLuck = 1 }
		for index = 1, 2000 do
			local treasure = Loot.roll("neon", context, rng, tostring(index), 0)
			expect.truthy(Config.Rarities.ById[treasure.rarity], "nadirlik tanımı")
			expect.truthy(Config.Mutations.ById[treasure.mutation], "mutasyon tanımı")
		end
	end)

	it("Efsanevi ve Glitch duyuru eşiğini geçer", function()
		expect.truthy(Loot.shouldAnnounce({ rarity = "legendary", mutation = "normal" }))
		expect.truthy(Loot.shouldAnnounce({ rarity = "common", mutation = "glitch" }))
		expect.falsy(Loot.shouldAnnounce({ rarity = "rare", mutation = "gold" }))
	end)

	it("isimlendirme mutasyonu öne alır", function()
		expect.equal(Loot.displayName({ rarity = "epic", mutation = "normal" }), "Epik")
		expect.equal(Loot.displayName({ rarity = "epic", mutation = "neon" }), "Neon Epik")
	end)
end)

return true
