--!strict
-- Bölgeler rebirth ile açılır; her bölge yeni sandık + yeni kasa teması demek.
export type Zone = {
	id: string,
	name: string,
	requiredRebirths: number,
	incomeBonus: number, -- bölgeye kasa taşıyan oyuncuya kalıcı gelir bonusu
	origin: { number }, -- dünya koordinatı (x, y, z); WorldService plotları buradan dizer
}

local Zones = {}

Zones.List = {
	{ id = "hub", name = "Merkez Kasa Katı", requiredRebirths = 0, incomeBonus = 0, origin = { 0, 0, 0 } },
	{ id = "neon_city", name = "Neon Şehir", requiredRebirths = 1, incomeBonus = 0.15, origin = { 2000, 0, 0 } },
	{ id = "glitch_sector", name = "Glitch Sektörü", requiredRebirths = 3, incomeBonus = 0.4, origin = { 4000, 0, 0 } },
	{ id = "void_vault", name = "Boşluk Kasası", requiredRebirths = 6, incomeBonus = 1.0, origin = { 6000, 0, 0 } },
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
