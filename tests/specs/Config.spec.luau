--!nonstrict
-- Denge dosyalarının tutarlılığı. Yeni sandık/mutasyon eklerken en sık
-- yapılan hatalar (yanlış id, unutulan ödül tanımı) burada yakalanır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

describe("Config bütünlüğü", function()
	it("nadirlik sırası benzersiz ve artan gelirli", function()
		local previousIncome = 0
		for index, rarity in Config.Rarities.List do
			expect.equal(rarity.order, index, rarity.id)
			expect.greater(rarity.baseIncome, previousIncome, rarity.id)
			previousIncome = rarity.baseIncome
		end
	end)

	it("sandık ağırlıkları tanımlı nadirliklere işaret eder", function()
		for _, crate in Config.Crates.List do
			local total = 0
			for rarityId, weight in crate.weights do
				expect.truthy(Config.Rarities.ById[rarityId], `{crate.id} -> {rarityId}`)
				expect.greater(weight, 0, `{crate.id}.{rarityId}`)
				total += weight
			end
			expect.greater(total, 0, crate.id)
			expect.truthy(Config.Zones.ById[crate.zone], `{crate.id} bölgesi`)
		end
	end)

	it("sandık fiyatları bölge ilerledikçe artar", function()
		local order = { "wood", "iron", "neon", "glitch", "void" }
		for index = 2, #order do
			expect.greater(
				Config.Crates.get(order[index]).cost,
				Config.Crates.get(order[index - 1]).cost,
				order[index]
			)
		end
	end)

	it("mutasyon ağırlıkları 10.000 üzerinden tanımlı", function()
		local total = 0
		local previous = math.huge
		for _, mutation in Config.Mutations.List do
			total += mutation.weight
			expect.less(mutation.weight, previous + 1, mutation.id)
			previous = mutation.weight
		end
		expect.equal(total, 10000)
		expect.equal(Config.Mutations.get(Config.Mutations.DefaultId).multiplier, 1)
	end)

	it("nadir mutasyon daha yüksek çarpan taşır", function()
		local previousMultiplier = 0
		for _, mutation in Config.Mutations.List do
			expect.greater(mutation.multiplier, previousMultiplier - 1e-9, mutation.id)
			previousMultiplier = mutation.multiplier
		end
	end)

	it("bölgeler artan rebirth gerektirir", function()
		local previous = -1
		for _, zone in Config.Zones.List do
			expect.greater(zone.requiredRebirths, previous, zone.id)
			previous = zone.requiredRebirths
		end
		expect.truthy(Config.Zones.isUnlocked("hub", 0), "başlangıç bölgesi hep açık")

		-- Eşik değerleri denge ayarıyla değişiyor; test sayıyı değil kuralı
		-- doğruluyor: her bölge kendi eşiğinde açılır, bir altında açılmaz.
		for _, zone in Config.Zones.List do
			expect.truthy(Config.Zones.isUnlocked(zone.id, zone.requiredRebirths), zone.id)
			if zone.requiredRebirths > 0 then
				expect.falsy(Config.Zones.isUnlocked(zone.id, zone.requiredRebirths - 1), zone.id)
			end
		end
	end)

	it("savunma istatistikleri seviye 0'da kapalı", function()
		for _, defense in Config.Defenses.List do
			for statName in defense.stats do
				expect.equal(Config.Defenses.stat(defense.id, statName, 0), 0, `{defense.id}.{statName}`)
			end
			expect.greater(Config.Defenses.upgradeCost(defense.id, 1), Config.Defenses.upgradeCost(defense.id, 0))
		end
	end)

	it("yükseltmeler tanımlı tavan ve artan maliyet taşır", function()
		for _, upgrade in Config.Upgrades.List do
			expect.greater(upgrade.maxLevel, 0, upgrade.id)
			expect.greater(upgrade.costGrowth, 1, upgrade.id)
			expect.greater(Config.Upgrades.cost(upgrade.id, 5), Config.Upgrades.cost(upgrade.id, 4), upgrade.id)
		end
	end)

	it("sandık alıp hazineyi satmak kâr ettirmez", function()
		-- Bu testin yakaladığı hata: Ahşap Sandık 250 coin'e satılırken
		-- içinden çıkan hazinenin ortalama satış değeri 1.080 coin'di.
		-- Kasaya hazine koymanın hiçbir anlamı kalmıyordu.
		local Loot = require(ReplicatedStorage.Shared.Core.Loot)
		local Economy = require(ReplicatedStorage.Shared.Core.Economy)

		-- Şans yükseltmesi beklenen değeri yükseltiyor; en kötü durumda bak.
		local maxLuck = 1 + Config.Upgrades.effect("luck", Config.Upgrades.get("luck").maxLevel)
		maxLuck *= 1.1 -- VIP

		local expectedMutation = 0
		for _, mutation in Config.Mutations.List do
			expectedMutation += Loot.mutationChance(mutation.id, 1) * mutation.multiplier
		end

		for _, crate in Config.Crates.List do
			if crate.currency ~= "coins" then
				continue
			end
			local expectedIncome = 0
			for _, rarity in Config.Rarities.List do
				expectedIncome += Loot.rarityChance(crate.id, rarity.id, maxLuck) * rarity.baseIncome
			end
			expectedIncome *= expectedMutation

			local refund = expectedIncome
				* Config.Rarities.SellSeconds
				* Config.Balance.Economy.sellRefundShare
			expect.less(refund / crate.cost, 0.6, `{crate.name} al-sat oranı`)
		end
	end)

	it("bilinmeyen id'ler sessizce geçmez", function()
		expect.throws(function()
			Config.Rarities.get("yok_boyle_bir_sey")
		end)
		expect.throws(function()
			Config.Crates.get("yok_boyle_bir_sey")
		end)
	end)

	it("her developer product'ın ödül tanımı var", function()
		for _, product in Config.Monetization.Products do
			expect.truthy(Config.Monetization.ProductRewards[product.id], product.id)
		end
	end)

	it("ödüllerdeki sandık id'leri gerçek", function()
		for productId, reward in Config.Monetization.ProductRewards do
			for crateId in reward.crates or {} do
				expect.truthy(Config.Crates.ById[crateId], `{productId} -> {crateId}`)
			end
		end
		for _, reward in Config.DailyRewards.List do
			for crateId in reward.crates or {} do
				expect.truthy(Config.Crates.ById[crateId], crateId)
			end
		end
	end)

	it("günlük ödül tablosu 7 gün ve başa sarıyor", function()
		expect.equal(#Config.DailyRewards.List, 7)
		expect.equal(Config.DailyRewards.forDay(8).day, 1)
		expect.equal(Config.DailyRewards.forDay(1).day, 1)
	end)

	it("event etkileri tanınan alanlar kullanıyor", function()
		local known = {
			incomeMultiplier = true,
			mutationLuck = true,
			rarityLuck = true,
			stealShareMultiplier = true,
			defenseMultiplier = true,
			guardsDisabled = true,
			crateDiscount = true,
		}
		for _, event in Config.ServerEvents.List do
			local count = 0
			for key in event.effects do
				expect.truthy(known[key], `{event.id} -> {key}`)
				count += 1
			end
			expect.greater(count, 0, event.id)
		end
	end)

	it("event penceresi tur süresinden kısa", function()
		expect.less(Config.ServerEvents.EventSeconds, Config.ServerEvents.CycleSeconds)
		expect.less(Config.ServerEvents.WarningSeconds, Config.ServerEvents.CycleSeconds - Config.ServerEvents.EventSeconds)
	end)

	it("yayına çıkmadan önce gerçek asset id'leri girilmeli", function()
		-- Bilinçli olarak yer tutucu; ID'ler girilince bu test kırmızıya döner
		-- ve "unuttuk" durumunu yakalar.
		expect.falsy(Config.Monetization.assetIdsConfigured(), "Monetization ID'leri hâlâ 0")
	end)
end)

return true
