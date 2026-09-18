--!nonstrict
-- Kayıt şeması ve göç (migration). Yeni alan eklerken: Version'ı artır,
-- create() içine varsayılanı yaz; reconcile eski kayıtları tamamlar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Core.Validate)

local ProfileTemplate = {}

ProfileTemplate.Version = 1

-- Saklanan makbuz sayısı tavanı: kayıt boyutu sınırsız büyümesin.
ProfileTemplate.MaxReceipts = 50

function ProfileTemplate.create(now: number)
	local crates = {}
	for crateId, amount in Config.Balance.Economy.starterCrates do
		crates[crateId] = amount
	end

	return {
		version = ProfileTemplate.Version,
		coins = Config.Balance.Economy.startingCoins,
		tokens = 0,
		rebirths = 0,
		zone = "hub",

		crates = crates,
		treasures = {},
		placed = {},
		uidCounter = 0, -- hazine kimlikleri için artan sayaç

		upgrades = {},
		defenses = {},

		stash = 0,
		lastIncomeAt = now,
		lastSeenAt = now,

		shieldUntil = 0,
		jailUntil = 0,
		lastRobbedAt = 0,
		robbedBy = {},

		boosts = {},
		purchases = {},
		receipts = {}, -- işlenmiş makbuzlar; çifte ödül vermemek için
		codes = {}, -- kullanılmış tanıtım kodları
		daily = { day = 0, lastClaimAt = 0 },
		tutorial = { step = 1, done = false },

		stats = {
			cratesOpened = 0,
			heistsWon = 0,
			heistsFailed = 0,
			timesRobbed = 0,
			coinsStolen = 0,
			coinsLost = 0,
			biggestSteal = 0,
		},
	}
end

-- Eksik alanı doldurur, tipi tutmayan alanı şablon değeriyle değiştirir.
-- Tip kontrolü şart: bozuk ya da elle kurcalanmış bir kayıtta `coins` bir
-- tablo olarak gelirse aritmetik hata verip oyuncuyu tamamen kilitler.
local function fillMissing(target, template, path: string)
	for key, value in template do
		local current = target[key]
		if current == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(current) ~= type(value) then
			warn(`[ProfileTemplate] {path}{key}: beklenen {type(value)}, gelen {type(current)} -- sıfırlandı`)
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" then
			fillMissing(current, value, `{path}{key}.`)
		end
	end
end

-- Kayda yazılmış sayıların akla uygunluğu: NaN, sonsuz ve negatif para
-- oyunu sessizce çökertir. (Bir istemci doğrulama açığı kapanana kadar
-- bunları yazabiliyordu; kayıtlar hâlâ taşıyor olabilir.)
local NUMERIC_FIELDS = {
	coins = 0,
	tokens = 0,
	rebirths = 0,
	stash = 0,
	lastIncomeAt = 0,
	lastSeenAt = 0,
	shieldUntil = 0,
	jailUntil = 0,
	lastRobbedAt = 0,
	uidCounter = 0,
}

local function sanitizeNumbers(profile, now: number)
	for field, minimum in NUMERIC_FIELDS do
		profile[field] = Validate.sanitizeNumber(profile[field], minimum, minimum)
	end
	-- Zaman damgaları gelecekten gelemez (saat oynanmış ya da bozuk kayıt).
	profile.lastSeenAt = math.min(profile.lastSeenAt, now)
	profile.lastIncomeAt = math.min(profile.lastIncomeAt, now)

	for key, value in profile.stats do
		profile.stats[key] = Validate.sanitizeNumber(value, 0, 0)
	end
	for crateId, amount in profile.crates do
		local sanitized = Validate.integer(amount, 1, Config.Balance.Crates.maxQueued)
		profile.crates[crateId] = sanitized -- geçersizse nil, yani düşer
	end
end

-- Eski kayıtları bozmadan yeni alanlarla tamamlar.
function ProfileTemplate.reconcile(profile, now: number)
	local template = ProfileTemplate.create(now)
	-- Başlangıç sandıkları yalnızca yeni hesaba verilir.
	template.crates = {}
	template.coins = profile.coins or template.coins

	fillMissing(profile, template, "")
	sanitizeNumbers(profile, now)
	profile.version = ProfileTemplate.Version

	-- Tanımsız nadirlik/mutasyon taşıyan hazineler kaydı bozar: düşür.
	for uid, treasure in profile.treasures do
		if
			type(treasure) ~= "table"
			or not Config.Rarities.ById[treasure.rarity]
			or not Config.Mutations.ById[treasure.mutation]
		then
			profile.treasures[uid] = nil
		end
	end

	-- Makbuz listesi sınırsız büyürse kayıt boyutu şişer. En yenileri kalsın.
	local receiptCount = 0
	for _ in profile.receipts do
		receiptCount += 1
	end
	if receiptCount > ProfileTemplate.MaxReceipts then
		local ordered = {}
		for id, at in profile.receipts do
			table.insert(ordered, { id = id, at = if type(at) == "number" then at else 0 })
		end
		table.sort(ordered, function(a, b)
			return a.at > b.at
		end)
		profile.receipts = {}
		for index = 1, ProfileTemplate.MaxReceipts do
			local entry = ordered[index]
			if entry then
				profile.receipts[entry.id] = entry.at
			end
		end
	end

	-- Kaydı her zaman tutarlı hale getir: yerleştirilmiş uid envanterde yoksa düş.
	local cleanedPlaced = {}
	for _, uid in profile.placed do
		if profile.treasures[uid] then
			table.insert(cleanedPlaced, uid)
		end
	end
	profile.placed = cleanedPlaced

	for defenseId, level in profile.defenses do
		if not Config.Defenses.ById[defenseId] then
			profile.defenses[defenseId] = nil
		else
			profile.defenses[defenseId] = math.clamp(level, 0, Config.Defenses.get(defenseId).maxLevel)
		end
	end
	for upgradeId, level in profile.upgrades do
		if not Config.Upgrades.ById[upgradeId] then
			profile.upgrades[upgradeId] = nil
		else
			profile.upgrades[upgradeId] = math.clamp(level, 0, Config.Upgrades.get(upgradeId).maxLevel)
		end
	end
	if not Config.Zones.ById[profile.zone] then
		profile.zone = "hub"
	end

	return profile
end

return ProfileTemplate
