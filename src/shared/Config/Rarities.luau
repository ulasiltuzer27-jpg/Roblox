--!strict
-- Hazine nadirlikleri. `baseIncome` saniyede üretilen ham coin miktarı;
-- gerçek gelir mutasyon çarpanı ve oyuncu çarpanlarıyla hesaplanır (Core/Economy).
export type Rarity = {
	id: string,
	name: string,
	order: number, -- 1 = en yaygın. Şans (luck) hesabı bu sıraya bakar.
	baseIncome: number,
	color: { number }, -- RGB 0-255, UI tarafında Color3.fromRGB ile kullanılır
	announce: boolean, -- true ise sunucu geneline duyuru yapılır ("X Efsanevi buldu!")
}

local Rarities = {}

Rarities.List = {
	{ id = "common", name = "Sıradan", order = 1, baseIncome = 1, color = { 158, 168, 184 }, announce = false },
	{ id = "uncommon", name = "Alışılmadık", order = 2, baseIncome = 4, color = { 92, 200, 122 }, announce = false },
	{ id = "rare", name = "Nadir", order = 3, baseIncome = 16, color = { 70, 150, 255 }, announce = false },
	{ id = "epic", name = "Epik", order = 4, baseIncome = 70, color = { 168, 96, 255 }, announce = false },
	{ id = "legendary", name = "Efsanevi", order = 5, baseIncome = 300, color = { 255, 176, 48 }, announce = true },
	{ id = "mythic", name = "Mitik", order = 6, baseIncome = 1400, color = { 255, 84, 108 }, announce = true },
	{ id = "secret", name = "Gizli", order = 7, baseIncome = 7500, color = { 0, 255, 214 }, announce = true },
} :: { Rarity }

Rarities.ById = {} :: { [string]: Rarity }
for _, rarity in Rarities.List do
	Rarities.ById[rarity.id] = rarity
end

-- Bir hazinenin "varlık değeri": kaç saniyelik gelirine denk sayılır.
-- Servet (net worth) hesabı bunu kullanır. Satışta ayrıca
-- Balance.Economy.sellRefundShare uygulanır -- ikisi bilerek ayrı:
-- varlık değeri yüksek, nakde çevirme oranı düşük olmalı, yoksa
-- "sandık al, hazineyi sat" kendi başına para basar.
Rarities.SellSeconds = 120

function Rarities.get(id: string): Rarity
	local rarity = Rarities.ById[id]
	assert(rarity, `bilinmeyen nadirlik: {id}`)
	return rarity
end

return Rarities
