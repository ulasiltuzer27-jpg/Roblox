--!strict
-- Sunucu eventleri. Zamanlama os.time() üzerinden hesaplandığı için
-- tüm sunucular aynı anda aynı eventi gösterir (Core/EventClock).
export type ServerEvent = {
	id: string,
	name: string,
	tagline: string,
	color: { number },
	effects: {
		incomeMultiplier: number?,
		mutationLuck: number?,
		rarityLuck: number?,
		stealShareMultiplier: number?,
		defenseMultiplier: number?,
		guardsDisabled: boolean?,
		crateDiscount: number?,
	},
}

local ServerEvents = {}

-- Bir tur = sessiz dönem + event. Oyuncu her 10 dakikada bir "kaçırmamam lazım" hissi alır.
ServerEvents.CycleSeconds = 600
ServerEvents.EventSeconds = 120
ServerEvents.WarningSeconds = 30 -- event başlamadan kaç saniye önce uyarı gösterilir

ServerEvents.List = {
	{
		id = "golden_hour",
		name = "Altın Saat",
		tagline = "Tüm kasalar 2 kat gelir üretiyor!",
		color = { 255, 200, 64 },
		effects = { incomeMultiplier = 2 },
	},
	{
		id = "vault_storm",
		name = "Kasa Fırtınası",
		tagline = "Soygun payı iki katı, savunmalar zayıf. Herkes koridorda!",
		color = { 122, 60, 255 },
		effects = { stealShareMultiplier = 2, defenseMultiplier = 0.75 },
	},
	{
		id = "mutation_rain",
		name = "Mutasyon Yağmuru",
		tagline = "Mutasyon şansı 2 kat. Prizma avı başlasın.",
		color = { 255, 64, 220 },
		effects = { mutationLuck = 2 },
	},
	{
		id = "lucky_crates",
		name = "Şanslı Sandıklar",
		tagline = "Nadir çıkma şansı +%50, sandıklar %25 indirimli.",
		color = { 64, 255, 236 },
		effects = { rarityLuck = 1.5, crateDiscount = 0.25 },
	},
	{
		id = "guard_strike",
		name = "Bekçi Grevi",
		tagline = "Bütün bekçiler mola verdi. Soygun için en iyi 2 dakika.",
		color = { 92, 200, 122 },
		effects = { guardsDisabled = true, stealShareMultiplier = 1.25 },
	},
} :: { ServerEvent }

ServerEvents.ById = {} :: { [string]: ServerEvent }
for _, event in ServerEvents.List do
	ServerEvents.ById[event.id] = event
end

function ServerEvents.get(id: string): ServerEvent
	local event = ServerEvents.ById[id]
	assert(event, `bilinmeyen event: {id}`)
	return event
end

return ServerEvents
