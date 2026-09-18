--!nonstrict
-- Denge raporu: her sandığın beklenen değerini ve geri ödeme süresini yazar.
-- `./scripts/balance.sh` ile çalışır. Sayı değiştirdiğinde önce buna bak.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)

local function expectedMutationMultiplier(mutationLuck: number): number
	local total = 0
	for _, mutation in Config.Mutations.List do
		total += Loot.mutationChance(mutation.id, mutationLuck) * mutation.multiplier
	end
	return total
end

local function expectedRarityIncome(crateId: string, luck: number): number
	local total = 0
	for _, rarity in Config.Rarities.List do
		total += Loot.rarityChance(crateId, rarity.id, luck) * rarity.baseIncome
	end
	return total
end

-- Türkçe karakterler çok baytlı; hizalama için karakter sayısı gerekiyor.
local function pad(text: string, width: number): string
	local length = utf8.len(text) or #text
	if length >= width then
		return text .. " "
	end
	return text .. string.rep(" ", width - length)
end

print("")
print("SANDIK BEKLENEN DEĞERLERİ (şans x1, mutasyon x1, çarpansız)")
print(string.rep("-", 100))
print(
	pad("Sandık", 18)
		.. pad("Fiyat", 12)
		.. pad("Gelir/sn", 12)
		.. pad("Geri ödeme", 14)
		.. pad("Bölge çarpanıyla", 18)
		.. pad("Satış değeri", 14)
)
print(string.rep("-", 100))

local mutationMultiplier = expectedMutationMultiplier(1)
for _, crate in Config.Crates.List do
	local income = expectedRarityIncome(crate.id, 1) * mutationMultiplier
	local value = income * Config.Rarities.SellSeconds
	local payback = if crate.currency == "coins" and income > 0 then crate.cost / income else 0

	-- O bölgeye ulaşan oyuncunun tipik çarpanı: bölge bonusu x rebirth çarpanı.
	local zone = Config.Zones.get(crate.zone)
	local zoneMultiplier = (1 + zone.incomeBonus) * Config.Rebirth.multiplier(zone.requiredRebirths)

	print(
		pad(crate.name, 18)
			.. pad(
				if crate.currency == "tokens" then `{crate.cost} jeton` else Format.short(crate.cost),
				12
			)
			.. pad(Format.short(income), 12)
			.. pad(if payback > 0 then Format.time(payback) else "-", 14)
			.. pad(if payback > 0 then Format.time(payback / zoneMultiplier) else "-", 18)
			.. pad(Format.short(value), 14)
	)
end

print("")
print(`Beklenen mutasyon çarpanı: x{string.format("%.3f", mutationMultiplier)}`)
print(`Mutasyon şansları: Altın {Format.odds(Loot.mutationChance("gold", 1))}, ` ..
	`Neon {Format.odds(Loot.mutationChance("neon", 1))}, ` ..
	`Glitch {Format.odds(Loot.mutationChance("glitch", 1))}, ` ..
	`Boşluk {Format.odds(Loot.mutationChance("void", 1))}, ` ..
	`Prizma {Format.odds(Loot.mutationChance("prism", 1))}`)

print("")
print("REBIRTH EŞİKLERİ")
print(string.rep("-", 100))
for rebirths = 0, 7 do
	print(
		pad(`Rebirth {rebirths} -> {rebirths + 1}`, 24)
			.. pad(Format.short(Config.Rebirth.requirement(rebirths)) .. " servet", 20)
			.. pad(`gelir x{Config.Rebirth.multiplier(rebirths + 1)}`, 16)
			.. pad(`+{Config.Rebirth.tokensFor(rebirths)} jeton`, 14)
	)
end

print("")
print("SAVUNMA MALİYETİ (kümülatif, tam seviye)")
print(string.rep("-", 100))
for _, defense in Config.Defenses.List do
	local total = 0
	for level = 0, defense.maxLevel - 1 do
		total += Config.Defenses.upgradeCost(defense.id, level)
	end
	print(pad(defense.name, 22) .. pad(`{defense.maxLevel} seviye`, 14) .. pad(Format.short(total) .. " coin", 16))
end

print("")
print("YÜKSELTME MALİYETİ (kümülatif, tam seviye)")
print(string.rep("-", 100))
for _, upgrade in Config.Upgrades.List do
	local total = 0
	for level = 0, upgrade.maxLevel - 1 do
		total += Config.Upgrades.cost(upgrade.id, level)
	end
	local effect = Config.Upgrades.effect(upgrade.id, upgrade.maxLevel)
	print(
		pad(upgrade.name, 22)
			.. pad(`{upgrade.maxLevel} seviye`, 14)
			.. pad(Format.short(total) .. " coin", 16)
			.. pad(`toplam etki {string.format("%.2f", effect)}`, 22)
	)
end

print("")
print("İLK 10 DAKİKA (yeni oyuncu, 3 ücretsiz Ahşap Sandık)")
print(string.rep("-", 100))
local starterIncome = expectedRarityIncome("wood", 1) * mutationMultiplier * 3
print(`Başlangıç coin: {Config.Balance.Economy.startingCoins}`)
print(`3 sandık sonrası beklenen gelir: {Format.short(starterIncome)}/sn`)
print(`Ahşap Sandık fiyatı: {Format.short(Config.Crates.get("wood").cost)} coin`)
print(`Bir sandık daha almak için gereken süre: {Format.time(Config.Crates.get("wood").cost / starterIncome)}`)
print(`Kasa birikim tavanı: {Format.time(Config.Balance.Vault.onlineStashSeconds)} değerinde gelir`)
print(`Çevrimdışı: {Config.Balance.Offline.capHours} saate kadar, %{Config.Balance.Offline.efficiency * 100} verimle`)
print("")

return true
