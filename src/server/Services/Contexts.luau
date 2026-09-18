--!nonstrict
-- Çarpanların tek toplanma noktası. Gelir, şans ve savunma hesaplarında
-- "hangi bonus nereden geliyor" sorusunun cevabı burada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local DataService = require(ServerScriptService.Server.Services.DataService)
local EventService = require(ServerScriptService.Server.Services.EventService)

local Contexts = {}

function Contexts.hasPass(player: Player, passId: string): boolean
	return DataService.runtime(player).gamepasses[passId] == true
end

function Contexts.boost(profile, kind: string): number
	local boost = profile.boosts and profile.boosts[kind]
	if not boost or boost.expiresAt <= os.time() then
		return 1
	end
	return boost.multiplier
end

function Contexts.placedTreasures(profile): { any }
	local placed = {}
	for _, uid in profile.placed do
		local treasure = profile.treasures[uid]
		if treasure then
			table.insert(placed, treasure)
		end
	end
	return placed
end

function Contexts.income(player: Player, profile): Economy.IncomeContext
	return {
		upgrades = profile.upgrades,
		rebirths = profile.rebirths,
		zone = profile.zone,
		doubleIncome = Contexts.hasPass(player, "double_income"),
		eventMultiplier = EventService.effects().incomeMultiplier,
	}
end

function Contexts.incomePerSecond(player: Player, profile): number
	return Economy.incomePerSecond(Contexts.placedTreasures(profile), Contexts.income(player, profile))
end

function Contexts.luck(player: Player, profile): number
	return Economy.luckMultiplier({
		upgrades = profile.upgrades,
		vip = Contexts.hasPass(player, "vip"),
		boostMultiplier = Contexts.boost(profile, "luck"),
		eventLuck = EventService.effects().rarityLuck,
	})
end

function Contexts.mutationLuck(player: Player, profile): number
	return EventService.effects().mutationLuck * Contexts.boost(profile, "mutation")
end

function Contexts.slots(player: Player, profile): number
	return Economy.slotCount(profile.upgrades, Contexts.hasPass(player, "extra_slots"))
end

-- Kasanın savunma bağlamı; sahibi çevrimiçi mi bilgisini çağıran verir
-- (çevrimdışı kasalar da soyulabiliyor).
function Contexts.defense(profile, ownerOnline: boolean, vipLock: boolean)
	local effects = EventService.effects()
	return {
		defenses = profile.defenses,
		defensePowerUpgrade = profile.upgrades.defense_power or 0,
		vipLock = vipLock,
		ownerOnline = ownerOnline,
		eventDefenseMultiplier = effects.defenseMultiplier,
		guardsDisabled = effects.guardsDisabled == true,
	}
end

return Contexts
