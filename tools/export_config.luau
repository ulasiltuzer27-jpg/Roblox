--!nonstrict
-- Denge konfigürasyonunu JSON olarak basar. Python simülasyonu bunu okur;
-- böylece simülasyon oyunun kendi sayılarını kullanır, kopyasını değil.
--
--   ./scripts/sim.sh   (build/config.json üretir ve simülasyonu koşar)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Küçük JSON kodlayıcı. Kütüphane yok; sadece bu dosyanın ihtiyacı kadar.
local function encode(value: any, indent: string): string
	local valueType = type(value)

	if valueType == "nil" then
		return "null"
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
			return string.format("%d", value)
		end
		return string.format("%.10g", value)
	elseif valueType == "string" then
		local escaped = value
			:gsub("\\", "\\\\")
			:gsub('"', '\\"')
			:gsub("\n", "\\n")
			:gsub("\r", "\\r")
			:gsub("\t", "\\t")
		return `"{escaped}"`
	elseif valueType ~= "table" then
		return "null"
	end

	local nextIndent = indent .. "  "

	-- Dizi mi sözlük mü?
	local count = 0
	for _ in value do
		count += 1
	end
	local isArray = count == #value and count > 0

	if count == 0 then
		return "{}"
	end

	local parts = {}
	if isArray then
		for _, item in value do
			table.insert(parts, nextIndent .. encode(item, nextIndent))
		end
		return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
	end

	local keys = {}
	for key in value do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)

	for _, key in keys do
		local item = value[key] ~= nil and value[key] or value[tonumber(key)]
		table.insert(parts, `{nextIndent}{encode(key, nextIndent)}: {encode(item, nextIndent)}`)
	end
	return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

-- Fonksiyonla hesaplanan eğriler önceden tablolaştırılıyor: Python formülü
-- yeniden yazmasın, oyunun kendi hesabını kullansın.
local function upgradeCurves()
	local curves = {}
	for _, upgrade in Config.Upgrades.List do
		local costs = {}
		for level = 0, upgrade.maxLevel - 1 do
			table.insert(costs, Config.Upgrades.cost(upgrade.id, level))
		end
		curves[upgrade.id] = {
			name = upgrade.name,
			maxLevel = upgrade.maxLevel,
			perLevel = upgrade.perLevel,
			costs = costs,
		}
	end
	return curves
end

local function defenseCurves()
	local curves = {}
	for _, defense in Config.Defenses.List do
		local costs = {}
		for level = 0, defense.maxLevel - 1 do
			table.insert(costs, Config.Defenses.upgradeCost(defense.id, level))
		end
		curves[defense.id] = {
			name = defense.name,
			maxLevel = defense.maxLevel,
			scoreWeight = defense.scoreWeight,
			costs = costs,
		}
	end
	return curves
end

local function rebirthCurve()
	local requirements = {}
	local multipliers = {}
	local tokens = {}
	for rebirths = 0, 19 do
		table.insert(requirements, Config.Rebirth.requirement(rebirths))
		table.insert(multipliers, Config.Rebirth.multiplier(rebirths))
		table.insert(tokens, Config.Rebirth.tokensFor(rebirths))
	end
	return { requirements = requirements, multipliers = multipliers, tokens = tokens }
end

local function crateList()
	local crates = {}
	for _, crate in Config.Crates.List do
		table.insert(crates, {
			id = crate.id,
			name = crate.name,
			zone = crate.zone,
			cost = crate.cost,
			currency = crate.currency,
			openTime = crate.openTime,
			weights = crate.weights,
		})
	end
	return crates
end

local payload = {
	rarities = Config.Rarities.List,
	sellSeconds = Config.Rarities.SellSeconds,
	mutations = Config.Mutations.List,
	defaultMutation = Config.Mutations.DefaultId,
	crates = crateList(),
	zones = Config.Zones.List,
	upgrades = upgradeCurves(),
	defenses = defenseCurves(),
	rebirth = rebirthCurve(),
	balance = Config.Balance,
	serverEvents = {
		cycleSeconds = Config.ServerEvents.CycleSeconds,
		eventSeconds = Config.ServerEvents.EventSeconds,
		list = Config.ServerEvents.List,
	},
	dailyRewards = Config.DailyRewards.List,
	gamepasses = Config.Monetization.Gamepasses,
	products = Config.Monetization.Products,
	luckExponent = require(ReplicatedStorage.Shared.Core.Loot).LuckExponent,
}

print(encode(payload, ""))
return true
