--!strict
-- Soygun kuralları: kim kimi soyabilir, alarm nasıl dolar, pay nasıl hesaplanır.
-- Tamamı saf fonksiyon -> testlerde birebir doğrulanıyor (tests/specs/Heist.spec.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Heist = {}
local HEIST = Config.Balance.Heist

export type DefenseContext = {
	defenses: { [string]: number },
	defensePowerUpgrade: number,
	vipLock: boolean,
	ownerOnline: boolean,
	eventDefenseMultiplier: number,
	guardsDisabled: boolean,
}

-- Savunma puanı hem koridorun zorluğunu hem de çalınabilen payı belirler.
function Heist.defenseScore(context: DefenseContext): number
	local score = 0
	for _, defense in Config.Defenses.List do
		if defense.id == "guard" and context.guardsDisabled then
			continue
		end
		score += (context.defenses[defense.id] or 0) * defense.scoreWeight * 10
	end

	local multiplier = 1 + Config.Upgrades.effect("defense_power", context.defensePowerUpgrade)
	if context.vipLock then
		multiplier *= 1.35
	end
	if not context.ownerOnline then
		multiplier *= 1 + HEIST.offlineDefenseBonus
	end
	multiplier *= math.max(context.eventDefenseMultiplier, 0)

	return score * multiplier
end

export type ShareContext = {
	carryUpgrade: number,
	perfect: boolean,
	defenseScore: number,
	ownerOnline: boolean,
	eventShareMultiplier: number,
}

-- Başarılı soygunda kasadaki birikimin ne kadarı gider.
function Heist.stealShare(context: ShareContext): number
	local share = HEIST.baseStealShare + Config.Upgrades.effect("carry", context.carryUpgrade)
	if context.perfect then
		share += HEIST.perfectBonus
	end

	local resistance = math.min(HEIST.defenseShareCap, context.defenseScore / HEIST.defenseShareDivisor)
	share *= 1 - resistance
	share *= math.max(context.eventShareMultiplier, 0)

	if not context.ownerOnline then
		share *= HEIST.offlineDefenderShareMultiplier
	end

	local cap = if context.eventShareMultiplier > 1 then HEIST.maxStealShareBoosted else HEIST.maxStealShare
	return math.clamp(share, 0.01, cap)
end

-- Stealth yükseltmesi alarm doldurma hızını düşürür (en fazla %60).
function Heist.stealthFactor(stealthUpgrade: number): number
	return 1 - math.clamp(Config.Upgrades.effect("stealth", stealthUpgrade), 0, 0.6)
end

-- Bir tick'lik alarm hareketi. Kaynak yoksa alarm geri düşer ki
-- "saklan, bekle, geç" oynanışı işe yarasın.
function Heist.stepAlarm(alarm: number, incomingPerSecond: number, deltaTime: number): number
	local next = alarm
	if incomingPerSecond > 0 then
		next += incomingPerSecond * deltaTime
	else
		next -= HEIST.alarmDecayPerSecond * deltaTime
	end
	return math.clamp(next, 0, HEIST.alarmCapacity)
end

function Heist.isCaught(alarm: number): boolean
	return alarm >= HEIST.alarmCapacity
end

function Heist.isPerfect(peakAlarm: number): boolean
	return peakAlarm <= HEIST.alarmCapacity * HEIST.perfectAlarmThreshold
end

function Heist.jailSeconds(hasVip: boolean): number
	return HEIST.jailSeconds * (if hasVip then HEIST.vipJailMultiplier else 1)
end

function Heist.payout(stash: number, share: number): number
	return math.floor(math.max(stash, 0) * share)
end

-- Yakalanan hırsız kasa sahibine tazminat bırakır: savunmaya yatırım yapmak kârlı olsun.
function Heist.caughtBounty(stash: number): number
	return math.floor(math.max(stash, 0) * HEIST.caughtBountyShare)
end

export type ThiefState = {
	userId: number,
	netWorth: number,
	jailUntil: number,
	lastHeistAt: number,
	lastTargetAt: number, -- bu hedefe en son ne zaman girdi
}

export type TargetState = {
	userId: number,
	netWorth: number,
	stash: number,
	shieldUntil: number,
	lastRobbedAt: number,
}

-- Tek doğruluk kaynağı: istemci de sunucu da aynı fonksiyonu çağırır.
-- İkinci dönüş değeri UI'da gösterilecek sebep kodudur.
function Heist.canRob(thief: ThiefState, target: TargetState, now: number): (boolean, string)
	if thief.userId == target.userId then
		return false, "self"
	end
	if now < thief.jailUntil then
		return false, "jailed"
	end
	if now - thief.lastHeistAt < HEIST.thiefGlobalCooldown then
		return false, "cooldown"
	end
	if now - thief.lastTargetAt < HEIST.sameTargetCooldown then
		return false, "same_target"
	end
	if now < target.shieldUntil then
		return false, "shielded"
	end
	if now - target.lastRobbedAt < HEIST.vaultRobCooldown then
		return false, "vault_cooldown"
	end
	if target.stash < Config.Balance.Vault.minStashToRob then
		return false, "empty"
	end
	if target.netWorth < HEIST.newbieProtectionNetWorth then
		return false, "newbie"
	end
	-- Kendinden çok daha fakir kasaları avlamak yok; yukarı doğru soygun serbest.
	if target.netWorth < thief.netWorth * HEIST.targetNetWorthFloor then
		return false, "too_poor"
	end
	return true, "ok"
end

Heist.ReasonText = {
	self = "Kendi kasanı soyamazsın.",
	jailed = "Hapisten çıkmayı bekle.",
	cooldown = "Yeni soyguna hazır değilsin.",
	same_target = "Bu kasaya çok yakın zamanda girdin.",
	shielded = "Kasa kilitli.",
	vault_cooldown = "Bu kasa az önce soyuldu.",
	empty = "Kasada alınacak bir şey yok.",
	newbie = "Yeni oyuncular korumalı.",
	too_poor = "Bu kasa senin seviyene göre çok küçük.",
	ok = "Hazır.",
}

return Heist
