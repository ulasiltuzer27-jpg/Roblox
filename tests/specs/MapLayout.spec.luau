--!nonstrict
-- Harita geometrisi testleri.
--
-- Bu testlerin varlık sebebi somut bir hata: elle kurulmuş ilk hub'da
-- parseller yarıçap 140'taydı ama zemin ±130'du. Oyuncular kasalarına
-- giderken haritadan düşüyordu ve bunu ancak Studio'da oynayınca
-- görebilirdin. Artık geometri Roblox'suz doğrulanıyor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local MapLayout = require(ReplicatedStorage.Shared.Core.MapLayout)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect
local DIM = Config.Map.Dimensions

local function horizontalDistance(a, b): number
	local dx, dz = a[1] - b[1], a[3] - b[3]
	return math.sqrt(dx * dx + dz * dz)
end

local function radiusFromOrigin(position, origin): number
	return horizontalDistance(position, origin)
end

-- Parçanın yatayda kapladığı en geniş yarıçap (dönüş açısından bağımsız,
-- yani güvenli taraftan bir üst sınır).
local function footprintRadius(part): number
	local halfX, halfZ = part.size[1] / 2, part.size[3] / 2
	return math.sqrt(halfX * halfX + halfZ * halfZ)
end

describe("Harita ölçüleri", function()
	it("parseller zeminin içinde kalıyor", function()
		-- Asıl yakalanan hata bu.
		local outerEdge = DIM.plotRadius + DIM.plotDepth / 2
		expect.less(outerEdge, DIM.floorSize / 2, "parsel dış kenarı / zemin yarısı")
	end)

	it("dış duvar parsellerin dışında ve zeminin içinde", function()
		expect.greater(DIM.wallRadius, DIM.plotRadius + DIM.plotDepth / 2, "duvar parsellerin dışında")
		expect.less(DIM.wallRadius + DIM.wallThickness / 2, DIM.floorSize / 2, "duvar zeminin içinde")
	end)

	it("meydan parsellere değmiyor", function()
		local plazaEdge = DIM.plazaRadius + DIM.plazaSteps * 3.5
		expect.less(plazaEdge, DIM.plotRadius - DIM.plotDepth / 2, "meydan kenarı / parsel iç kenarı")
	end)

	it("dekoratif sütunlar duvarla parsel arasında", function()
		expect.greater(DIM.pillarRadius, DIM.plotRadius + DIM.plotDepth / 2)
		expect.less(DIM.pillarRadius, DIM.wallRadius)
	end)

	it("kiosklar meydanın üstünde", function()
		expect.less(DIM.kioskRadius + DIM.kioskSize[1] / 2, DIM.plazaRadius, "kiosk meydandan taşmıyor")
	end)

	it("kapılar meydanın dışında, parsellerin içinde", function()
		expect.greater(DIM.gateRadius - DIM.gateSize[1] / 2, DIM.plazaRadius)
		expect.less(DIM.gateRadius + DIM.gateSize[1] / 2, DIM.plotRadius - DIM.plotDepth / 2)
	end)
end)

