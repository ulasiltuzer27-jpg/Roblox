--!strict
-- Koridor üreteci. Tohumdan deterministik: sunucu parçaları buna göre kurar,
-- istemci aynı veriyi minimap ve ipuçları için kullanır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local Types = require(ReplicatedStorage.Shared.Core.Types)

local Layout = {}
local CORRIDOR = Config.Balance.Corridor

export type GenerateOptions = {
	defenses: { [string]: number },
	guardsDisabled: boolean,
	defenseMultiplier: number,
}

local function segmentCount(defenses: { [string]: number }): number
	local total = 0
	for _, level in defenses do
		total += level
	end
	local count = CORRIDOR.minSegments + math.floor(total * CORRIDOR.segmentsPerDefenseLevel)
	return math.clamp(count, CORRIDOR.minSegments, CORRIDOR.maxSegments)
end

function Layout.generate(seed: number, options: GenerateOptions): Types.Layout
	local rng = Rng.new(seed)
	local defenses = options.defenses
	local strength = math.max(options.defenseMultiplier, 0)

	local segments = segmentCount(defenses)
	local length = segments * CORRIDOR.segmentLength
	local width = CORRIDOR.width
	local halfWidth = width / 2

	-- Kapı koridorun sonunda; tehlikeler girişten kapıya kadar yayılır.
	local usableStart = CORRIDOR.segmentLength * 0.5
	local usableEnd = length - CORRIDOR.segmentLength * 0.35

	local function spreadZ(index: number, count: number): number
		if count <= 1 then
			return (usableStart + usableEnd) / 2
		end
		local step = (usableEnd - usableStart) / (count - 1)
		local jitter = Rng.range(rng, -step * 0.18, step * 0.18)
		return usableStart + step * (index - 1) + jitter
	end

	local lasers: { Types.LaserSpec } = {}
	local laserLevel = defenses.laser or 0
	local laserCount = math.floor(Config.Defenses.stat("laser", "count", laserLevel))
	for index = 1, laserCount do
		table.insert(lasers, {
			id = index,
			z = spreadZ(index, laserCount),
			axis = if index % 2 == 0 then "vertical" else "horizontal",
			span = if index % 2 == 0 then CORRIDOR.height * 0.7 else width * 0.8,
			speed = Config.Defenses.stat("laser", "sweepSpeed", laserLevel) * Rng.range(rng, 0.85, 1.25),
			phase = Rng.range(rng, 0, math.pi * 2),
			alarmPerSecond = Config.Defenses.stat("laser", "alarmPerSecond", laserLevel) * strength,
		})
	end

	local traps: { Types.TrapSpec } = {}
	local trapLevel = defenses.trap or 0
	local trapCount = math.floor(Config.Defenses.stat("trap", "count", trapLevel))
	for index = 1, trapCount do
		table.insert(traps, {
			id = index,
			z = spreadZ(index, trapCount) + Rng.range(rng, -4, 4),
			x = Rng.range(rng, -halfWidth * 0.75, halfWidth * 0.75),
			radius = 3.5,
			rootSeconds = Config.Defenses.stat("trap", "rootSeconds", trapLevel),
			alarmOnTrigger = Config.Defenses.stat("trap", "alarmOnTrigger", trapLevel) * strength,
		})
	end

	local sensors: { Types.SensorSpec } = {}
	local sensorLevel = defenses.sensor or 0
	local sensorCount = math.floor(Config.Defenses.stat("sensor", "count", sensorLevel))
	for index = 1, sensorCount do
		table.insert(sensors, {
			id = index,
			z = spreadZ(index, sensorCount) + Rng.range(rng, -6, 6),
			x = Rng.range(rng, -halfWidth * 0.9, halfWidth * 0.9),
			radius = Config.Defenses.stat("sensor", "radius", sensorLevel),
			alarmPerSecond = Config.Defenses.stat("sensor", "alarmPerSecond", sensorLevel) * strength,
		})
	end

	local guards: { Types.GuardSpec } = {}
	local guardLevel = if options.guardsDisabled then 0 else (defenses.guard or 0)
	local guardCount = math.floor(Config.Defenses.stat("guard", "count", guardLevel))
	for index = 1, guardCount do
		table.insert(guards, {
			id = index,
			z = spreadZ(index, guardCount),
			patrolHalfWidth = halfWidth * Rng.range(rng, 0.5, 0.85),
			speed = Rng.range(rng, 5, 8),
			viewRange = Config.Defenses.stat("guard", "viewRange", guardLevel),
			viewAngle = math.rad(45),
			alarmPerSecond = Config.Defenses.stat("guard", "alarmPerSecond", guardLevel) * strength,
		})
	end

	local doorLevel = defenses.door or 0
	local door: Types.DoorSpec = {
		z = length,
		stages = math.max(1, math.floor(Config.Defenses.stat("door", "stages", doorLevel))),
		windowSeconds = math.max(0.35, Config.Defenses.stat("door", "windowSeconds", doorLevel)),
	}
	if doorLevel <= 0 then
		door.stages = 1
		door.windowSeconds = 1.15
	end

	local checkpoints = {}
	for index = 1, segments do
		table.insert(checkpoints, index * CORRIDOR.segmentLength)
	end

	return {
		seed = seed,
		segments = segments,
		length = length,
		width = width,
		lasers = lasers,
		traps = traps,
		sensors = sensors,
		guards = guards,
		door = door,
		checkpoints = checkpoints,
	}
end

-- Kasa kapısındaki kilit zamanlaması. İşaretçi 0'dan 1'e süpürür,
-- hedef bölge ortadadır. Sunucu ve istemci aynı fonksiyonu kullanır ki
-- ekranda görülen ile kabul edilen atış aynı olsun.
Layout.DoorPeriod = 1.8

function Layout.doorMarker(elapsed: number): number
	return (elapsed % Layout.DoorPeriod) / Layout.DoorPeriod
end

function Layout.doorHalfWidth(windowSeconds: number): number
	return math.clamp(windowSeconds / Layout.DoorPeriod / 2, 0.05, 0.4)
end

function Layout.doorHit(elapsed: number, windowSeconds: number): boolean
	return math.abs(Layout.doorMarker(elapsed) - 0.5) <= Layout.doorHalfWidth(windowSeconds)
end

-- Lazerin t anındaki konumu (koridor merkezine göre ofset).
function Layout.laserOffset(laser: Types.LaserSpec, clock: number): number
	return math.sin(clock * laser.speed + laser.phase) * (laser.span / 2)
end

return Layout
