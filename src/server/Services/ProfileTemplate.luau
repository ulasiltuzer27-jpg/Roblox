--!nonstrict
-- Kayıt şeması ve göç (migration). Yeni alan eklerken: Version'ı artır,
-- create() içine varsayılanı yaz; reconcile eski kayıtları tamamlar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ProfileTemplate = {}

ProfileTemplate.Version = 1

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

local function fillMissing(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" then
			fillMissing(target[key], value)
		end
	end
end

-- Eski kayıtları bozmadan yeni alanlarla tamamlar.
function ProfileTemplate.reconcile(profile, now: number)
	local template = ProfileTemplate.create(now)
	-- Başlangıç sandıkları yalnızca yeni hesaba verilir.
	template.crates = {}
	template.coins = profile.coins or template.coins

	fillMissing(profile, template)
	profile.version = ProfileTemplate.Version

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
