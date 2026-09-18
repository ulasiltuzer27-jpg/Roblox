--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect
local Codes = Config.Codes

describe("Tanıtım kodları", function()
	it("büyük/küçük harf ve boşluk duyarsız eşleşir", function()
		expect.truthy(Codes.find("kasa"))
		expect.truthy(Codes.find("  KaSa "))
		expect.equal(Codes.find("kasa").code, "KASA")
	end)

	it("olmayan kod bulunmaz", function()
		expect.equal(Codes.find("yokboylebirkod"), nil)
		expect.equal(Codes.find(""), nil)
	end)

	it("süresiz kodlar hep aktif", function()
		local code = Codes.find("KASA")
		expect.equal(code.expiresAt, 0)
		expect.truthy(Codes.isActive(code, os.time()))
		expect.truthy(Codes.isActive(code, 2 ^ 31))
	end)

	it("süreli kod zamanı geçince kapanır", function()
		local code = { code = "TEST", label = "test", expiresAt = 1000, rewards = {} }
		expect.truthy(Codes.isActive(code, 999))
		expect.falsy(Codes.isActive(code, 1000))
	end)

	it("kodlar benzersiz", function()
		local seen = {}
		for _, entry in Codes.List do
			local key = Codes.normalize(entry.code)
			expect.falsy(seen[key], `tekrar eden kod: {key}`)
			seen[key] = true
		end
	end)

	it("ödüller gerçek sandıklara işaret eder ve boş değil", function()
		for _, entry in Codes.List do
			local rewardCount = 0
			for _ in entry.rewards do
				rewardCount += 1
			end
			expect.greater(rewardCount, 0, entry.code)
			for crateId in entry.rewards.crates or {} do
				expect.truthy(Config.Crates.ById[crateId], `{entry.code} -> {crateId}`)
			end
		end
	end)
end)

return true
