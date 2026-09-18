--!strict
-- Bölgeler rebirth ile açılır; her bölge yeni sandık + yeni kasa teması demek.
--
-- Eşikler ekonomi simülasyonuna göre ayarlandı (sim/). İlk ölçümde
-- 0/1/3/6 idi ve hardcore oyuncu son bölgeyi **2. günde** açıyordu -- yani
-- bütün içerik iki günde tükeniyordu. Haftalık güncelleme temposuyla
-- yetişilebilecek bir eğri için eşikler açıldı.
export type Zone = {
	id: string,
	name: string,
	requiredRebirths: number,
	incomeBonus: number, -- bölgeye kasa taşıyan oyuncuya kalıcı gelir bonusu
	origin: { number }, -- ileride bölgeler ayrı fiziksel alan olursa diye ayrıldı; şu an kullanılmıyor
}

local Zones = {}

Zones.List = {
	{ id = "hub", name = "Merkez Kasa Katı", requiredRebirths = 0, incomeBonus = 0, origin = { 0, 0, 0 } },
	{ id = "neon_city", name = "Neon Şehir", requiredRebirths = 2, incomeBonus = 0.15, origin = { 2000, 0, 0 } },
	{ id = "glitch_sector", name = "Glitch Sektörü", requiredRebirths = 6, incomeBonus = 0.4, origin = { 4000, 0, 0 } },
	{ id = "void_vault", name = "Boşluk Kasası", requiredRebirths = 12, incomeBonus = 1.0, origin = { 6000, 0, 0 } },
	-- Uzun vadeli hedef: en hızlı oyuncunun bile haftalarca peşinden koşacağı bölge.
	{ id = "quantum", name = "Kuantum Kasa", requiredRebirths = 20, incomeBonus = 2.0, origin = { 8000, 0, 0 } },
} :: { Zone }

Zones.ById = {} :: { [string]: Zone }
for _, zone in Zones.List do
	Zones.ById[zone.id] = zone
end

function Zones.get(id: string): Zone
	local zone = Zones.ById[id]
	assert(zone, `bilinmeyen bölge: {id}`)
	return zone
end

function Zones.isUnlocked(zoneId: string, rebirths: number): boolean
	return rebirths >= Zones.get(zoneId).requiredRebirths
end

return Zones
