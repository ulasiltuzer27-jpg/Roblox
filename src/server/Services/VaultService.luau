--!nonstrict
-- Kasa mantığı: hazine yerleştirme, satma, birikim toplama, hedef listesi ve
-- soygun sonucunun iki tarafa da işlenmesi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Heist = require(ReplicatedStorage.Shared.Core.Heist)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local Bots = require(ReplicatedStorage.Shared.Core.Bots)
local BotVaultService = require(ServerScriptService.Server.Services.BotVaultService)
local Contexts = require(ServerScriptService.Server.Services.Contexts)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NetService = require(ServerScriptService.Server.Services.NetService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)

local VAULT = Config.Balance.Vault

local VaultService = {}

VaultService.Changed = Signal.new() -- (userId) -- kasa görseli güncellensin

-- Sunucudan ayrılmış ama hâlâ soyulabilir kasalar.
local lingering: { [number]: any } = {}

local function displayNameOf(userId: number, fallback: string): string
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else fallback
end

function VaultService.summary(userId: number, name: string, profile, online: boolean, vipLock: boolean)
	local placed = Contexts.placedTreasures(profile)
	local incomeContext = {
		upgrades = profile.upgrades,
		rebirths = profile.rebirths,
		zone = profile.zone,
		doubleIncome = false,
		eventMultiplier = 1,
	}
	return {
		userId = userId,
		displayName = name,
		netWorth = Economy.netWorth(profile),
		incomePerSecond = Economy.incomePerSecond(placed, incomeContext),
		stash = math.floor(profile.stash),
		defenseScore = math.floor(Heist.defenseScore(Contexts.defense(profile, online, vipLock))),
		slots = #placed,
		online = online,
		shielded = os.time() < profile.shieldUntil,
		treasureCount = #placed,
	}
end

-- Soyulabilir kasa listesi: sunucudaki oyuncular + yakın zamanda çıkanlar.
function VaultService.list(requester: Player)
	local profile = DataService.get(requester)
	if not profile then
		return {}
	end

	local runtime = DataService.runtime(requester)
	local thief = {
		userId = requester.UserId,
		netWorth = Economy.netWorth(profile),
		jailUntil = profile.jailUntil,
		lastHeistAt = runtime.lastHeistAt,
		lastTargetAt = 0,
	}

	local results = {}
	local robbableCount = 0

	local function consider(userId: number, name: string, targetProfile, online: boolean, vipLock: boolean, isBot: boolean?)
		if userId == requester.UserId then
			return
		end
		local summary = VaultService.summary(userId, name, targetProfile, online, vipLock)
		thief.lastTargetAt = runtime.targetHistory[userId] or 0
		local canRob, reason = Heist.canRob(thief, {
			userId = userId,
			netWorth = summary.netWorth,
			stash = summary.stash,
			shieldUntil = targetProfile.shieldUntil,
			lastRobbedAt = targetProfile.lastRobbedAt,
		}, os.time())

		summary.canRob = canRob
		summary.reason = reason
		summary.reasonText = Heist.ReasonText[reason]
		summary.bot = isBot == true
		if canRob and not summary.bot then
			robbableCount += 1
		end
		table.insert(results, summary)
	end

	DataService.forEachLoaded(function(player, targetProfile)
		consider(player.UserId, player.DisplayName, targetProfile, true, Contexts.hasPass(player, "vip_lock"))
	end)

	for userId, entry in lingering do
		if os.time() < entry.expiresAt then
			consider(userId, entry.name, entry.profile, false, entry.vipLock)
		else
			lingering[userId] = nil
		end
	end

	-- Gerçek hedef azsa NPC kasalarıyla tamamla: soygun döngüsü tek başına
	-- oynayan biri için de çalışsın.
	for _, entry in BotVaultService.supplement(requester, robbableCount) do
		consider(entry.userId, entry.name, entry.profile, false, false, true)
	end

	-- Soyulabilirler önce, sonra birikimi büyük olanlar.
	table.sort(results, function(a, b)
		if a.canRob ~= b.canRob then
			return a.canRob
		end
		return a.stash > b.stash
	end)

	while #results > VAULT.maxTargetsListed do
		table.remove(results)
	end
	return results
end

function VaultService.findTarget(userId: number)
	if Bots.isBot(userId) then
		return BotVaultService.find(userId)
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		local profile = DataService.get(player)
		if profile then
			return {
				userId = userId,
				name = player.DisplayName,
				profile = profile,
				online = true,
				vipLock = Contexts.hasPass(player, "vip_lock"),
			}
		end
	end

	local entry = lingering[userId]
	if entry and os.time() < entry.expiresAt then
		return {
			userId = userId,
			name = entry.name,
			profile = entry.profile,
			online = false,
			vipLock = entry.vipLock,
		}
	end
	return nil
end

