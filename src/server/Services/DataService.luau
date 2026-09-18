--!nonstrict
-- Kalıcı kayıt. Oturum kilidi (session lock) ile aynı profilin iki sunucuda
-- aynı anda yazılmasını engelliyoruz; çevrimdışı oyuncunun kasasından çalınan
-- para da buradan, kilidi kontrol ederek işleniyor.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local ProfileTemplate = require(ServerScriptService.Server.Services.ProfileTemplate)

local SAVE = Config.Balance.Save
local STORE_NAME = "VaultHeist_Profiles_v1"

local DataService = {}

DataService.Loaded = Signal.new() -- (player, profile)
DataService.Released = Signal.new() -- (userId, profile)

local profiles: { [number]: any } = {}
local runtimes: { [number]: any } = {}
local loading: { [number]: boolean } = {}

local store: DataStore? = nil
local mockStore: { [string]: any } = {}
local useMock = false
local jobId = if game.JobId ~= "" then game.JobId else `studio-{os.clock()}`

local function keyFor(userId: number): string
	return `player_{userId}`
end

local function now(): number
	return os.time()
end

-- DataStore erişimi yoksa (Studio'da API kapalı, yerel test) bellek içi
-- sahte depoya düşüyoruz ki oyun yine de oynanabilsin.
local function probeStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		useMock = true
		warn("[DataService] DataStore alınamadı, bellek içi kayda düşülüyor:", result)
		return
	end
	store = result

	local probeOk, probeErr = pcall(function()
		result:GetAsync("__probe")
	end)
	if not probeOk then
		useMock = true
		warn("[DataService] DataStore yazılamıyor, bellek içi kayda düşülüyor:", probeErr)
	end
end

local function mockUpdate(key: string, transform: (any) -> any)
	local updated = transform(mockStore[key])
	if updated ~= nil then
		mockStore[key] = updated
	end
	return mockStore[key]
end

local function updateAsync(key: string, transform: (any) -> any): (boolean, any)
	if useMock or not store then
		local ok, result = pcall(mockUpdate, key, transform)
		return ok, result
	end
	local ok, result = pcall(function()
		return store:UpdateAsync(key, transform)
	end)
	return ok, result
end

local function getAsync(key: string): (boolean, any)
	if useMock or not store then
		return true, mockStore[key]
	end
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	return ok, result
end

local function lockHeldByOther(record: any): boolean
	local lock = record and record.lock
	if not lock then
		return false
	end
	if lock.jobId == jobId then
		return false
	end
	-- Sunucu çökmüşse kilit bir süre sonra bayatlar ve devralınabilir.
	return now() - (lock.at or 0) < SAVE.sessionLockStaleSeconds
end

local function newRecord(profile)
	return { data = profile, lock = { jobId = jobId, at = now() }, updatedAt = now() }
end

-- Kilidi alarak profili yükler. Başka sunucu tutuyorsa birkaç kez dener.
local function acquire(userId: number): any?
	local key = keyFor(userId)
	for attempt = 1, SAVE.sessionLockMaxRetries do
		local ok, record = updateAsync(key, function(stored)
			if lockHeldByOther(stored) then
				return nil -- yazmayı iptal et, sonra tekrar dene
			end
			local profile = stored and stored.data or ProfileTemplate.create(now())
			ProfileTemplate.reconcile(profile, now())
			return { data = profile, lock = { jobId = jobId, at = now() }, updatedAt = now() }
		end)

		if ok and record and record.lock and record.lock.jobId == jobId then
			return record.data
		end
		if not ok then
			warn(`[DataService] {userId} yüklenemedi (deneme {attempt}):`, record)
		end
		task.wait(SAVE.sessionLockRetrySeconds)
	end
	return nil
end

local function write(userId: number, profile, releaseLock: boolean): boolean
	local ok, err = updateAsync(keyFor(userId), function(stored)
		if lockHeldByOther(stored) then
			return nil
		end
		return {
			data = profile,
			lock = if releaseLock then nil else { jobId = jobId, at = now() },
			updatedAt = now(),
		}
	end)
	if not ok then
		warn(`[DataService] {userId} kaydedilemedi:`, err)
	end
	return ok
end

function DataService.get(player: Player)
	return profiles[player.UserId]
end

-- Oturum boyunca yaşayan, kaydedilmeyen veriler (gamepass önbelleği, sayaçlar).
function DataService.runtime(player: Player)
	local runtime = runtimes[player.UserId]
	if not runtime then
		runtime = {
			gamepasses = {},
			-- Gamepass sorgusu ağ üzerinden geliyor; hazır olmadan gelir
			-- hesaplamak "2x Gelir" sahibine eksik çevrimdışı kazanç yazıyordu.
			gamepassesReady = false,
			lastHeistAt = 0,
			targetHistory = {},
			actionBudget = {},
			joinedAt = os.clock(),
		}
		runtimes[player.UserId] = runtime
	end
	return runtime
end

function DataService.forEachLoaded(callback: (Player, any) -> ())
	for _, player in Players:GetPlayers() do
		local profile = profiles[player.UserId]
		if profile then
			callback(player, profile)
		end
	end
end

function DataService.save(player: Player)
	local profile = profiles[player.UserId]
	if profile then
		profile.lastSeenAt = now()
		write(player.UserId, profile, false)
	end
end

-- Çevrimdışı (ya da sunucuda olmayan) bir oyuncunun kasasına dokunur.
-- Kilit başka sunucudaysa dokunmaz: veri kaybı riskini almıyoruz.
function DataService.mutateOffline(userId: number, transform: (any) -> boolean): (boolean, string)
	if profiles[userId] then
		local changed = transform(profiles[userId])
		return changed, if changed then "ok" else "aborted"
	end

	local applied = false
	local ok, err = updateAsync(keyFor(userId), function(stored)
		if not stored or not stored.data then
			return nil
		end
		if lockHeldByOther(stored) then
			return nil
		end
		ProfileTemplate.reconcile(stored.data, now())
		if not transform(stored.data) then
			return nil
		end
		applied = true
		stored.updatedAt = now()
		return stored
	end)

	if not ok then
		warn(`[DataService] {userId} çevrimdışı güncellenemedi:`, err)
		return false, "error"
	end
	return applied, if applied then "ok" else "locked"
end

-- Sadece okuma: sunucudan ayrılmış oyuncunun kasasını listelemek için.
function DataService.peek(userId: number)
	if profiles[userId] then
		return profiles[userId]
	end
	local ok, record = getAsync(keyFor(userId))
	if ok and record then
		return record.data
	end
	return nil
end

local function onPlayerAdded(player: Player)
	-- init() hem mevcut oyuncuları yükler hem PlayerAdded'e bağlanır;
	-- tam o anda katılan oyuncu iki kez yüklenmesin.
	if loading[player.UserId] or profiles[player.UserId] then
		return
	end
	loading[player.UserId] = true

	local profile = acquire(player.UserId)
	loading[player.UserId] = nil

	if not profile then
		player:Kick("Kasan başka bir sunucuda açık görünüyor. Birkaç saniye sonra tekrar dene.")
		return
	end
	if not player.Parent then
		-- Yükleme sırasında çıkmış: kilidi bırak.
		write(player.UserId, profile, true)
		return
	end

	profiles[player.UserId] = profile
	DataService.runtime(player)
	DataService.Loaded:fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.lastSeenAt = now()
	DataService.Released:fire(player.UserId, profile)
	write(player.UserId, profile, true)
	profiles[player.UserId] = nil
	runtimes[player.UserId] = nil
end

function DataService.init()
	probeStore()

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(SAVE.autosaveSeconds)
			for userId, profile in profiles do
				profile.lastSeenAt = now()
				write(userId, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and useMock then
			return
		end
		local pending = 0
		for userId, profile in profiles do
			pending += 1
			task.spawn(function()
				profile.lastSeenAt = now()
				write(userId, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