describe("Bölge yerleşimi", function()
	for _, mapZone in Config.Map.Zones do
		local zoneId = mapZone.id

		it(`{zoneId}: her parça zeminin üstünde duruyor`, function()
			local layout = MapLayout.build(zoneId)
			local half = layout.floorHalf
			for _, part in layout.parts do
				local dx = math.abs(part.position[1] - layout.origin[1])
				local dz = math.abs(part.position[3] - layout.origin[3])
				expect.less(dx, half + 1, `{part.name} x`)
				expect.less(dz, half + 1, `{part.name} z`)
				-- Zeminin altına gömülü parça olmamalı (zemin hariç).
				if part.name ~= "Zemin" then
					expect.greater(part.position[2] + part.size[2] / 2, layout.origin[2] - 0.01, part.name)
				end
			end
		end)

		it(`{zoneId}: parseller birbirine girmiyor`, function()
			local layout = MapLayout.build(zoneId)
			local count = #layout.plots
			expect.greater(count, 0, "parsel sayısı")

			-- Komşu parsel merkezleri arasındaki teğet mesafe, parsel
			-- genişliğinden belirgin fazla olmalı.
			local separation = 2 * DIM.plotRadius * math.sin(math.pi / count)
			expect.greater(separation, DIM.plotWidth + 3, `{zoneId} parsel aralığı`)
		end)

		it(`{zoneId}: parseller duvarın içinde`, function()
			local layout = MapLayout.build(zoneId)
			for _, plot in layout.plots do
				local radius = radiusFromOrigin(plot.position, layout.origin)
				expect.less(radius + DIM.plotDepth / 2, layout.wallRadius, `parsel {plot.index}`)
			end
		end)

		it(`{zoneId}: kiosklar üst üste binmiyor`, function()
			local layout = MapLayout.build(zoneId)
			for indexA, a in layout.kiosks do
				for indexB, b in layout.kiosks do
					if indexA < indexB then
						local distance = horizontalDistance(a.position, b.position)
						expect.greater(distance, DIM.kioskSize[1] + 1, `{a.name} ↔ {b.name}`)
					end
				end
			end
		end)

		it(`{zoneId}: spawn boş ve meydanın üstünde`, function()
			local layout = MapLayout.build(zoneId)
			local spawn = layout.spawn.position

			expect.greater(spawn[2], layout.origin[2], "spawn zeminin üstünde")
			expect.less(radiusFromOrigin(spawn, layout.origin), DIM.plazaRadius, "spawn meydanda")

			-- Spawn'ın üstünde kimse durmamalı: kiosk, kapı, dikilitaş...
			for _, kiosk in layout.kiosks do
				expect.greater(horizontalDistance(spawn, kiosk.position), 8, kiosk.name)
			end
			for _, gate in layout.gates do
				expect.greater(horizontalDistance(spawn, gate.position), 12, gate.label)
			end
			for _, part in layout.parts do
				if part.collide ~= false and part.name ~= "Zemin" and not part.name:find("Meydan") and not part.name:find("Basamak") then
					local distance = horizontalDistance(spawn, part.position)
					expect.greater(distance, footprintRadius(part) + 2, `spawn ↔ {part.name}`)
				end
			end
		end)

		it(`{zoneId}: kapılar diğer bütün bölgelere açılıyor`, function()
			local layout = MapLayout.build(zoneId)
			local seen = {}
			for _, gate in layout.gates do
				expect.truthy(Config.Zones.ById[gate.targetZone], gate.targetZone)
				expect.falsy(seen[gate.targetZone], `tekrar eden kapı: {gate.targetZone}`)
				expect.truthy(gate.targetZone ~= zoneId, "kendi bölgesine kapı yok")
				seen[gate.targetZone] = true
			end
			expect.equal(#layout.gates, #Config.Zones.List - 1, "kapı sayısı")
		end)

		it(`{zoneId}: kapılar birbirine girmiyor`, function()
			local layout = MapLayout.build(zoneId)
			for indexA, a in layout.gates do
				for indexB, b in layout.gates do
					if indexA < indexB then
						expect.greater(
							horizontalDistance(a.position, b.position),
							DIM.gateSize[1] + 2,
							`{a.label} ↔ {b.label}`
						)
					end
				end
			end
		end)

		it(`{zoneId}: parça sayısı bütçede`, function()
			local layout = MapLayout.build(zoneId)
			-- Bölge başına üst sınır: beş bölge × 600 = 3000 parça, Roblox
			-- için rahat. Bunu aşarsak önce süslemeyi seyreltmeliyiz.
			expect.between(#layout.parts, 60, 600, `{zoneId} parça sayısı`)
		end)

		it(`{zoneId}: ışık bütçesi aşılmıyor`, function()
			-- Roblox'ta ışık pahalı, özellikle mobilde. İlk sürümde beş
			-- bölgede toplam 189 ışık vardı; her parsel çerçevesine ve her
			-- sütuna ışık koymak kare hızını düşürüyordu.
			local layout = MapLayout.build(zoneId)
			local lights = 0
			for _, part in layout.parts do
				if part.light then
					lights += 1
				end
			end
			expect.between(lights, 1, 20, `{zoneId} ışık sayısı`)
		end)

		it(`{zoneId}: malzemeler tanımlı listede`, function()
			local layout = MapLayout.build(zoneId)
			local allowed = {
				Concrete = true, Slate = true, Metal = true, Neon = true,
				Glass = true, Marble = true, SmoothPlastic = true,
				DiamondPlate = true, ForceField = true, Plastic = true,
			}
			for _, part in layout.parts do
				expect.truthy(allowed[part.material], `{part.name}: {part.material}`)
			end
		end)
	end
end)

describe("Bölgeler arası", function()
	it("her bölgenin harita tanımı var", function()
		for _, zone in Config.Zones.List do
			expect.truthy(Config.Map.ZoneById[zone.id], zone.id)
		end
		expect.equal(#Config.Map.Zones, #Config.Zones.List)
	end)

	it("bölgeler birbirinin üstüne binmiyor", function()
		local layouts = MapLayout.buildAll()
		for idA, a in layouts do
			for idB, b in layouts do
				if idA < idB then
					local distance = horizontalDistance(a.origin, b.origin)
					expect.greater(distance, a.floorHalf + b.floorHalf + 40, `{idA} ↔ {idB}`)
				end
			end
		end
	end)

	it("soygun arenaları haritalardan uzakta", function()
		local corridor = Config.Balance.Corridor
		local arenaX = corridor.arenaOrigin[1]
		local arenaZ = corridor.arenaOrigin[3]
		local lastArenaX = arenaX + (corridor.maxConcurrentHeists - 1) * corridor.arenaSpacing

		for _, zone in Config.Zones.List do
			local half = Config.Map.Dimensions.floorSize / 2
			-- Arenalar bölge kutusunun tamamen dışında kalmalı.
			local zoneMinX, zoneMaxX = zone.origin[1] - half, zone.origin[1] + half
			local overlapsX = lastArenaX >= zoneMinX and arenaX <= zoneMaxX
            local farInZ = math.abs(arenaZ - zone.origin[3]) > half + 100
			expect.truthy(not overlapsX or farInZ, `{zone.id} arenayla çakışıyor`)
		end
	end)

	it("bölge sırası rebirth eşiğiyle uyumlu", function()
		local previous = -1
		for _, zone in Config.Zones.List do
			expect.greater(zone.requiredRebirths, previous, zone.id)
			previous = zone.requiredRebirths
		end
	end)
end)

return true
