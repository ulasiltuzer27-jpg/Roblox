--!strict
-- ⚠️ Buradaki bütün ID'ler yer tutucudur (0). Roblox Creator Dashboard'da
-- gamepass / developer product oluşturup ID'leri buraya yaz; başka hiçbir
-- dosyada ID geçmiyor.
export type Gamepass = {
	id: string,
	assetId: number,
	name: string,
	description: string,
	suggestedRobux: number,
}

export type Product = {
	id: string,
	assetId: number,
	name: string,
	description: string,
	suggestedRobux: number,
	oneTime: boolean,
}

local Monetization = {}

Monetization.Gamepasses = {
	{
		id = "auto_collect",
		assetId = 0,
		name = "Otomatik Toplama",
		description = "Kasandaki birikimi 10 saniyede bir otomatik toplar; çevrimdışı limitin 12 saate çıkar.",
		suggestedRobux = 199,
	},
	{
		id = "double_income",
		assetId = 0,
		name = "2x Gelir",
		description = "Tüm hazinelerin geliri kalıcı olarak 2 katına çıkar.",
		suggestedRobux = 399,
	},
	{
		id = "extra_slots",
		assetId = 0,
		name = "Ekstra Kasa Slotu",
		description = "Kasana 4 hazine yuvası daha ekler.",
		suggestedRobux = 299,
	},
	{
		id = "vip_lock",
		assetId = 0,
		name = "VIP Kilit",
		description = "Savunmaların +%35 güçlenir, saatte bir ücretsiz kasa kilidi kazanırsın.",
		suggestedRobux = 499,
	},
	{
		id = "vip",
		assetId = 0,
		name = "VIP",
		description = "Sohbet etiketi, +%10 şans, hapis süresi yarıya iner.",
		suggestedRobux = 249,
	},
} :: { Gamepass }

Monetization.Products = {
	{
		id = "luck_potion",
		assetId = 0,
		name = "Şans İksiri",
		description = "10 dakika boyunca 2x nadirlik şansı.",
		suggestedRobux = 49,
		oneTime = false,
	},
	{
		id = "instant_lock",
		assetId = 0,
		name = "Anında Kasa Kilidi",
		description = "15 dakika boyunca kasan soyulamaz.",
		suggestedRobux = 39,
		oneTime = false,
	},
	{
		id = "time_skip",
		assetId = 0,
		name = "Süre Atlama",
		description = "1 saatlik geliri anında hesabına yazar, sandık bekleme süresini sıfırlar.",
		suggestedRobux = 79,
		oneTime = false,
	},
	{
		id = "starter_pack",
		assetId = 0,
		name = "Başlangıç Paketi",
		description = "25.000 coin + 3 Demir Sandık + 1 saat şans. Hesap başına bir kez.",
		suggestedRobux = 99,
		oneTime = true,
	},
	{
		id = "coins_small",
		assetId = 0,
		name = "Bir Avuç Coin",
		description = "50.000 coin.",
		suggestedRobux = 49,
		oneTime = false,
	},
	{
		id = "coins_large",
		assetId = 0,
		name = "Kasa Dolusu Coin",
		description = "1.500.000 coin.",
		suggestedRobux = 399,
		oneTime = false,
	},
} :: { Product }

Monetization.GamepassById = {} :: { [string]: Gamepass }
for _, pass in Monetization.Gamepasses do
	Monetization.GamepassById[pass.id] = pass
end

Monetization.ProductById = {} :: { [string]: Product }
for _, product in Monetization.Products do
	Monetization.ProductById[product.id] = product
end

-- Ödül tanımları: MonetizationService satın alma sonrası buradan uygular.
Monetization.ProductRewards = {
	luck_potion = { boost = "luck", multiplier = 2, seconds = 600 },
	instant_lock = { shieldSeconds = 900 },
	time_skip = { incomeSeconds = 3600 },
	starter_pack = { coins = 25000, crates = { iron = 3 }, boost = "luck", multiplier = 1.5, seconds = 3600 },
	coins_small = { coins = 50000 },
	coins_large = { coins = 1500000 },
}

function Monetization.assetIdsConfigured(): boolean
	for _, pass in Monetization.Gamepasses do
		if pass.assetId ~= 0 then
			return true
		end
	end
	for _, product in Monetization.Products do
		if product.assetId ~= 0 then
			return true
		end
	end
	return false
end

return Monetization
