--!strict
-- NPC kasalarının ölçeklenmesi. Saf matematik: hırsız ne kadar güçlüyse
-- NPC kasası da o kadar dolu ve o kadar korunaklı olsun.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

type Rng = Rng.Rng

local Bots = {}
local BOTS = Config.Balance.Bots

-- Birikim hırsızın kendi gelirine bağlı: yeni oyuncuya anlamlı, kıdemliye
-- küçük kalmayan bir ödül. Tavan, ekonominin kaçmasını engelliyor.
function Bots.stashFor(thiefIncomePerSecond: number, variance: number): number
	local base = math.max(BOTS.minStash, thiefIncomePerSecond * BOTS.stashSeconds)
	local scaled = base * math.clamp(variance, 0.5, BOTS.maxStashMultiplier)
	return math.floor(scaled)
end

-- Savunma seviyeleri rebirth ile ve listedeki sıraya göre artar: ilk kasa
-- kolay, sonuncusu ciddi bir meydan okuma.
function Bots.defensesFor(rebirths: number, index: number): { [string]: number }
	local level = math.clamp(
		BOTS.baseDefenseLevel + rebirths * BOTS.defenseLevelPerRebirth + (index - 1),
		0,
		BOTS.maxDefenseLevel
	)
	local defenses = {}
	for _, defense in Config.Defenses.List do
		-- Bekçi ve kapı bir tık geriden gelsin ki ilk NPC kasası bunaltmasın.
		local offset = if defense.id == "guard" or defense.id == "door" then 2 else 0
		defenses[defense.id] = math.max(0, level - offset)
	end
	return defenses
end

function Bots.nameFor(index: number): string
	local names = BOTS.names
	return names[((index - 1) % #names) + 1]
end

-- NPC kasalarına negatif kullanıcı kimliği veriyoruz: gerçek oyuncu
-- kimlikleriyle asla çakışmaz ve kayıt katmanı bunları görünce durur.
function Bots.userIdFor(index: number): number
	return -index
end

function Bots.isBot(userId: number): boolean
	return userId < 0
end

function Bots.build(index: number, thiefIncomePerSecond: number, rebirths: number, rng: Rng)
	local stash = Bots.stashFor(thiefIncomePerSecond, Rng.range(rng, 0.7, 1.6))
	return {
		userId = Bots.userIdFor(index),
		name = Bots.nameFor(index),
		stash = stash,
		-- Servet, hedef seçimi kurallarını geçebilmesi için birikimin üstünde.
		netWorth = stash * 4,
		defenses = Bots.defensesFor(rebirths, index),
	}
end

return Bots
