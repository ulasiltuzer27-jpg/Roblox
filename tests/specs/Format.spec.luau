--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Format = require(ReplicatedStorage.Shared.Core.Format)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

describe("Format", function()
	it("1000 altını olduğu gibi yazar", function()
		expect.equal(Format.short(0), "0")
		expect.equal(Format.short(999), "999")
	end)

	it("binleri kısaltır ve gereksiz sıfır bırakmaz", function()
		expect.equal(Format.short(1000), "1K")
		expect.equal(Format.short(1500), "1.5K")
		expect.equal(Format.short(1234567), "1.23M")
	end)

	it("üç basamaklı kısaltmada rakam yemez", function()
		-- Eski hata: "100M" -> "1M". Regresyon testi.
		expect.equal(Format.short(100000000), "100M")
		expect.equal(Format.short(900000), "900K")
	end)

	it("negatif sayıyı korur", function()
		expect.equal(Format.short(-2500), "-2.5K")
	end)

	it("binlik ayracı koyar", function()
		expect.equal(Format.comma(1234567), "1.234.567")
		expect.equal(Format.comma(123), "123")
	end)

	it("süreyi okunur yazar", function()
		expect.equal(Format.time(75), "1:15")
		expect.equal(Format.time(3671), "1:01:11")
	end)

	it("küçük ihtimalleri '1 / N' diye gösterir", function()
		expect.equal(Format.odds(0.0002), "1 / 5K")
		expect.equal(Format.odds(0.5), "50.00%")
	end)
end)

return true
