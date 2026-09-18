--!nonstrict
-- Küçük test çatısı. Roblox'a hiç bağlı değil; `luau tests/run.luau` ile koşar.
local Framework = {}

local suites = {}
local current = nil

function Framework.describe(name: string, body: () -> ())
	current = { name = name, cases = {} }
	table.insert(suites, current)
	body()
	current = nil
end

function Framework.it(name: string, body: () -> ())
	assert(current, "it() yalnızca describe() içinde çağrılabilir")
	table.insert(current.cases, { name = name, body = body })
end

local function fail(message: string, ...): never
	error(string.format(message, ...), 3)
end

local Expect = {}

function Expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		fail("%s: beklenen %s, gelen %s", label or "eşitlik", tostring(expected), tostring(actual))
	end
end

function Expect.near(actual: number, expected: number, tolerance: number?, label: string?)
	local epsilon = tolerance or 1e-6
	if math.abs(actual - expected) > epsilon then
		fail("%s: beklenen %.6f (±%.6f), gelen %.6f", label or "yaklaşıklık", expected, epsilon, actual)
	end
end

function Expect.truthy(value: any, label: string?)
	if not value then
		fail("%s: doğru bekleniyordu, gelen %s", label or "doğruluk", tostring(value))
	end
end

function Expect.falsy(value: any, label: string?)
	if value then
		fail("%s: yanlış bekleniyordu, gelen %s", label or "yanlışlık", tostring(value))
	end
end

function Expect.greater(actual: number, threshold: number, label: string?)
	if not (actual > threshold) then
		fail("%s: %s > %s olmalıydı", label or "büyüklük", tostring(actual), tostring(threshold))
	end
end

function Expect.less(actual: number, threshold: number, label: string?)
	if not (actual < threshold) then
		fail("%s: %s < %s olmalıydı", label or "küçüklük", tostring(actual), tostring(threshold))
	end
end

function Expect.between(actual: number, min: number, max: number, label: string?)
	if actual < min or actual > max then
		fail("%s: %s, [%s, %s] aralığında olmalıydı", label or "aralık", tostring(actual), tostring(min), tostring(max))
	end
end

function Expect.throws(body: () -> (), label: string?)
	local ok = pcall(body)
	if ok then
		fail("%s: hata bekleniyordu ama fonksiyon sorunsuz döndü", label or "hata")
	end
end

Framework.expect = Expect

function Framework.run(): number
	local passed, failed = 0, 0
	local failures = {}

	for _, suite in suites do
		print(string.format("\27[1m%s\27[0m", suite.name))
		for _, case in suite.cases do
			local ok, err = pcall(case.body)
			if ok then
				passed += 1
				print(string.format("  \27[32m✓\27[0m %s", case.name))
			else
				failed += 1
				print(string.format("  \27[31m✗\27[0m %s", case.name))
				print(string.format("      %s", tostring(err)))
				table.insert(failures, `{suite.name} > {case.name}`)
			end
		end
	end

	print("")
	print(string.format("%d geçti, %d kaldı", passed, failed))
	if failed > 0 then
		for _, name in failures do
			print("  ! " .. name)
		end
	end
	return failed
end

return Framework
