--!strict
-- Tanıtım kodları. YouTube/TikTok tanıtımcılarına verilen kodlar ve
-- güncelleme kodları buraya eklenir; her kod oyuncu başına bir kez kullanılır.
--
-- expiresAt = 0 -> süresiz. Aksi halde Unix zamanı (os.time).
export type Code = {
	code: string,
	label: string,
	expiresAt: number,
	rewards: {
		coins: number?,
		tokens: number?,
		crates: { [string]: number }?,
		shieldSeconds: number?,
	},
}

local Codes = {}

Codes.List = {
	{
		code = "KASA",
		label = "Açılış hediyesi",
		expiresAt = 0,
		rewards = { coins = 5000, crates = { wood = 5 } },
	},
	{
		code = "SOYGUN",
		label = "İlk soygun paketi",
		expiresAt = 0,
		rewards = { crates = { iron = 3 }, shieldSeconds = 900 },
	},
	{
		code = "PRIZMA",
		label = "Mutasyon avı",
		expiresAt = 0,
		rewards = { coins = 25000, crates = { iron = 5 } },
	},
} :: { Code }

-- Kodlar büyük/küçük harf ve boşluk duyarsız eşleşir.
function Codes.normalize(input: string): string
	return (input:upper():gsub("%s", ""))
end

Codes.ByCode = {} :: { [string]: Code }
for _, entry in Codes.List do
	Codes.ByCode[Codes.normalize(entry.code)] = entry
end

function Codes.find(input: string): Code?
	return Codes.ByCode[Codes.normalize(input)]
end

function Codes.isActive(code: Code, now: number): boolean
	return code.expiresAt == 0 or now < code.expiresAt
end

return Codes
