--!strict
-- Oyunun geri kalan bütün sayıları. Denge değişikliği yapacaksan önce buraya bak.
local Balance = {}

Balance.Vault = {
	baseSlots = 6,
	extraSlotsGamepass = 4,
	maxSlots = 18,
	-- Birikim (stash) toplanana kadar çalınabilir. Oyunun bütün gerilimi bu satırda.
	onlineStashSeconds = 7200, -- çevrimiçiyken en fazla 2 saatlik birikim tutulur
	autoCollectInterval = 10, -- "Otomatik Toplama" gamepass'i
	minStashToRob = 500,
	-- Oyuncu sunucudan çıktıktan sonra kasası bir süre daha soyulabilir kalır.
	-- Aksi halde herkes "soyulmamak için çık" oynardı.
	lingerSeconds = 600,
	maxTargetsListed = 12,
}

Balance.Offline = {
	-- Simülasyon, 0.5 verim ve 8 saat tavanla gelirin **%82'sinin**
	-- çevrimdışından geldiğini gösterdi: oyuna girip oynamanın ekonomik
	-- karşılığı yoktu, "gir-topla-çık" en verimli strateji oluyordu.
	-- Oturum süresi ve ertesi gün dönüşü keşfet algoritmasının baktığı
	-- metrikler olduğu için bu doğrudan bir büyüme sorunu.
	efficiency = 0.25,
	capHours = 6,
	capHoursWithGamepass = 10,
}

Balance.Heist = {
	alarmCapacity = 100,
	alarmDecayPerSecond = 9,
	timeLimitSeconds = 120,

	baseStealShare = 0.22,
	perfectBonus = 0.15,
	maxStealShare = 0.6,
	maxStealShareBoosted = 0.75,

	-- Savunma puanı payı düşürür: share * (1 - min(cap, score / divisor))
	-- 400/0.5 iken direnç 200 puanda tavana vuruyordu; tam donanımlı bir
	-- kasa ~800 puan ürettiği için savunma harcamasının dörtte üçü çalınan
	-- paya hiç etki etmiyordu (simülasyon yakaladı). Artık eğri yatırımın
	-- tamamı boyunca anlamlı.
	defenseShareDivisor = 800,
	defenseShareCap = 0.65,

	-- Savunan çevrimdışıyken hem daha az kaybeder hem daha iyi savunur.
	offlineDefenderShareMultiplier = 0.5,
	offlineDefenseBonus = 0.25,

	-- "Mükemmel soygun": alarm hiç bu oranın üstüne çıkmadıysa.
	perfectAlarmThreshold = 0.25,
	perfectTreasureStealChance = 0.5,

	jailSeconds = 25,
	vipJailMultiplier = 0.5,
	-- Yakalanan hırsız kasa sahibine tazminat bırakır (sahibi çevrimdışıyken de birikir).
	caughtBountyShare = 0.05,

	-- Bekleme süreleri (saniye)
	vaultRobCooldown = 90, -- aynı kasa ne sıklıkla soyulabilir
	sameTargetCooldown = 300, -- aynı hırsız aynı kasaya
	-- Hırsızın iki soygun arası. 20 sn'de soygun geliri kasa gelirini
	-- gölgede bırakıyordu; kapalı ekonomide herkes soyup kimse kasa
	-- kurmazsa çalacak bir şey kalmaz.
	thiefGlobalCooldown = 45,
	shieldAfterRobbed = 60, -- soyulduktan sonra dokunulmazlık
	newbieProtectionNetWorth = 5000,
	targetNetWorthFloor = 0.5, -- hedefin serveti, hırsızınkinin en az yarısı olmalı
}

Balance.Movement = {
	walkSpeed = 16,
	sprintSpeed = 24,
	sneakSpeed = 8,
	noiseWalk = 1,
	noiseSprint = 1.8,
	noiseSneak = 0.35,
}

Balance.Corridor = {
	segmentLength = 24,
	width = 16,
	height = 14,
	minSegments = 3,
	maxSegments = 8,
	segmentsPerDefenseLevel = 0.25, -- toplam savunma seviyesi / 4
	arenaSpacing = 500, -- her aktif soygun kendi arenasında; arenalar bu kadar uzakta
	arenaOrigin = { -5000, 500, -5000 },
	maxConcurrentHeists = 12,
}

Balance.AntiCheat = {
	-- İstemcinin bildirdiği kontrol noktaları sunucuda doğrulanır.
	minSecondsPerSegment = 0.6,
	maxHorizontalSpeed = 40, -- stud/sn; sunucunun izin verdiği koşu hızının üstü
	-- Tik başına eklenen sabit pay. 12'ydi: 20 Hz'de saniyede 240 stud'luk
	-- ışınlanmaya izin veriyordu ve anti-cheat pratikte hiçbir şey yakalamıyordu.
	-- 3 stud, ağ gecikmesinden doğan sıçramalara yetiyor.
	positionToleranceStuds = 3,
	maxViolations = 3, -- bu kadar ihlalden sonra soygun yakalanmış sayılır
}

Balance.Crates = {
	maxQueued = 25, -- envanterde bekleyen açılmamış sandık sayısı
	maxInventoryTreasures = 120,
	bulkOpenLimit = 10,
}

Balance.Economy = {
	startingCoins = 250,
	-- İlk 60 saniye: yeni oyuncu bunları hazır bulur, ilk ödülünü 10 saniyede alır.
	starterCrates = { wood = 3 },
	-- Hazine satarken varlık değerinin ne kadarı nakde dönüyor.
	-- 1.0 iken "ucuz sandık al, çıkanı sat" beklenen değerde kâr ediyordu
	-- (Ahşap: 250 coin sandık -> ortalama 1.080 coin hazine) ve kasaya
	-- hazine yerleştirmenin hiçbir anlamı kalmıyordu. Ekonomi simülasyonu
	-- yakaladı; sim/ ve tests/specs/Config.spec bunu bir daha bırakmıyor.
	sellRefundShare = 0.25,
}

Balance.Bots = {
	-- Boş sunucuda soygun döngüsü çalışmazsa oyun yarım kalıyor. Yeterli
	-- gerçek hedef yoksa listeye açıkça "NPC" etiketli kasalar ekleniyor.
	enabled = true,
	minRobbableTargets = 3,
	count = 4,
	refreshSeconds = 240,
	-- NPC kasasındaki birikim, hırsızın kendi gelirine göre ölçekleniyor ki
	-- ödül ne anlamsız kalsın ne de ekonomiyi patlatsın.
	stashSeconds = 420,
	minStash = 2500,
	maxStashMultiplier = 3,
	baseDefenseLevel = 1,
	defenseLevelPerRebirth = 1,
	maxDefenseLevel = 6,
	names = {
		"Terk Edilmiş Kasa",
		"Şehir Bankası Deposu",
		"Neon Antrepo",
		"Glitch Sunucu Odası",
		"Eski Maden Kasası",
		"Liman Ambarı",
	},
}

Balance.Net = {
	-- İstemciden gelen istekler için jeton kovası. Aşan istek sessizce düşer.
	actionsPerSecond = 8,
	actionBurst = 20,
	inputsPerSecond = 30,
	inputBurst = 45,
	syncInterval = 0.4, -- profil değişikliklerinin istemciye yayın aralığı
}

Balance.Leaderboard = {
	refreshSeconds = 60,
	topCount = 25,
	boards = { "net_worth", "heists_won", "biggest_steal" },
}

Balance.Save = {
	autosaveSeconds = 120,
	sessionLockRetrySeconds = 6,
	sessionLockMaxRetries = 10,
	sessionLockStaleSeconds = 900,
}

return Balance
