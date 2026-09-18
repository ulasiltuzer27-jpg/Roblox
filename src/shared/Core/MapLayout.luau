--!strict
-- Harita geometrisi. Saf fonksiyonlar: Roblox'a hiç dokunmaz, sadece
-- "şu boyutta, şu konumda, şu renkte parça" tarifleri üretir.
--
-- WorldService bu tarifleri Instance'a çevirir. Ayrımın sebebi: harita
-- hataları (parsel zeminin dışında, kiosklar üst üste, spawn duvarın içinde)
-- Roblox açmadan testle yakalanabilsin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapLayout = {}

local DIM = Config.Map.Dimensions

export type Light = { color: { number }, brightness: number, range: number }

export type PartSpec = {
	name: string,
	size: { number }, -- x, y, z
	position: { number }, -- dünya konumu (bölge merkezi dahil)
	rotation: { number }, -- derece: x, y, z
	color: { number },
	material: string,
	transparency: number?,
	collide: boolean?, -- varsayılan true
	shape: string?, -- "Ball" | "Cylinder"
	light: Light?,
}

export type PlotSpec = { index: number, position: { number }, rotation: { number } }
export type KioskSpec = {
	name: string,
	prompt: string,
	position: { number },
	rotation: { number },
	color: { number },
}
export type GateSpec = {
	targetZone: string,
	label: string,
	position: { number },
	rotation: { number },
	locked: boolean,
	requiredRebirths: number,
}

export type ZoneLayout = {
	zoneId: string,
	origin: { number },
	spawn: { position: { number }, rotation: { number } },
	parts: { PartSpec },
	plots: { PlotSpec },
	kiosks: { KioskSpec },
	gates: { GateSpec },
	floorHalf: number,
	wallRadius: number,
}

-- Bir açıdaki nesnenin merkeze bakması için gereken Y dönüşü (derece).
local function facingCenter(angle: number): number
	return math.deg(math.pi / 2 - angle)
end

local function polar(origin: { number }, angle: number, radius: number, height: number): { number }
	return { origin[1] + math.cos(angle) * radius, origin[2] + height, origin[3] + math.sin(angle) * radius }
end

--═══ Yapı taşları ══════════════════════════════════════════════════════

local function buildFloor(parts: { PartSpec }, origin: { number }, theme)
	table.insert(parts, {
		name = "Zemin",
		size = { DIM.floorSize, DIM.floorThickness, DIM.floorSize },
		position = { origin[1], origin[2] - DIM.floorThickness / 2, origin[3] },
		rotation = { 0, 0, 0 },
		color = theme.floor,
		material = theme.floorMaterial,
	})

	-- Zeminde yön veren ışık şeritleri: meydandan parsellere doğru.
	for index = 1, 8 do
		local angle = (index - 1) / 8 * math.pi * 2
		local length = DIM.plotRadius - DIM.plazaRadius - 14
		local mid = DIM.plazaRadius + 7 + length / 2
		table.insert(parts, {
			name = `Serit{index}`,
			size = { 1.6, 0.16, length },
			position = polar(origin, angle, mid, 0.08),
			rotation = { 0, facingCenter(angle), 0 },
			color = theme.accent,
			material = "Neon",
			transparency = 0.25,
			collide = false,
		})
	end
end

