--!nonstrict
-- Koridoru Layout verisinden parçalara çevirir. Görsel tarafta bilerek sade:
-- neon parçalar + koyu duvarlar okunaklı ve ucuz.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)

local CORRIDOR = Balance.Corridor

local CorridorBuilder = {}

local COLORS = {
	floor = Color3.fromRGB(28, 30, 38),
	wall = Color3.fromRGB(18, 19, 26),
	laser = Color3.fromRGB(255, 64, 88),
	trap = Color3.fromRGB(255, 176, 48),
	sensor = Color3.fromRGB(64, 255, 236),
	guard = Color3.fromRGB(255, 120, 60),
	door = Color3.fromRGB(122, 60, 255),
	start = Color3.fromRGB(92, 200, 122),
}

local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Koridor yerel koordinatı: x sağa, y yukarı, z ileri (girişten kapıya).
local function place(part: Part, origin: CFrame, x: number, y: number, z: number)
	part.CFrame = origin * CFrame.new(x, y, z)
end

export type Corridor = {
	model: Model,
	origin: CFrame,
	spawnCFrame: CFrame,
	lasers: { { part: Part, spec: any } },
	traps: { { part: Part, spec: any } },
	sensors: { { part: Part, spec: any } },
	guards: { { part: Part, spec: any } },
	door: Part,
}

function CorridorBuilder.build(layout, origin: CFrame, parent: Instance): Corridor
	local model = Instance.new("Model")
	model.Name = "Corridor"

	local width = layout.width
	local height = CORRIDOR.height
	local length = layout.length

	local floor = newPart("Zemin", Vector3.new(width, 1, length + 16), COLORS.floor, model)
	place(floor, origin, 0, -0.5, length / 2 - 8)

	local ceiling = newPart("Tavan", Vector3.new(width, 1, length + 16), COLORS.wall, model)
	place(ceiling, origin, 0, height, length / 2 - 8)

	for _, side in { -1, 1 } do
		local wall = newPart("Duvar", Vector3.new(1, height, length + 16), COLORS.wall, model)
		place(wall, origin, side * (width / 2), height / 2, length / 2 - 8)
	end

	local startPad = newPart("Giris", Vector3.new(width - 2, 0.4, 8), COLORS.start, model)
	startPad.Material = Enum.Material.Neon
	startPad.Transparency = 0.5
	place(startPad, origin, 0, 0.2, -4)

	local lasers = {}
	for _, spec in layout.lasers do
		local size = if spec.axis == "horizontal"
			then Vector3.new(width - 1, 0.35, 0.35)
			else Vector3.new(0.35, height - 1, 0.35)
		local part = newPart(`Lazer{spec.id}`, size, COLORS.laser, model)
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		place(part, origin, 0, height / 2, spec.z)
		table.insert(lasers, { part = part, spec = spec })
	end

	local traps = {}
	for _, spec in layout.traps do
		local part = newPart(`Kapan{spec.id}`, Vector3.new(spec.radius * 2, 0.25, spec.radius * 2), COLORS.trap, model)
		part.Material = Enum.Material.Neon
		part.Transparency = 0.45
		part.CanCollide = false
		place(part, origin, spec.x, 0.15, spec.z)
		table.insert(traps, { part = part, spec = spec })
	end

	local sensors = {}
	for _, spec in layout.sensors do
		local part = newPart(`Sensor{spec.id}`, Vector3.new(1.5, 1.5, 1.5), COLORS.sensor, model)
		part.Material = Enum.Material.Neon
		part.Shape = Enum.PartType.Ball
		part.CanCollide = false
		place(part, origin, spec.x, height - 1.5, spec.z)

		local range = Instance.new("Part")
		range.Name = "Menzil"
		range.Shape = Enum.PartType.Ball
		range.Size = Vector3.new(spec.radius * 2, spec.radius * 2, spec.radius * 2)
		range.Color = COLORS.sensor
		range.Material = Enum.Material.ForceField
		range.Transparency = 0.85
		range.Anchored = true
		range.CanCollide = false
		range.CFrame = origin * CFrame.new(spec.x, 2, spec.z)
		range.Parent = model

		table.insert(sensors, { part = part, spec = spec, range = range })
	end

	local guards = {}
	for _, spec in layout.guards do
		local part = newPart(`Bekci{spec.id}`, Vector3.new(2, 5, 2), COLORS.guard, model)
		part.CanCollide = false
		place(part, origin, 0, 2.5, spec.z)

		local cone = Instance.new("SpotLight")
		cone.Range = spec.viewRange
		cone.Angle = math.deg(spec.viewAngle) * 2
		cone.Brightness = 3
		cone.Color = COLORS.guard
		cone.Face = Enum.NormalId.Front
		cone.Parent = part

		table.insert(guards, { part = part, spec = spec })
	end

	local door = newPart("Kasa Kapisi", Vector3.new(width - 1, height - 1, 1.5), COLORS.door, model)
	door.Material = Enum.Material.Metal
	place(door, origin, 0, (height - 1) / 2, length)

	model.Parent = parent

	return {
		model = model,
		origin = origin,
		spawnCFrame = origin * CFrame.new(0, 4, -6),
		lasers = lasers,
		traps = traps,
		sensors = sensors,
		guards = guards,
		door = door,
	}
end

-- Tehlikeleri o anki zamana göre hareket ettirir.
function CorridorBuilder.animate(corridor: Corridor, clock: number, height: number)
	for _, entry in corridor.lasers do
		local offset = Layout.laserOffset(entry.spec, clock)
		if entry.spec.axis == "horizontal" then
			place(entry.part, corridor.origin, 0, height / 2 + offset, entry.spec.z)
		else
			place(entry.part, corridor.origin, offset, height / 2, entry.spec.z)
		end
	end

	for _, entry in corridor.guards do
		local spec = entry.spec
		local x = math.sin(clock * spec.speed / spec.patrolHalfWidth) * spec.patrolHalfWidth
		local facing = if math.cos(clock * spec.speed / spec.patrolHalfWidth) >= 0 then 1 else -1
		entry.part.CFrame = corridor.origin
			* CFrame.new(x, 2.5, spec.z)
			* CFrame.Angles(0, math.rad(90) * facing, 0)
	end
end

return CorridorBuilder
