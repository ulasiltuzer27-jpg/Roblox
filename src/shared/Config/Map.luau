--!strict
-- Harita tanımı. Saf veri: ölçüler, temalar, yerleşim parametreleri.
-- Geometriyi Core/MapLayout üretiyor, parçaları WorldService kuruyor.
--
-- Bu ayrım bilinçli: harita Roblox'a dokunmadan üretilebildiği için
-- "parseller zeminin dışında kalmış" gibi hatalar testle yakalanıyor
-- (tests/specs/MapLayout.spec.luau). Önceki elle kurulmuş hub'da parseller
-- yarıçap 140'taydı ama zemin ±130'du: oyuncular kasalarına giderken
-- boşluğa düşüyordu.
export type Theme = {
	floor: { number },
	floorMaterial: string,
	plaza: { number },
	wall: { number },
	wallMaterial: string,
	accent: { number },
	glow: { number },
	propStyle: string,
	fogColor: { number },
	fogEnd: number,
	ambient: { number },
	clockTime: number,
}

export type ZoneMap = {
	id: string,
	theme: string,
	plots: number,
	-- Bölgeye özel not: arayüzde ve tabelalarda görünür.
	tagline: string,
}

local Map = {}

--═══ Ölçüler ═══════════════════════════════════════════════════════════
-- Hepsi stud. Değiştirirsen testler tutarlılığı kontrol eder.

Map.Dimensions = {
	floorSize = 340, -- kare zemin kenarı (±170)
	floorThickness = 4,

	plazaRadius = 38, -- merkez meydan (sekizgen)
	plazaHeight = 1.5,
	plazaSteps = 3,

	obeliskHeight = 30,
	obeliskWidth = 6,

	spawnOffset = 20, -- meydan merkezinden spawn platformuna
	spawnSize = 16,

	kioskRadius = 30,
	kioskSize = { 6, 9, 2 },

	gateRadius = 54,
	gateSize = { 10, 1, 10 },
	gateArchHeight = 14,

	plotRadius = 112,
	plotWidth = 24,
	plotDepth = 20,
	plotWallHeight = 16,

	wallRadius = 158, -- dış duvar sekizgeni
	wallHeight = 26,
	wallThickness = 3,

	pillarRadius = 138, -- dekoratif sütun halkası
	pillarCount = 16,
	pillarHeight = 22,
}

--═══ Temalar ═══════════════════════════════════════════════════════════

Map.Themes = {
	vault = {
		floor = { 26, 28, 36 },
		floorMaterial = "Concrete",
		plaza = { 38, 41, 52 },
		wall = { 18, 19, 26 },
		wallMaterial = "Concrete",
		accent = { 255, 200, 64 },
		glow = { 255, 176, 48 },
		propStyle = "pillars",
		fogColor = { 14, 15, 22 },
		fogEnd = 460,
		ambient = { 14, 14, 22 },
		clockTime = 21,
	},
	neon = {
		floor = { 18, 20, 30 },
		floorMaterial = "Slate",
		plaza = { 26, 30, 44 },
		wall = { 12, 14, 22 },
		wallMaterial = "Metal",
		accent = { 64, 255, 236 },
		glow = { 255, 64, 220 },
		propStyle = "signs",
		fogColor = { 10, 14, 26 },
		fogEnd = 380,
		ambient = { 10, 16, 26 },
		clockTime = 1,
	},
	glitch = {
		floor = { 22, 18, 30 },
		floorMaterial = "DiamondPlate",
		plaza = { 34, 24, 44 },
		wall = { 16, 12, 24 },
		wallMaterial = "Metal",
		accent = { 255, 64, 220 },
		glow = { 92, 255, 140 },
		propStyle = "shards",
		fogColor = { 20, 10, 28 },
		fogEnd = 320,
		ambient = { 20, 10, 28 },
		clockTime = 23,
	},
	void = {
		floor = { 14, 10, 24 },
		floorMaterial = "Glass",
		plaza = { 24, 16, 40 },
		wall = { 10, 6, 18 },
		wallMaterial = "ForceField",
		accent = { 122, 60, 255 },
		glow = { 168, 96, 255 },
		propStyle = "floating",
		fogColor = { 8, 4, 16 },
		fogEnd = 300,
		ambient = { 12, 6, 24 },
		clockTime = 0,
	},
	quantum = {
		floor = { 232, 234, 240 },
		floorMaterial = "Marble",
		plaza = { 248, 250, 255 },
		wall = { 210, 214, 226 },
		wallMaterial = "SmoothPlastic",
		accent = { 0, 200, 214 },
		glow = { 0, 255, 214 },
		propStyle = "rings",
		fogColor = { 226, 236, 242 },
		fogEnd = 520,
		ambient = { 150, 165, 180 },
		clockTime = 14,
	},
} :: { [string]: Theme }

--═══ Bölgeler ══════════════════════════════════════════════════════════
-- Sıra Config/Zones ile aynı; parsel sayısı bölgenin beklenen nüfusuna göre.

Map.Zones = {
	{ id = "hub", theme = "vault", plots = 24, tagline = "Her şey burada başlar" },
	{ id = "neon_city", theme = "neon", plots = 20, tagline = "Işıklar hiç sönmez" },
	{ id = "glitch_sector", theme = "glitch", plots = 16, tagline = "Burada kurallar bozuk" },
	{ id = "void_vault", theme = "void", plots = 14, tagline = "Aşağıda zemin yok" },
	{ id = "quantum", theme = "quantum", plots = 12, tagline = "Son kasa" },
} :: { ZoneMap }

Map.ZoneById = {} :: { [string]: ZoneMap }
for _, zone in Map.Zones do
	Map.ZoneById[zone.id] = zone
end

-- Kiosklar meydanın etrafında; isimler istemcideki panel eşlemesiyle aynı.
Map.Kiosks = {
	{ name = "Sandık Dükkanı", prompt = "Aç", color = { 255, 200, 64 } },
	{ name = "Kasam", prompt = "Aç", color = { 92, 200, 122 } },
	{ name = "Savunmalar", prompt = "Aç", color = { 122, 60, 255 } },
	{ name = "Soygun Panosu", prompt = "Aç", color = { 255, 64, 88 } },
	{ name = "Mağaza", prompt = "Aç", color = { 64, 255, 236 } },
	{ name = "Günlük Ödül", prompt = "Al", color = { 255, 120, 60 } },
}

function Map.zone(zoneId: string): ZoneMap
	local zone = Map.ZoneById[zoneId]
	assert(zone, `harita tanımı yok: {zoneId}`)
	return zone
end

function Map.theme(zoneId: string): Theme
	return Map.Themes[Map.zone(zoneId).theme]
end

return Map
