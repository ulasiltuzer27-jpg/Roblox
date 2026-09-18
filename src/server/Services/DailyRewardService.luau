--!nonstrict
-- Günlük ödül ve seri. Ertesi gün geri dönüş oranı keşfet algoritmasının
-- baktığı metrik olduğu için 7. gün bilerek büyük.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)

local DAILY = Config.DailyRewards

local DailyRewardService = {}

function DailyRewardService.status(profile)
	local elapsed = os.time() - (profile.daily.lastClaimAt or 0)
	local ready = elapsed >= DAILY.ResetHours * 3600
	local streakLost = elapsed >= DAILY.StreakBreakHours * 3600
	local day = if streakLost then 1 else (profile.daily.day or 0) + 1
	return ready, day, math.max(0, DAILY.ResetHours * 3600 - elapsed)
end

function DailyRewardService.claim(player: Player): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local ready, day, secondsLeft = DailyRewardService.status(profile)
	if not ready then
		return false, `Sıradaki ödül {Format.time(secondsLeft)} sonra.`
	end

	local reward = DAILY.forDay(day)
	if reward.coins then
		profile.coins += reward.coins
	end
	if reward.tokens then
		profile.tokens += reward.tokens
	end
	if reward.crates then
		for crateId, amount in reward.crates do
			profile.crates[crateId] = (profile.crates[crateId] or 0) + amount
		end
	end
	if reward.shieldSeconds then
		profile.shieldUntil = math.max(profile.shieldUntil, os.time()) + reward.shieldSeconds
	end

	profile.daily.day = day
	profile.daily.lastClaimAt = os.time()

	SyncService.markDirty(player)
	NotificationService.toast(player, `{day}. gün ödülü: {reward.label}`, "good")
	return true, { day = day, label = reward.label }
end

return DailyRewardService
