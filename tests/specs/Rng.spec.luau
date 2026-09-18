--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

describe("Rng", function()
	it("aynı tohumdan aynı diziyi üretir", function()
		local a, b = Rng.new(12345), Rng.new(12345)
		for _ = 1, 50 do
			expect.equal(Rng.nextInteger(a), Rng.nextInteger(b))
		end
	end)

	it("farklı tohum farklı dizi verir", function()
		local a, b = Rng.new(1), Rng.new(2)
		expect.truthy(Rng.nextInteger(a) ~= Rng.nextInteger(b))
	end)

	it("nextNumber [0,1) aralığında kalır", function()
		local rng = Rng.new(99)
		for _ = 1, 500 do
			local value = Rng.nextNumber(rng)
			expect.between(value, 0, 0.9999999)
		end
	end)

	it("int sınırları aşmaz", function()
		local rng = Rng.new(7)
		for _ = 1, 500 do
			expect.between(Rng.int(rng, 1, 5), 1, 5)
		end
	end)

	it("ağırlıklı seçim ağırlıkla orantılı çıkar", function()
		local rng = Rng.new(2024)
		local counts = { a = 0, b = 0 }
		local order = { "a", "b" }
		for _ = 1, 20000 do
			local key = Rng.weightedKey(rng, { a = 3, b = 1 }, order)
			counts[key] += 1
		end
		-- Beklenen oran 0.75; istatistiksel tolerans bırakıyoruz.
		expect.near(counts.a / 20000, 0.75, 0.02, "a payı")
	end)

	it("sıfır ağırlıklı anahtarı seçmez", function()
		local rng = Rng.new(5)
		for _ = 1, 200 do
			expect.equal(Rng.weightedKey(rng, { a = 0, b = 10 }, { "a", "b" }), "b")
		end
	end)
end)

return true
