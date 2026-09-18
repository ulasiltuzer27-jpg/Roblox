--!strict
-- Sandık açma matematiği. Sunucu otoritesi burada: istemci hiçbir zaman
-- kendi sonucunu üretmez, sadece bu modülün çıktısını animasyonla gösterir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local Types = require(ReplicatedStorage.Shared.Core.Types)

type Rng = Rng.Rng

local Loot = {}

-- Şans çarpanı ağırlıkları nadirlik sırasına göre büker.
-- w' = w * luck^((order - 2) * LuckExponent); yani "Sıradan" ve "Alışılmadık"
-- etkilenmez, üst kademeler kademeli olarak artar.
Loot.LuckExponent = 0.5

local function rarityOrderList(crateId: string): { string }
	local crate = Config.Crates.get(crateId)
	local order = {}
	for _, rarity in Config.Rarities.List do
		if crate.weights[rarity.id] then
			table.insert(order, rarity.id)
		end
	end
	return order
end

-- Şans uygulanmış ağırlıklar. UI'daki yüzdeler de buradan okunur ki
-- gösterilen oran gerçekten atılan zarla aynı olsun.
function Loot.weightsFor(crateId: string, luck: number): ({ [string]: number }, { string })
	local crate = Config.Crates.get(crateId)
	local order = rarityOrderList(crateId)
	local weights = {}
	for _, rarityId in order do
		local rarity = Config.Rarities.get(rarityId)
		local exponent = math.max(0, rarity.order - 2) * Loot.LuckExponent
		weights[rarityId] = crate.weights[rarityId] * math.max(luck, 0.01) ^ exponent
	end
	return weights, order
end

function Loot.rarityChance(crateId: string, rarityId: string, luck: number): number
	local weights, order = Loot.weightsFor(crateId, luck)
	local total = 0
	for _, id in order do
		total += weights[id]
	end
	if total <= 0 then
		return 0
	end
	return (weights[rarityId] or 0) / total
end

function Loot.rollRarity(crateId: string, luck: number, rng: Rng): string
	local weights, order = Loot.weightsFor(crateId, luck)
	return Rng.weightedKey(rng, weights, order)
end

-- Mutasyon şansı: "normal" sabit kalır, diğerleri çarpanla büyür.
function Loot.mutationWeights(mutationLuck: number): ({ [string]: number }, { string })
	local weights = {}
	local order = {}
	for _, mutation in Config.Mutations.List do
		table.insert(order, mutation.id)
		if mutation.id == Config.Mutations.DefaultId then
			weights[mutation.id] = mutation.weight
		else
			weights[mutation.id] = mutation.weight * math.max(mutationLuck, 0)
		end
	end
	return weights, order
end

function Loot.mutationChance(mutationId: string, mutationLuck: number): number
	local weights, order = Loot.mutationWeights(mutationLuck)
	local total = 0
	for _, id in order do
		total += weights[id]
	end
	if total <= 0 then
		return 0
	end
	return (weights[mutationId] or 0) / total
end

function Loot.rollMutation(mutationLuck: number, rng: Rng): string
	local weights, order = Loot.mutationWeights(mutationLuck)
	return Rng.weightedKey(rng, weights, order)
end

export type RollContext = {
	luck: number,
	mutationLuck: number,
}

-- Tek sandığın sonucu. uid'i çağıran verir (sunucu sayacı) ki test edilebilir kalsın.
function Loot.roll(crateId: string, context: RollContext, rng: Rng, uid: string, now: number): Types.Treasure
	return {
		uid = uid,
		rarity = Loot.rollRarity(crateId, context.luck, rng),
		mutation = Loot.rollMutation(context.mutationLuck, rng),
		crate = crateId,
		foundAt = now,
	}
end

-- Sunucu geneline duyurulacak kadar iyi mi? (Efsanevi+ ya da Glitch+ mutasyon)
function Loot.shouldAnnounce(treasure: Types.Treasure): boolean
	return Config.Rarities.get(treasure.rarity).announce or Config.Mutations.get(treasure.mutation).announce
end

function Loot.displayName(treasure: Types.Treasure): string
	local mutation = Config.Mutations.get(treasure.mutation)
	local rarity = Config.Rarities.get(treasure.rarity)
	if mutation.id == Config.Mutations.DefaultId then
		return rarity.name
	end
	return `{mutation.name} {rarity.name}`
end

return Loot
