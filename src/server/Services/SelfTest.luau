--!nonstrict
-- Studio açılış kontrolü. Oyun başlarken çalışır ve "çalışıyor mu" sorusunun
-- makine tarafından cevaplanabilir kısmını cevaplar: denge dosyaları tutarlı
-- mı, ağ kuruldu mu, kayıt çalışıyor mu, satın alma ID'leri girildi mi.
--
-- Yayındaki sunucularda çalışmaz (sadece Studio). Elle yapılması gereken
-- testler için: docs/STUDIO_TEST.md
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)

local SelfTest = {}

type Check = { name: string, ok: boolean, detail: string?, warn: boolean? }

local function collect(): { Check }
	local checks: { Check } = {}

	local function add(name: string, ok: boolean, detail: string?, warn: boolean?)
		table.insert(checks, { name = name, ok = ok, detail = detail, warn = warn })
	end

	-- Ağ
	local netFolder = ReplicatedStorage:FindFirstChild("VaultHeistNet")
	add(
		"Ağ klasörü kuruldu",
		netFolder ~= nil and netFolder:FindFirstChild("Action") ~= nil,
		"ReplicatedStorage.VaultHeistNet"
	)

	-- Dünya
	local world = Workspace:FindFirstChild("Dunya")
	add("Dünya klasörü kuruldu", world ~= nil)
	if world then
		local built, missing = 0, {}
		for _, mapZone in Config.Map.Zones do
			local zone = world:FindFirstChild(mapZone.id)
			if zone and zone:FindFirstChild("Kasalar") and zone:FindFirstChild("Spawn") then
				built += 1
			else
				table.insert(missing, mapZone.id)
			end
		end
		add(
			"Bütün bölgeler kuruldu",
			built == #Config.Map.Zones,
			if #missing > 0 then `eksik: {table.concat(missing, ", ")}` else `{built} bölge`
		)
	end

	-- Kayıt
	local storeOk, storeError = pcall(function()
		return DataStoreService:GetDataStore("VaultHeist_Profiles_v1"):GetAsync("__selftest")
	end)
	add(
		"DataStore erişimi",
		storeOk,
		if storeOk
			then "kayıt kalıcı"
			else "Game Settings → Security → Enable Studio Access to API Services açık değil; "
				.. "oyun çalışır ama kayıt sunucu kapanınca gider",
		not storeOk
	)

	-- Denge tutarlılığı (testlerdeki kontrollerin çalışma anı karşılığı)
	local balanceOk = true
	local balanceDetail = nil
	for _, crate in Config.Crates.List do
		local total = 0
		for _, rarity in Config.Rarities.List do
			total += Loot.rarityChance(crate.id, rarity.id, 1)
		end
		if math.abs(total - 1) > 1e-6 then
			balanceOk = false
			balanceDetail = `{crate.name}: ihtimaller toplamı {total}`
			break
		end
	end
	add("Sandık ihtimalleri tutarlı", balanceOk, balanceDetail)

	-- Al-sat açığı kontrolü
	local flipOk = true
	local flipDetail = nil
	local expectedMutation = 0
	for _, mutation in Config.Mutations.List do
		expectedMutation += Loot.mutationChance(mutation.id, 1) * mutation.multiplier
	end
	for _, crate in Config.Crates.List do
		if crate.currency ~= "coins" then
			continue
		end
		local income = 0
		for _, rarity in Config.Rarities.List do
			income += Loot.rarityChance(crate.id, rarity.id, 1) * rarity.baseIncome
		end
		income *= expectedMutation
		local refund = income * Config.Rarities.SellSeconds * Config.Balance.Economy.sellRefundShare
		if refund / crate.cost > 0.6 then
			flipOk = false
			flipDetail = `{crate.name}: al-sat oranı {string.format("%.2f", refund / crate.cost)}`
			break
		end
	end
	add("Sandık al-sat açığı yok", flipOk, flipDetail)

	-- Monetizasyon
	local configuredPasses, configuredProducts = 0, 0
	for _, pass in Config.Monetization.Gamepasses do
		if pass.assetId ~= 0 then
			configuredPasses += 1
		end
	end
	for _, product in Config.Monetization.Products do
		if product.assetId ~= 0 then
			configuredProducts += 1
		end
	end
	add(
		"Satın alma ID'leri",
		true,
		`{configuredPasses}/{#Config.Monetization.Gamepasses} gamepass, `
			.. `{configuredProducts}/{#Config.Monetization.Products} ürün girilmiş`,
		configuredPasses == 0 and configuredProducts == 0
	)
	add("ProcessReceipt bağlı", MarketplaceService.ProcessReceipt ~= nil)

	-- Yeni oyuncunun ilk 60 saniyesi
	local starterIncome = 0
	local starterCount = 0
	for crateId, amount in Config.Balance.Economy.starterCrates do
		local income = 0
		for _, rarity in Config.Rarities.List do
			income += Loot.rarityChance(crateId, rarity.id, 1) * rarity.baseIncome
		end
		starterIncome += income * expectedMutation * amount
		starterCount += amount
	end
	add(
		"Yeni oyuncu hemen gelir üretiyor",
		starterIncome > 0 and starterCount > 0,
		`{starterCount} ücretsiz sandık ≈ {math.floor(starterIncome)}/sn`
	)
	add(
		"Başlangıç sandıkları yuvaları doldurmuyor",
		starterCount < Economy.slotCount({}, false),
		`{starterCount} sandık / {Economy.slotCount({}, false)} yuva`
	)

	return checks
end

function SelfTest.run(): boolean
	local checks = collect()
	local failed, warned = 0, 0

	print("")
	print("═══ VAULT HEIST AÇILIŞ KONTROLÜ ═══")
	for _, check in checks do
		local mark
		if not check.ok then
			mark = "✗"
			failed += 1
		elseif check.warn then
			mark = "!"
			warned += 1
		else
			mark = "✓"
		end
		print(string.format("  %s %s%s", mark, check.name, if check.detail then `  —  {check.detail}` else ""))
	end

	if failed > 0 then
		warn(`[SelfTest] {failed} kontrol başarısız — oyun düzgün çalışmayabilir`)
	elseif warned > 0 then
		print(`  {warned} uyarı var (yukarıda "!" ile işaretli)`)
	else
		print("  Hepsi tamam.")
	end
	print("  Elle test listesi: docs/STUDIO_TEST.md")
	print("═══════════════════════════════════")
	print("")

	return failed == 0
end

function SelfTest.init()
	if not RunService:IsStudio() then
		return
	end
	-- Diğer servisler dünyayı kurduktan sonra bak.
	task.delay(2, SelfTest.run)
end

return SelfTest