local function buildPlaza(parts: { PartSpec }, origin: { number }, theme)
	-- Sekizgen meydan: 45 derece çaprazlanmış iki kare.
	local side = DIM.plazaRadius * 2 / math.sqrt(2) * 1.08
	for index, rotation in { 0, 45 } do
		table.insert(parts, {
			name = `Meydan{index}`,
			size = { side, DIM.plazaHeight, side },
			position = { origin[1], origin[2] + DIM.plazaHeight / 2, origin[3] },
			rotation = { 0, rotation, 0 },
			color = theme.plaza,
			material = theme.floorMaterial,
		})
	end

	-- Basamaklar: meydana çıkışı yumuşatır, düz zemin sıkıcı durmasın.
	for step = 1, DIM.plazaSteps do
		local grow = step * 3.5
		local height = DIM.plazaHeight * (1 - step / (DIM.plazaSteps + 1))
		for index, rotation in { 0, 45 } do
			table.insert(parts, {
				name = `Basamak{step}_{index}`,
				size = { side + grow * 2, height, side + grow * 2 },
				position = { origin[1], origin[2] + height / 2, origin[3] },
				rotation = { 0, rotation, 0 },
				color = theme.plaza,
				material = theme.floorMaterial,
			})
		end
	end

	-- Merkez dikilitaş: uzaktan görünen işaret noktası.
	local segments = 4
	for index = 1, segments do
		local ratio = index / segments
		local width = DIM.obeliskWidth * (1.05 - ratio * 0.55)
		local height = DIM.obeliskHeight / segments
		table.insert(parts, {
			name = `Dikilitas{index}`,
			size = { width, height, width },
			position = {
				origin[1],
				origin[2] + DIM.plazaHeight + height * (index - 0.5),
				origin[3],
			},
			rotation = { 0, index * 11, 0 },
			color = if index == segments then theme.glow else theme.wall,
			material = if index == segments then "Neon" else theme.wallMaterial,
			light = if index == segments
				then { color = theme.glow, brightness = 4, range = 60 }
				else nil,
		})
	end
end

local function buildKiosks(kiosks: { KioskSpec }, parts: { PartSpec }, origin: { number })
	local list = Config.Map.Kiosks
	for index, kiosk in list do
		local angle = (index - 1) / #list * math.pi * 2
		local position = polar(origin, angle, DIM.kioskRadius, DIM.plazaHeight + DIM.kioskSize[2] / 2)
		local rotation = { 0, facingCenter(angle), 0 }

		table.insert(kiosks, {
			name = kiosk.name,
			prompt = kiosk.prompt,
			position = position,
			rotation = rotation,
			color = kiosk.color,
		})

		-- Kioskun altındaki ışıklı taban
		table.insert(parts, {
			name = `KioskTaban{index}`,
			size = { DIM.kioskSize[1] + 2, 0.4, DIM.kioskSize[3] + 3 },
			position = polar(origin, angle, DIM.kioskRadius, DIM.plazaHeight + 0.2),
			rotation = rotation,
			color = kiosk.color,
			material = "Neon",
			transparency = 0.45,
			collide = false,
		})
	end
end

local function buildGates(gates: { GateSpec }, parts: { PartSpec }, origin: { number }, zoneId: string, theme)
	-- Diğer bölgelere açılan kapılar. Kilitliyse görsel olarak da kapalı.
	local targets = {}
	for _, zone in Config.Zones.List do
		if zone.id ~= zoneId then
			table.insert(targets, zone)
		end
	end

	for index, zone in targets do
		-- Kapılar meydanın arkasına yarım daire hâlinde diziliyor.
		local spread = math.pi * 0.9
		local start = math.pi * 1.05
		local angle = start + (index - 0.5) / #targets * spread
		local position = polar(origin, angle, DIM.gateRadius, 0)
		local rotation = { 0, facingCenter(angle), 0 }

		table.insert(gates, {
			targetZone = zone.id,
			label = zone.name,
			position = position,
			rotation = rotation,
			locked = zone.requiredRebirths > 0,
			requiredRebirths = zone.requiredRebirths,
		})

		-- Kapı zemini
		table.insert(parts, {
			name = `KapiPed{index}`,
			size = { DIM.gateSize[1], 0.5, DIM.gateSize[3] },
			position = polar(origin, angle, DIM.gateRadius, 0.25),
			rotation = rotation,
			color = theme.accent,
			material = "Neon",
			transparency = 0.4,
			collide = false,
		})

		-- Kemer: iki dikme + üst kiriş
		for _, side in { -1, 1 } do
			local offsetAngle = angle + side * (DIM.gateSize[1] / 2) / DIM.gateRadius
			table.insert(parts, {
				name = `KapiDikme{index}`,
				size = { 1.2, DIM.gateArchHeight, 1.2 },
				position = polar(origin, offsetAngle, DIM.gateRadius, DIM.gateArchHeight / 2),
				rotation = rotation,
				color = theme.wall,
				material = theme.wallMaterial,
			})
		end
		table.insert(parts, {
			name = `KapiKiris{index}`,
			size = { DIM.gateSize[1] + 2.4, 1.6, 1.6 },
			position = polar(origin, angle, DIM.gateRadius, DIM.gateArchHeight + 0.8),
			rotation = rotation,
			color = theme.glow,
			material = "Neon",
			light = { color = theme.glow, brightness = 2, range = 28 },
		})
	end
