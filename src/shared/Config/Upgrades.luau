--!strict
-- Kasa yükseltmeleri. Hepsi coin ile alınır ve rebirth'te sıfırlanır.
export type Upgrade = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	costBase: number,
	costGrowth: number,
	perLevel: number, -- etkinin seviye başına artışı
}

local Upgrades = {}

Upgrades.List = {
	{
		id = "slots",
		name = "Kasa Rafı",
		description = "Kasana bir hazine yuvası daha ekler.",
		maxLevel = 8,
		costBase = 5000,
		costGrowth = 1.9,
		perLevel = 1,
	},
	{
		id = "income",
		name = "Gelir Şebekesi",
		description = "Tüm hazinelerin geliri +%8.",
		maxLevel = 25,
		costBase = 2500,
		costGrowth = 1.45,
		perLevel = 0.08,
	},
	{
		id = "luck",
		name = "Şans Modülü",
		description = "Sandıklardan nadir hazine çıkma ihtimalini artırır.",
		maxLevel = 20,
		costBase = 8000,
		costGrowth = 1.6,
		perLevel = 0.04,
	},
	{
		id = "stealth",
		name = "Sinyal Karıştırıcı",
		description = "Soygunlarda alarm doldurma hızını %4 düşürür.",
		maxLevel = 20,
		costBase = 6000,
		costGrowth = 1.55,
		perLevel = 0.04,
	},
	{
		id = "carry",
		name = "Çanta Kapasitesi",
		description = "Başarılı soygunda çaldığın payı %2 artırır.",
		maxLevel = 15,
		costBase = 12000,
		costGrowth = 1.7,
		perLevel = 0.02,
	},
	{
		id = "defense_power",
		name = "Savunma Yazılımı",
		description = "Kasandaki tüm savunmaların gücü %5 artar.",
		maxLevel = 20,
		costBase = 7000,
		costGrowth = 1.6,
		perLevel = 0.05,
	},
} :: { Upgrade }

Upgrades.ById = {} :: { [string]: Upgrade }
for _, upgrade in Upgrades.List do
	Upgrades.ById[upgrade.id] = upgrade
end

function Upgrades.get(id: string): Upgrade
	local upgrade = Upgrades.ById[id]
	assert(upgrade, `bilinmeyen yükseltme: {id}`)
	return upgrade
end

function Upgrades.cost(id: string, currentLevel: number): number
	local upgrade = Upgrades.get(id)
	return math.floor(upgrade.costBase * upgrade.costGrowth ^ currentLevel)
end

function Upgrades.effect(id: string, level: number): number
	return Upgrades.get(id).perLevel * level
end

return Upgrades
