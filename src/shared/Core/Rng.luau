--!strict
-- Deterministik üreteç (Lehmer / Park-Miller). Aynı tohum -> aynı koridor,
-- böylece sunucu ile istemci tek sayı alışverişiyle aynı düzeni kurabilir.
local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 16807

export type Rng = typeof(setmetatable({} :: { _state: number }, Rng))

function Rng.new(seed: number?): Rng
	local state = math.floor(seed or 1) % MODULUS
	if state <= 0 then
		state += MODULUS - 1
	end
	return setmetatable({ _state = state }, Rng)
end

function Rng.nextInteger(self: Rng): number
	self._state = (self._state * MULTIPLIER) % MODULUS
	return self._state
end

-- [0, 1)
function Rng.nextNumber(self: Rng): number
	return (Rng.nextInteger(self) - 1) / (MODULUS - 1)
end

function Rng.range(self: Rng, min: number, max: number): number
	return min + Rng.nextNumber(self) * (max - min)
end

function Rng.int(self: Rng, min: number, max: number): number
	return math.floor(Rng.range(self, min, max + 1 - 1e-9))
end

function Rng.chance(self: Rng, probability: number): boolean
	return Rng.nextNumber(self) < probability
end

-- entries: { { weight = n, ... } } veya { [key] = weight }
function Rng.weightedIndex(self: Rng, weights: { number }): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total <= 0 then
		return 1
	end
	local roll = Rng.nextNumber(self) * total
	local cursor = 0
	for index, weight in weights do
		cursor += weight
		if roll < cursor then
			return index
		end
	end
	return #weights
end

function Rng.weightedKey(self: Rng, weights: { [string]: number }, order: { string }): string
	local list = table.create(#order)
	for _, key in order do
		table.insert(list, weights[key] or 0)
	end
	return order[Rng.weightedIndex(self, list)]
end

function Rng.pick<T>(self: Rng, list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[Rng.int(self, 1, #list)]
end

return Rng