end

local function buildPlots(plots: { PlotSpec }, parts: { PartSpec }, origin: { number }, count: number, theme)
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local rotation = { 0, facingCenter(angle), 0 }

		table.insert(plots, {
			index = index,
			position = polar(origin, angle, DIM.plotRadius, 0),
			rotation = rotation,
		})

		-- Zemin platformu
		table.insert(parts, {
			name = `ParselZemin{index}`,
			size = { DIM.plotWidth, 1, DIM.plotDepth },
			position = polar(origin, angle, DIM.plotRadius, 0.5),
			rotation = rotation,
			color = theme.plaza,
			material = theme.floorMaterial,
		})

		-- Arka duvar (kasa cephesi)
		table.insert(parts, {
			name = `ParselDuvar{index}`,
			size = { DIM.plotWidth, DIM.plotWallHeight, 1.5 },
			position = polar(
				origin,
				angle,
				DIM.plotRadius + DIM.plotDepth / 2 - 0.75,
				DIM.plotWallHeight / 2 + 1
			),
			rotation = rotation,
			color = theme.wall,
			material = theme.wallMaterial,
		})

		-- Cephe ışık çerçevesi
		table.insert(parts, {
			name = `ParselCerceve{index}`,
			size = { DIM.plotWidth - 2, 0.5, 0.5 },
			position = polar(
				origin,
				angle,
				DIM.plotRadius + DIM.plotDepth / 2 - 1.6,
				DIM.plotWallHeight + 0.8
			),
			rotation = rotation,
			color = theme.accent,
			material = "Neon",
			collide = false,
			-- Işık yok: Neon malzeme zaten parlıyor ve 24 parselde 24 ışık
			-- mobilde kare hızını düşürüyor (ışık bütçesi için testlere bak).
		})

		-- Yan bölmeler: parseller birbirinden ayrılsın
		for _, side in { -1, 1 } do
			local lateral = side * (DIM.plotWidth / 2 - 0.5)
			local sideAngle = angle + lateral / DIM.plotRadius
			table.insert(parts, {
				name = `ParselBolme{index}`,
				size = { 1, DIM.plotWallHeight * 0.55, DIM.plotDepth },
				position = polar(origin, sideAngle, DIM.plotRadius, DIM.plotWallHeight * 0.275 + 1),
				rotation = rotation,
				color = theme.wall,
				material = theme.wallMaterial,
			})
		end
	end
end

local function buildWalls(parts: { PartSpec }, origin: { number }, theme)
	-- Sekizgen dış duvar: haritadan düşmeyi engelliyor.
	local segmentLength = 2 * DIM.wallRadius * math.tan(math.pi / 8) + DIM.wallThickness
	for index = 1, 8 do
		local angle = (index - 1) / 8 * math.pi * 2 + math.pi / 8
		table.insert(parts, {
			name = `Duvar{index}`,
			size = { segmentLength, DIM.wallHeight, DIM.wallThickness },
			position = polar(origin, angle, DIM.wallRadius, DIM.wallHeight / 2),
			rotation = { 0, facingCenter(angle), 0 },
			color = theme.wall,
			material = theme.wallMaterial,
		})
		-- Duvar üstü ışık bandı
		table.insert(parts, {
			name = `DuvarBant{index}`,
			size = { segmentLength, 0.6, DIM.wallThickness + 0.4 },
			position = polar(origin, angle, DIM.wallRadius, DIM.wallHeight + 0.3),
			rotation = { 0, facingCenter(angle), 0 },
			color = theme.accent,
			material = "Neon",
			collide = false,
		})
	end
