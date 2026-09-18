--!strict
-- Gelir, servet ve yükseltme matematiği. Sunucu her saniye bunu çalıştırır,
-- istemci aynı fonksiyonlarla önizleme gösterir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Core.Types)

local Economy = {}

-- Bir hazinenin çarpansız saniyelik geliri.
function Economy.treasureIncome(treasure: Types.Treasure): number
	local rarity = Config.Rarities.get(treasure.rarity)
	local mutation = Config.Mutations.get(treasure.mutation)
	return rarity.baseIncome * mutation.multiplier
end

-- Satış / servet değeri: gelirin sabit bir süre karşılığı.
function Economy.treasureValue(treasure: Types.Treasure): number
	return Economy.treasureIncome(treasure) * Config.Rarities.SellSeconds
end

export type IncomeContext = {
	upgrades: { [string]: number },
	rebirths: number,
	zone: string,
	doubleIncome: boolean,
	eventMultiplier: number,
}

-- Tüm kalıcı ve geçici çarpanların çarpımı.
function Economy.incomeMultiplier(context: IncomeContext): number
	local upgradeBonus = 1 + Config.Upgrades.effect("income", context.upgrades.income or 0)
	local rebirthBonus = Config.Rebirth.multiplier(context.rebirths)
	local zoneBonus = 1 + Config.Zones.get(context.zone).incomeBonus
	local gamepassBonus = if context.doubleIncome then 2 else 1
	return upgradeBonus * rebirthBonus * zoneBonus * gamepassBonus * math.max(context.eventMultiplier, 0)
end

-- Kasadaki yerleştirilmiş hazinelerin toplam saniyelik geliri.
function Economy.incomePerSecond(placed: { Types.Treasure }, context: IncomeContext): number
	local base = 0
	for _, treasure in placed do
		base += Economy.treasureIncome(treasure)
	end
	return base * Economy.incomeMultiplier(context)
end

function Economy.slotCount(upgrades: { [string]: number }, extraSlots: boolean): number
	local slots = Config.Balance.Vault.baseSlots + (upgrades.slots or 0)
	if extraSlots then
		slots += Config.Balance.Vault.extraSlotsGamepass
	end
	return math.min(slots, Config.Balance.Vault.maxSlots)
end

-- Toplanmamış birikimin tavanı. Tavan dolunca üretim durur: oyuncuyu
-- "gel topla" diye geri çağıran şey bu.
function Economy.stashCap(incomePerSecond: number): number
	return incomePerSecond * Config.Balance.Vault.onlineStashSeconds
end

-- Çevrimdışı kazanç: verimlilik düşük ve tavanlı, yoksa kimse oyuna girmez.
function Economy.offlineEarnings(incomePerSecond: number, elapsedSeconds: number, hasAutoCollect: boolean): number
	local offline = Config.Balance.Offline
	local capHours = if hasAutoCollect then offline.capHoursWithGamepass else offline.capHours
	local cappedSeconds = math.clamp(elapsedSeconds, 0, capHours * 3600)
	return incomePerSecond * cappedSeconds * offline.efficiency
end

function Economy.netWorth(profile: Types.Profile): number
	local total = profile.coins + profile.stash
	for _, treasure in profile.treasures do
		total += Economy.treasureValue(treasure)
	end
	return math.floor(total)
end

function Economy.upgradeCost(upgradeId: string, currentLevel: number): number
	return Config.Upgrades.cost(upgradeId, currentLevel)
end

function Economy.canAffordUpgrade(coins: number, upgradeId: string, currentLevel: number): boolean
	local upgrade = Config.Upgrades.get(upgradeId)
	if currentLevel >= upgrade.maxLevel then
		return false
	end
	return coins >= Economy.upgradeCost(upgradeId, currentLevel)
end

function Economy.crateCost(crateId: string, discount: number): number
	local crate = Config.Crates.get(crateId)
	return math.max(1, math.floor(crate.cost * (1 - math.clamp(discount, 0, 0.9))))
end

function Economy.canRebirth(netWorth: number, rebirths: number): boolean
	return netWorth >= Config.Rebirth.requirement(rebirths)
end

-- Şans çarpanı: yükseltme + gamepass + aktif iksir + event.
export type LuckContext = {
	upgrades: { [string]: number },
	vip: boolean,
	boostMultiplier: number,
	eventLuck: number,
}

function Economy.luckMultiplier(context: LuckContext): number
	local luck = 1 + Config.Upgrades.effect("luck", context.upgrades.luck or 0)
	if context.vip then
		luck *= 1.1
	end
	return luck * math.max(context.boostMultiplier, 1) * math.max(context.eventLuck, 1)
end

return Economy
