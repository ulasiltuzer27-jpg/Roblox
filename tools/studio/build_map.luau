--!nonstrict
-- HARİTA KURUCU
--
-- Creator Store'dan seçtiğin modelleri yerleştirir, hizalar, zemine oturtur,
-- script'lerini temizler ve ışık/atmosferi Vault Heist'in tonuna ayarlar.
--
-- Kullanım:
--   1. Aşağıdaki ASSETS tablosunu kendi asset ID'lerinle doldur
--   2. Bu dosyanın tamamını Studio'da Command Bar'a yapıştır, Enter
--   3. Output'u oku; yerleşmeyen modeller orada listelenir
--   4. Beğenmediğin yerleşimi elle düzelt
--
-- Not: LoadAsset yalnızca senin sahip olduğun ya da ücretsiz (free) modeller
-- için çalışır. Satın alınmış bir modelde önce "Add to Inventory" demelisin.

--═══════════════════════════════════════════════════════════════════════════
-- BURAYI DOLDUR
--═══════════════════════════════════════════════════════════════════════════

local ASSETS = {
	-- Örnek satırlar; id'leri kendi seçtiklerinle değiştir, gerekmeyenleri sil.
	--
	--   id        Creator Store asset ID'si (sayı)
	--   name      Workspace'te görünecek isim
	--   position  {x, y, z} -- hub merkezi (0,0,0)
	--   rotation  y ekseninde derece (isteğe bağlı)
	--   scale     ölçek çarpanı (isteğe bağlı, varsayılan 1)
	--   ground    true ise modelin altı y=0'a oturtulur (varsayılan true)
	--   collide   false ise dekoratif, çarpışmasız olur (varsayılan true)

	{ id = 0, name = "Kasa Kapısı", position = { 0, 0, -34 }, rotation = 0 },
	{ id = 0, name = "Neon Tabela", position = { 0, 12, -36 }, rotation = 0, collide = false },
	{ id = 0, name = "Güvenlik Kamerası A", position = { -26, 10, -26 }, rotation = 45, collide = false },
	{ id = 0, name = "Güvenlik Kamerası B", position = { 26, 10, -26 }, rotation = -45, collide = false },
	{ id = 0, name = "Sandık Standı", position = { -22, 0, -20 }, rotation = 180 },
	{ id = 0, name = "Bitki A", position = { -40, 0, 10 }, scale = 1.2, collide = false },
	{ id = 0, name = "Bitki B", position = { 40, 0, 10 }, scale = 1.2, collide = false },
}

-- Işık ve atmosfer. Oyunun tonu: karanlık kasa katı, neon vurgular.
local LIGHTING = {
	ambient = Color3.fromRGB(12, 12, 20),
	outdoorAmbient = Color3.fromRGB(28, 28, 42),
	brightness = 2,
	clockTime = 21,
	fogEnd = 420,
	fogColor = Color3.fromRGB(16, 16, 26),
	exposure = 0.15,
}

local ATMOSPHERE = {
	density = 0.32,
	offset = 0.1,
	color = Color3.fromRGB(28, 28, 40),
	decay = Color3.fromRGB(70, 60, 110),
	glare = 0.25,
	haze = 1.6,
}

-- Neon vurgu ışıkları: hub'ın çevresine dizilir.
local ACCENT_LIGHTS = {
	enabled = true,
	count = 8,
	radius = 70,
	height = 13,
	color = Color3.fromRGB(122, 60, 255),
	brightness = 3,
	range = 42,
}

local STRIP_SCRIPTS = true -- import edilen modellerdeki script'leri sil
local FOLDER_NAME = "Harita"

--═══════════════════════════════════════════════════════════════════════════
-- BURADAN AŞAĞISI DEĞİŞMEZ
--═══════════════════════════════════════════════════════════════════════════

local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local placed, failed, strippedScripts = 0, 0, 0

local function clearFolder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function stripScripts(model: Instance): number
	local removed = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

