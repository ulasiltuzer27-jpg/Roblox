--!nonstrict
-- Pasif gelir. Üretilen para doğrudan cebe değil kasadaki "birikime" gider;
-- toplanmamış birikim çalınabilir olduğu için oyunun gerilimi buradan doğar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Contexts = require(ServerScriptService.Server.Services.Contexts)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)

local VAULT = Config.Balance.Vault

local IncomeService = {}

local lastAutoCollect: { [number]: number } = {}

function IncomeService.collect(player: Player): number
	local profile = DataService.get(player)
	if not profile or profile.stash <= 0 then
		return 0
	end
	local amount = math.floor(profile.stash)
	profile.coins += amount
	profile.stash -= amount
	SyncService.markDirty(player)
	return amount
end

-- Çevrimdışı kazanç girişte bir kez hesaplanır ve birikime eklenir.
local function applyOfflineEarnings(player: Player, profile)
	local elapsed = os.time() - (profile.lastSeenAt or os.time())
	if elapsed <= 60 then
		profile.lastIncomeAt = os.time()
		return
	end

	local rate = Contexts.incomePerSecond(player, profile)
	local earned = Economy.offlineEarnings(rate, elapsed, Contexts.hasPass(player, "auto_collect"))
	profile.lastIncomeAt = os.time()
	if earned <= 0 then
		return
	end

	local cap = Economy.stashCap(rate)
	profile.stash = math.min(profile.stash + earned, math.max(cap, profile.stash))
	NotificationService.toast(
		player,
		`Yokluğunda kasan {Format.short(earned)} coin üretti. Toplamayı unutma!`,
		"good"
	)
end

local function tick(player: Player, profile, deltaTime: number)
	local rate = Contexts.incomePerSecond(player, profile)

	-- "Süre Atlama" ürünü: anında N saniyelik gelir.
	if profile.pendingTimeSkip and profile.pendingTimeSkip > 0 then
		profile.coins += rate * profile.pendingTimeSkip
		profile.pendingTimeSkip = nil
		SyncService.markDirty(player)
	end

	if rate <= 0 then
		return
	end

	local cap = Economy.stashCap(rate)
	if profile.stash < cap then
		profile.stash = math.min(profile.stash + rate * deltaTime, cap)
		SyncService.markDirty(player)
	end

	if Contexts.hasPass(player, "auto_collect") then
		local last = lastAutoCollect[player.UserId] or 0
		if os.clock() - last >= VAULT.autoCollectInterval then
			lastAutoCollect[player.UserId] = os.clock()
			IncomeService.collect(player)
		end
	end
end

function IncomeService.init()
	DataService.Loaded:connect(applyOfflineEarnings)

	Players.PlayerRemoving:Connect(function(player)
		lastAutoCollect[player.UserId] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local clock = os.clock()
			local deltaTime = clock - last
			last = clock
			DataService.forEachLoaded(function(player, profile)
				tick(player, profile, deltaTime)
			end)
		end
	end)
end

return IncomeService
