--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect
local CORRIDOR = Config.Balance.Corridor

local function options(overrides)
	local base = { defenses = {}, guardsDisabled = false, defenseMultiplier = 1 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

describe("Layout", function()
	it("aynı tohum aynı koridoru üretir", function()
		local defenses = { laser = 4, trap = 3, sensor = 2, guard = 2, door = 2 }
		local a = Layout.generate(777, options({ defenses = defenses }))
		local b = Layout.generate(777, options({ defenses = defenses }))
		expect.equal(a.segments, b.segments)
		expect.equal(#a.lasers, #b.lasers)
		for index, laser in a.lasers do
			expect.near(laser.z, b.lasers[index].z, 1e-9)
			expect.near(laser.phase, b.lasers[index].phase, 1e-9)
		end
	end)

	it("farklı tohum farklı yerleşim verir", function()
		local defenses = { laser = 4 }
		local a = Layout.generate(1, options({ defenses = defenses }))
		local b = Layout.generate(2, options({ defenses = defenses }))
		expect.truthy(math.abs(a.lasers[1].phase - b.lasers[1].phase) > 1e-6)
	end)

	it("bölüm sayısı sınırlar içinde kalır", function()
		local empty = Layout.generate(1, options())
		expect.equal(empty.segments, CORRIDOR.minSegments)

		local maxed = Layout.generate(1, options({
			defenses = { laser = 8, trap = 8, sensor = 8, guard = 8, door = 6 },
		}))
		expect.equal(maxed.segments, CORRIDOR.maxSegments)
	end)

	it("savunma seviyesi tehlike sayısını belirler", function()
		local layout = Layout.generate(9, options({ defenses = { laser = 3, trap = 2, sensor = 2 } }))
		expect.equal(#layout.lasers, math.floor(Config.Defenses.stat("laser", "count", 3)))
		expect.equal(#layout.traps, math.floor(Config.Defenses.stat("trap", "count", 2)))
	end)

	it("kurulmamış savunma koridora eklenmez", function()
		local layout = Layout.generate(3, options({ defenses = { laser = 2 } }))
		expect.equal(#layout.traps, 0)
		expect.equal(#layout.sensors, 0)
		expect.equal(#layout.guards, 0)
	end)

	it("Bekçi Grevi bekçileri koridordan siler", function()
		local layout = Layout.generate(3, options({ defenses = { guard = 8 }, guardsDisabled = true }))
		expect.equal(#layout.guards, 0)
	end)

	it("tehlikeler koridor sınırları içinde duruyor", function()
		local layout = Layout.generate(31337, options({
			defenses = { laser = 8, trap = 8, sensor = 8, guard = 8, door = 6 },
		}))
		local half = layout.width / 2
		for _, trap in layout.traps do
			expect.between(trap.x, -half, half, "kapan x")
			expect.between(trap.z, 0, layout.length, "kapan z")
		end
		for _, sensor in layout.sensors do
			expect.between(sensor.x, -half, half, "sensör x")
			expect.between(sensor.z, 0, layout.length, "sensör z")
		end
		for _, laser in layout.lasers do
			expect.between(laser.z, 0, layout.length, "lazer z")
			expect.greater(laser.speed, 0, "lazer hızı")
		end
	end)

	it("event savunma çarpanı alarm hızına yansır", function()
		local normal = Layout.generate(5, options({ defenses = { laser = 4 } }))
		local weakened = Layout.generate(5, options({ defenses = { laser = 4 }, defenseMultiplier = 0.75 }))
		expect.near(weakened.lasers[1].alarmPerSecond, normal.lasers[1].alarmPerSecond * 0.75, 1e-6)
	end)

	it("kapı en az bir kademe içerir", function()
		local noDoor = Layout.generate(1, options())
		expect.equal(noDoor.door.stages, 1)
		local strongDoor = Layout.generate(1, options({ defenses = { door = 6 } }))
		expect.greater(strongDoor.door.stages, 1)
		expect.greater(strongDoor.door.windowSeconds, 0.3)
	end)

	it("kontrol noktaları bölüm sayısıyla eşleşir ve artan sırada", function()
		local layout = Layout.generate(88, options({ defenses = { laser = 5, guard = 3 } }))
		expect.equal(#layout.checkpoints, layout.segments)
		for index = 2, #layout.checkpoints do
			expect.greater(layout.checkpoints[index], layout.checkpoints[index - 1])
		end
		expect.equal(layout.checkpoints[#layout.checkpoints], layout.length)
	end)

	it("kapı işaretçisi 0-1 arasında süpürür", function()
		for step = 0, 100 do
			expect.between(Layout.doorMarker(step * 0.07), 0, 1, "işaretçi")
		end
		expect.near(Layout.doorMarker(0), 0, 1e-9)
		expect.near(Layout.doorMarker(Layout.DoorPeriod / 2), 0.5, 1e-9)
	end)

	it("kapı vuruşu yalnızca orta bölgede sayılır", function()
		local window = 1.15
		-- Süpürmenin tam ortası her zaman isabet.
		expect.truthy(Layout.doorHit(Layout.DoorPeriod / 2, window))
		-- Başı ve sonu her zaman ıska.
		expect.falsy(Layout.doorHit(0, window))
		expect.falsy(Layout.doorHit(Layout.DoorPeriod * 0.99, window))
	end)

	it("dar pencere isabet aralığını daraltır", function()
		expect.less(Layout.doorHalfWidth(0.4), Layout.doorHalfWidth(1.15))
		-- Tavan ve taban var: kapı ne imkansız ne de bedava olsun.
		expect.between(Layout.doorHalfWidth(0.01), 0.05, 0.4)
		expect.between(Layout.doorHalfWidth(99), 0.05, 0.4)
	end)

	it("kapı isabeti tur boyunca tekrar eder", function()
		local window = 0.9
		local center = Layout.DoorPeriod / 2
		expect.truthy(Layout.doorHit(center, window))
		expect.truthy(Layout.doorHit(center + Layout.DoorPeriod * 3, window), "üçüncü turda da")
	end)

	it("lazer salınımı menzilin dışına taşmaz", function()
		local layout = Layout.generate(12, options({ defenses = { laser = 6 } }))
		local laser = layout.lasers[1]
		for step = 0, 200 do
			local offset = Layout.laserOffset(laser, step * 0.05)
			expect.between(offset, -laser.span / 2, laser.span / 2, "lazer ofseti")
		end
	end)
end)

return true