local function prepareParts(model: Instance, collide: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = collide
			-- İmleç modelin içinden geçsin, oyuncu tıklamaları takılmasın.
			descendant.CanQuery = collide
		end
	end
end

-- Modelin altını y = 0'a oturtur.
local function groundModel(model: Model, position: Vector3): Vector3
	local _, size = model:GetBoundingBox()
	return Vector3.new(position.X, position.Y + size.Y / 2, position.Z)
end

local function place(entry, folder: Folder)
	if not entry.id or entry.id == 0 then
		warn(`[Harita] "{entry.name}" atlandı: asset ID girilmemiş`)
		failed += 1
		return
	end

	local ok, result = pcall(function()
		return InsertService:LoadAsset(entry.id)
	end)
	if not ok then
		warn(`[Harita] "{entry.name}" ({entry.id}) yüklenemedi: {result}`)
		warn('           Modeli envanterine eklemen ("Add to Inventory") gerekebilir.')
		failed += 1
		return
	end

	local container = result
	local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
	if not model then
		warn(`[Harita] "{entry.name}" içinde model bulunamadı`)
		container:Destroy()
		failed += 1
		return
	end
	model.Parent = folder
	container:Destroy()
	model.Name = entry.name

	if STRIP_SCRIPTS then
		strippedScripts += stripScripts(model)
	end

	local collide = if entry.collide == nil then true else entry.collide
	prepareParts(model, collide)

	if model:IsA("Model") then
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
		if entry.scale and entry.scale ~= 1 then
			model:ScaleTo(entry.scale)
		end
	end

	local position = Vector3.new(entry.position[1], entry.position[2], entry.position[3])
	if entry.ground ~= false and model:IsA("Model") then
		position = groundModel(model, position)
	end

	local cframe = CFrame.new(position) * CFrame.Angles(0, math.rad(entry.rotation or 0), 0)
	if model:IsA("Model") then
		model:PivotTo(cframe)
	else
		(model :: BasePart).CFrame = cframe
	end

	placed += 1
	print(`  ✓ {entry.name}  →  {position}`)
end

local function applyLighting()
	Lighting.Ambient = LIGHTING.ambient
	Lighting.OutdoorAmbient = LIGHTING.outdoorAmbient
	Lighting.Brightness = LIGHTING.brightness
	Lighting.ClockTime = LIGHTING.clockTime
	Lighting.FogEnd = LIGHTING.fogEnd
	Lighting.FogColor = LIGHTING.fogColor
	Lighting.ExposureCompensation = LIGHTING.exposure
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.ShadowMap

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = ATMOSPHERE.density
	atmosphere.Offset = ATMOSPHERE.offset
	atmosphere.Color = ATMOSPHERE.color
	atmosphere.Decay = ATMOSPHERE.decay
	atmosphere.Glare = ATMOSPHERE.glare
	atmosphere.Haze = ATMOSPHERE.haze
	atmosphere.Parent = Lighting

	-- Neon vurgu için hafif bloom; abartılmıyor, okunabilirlik önce gelir.
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 20
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		or Instance.new("ColorCorrectionEffect")
	colorCorrection.Saturation = 0.08
	colorCorrection.Contrast = 0.12
	colorCorrection.TintColor = Color3.fromRGB(240, 238, 255)
	colorCorrection.Parent = Lighting
end

local function buildAccentLights(folder: Folder)
	if not ACCENT_LIGHTS.enabled then
		return
	end
	local lights = Instance.new("Folder")
	lights.Name = "VurguIsiklari"
	lights.Parent = folder

	for index = 1, ACCENT_LIGHTS.count do
		local angle = (index - 1) / ACCENT_LIGHTS.count * math.pi * 2
		local pillar = Instance.new("Part")
		pillar.Name = `Vurgu{index}`
		pillar.Size = Vector3.new(1.2, ACCENT_LIGHTS.height, 1.2)
		pillar.Color = ACCENT_LIGHTS.color
		pillar.Material = Enum.Material.Neon
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CFrame = CFrame.new(
			math.cos(angle) * ACCENT_LIGHTS.radius,
			ACCENT_LIGHTS.height / 2,
			math.sin(angle) * ACCENT_LIGHTS.radius
		)
		pillar.Parent = lights

		local light = Instance.new("PointLight")
		light.Color = ACCENT_LIGHTS.color
		light.Brightness = ACCENT_LIGHTS.brightness
		light.Range = ACCENT_LIGHTS.range
		light.Parent = pillar
	end
	print(`  ✓ {ACCENT_LIGHTS.count} vurgu ışığı`)
end

print("")
print("═══ HARİTA KURULUYOR ═══")
local folder = clearFolder()

for _, entry in ASSETS do
	place(entry, folder)
end

buildAccentLights(folder)
applyLighting()

print("")
print(`Yerleşen: {placed}  ·  Başarısız: {failed}`)
if strippedScripts > 0 then
	print(`Temizlenen script/remote: {strippedScripts}`)
end
print("Işık ve atmosfer ayarlandı.")
print("")
print("Sırada: modelleri Explorer'dan seçip asset_audit.luau ile bir kez daha tara.")
print("════════════════════════")