end

--═══ Tema süslemeleri ══════════════════════════════════════════════════

local function buildProps(parts: { PartSpec }, origin: { number }, theme)
	local style = theme.propStyle

	if style == "pillars" then
		for index = 1, DIM.pillarCount do
			local angle = (index - 1) / DIM.pillarCount * math.pi * 2
			table.insert(parts, {
				name = `Sutun{index}`,
				size = { 4, DIM.pillarHeight, 4 },
				position = polar(origin, angle, DIM.pillarRadius, DIM.pillarHeight / 2),
				rotation = { 0, facingCenter(angle), 0 },
				color = theme.wall,
				material = theme.wallMaterial,
			})
			table.insert(parts, {
				name = `SutunBaslik{index}`,
				size = { 5.2, 1.2, 5.2 },
				position = polar(origin, angle, DIM.pillarRadius, DIM.pillarHeight + 0.6),
				rotation = { 0, facingCenter(angle), 0 },
				color = theme.accent,
				material = "Neon",
				-- Işık her dördüncü sütunda: bütçe sınırlı.
				light = if index % 4 == 1
					then { color = theme.accent, brightness = 3, range = 52 }
					else nil,
			})
		end
	elseif style == "signs" then
		for index = 1, 12 do
			local angle = (index - 1) / 12 * math.pi * 2 + 0.1
			local height = 18 + (index % 4) * 7
			table.insert(parts, {
				name = `Pilon{index}`,
				size = { 2, height, 2 },
				position = polar(origin, angle, DIM.pillarRadius, height / 2),
				rotation = { 0, facingCenter(angle), 0 },
				color = theme.wall,
				material = theme.wallMaterial,
			})
			for bar = 1, 3 do
				local barHeight = height * (0.4 + bar * 0.16)
				table.insert(parts, {
					name = `Tabela{index}_{bar}`,
					size = { 9, 2.2, 0.6 },
					position = polar(origin, angle, DIM.pillarRadius, barHeight),
					rotation = { 0, facingCenter(angle), 0 },
					color = if bar % 2 == 0 then theme.accent else theme.glow,
					material = "Neon",
					collide = false,
					light = if (index + bar) % 6 == 0
						then { color = theme.glow, brightness = 2.5, range = 34 }
						else nil,
				})
			end
		end
	elseif style == "shards" then
		for index = 1, 20 do
			local angle = (index - 1) / 20 * math.pi * 2
			local radius = DIM.pillarRadius - (index % 5) * 8
			local height = 10 + (index % 6) * 6
			table.insert(parts, {
				name = `Parca{index}`,
				size = { 5, height, 5 },
				position = polar(origin, angle, radius, height / 2 - 2),
				-- Eğik duruş: sektörün "bozuk" hissi buradan geliyor.
				rotation = { (index % 7) * 4 - 12, facingCenter(angle), (index % 5) * 5 - 10 },
				color = if index % 3 == 0 then theme.accent else theme.wall,
				material = if index % 3 == 0 then "Neon" else theme.wallMaterial,
				transparency = if index % 3 == 0 then 0.15 else 0,
			})
		end
		-- Havada asılı glitch bloklar
		for index = 1, 10 do
			local angle = index / 10 * math.pi * 2 + 0.4
			table.insert(parts, {
				name = `GlitchBlok{index}`,
				size = { 6, 6, 6 },
				position = polar(origin, angle, 70 + (index % 3) * 18, 26 + (index % 4) * 9),
				rotation = { (index * 13) % 45, (index * 27) % 360, (index * 19) % 45 },
				color = theme.glow,
				material = "Neon",
				transparency = 0.35,
				collide = false,
			})
		end
	elseif style == "floating" then
		-- Boşluk: zemin cam, etrafta yüzen kristaller
		for index = 1, 26 do
			local angle = index / 26 * math.pi * 2 * 3
			local radius = 46 + (index % 7) * 16
			local height = 14 + (index % 9) * 8
			local size = 3 + (index % 4) * 2
			table.insert(parts, {
				name = `Kristal{index}`,
				size = { size, size * 1.8, size },
				position = polar(origin, angle, radius, height),
				rotation = { (index * 17) % 40 - 20, (index * 31) % 360, (index * 23) % 40 - 20 },
				color = theme.accent,
				material = "Neon",
				transparency = 0.25,
				collide = false,
				light = if index % 4 == 1
					then { color = theme.accent, brightness = 2, range = 30 }
					else nil,
			})
		end
	elseif style == "rings" then
		-- Kuantum: iç içe geçmiş halkalar
		for index = 1, 5 do
			local radius = 52 + index * 18
			local segments = 24
			for segment = 1, segments do
				local angle = (segment - 1) / segments * math.pi * 2
				table.insert(parts, {
					name = `Halka{index}_{segment}`,
					size = { 2 * radius * math.tan(math.pi / segments) + 0.6, 0.8, 1.6 },
					position = polar(origin, angle, radius, 6 + index * 5),
					rotation = { 0, facingCenter(angle), index * 3 },
					color = if index % 2 == 0 then theme.accent else theme.glow,
					material = "Neon",
					transparency = 0.2,
					collide = false,
				})
			end
		end
	end
