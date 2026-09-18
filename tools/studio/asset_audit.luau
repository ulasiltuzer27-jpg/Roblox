--!nonstrict
-- MARKETPLACE MODEL DENETİMİ
--
-- Kullanım: modeli Studio'ya import et, Explorer'da seç, sonra bu dosyanın
-- tamamını Command Bar'a yapıştır ve Enter'a bas.
--
-- Ne yapar:
--   1. Seçili modeldeki her script'i, remote'u ve şüpheli deseni raporlar
--   2. STRIP_SCRIPTS = true ise bütün script'leri siler
--
-- ⚠️ ÖNEMLİ: Bu tarayıcı bir garanti değil. Bilinen desenleri yakalar,
-- yeni/obfuske edilmiş bir backdoor'u kaçırabilir. Tek gerçekten güvenli
-- yaklaşım: **import ettiğin modelde hiç script bırakma.** Dekoratif bir
-- model zaten script'e ihtiyaç duymaz. STRIP_SCRIPTS'i açık bırak.

local STRIP_SCRIPTS = true -- bulunan bütün script'leri sil
local STRIP_REMOTES = true -- modelin içindeki RemoteEvent/RemoteFunction'ları sil

-- Kaynak kodunda arandığında alarm veren desenler. Her biri tek başına
-- suç değil ama dekoratif bir modelde hiçbirinin işi yok.
local PATTERNS = {
	{ pattern = "require%s*%(%s*%d+", label = "sayısal asset ID ile require (klasik backdoor)" },
	{ pattern = "getfenv", label = "getfenv (ortam kurcalama)" },
	{ pattern = "setfenv", label = "setfenv (ortam kurcalama)" },
	{ pattern = "loadstring", label = "loadstring (uzaktan kod çalıştırma)" },
	{ pattern = "HttpService", label = "HttpService (dışarıya veri gönderme)" },
	{ pattern = "GetAsync", label = "GetAsync" },
	{ pattern = "PostAsync", label = "PostAsync" },
	{ pattern = "MarketplaceService", label = "MarketplaceService (satın alma penceresi)" },
	{ pattern = "GamePassService", label = "GamePassService" },
	-- Lua desenlerinde alternasyon (|) yok; her desen ayrı satır.
	{ pattern = [[\%d%d%d]], label = "kaçış dizisiyle gizlenmiş dizgi (\\104\\105...)" },
	{ pattern = "string%.char%s*%(", label = "string.char zinciri (obfuskasyon)" },
	{ pattern = [[%[["'']%w+["'']%]%s*%(]], label = "dizgi indeksiyle çağrı (obfuskasyon)" },
	{ pattern = "Players%.LocalPlayer%.UserId", label = "kullanıcı kimliği okuma" },
	{ pattern = "BanAsync", label = "BanAsync (oyuncu banlama)" },
	{ pattern = ":Kick%s*%(", label = "Kick (oyuncu atma)" },
	{ pattern = "DataStoreService", label = "DataStoreService (kayda erişim)" },
	{ pattern = "ServerScriptService", label = "ServerScriptService'e erişim" },
}

local SUSPICIOUS_NAMES = {
	"backdoor", "vaccine", "antivirus", "fire", "synapse", "krnl", "exploit",
	"admin", "cmdbar", "remotespy", "ohaxor", "nilware",
}

local selection = game:GetService("Selection"):Get()
if #selection == 0 then
	warn("[Denetim] Önce Explorer'da modeli seç.")
	return
end

local scripts = {}
local remotes = {}
local findings = {}
local suspiciousNames = {}

local function scan(root)
	for _, descendant in root:GetDescendants() do
		local className = descendant.ClassName
		local path = descendant:GetFullName()

		if descendant:IsA("LuaSourceContainer") then
			table.insert(scripts, descendant)
			local ok, source = pcall(function()
				return descendant.Source
			end)
			if not ok then
				table.insert(findings, {
					path = path,
					label = "kaynak kodu okunamadı (korumalı script -- kesinlikle sil)",
				})
			else
				-- Ham kaynağa bakıyoruz: Roblox API isimleri büyük/küçük harfe
				-- duyarlı, çalışması için doğru yazılmak zorundalar. Kaynağı
				-- küçük harfe çevirmek "HttpService" gibi desenlerin hiçbirini
				-- eşleştirmiyordu.
				for _, entry in PATTERNS do
					if source:find(entry.pattern) then
						table.insert(findings, { path = path, label = entry.label })
					end
				end
				-- Çok uzun tek satır = obfuskasyon işareti
				for line in source:gmatch("[^\r\n]+") do
					if #line > 500 then
						table.insert(findings, { path = path, label = `{#line} karakterlik tek satır (obfuskasyon)` })
						break
					end
				end
			end
		elseif className == "RemoteEvent" or className == "RemoteFunction" or className == "BindableEvent" then
			table.insert(remotes, descendant)
		end

		local lowerName = descendant.Name:lower()
		for _, needle in SUSPICIOUS_NAMES do
			if lowerName:find(needle, 1, true) then
				table.insert(suspiciousNames, `{path}  ({descendant.Name})`)
			end
		end
	end
end

for _, instance in selection do
	scan(instance)
end

print("")
print("═══ MARKETPLACE MODEL DENETİMİ ═══")
print(`Taranan: {#selection} nesne`)
print(`Script sayısı: {#scripts}`)
print(`Remote/Bindable sayısı: {#remotes}`)
print("")

if #findings > 0 then
	warn(`⚠️ {#findings} şüpheli bulgu:`)
	for _, finding in findings do
		warn(`   {finding.path}`)
		warn(`      → {finding.label}`)
	end
	print("")
end

if #suspiciousNames > 0 then
	warn("⚠️ Şüpheli isimler:")
	for _, name in suspiciousNames do
		warn(`   {name}`)
	end
	print("")
end

if #scripts == 0 and #remotes == 0 then
	print("✓ Hiç script ya da remote yok. Bu model dekoratif, güvenli sayılabilir.")
else
	if STRIP_SCRIPTS then
		for _, instance in scripts do
			instance:Destroy()
		end
		print(`✓ {#scripts} script silindi.`)
	else
		warn(`{#scripts} script duruyor. STRIP_SCRIPTS = true yapıp tekrar çalıştır.`)
	end

	if STRIP_REMOTES then
		for _, instance in remotes do
			instance:Destroy()
		end
		print(`✓ {#remotes} remote/bindable silindi.`)
	else
		warn(`{#remotes} remote duruyor.`)
	end
end

print("")
print("Hatırlatma: bu tarama garanti değil. Dekoratif modelde script olmaz;")
print("script'leri silip modeli öyle kullanmak tek güvenli yol.")
print("═════════════════════════════════")
