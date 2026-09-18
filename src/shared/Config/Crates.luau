--!strict
-- Sandıklar. Her sandık bir nadirlik ağırlık tablosu taşır; ağırlıklar
-- Core/Loot içinde şans çarpanıyla yeniden şekillendirilir.
--
-- Fiyatlandırma kuralı 1: bir sandık, o kademenin beklenen gelirine göre
-- kabaca 1-30 dakikada kendini ödesin (bkz. ./scripts/balance.sh).
-- Fiyatlandırma kuralı 2: beklenen satış iadesi sandık fiyatının yarısını
-- geçmesin, yoksa sandık alıp satmak tek başına para basar.
-- Asıl darboğaz para değil yuva sayısı: üst kademe sandık, dolu bir yuvayı
-- daha iyisiyle değiştirdiği için değerli.
export type Crate = {
	id: string,
	name: string,
	zone: string,
	cost: number,
	currency: "coins" | "tokens",
	openTime: number, -- saniye; "Süre Atlama" ürünü bunu sıfırlar
	weights: { [string]: number },
}

local Crates = {}

Crates.List = {
	{
		id = "wood",
		name = "Ahşap Sandık",
		zone = "hub",
		cost = 600,
		currency = "coins",
		openTime = 1.5,
		weights = { common = 6000, uncommon = 3000, rare = 900, epic = 95, legendary = 5 },
	},
	{
		id = "iron",
		name = "Demir Sandık",
		zone = "hub",
		cost = 5000,
		currency = "coins",
		openTime = 2,
		weights = { common = 3000, uncommon = 4200, rare = 2200, epic = 520, legendary = 75, mythic = 5 },
	},
	{
		id = "neon",
		name = "Neon Sandık",
		zone = "neon_city",
		cost = 60000,
		currency = "coins",
		openTime = 2.5,
		weights = { uncommon = 2500, rare = 4300, epic = 2400, legendary = 700, mythic = 95, secret = 5 },
	},
	{
		id = "glitch",
		name = "Glitch Sandığı",
		zone = "glitch_sector",
		cost = 750000,
		currency = "coins",
		openTime = 3,
		weights = { rare = 2200, epic = 4300, legendary = 2700, mythic = 740, secret = 60 },
	},
	{
		id = "void",
		name = "Boşluk Sandığı",
		zone = "void_vault",
		cost = 7000000,
		currency = "coins",
		openTime = 3.5,
		weights = { epic = 1800, legendary = 4200, mythic = 3200, secret = 800 },
	},
	{
		id = "quantum",
		name = "Kuantum Sandığı",
		zone = "quantum",
		cost = 150000000,
		currency = "coins",
		openTime = 4,
		weights = { legendary = 2200, mythic = 5000, secret = 2800 },
	},
	{
		-- Rebirth para birimiyle alınır, haftalık rotasyona en uygun sandık bu.
		id = "storm",
		name = "Fırtına Sandığı",
		zone = "hub",
		cost = 3,
		currency = "tokens",
		openTime = 3,
		weights = { legendary = 3000, mythic = 5200, secret = 1800 },
	},
} :: { Crate }

Crates.ById = {} :: { [string]: Crate }
for _, crate in Crates.List do
	Crates.ById[crate.id] = crate
end

function Crates.get(id: string): Crate
	local crate = Crates.ById[id]
	assert(crate, `bilinmeyen sandık: {id}`)
	return crate
end

return Crates