end

--═══ Giriş noktası ═════════════════════════════════════════════════════

function MapLayout.build(zoneId: string): ZoneLayout
	local zone = Config.Zones.get(zoneId)
	local mapZone = Config.Map.zone(zoneId)
	local theme = Config.Map.theme(zoneId)
	local origin = zone.origin

	local parts: { PartSpec } = {}
	local plots: { PlotSpec } = {}
	local kiosks: { KioskSpec } = {}
	local gates: { GateSpec } = {}

	buildFloor(parts, origin, theme)
	buildPlaza(parts, origin, theme)
	buildKiosks(kiosks, parts, origin)
	buildGates(gates, parts, origin, zoneId, theme)
	buildPlots(plots, parts, origin, mapZone.plots, theme)
	buildWalls(parts, origin, theme)
	buildProps(parts, origin, theme)

	-- Spawn: meydanın üstünde, dikilitaşın önünde.
	table.insert(parts, {
		name = "SpawnPed",
		size = { DIM.spawnSize + 2, 0.3, DIM.spawnSize + 2 },
		position = { origin[1], origin[2] + DIM.plazaHeight + 0.15, origin[3] + DIM.spawnOffset },
		rotation = { 0, 0, 0 },
		color = theme.accent,
		material = "Neon",
		transparency = 0.6,
		collide = false,
	})

	return {
		zoneId = zoneId,
		origin = origin,
		spawn = {
			position = { origin[1], origin[2] + DIM.plazaHeight + 0.5, origin[3] + DIM.spawnOffset },
			rotation = { 0, 180, 0 },
		},
		parts = parts,
		plots = plots,
		kiosks = kiosks,
		gates = gates,
		floorHalf = DIM.floorSize / 2,
		wallRadius = DIM.wallRadius,
	}
end

function MapLayout.buildAll(): { [string]: ZoneLayout }
	local layouts = {}
	for _, zone in Config.Map.Zones do
		layouts[zone.id] = MapLayout.build(zone.id)
	end
	return layouts
end

return MapLayout
