--!strict
-- Kasa savunmaları. Seviyeler hem soygun koridorunun uzunluğunu hem de
-- hırsızın alarm doldurma hızını belirler (Core/Heist).
export type Defense = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	costBase: number,
	costGrowth: number,
	scoreWeight: number, -- savunma gücü puanına katkısı
	stats: { [string]: { base: number, perLevel: number } },
}

local Defenses = {}

Defenses.List = {
	{
		id = "laser",
		name = "Lazer Izgarası",
		description = "Koridoru tarayan ışınlar. Işına girdiğin sürece alarm dolar.",
		maxLevel = 8,
		costBase = 3000,
		costGrowth = 2.1,
		scoreWeight = 1.0,
		stats = {
			count = { base = 2, perLevel = 1 },
			alarmPerSecond = { base = 22, perLevel = 2.5 },
			sweepSpeed = { base = 0.55, perLevel = 0.07 },
		},
	},
	{
		id = "trap",
		name = "Basınç Kapanı",
		description = "Bastığında hırsızı yerinde sabitler. Lazerler tam o sırada geçer.",
		maxLevel = 8,
		costBase = 5200,
		costGrowth = 2.15,
		scoreWeight = 0.8,
		stats = {
			count = { base = 1, perLevel = 1 },
			rootSeconds = { base = 1.2, perLevel = 0.1 },
			alarmOnTrigger = { base = 12, perLevel = 1.5 },
		},
	},
	{
		id = "sensor",
		name = "Hareket Sensörü",
		description = "Hızlı koşarsan yakalar. Sessiz yürüyüş (Shift) gürültünü düşürür.",
		maxLevel = 8,
		costBase = 7500,
		costGrowth = 2.2,
		scoreWeight = 0.9,
		stats = {
			count = { base = 1, perLevel = 0.5 },
			radius = { base = 10, perLevel = 1.2 },
			alarmPerSecond = { base = 18, perLevel = 2 },
		},
	},
	{
		id = "guard",
		name = "Bekçi NPC",
		description = "Devriye gezer. Görüş konisine girersen alarm çok hızlı dolar.",
		maxLevel = 8,
		costBase = 14000,
		costGrowth = 2.3,
		scoreWeight = 1.4,
		stats = {
			count = { base = 0, perLevel = 0.5 },
			viewRange = { base = 26, perLevel = 2 },
			alarmPerSecond = { base = 34, perLevel = 3 },
		},
	},
	{
		id = "door",
		name = "Kasa Kapısı",
		description = "Koridorun sonundaki kilit. Her kademe ekstra zamanlama testi.",
		maxLevel = 6,
		costBase = 20000,
		costGrowth = 2.4,
		scoreWeight = 1.2,
		stats = {
			stages = { base = 1, perLevel = 0.34 },
			windowSeconds = { base = 1.15, perLevel = -0.09 },
		},
	},
} :: { Defense }

Defenses.ById = {} :: { [string]: Defense }
for _, defense in Defenses.List do
	Defenses.ById[defense.id] = defense
end

function Defenses.get(id: string): Defense
	local defense = Defenses.ById[id]
	assert(defense, `bilinmeyen savunma: {id}`)
	return defense
end

-- Seviye 0 savunmanın istatistiği yoktur; kurulu olmayan savunma koridora hiç eklenmez.
function Defenses.stat(id: string, statName: string, level: number): number
	local defense = Defenses.get(id)
	local stat = defense.stats[statName]
	assert(stat, `{id} savunmasında {statName} istatistiği yok`)
	if level <= 0 then
		return 0
	end
	return stat.base + stat.perLevel * (level - 1)
end

function Defenses.upgradeCost(id: string, currentLevel: number): number
	local defense = Defenses.get(id)
	return math.floor(defense.costBase * defense.costGrowth ^ currentLevel)
end

return Defenses
