--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Validate = require(ReplicatedStorage.Shared.Core.Validate)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect

local NAN = 0 / 0
local INF = math.huge

describe("Validate", function()
	it("NaN ve sonsuzu eler", function()
		-- Asıl mesele bu: math.clamp(nan, 1, 10) nan döndürüyor ve
		-- nan profile yazılınca kayıt kalıcı olarak bozuluyor.
		expect.equal(Validate.finite(NAN), nil)
		expect.equal(Validate.finite(INF), nil)
		expect.equal(Validate.finite(-INF), nil)
		expect.equal(Validate.finite(42), 42)
		expect.equal(Validate.finite("42"), nil, "dizgi sayı sayılmaz")
		expect.equal(Validate.finite(nil), nil)
		expect.equal(Validate.finite({}), nil)
	end)

	it("tam sayı aralığı dışını reddeder", function()
		expect.equal(Validate.integer(5, 1, 10), 5)
		expect.equal(Validate.integer(5.9, 1, 10), 5, "aşağı yuvarlar")
		expect.equal(Validate.integer(0, 1, 10), nil)
		expect.equal(Validate.integer(11, 1, 10), nil)
		expect.equal(Validate.integer(NAN, 1, 10), nil)
		expect.equal(Validate.integer(INF, 1, 10), nil)
		expect.equal(Validate.integer(-5, 1, 10), nil)
	end)

	it("kırpan sürüm varsayılana düşer", function()
		expect.equal(Validate.clampedInteger(NAN, 1, 10, 3), 3)
		expect.equal(Validate.clampedInteger(99, 1, 10, 3), 10)
		expect.equal(Validate.clampedInteger(-99, 1, 10, 3), 1)
		expect.equal(Validate.clampedInteger(nil, 1, 10, 3), 3)
	end)

	it("kimlik dizgisi kontrol karakteri kabul etmez", function()
		expect.equal(Validate.identifier("wood"), "wood")
		expect.equal(Validate.identifier(""), nil)
		expect.equal(Validate.identifier(string.rep("a", 65)), nil)
		expect.equal(Validate.identifier("kötü\nsatır"), nil)
		expect.equal(Validate.identifier("\0"), nil)
		expect.equal(Validate.identifier(123), nil)
		expect.equal(Validate.identifier({}), nil)
	end)

	it("uzun listeyi reddeder", function()
		local short = {}
		for index = 1, 10 do
			short[index] = "uid" .. index
		end
		expect.equal(#Validate.list(short, 50, Validate.identifier), 10)

		local long = {}
		for index = 1, 200 do
			long[index] = "uid" .. index
		end
		-- Sunucuyu döngüde tutmaya çalışan istek tamamen reddedilir.
		expect.equal(Validate.list(long, 50, Validate.identifier), nil)
	end)

	it("listede tek bozuk eleman tümünü reddeder", function()
		expect.equal(Validate.list({ "a", "b", 5 }, 10, Validate.identifier), nil)
		expect.equal(Validate.list({}, 10, Validate.identifier), nil, "boş liste")
		expect.equal(Validate.list("dizgi", 10, Validate.identifier), nil)
	end)

	it("tanımlı kümeyi doğrular", function()
		local allowed = { wood = true, iron = true }
		expect.equal(Validate.oneOf("wood", allowed), "wood")
		expect.equal(Validate.oneOf("altin", allowed), nil)
		expect.equal(Validate.oneOf(nil, allowed), nil)
	end)

	it("bozuk kayıt sayısını güvenli değere çeker", function()
		expect.equal(Validate.sanitizeNumber(NAN, 0), 0)
		expect.equal(Validate.sanitizeNumber(INF, 0), 0)
		expect.equal(Validate.sanitizeNumber(-50, 0, 0), 0, "negatif para sıfırlanır")
		expect.equal(Validate.sanitizeNumber(1234, 0, 0), 1234)
		expect.equal(Validate.sanitizeNumber("bozuk", 7), 7)
	end)
end)

return true