function VaultService.place(player: Player, uid: string, slotIndex: number?): (boolean, string?)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end
	if not profile.treasures[uid] then
		return false, "Böyle bir hazinen yok."
	end
	if table.find(profile.placed, uid) then
		return false, "Bu hazine zaten kasada."
	end
	if #profile.placed >= Contexts.slots(player, profile) then
		return false, "Kasanda boş yuva yok. Kasa Rafı yükseltmesine bak."
	end

	local index = math.clamp(math.floor(tonumber(slotIndex) or (#profile.placed + 1)), 1, #profile.placed + 1)
	table.insert(profile.placed, index, uid)

	SyncService.markDirty(player)
	VaultService.Changed:fire(player.UserId)
	return true
end

function VaultService.unplace(player: Player, uid: string): (boolean, string?)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end
	local index = table.find(profile.placed, uid)
	if not index then
		return false, "Bu hazine kasada değil."
	end
	table.remove(profile.placed, index)

	SyncService.markDirty(player)
	VaultService.Changed:fire(player.UserId)
	return true
end

-- Boş yuva varsa hazineyi kendiliğinden yerleştirir: yeni oyuncu ilk
-- sandığını açtığı anda gelir akmaya başlasın diye.
function VaultService.autoPlace(player: Player, profile, uid: string): boolean
	if #profile.placed >= Contexts.slots(player, profile) then
		return false
	end
	table.insert(profile.placed, uid)
	VaultService.Changed:fire(player.UserId)
	return true
end

function VaultService.sell(player: Player, uids: { string }): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local total = 0
	local sold = 0
	for _, uid in uids do
		local treasure = profile.treasures[uid]
		if treasure then
			local index = table.find(profile.placed, uid)
			if index then
				table.remove(profile.placed, index)
			end
			profile.treasures[uid] = nil
			total += Economy.treasureValue(treasure) * Config.Balance.Economy.sellRefundShare
			sold += 1
		end
	end

	if sold == 0 then
		return false, "Satılacak hazine bulunamadı."
	end

	profile.coins += math.floor(total)
	SyncService.markDirty(player)
	VaultService.Changed:fire(player.UserId)
	return true, { sold = sold, coins = math.floor(total) }
end

-- Soygun sonucunu hedefe işler. Hedef çevrimdışıysa kayıt üzerinden gider.
-- Dönen değer: çalınan coin ve (varsa) çalınan hazine.
function VaultService.applySteal(targetUserId: number, share: number, takeTreasure: boolean)
	if Bots.isBot(targetUserId) then
		-- NPC kasasında hazine yok, kayıt da yok.
		return BotVaultService.applySteal(targetUserId, share), nil
	end

	local stolenCoins = 0
	local stolenTreasure = nil

	local function transform(profile): boolean
		stolenCoins = Heist.payout(profile.stash, share)
		if stolenCoins <= 0 and not takeTreasure then
			return false
		end
		profile.stash -= stolenCoins
		profile.lastRobbedAt = os.time()
		profile.shieldUntil = math.max(profile.shieldUntil, os.time() + Config.Balance.Heist.shieldAfterRobbed)
		profile.stats.timesRobbed += 1
		profile.stats.coinsLost += stolenCoins

		if takeTreasure and #profile.placed > 1 then
			-- En değerli hazine dokunulmaz: oyuncunun "gurur eşyası" kalsın,
			-- yoksa soyulmak oyunu bıraktırır.
			local best, bestValue = nil, -1
			for _, uid in profile.placed do
				local value = Economy.treasureValue(profile.treasures[uid])
				if value > bestValue then
					best, bestValue = uid, value
				end
			end

			local candidates = {}
			for _, uid in profile.placed do
				if uid ~= best then
					table.insert(candidates, uid)
				end
			end
			if #candidates > 0 then
				local uid = candidates[math.random(#candidates)]
				stolenTreasure = profile.treasures[uid]
				profile.treasures[uid] = nil
				local index = table.find(profile.placed, uid)
				if index then
					table.remove(profile.placed, index)
				end
			end
		end
		return true
	end

	local player = Players:GetPlayerByUserId(targetUserId)
	local profile = if player then DataService.get(player) else nil

	if profile then
		if not transform(profile) then
			return 0, nil
		end
		SyncService.markDirty(player)
		VaultService.Changed:fire(targetUserId)
	else
		local entry = lingering[targetUserId]
		local applied = DataService.mutateOffline(targetUserId, transform)
		if not applied then
			return 0, nil
		end
		if entry then
			-- Sunucu içi görünüm de küçülsün ki liste gerçeği yansıtsın.
			entry.profile.stash = math.max(0, entry.profile.stash - stolenCoins)
			entry.profile.lastRobbedAt = os.time()
			entry.profile.shieldUntil = os.time() + Config.Balance.Heist.shieldAfterRobbed
		end
	end

	return stolenCoins, stolenTreasure
end

-- Yakalanan hırsızın bıraktığı tazminat kasa sahibine yazılır.
function VaultService.grantBounty(targetUserId: number, amount: number)
	if amount <= 0 or Bots.isBot(targetUserId) then
		return
	end
	local player = Players:GetPlayerByUserId(targetUserId)
	local profile = if player then DataService.get(player) else nil

	if profile then
		profile.coins += amount
		SyncService.markDirty(player)
		NotificationService.toast(
			player,
			`Savunman bir hırsızı yakaladı: +{Format.short(amount)} coin tazminat.`,
			"good"
		)
		return
	end

	DataService.mutateOffline(targetUserId, function(stored)
		stored.coins += amount
		return true
	end)
end

function VaultService.notifyRobbed(targetUserId: number, thiefName: string, coins: number, treasure)
	local player = Players:GetPlayerByUserId(targetUserId)
	if not player then
		return
	end
	NetService.push(player, "Robbed", {
		thief = thiefName,
		coins = coins,
		treasure = if treasure then Loot.displayName(treasure) else nil,
	})
	NotificationService.toast(
		player,
		`{thiefName} kasandan {Format.short(coins)} coin çaldı!`,
		"bad"
	)
end

function VaultService.init()
	DataService.Released:connect(function(userId, profile)
		local player = Players:GetPlayerByUserId(userId)
		lingering[userId] = {
			name = if player then player.DisplayName else "Kasa Sahibi",
			-- Derin kopya değil: profil bu sunucuda artık kullanılmıyor.
			profile = profile,
			vipLock = if player then DataService.runtime(player).gamepasses.vip_lock == true else false,
			expiresAt = os.time() + VAULT.lingerSeconds,
		}
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			for userId, entry in lingering do
				if os.time() >= entry.expiresAt then
					lingering[userId] = nil
				end
			end
		end
	end)
end

return VaultService
