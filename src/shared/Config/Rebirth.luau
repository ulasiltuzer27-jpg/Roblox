--!strict
-- Rebirth: coin, hazine ve yükseltmeler sıfırlanır; kalıcı çarpan ve jeton kalır.
--
-- Eşik, ilerleme simülasyonuyla ölçüldü (25 tohum, tests/specs/Progression.spec
-- ve sim/). Satış ekonomisi düzeltildikten sonra ortanca servet:
-- 10 dk ~77K, 20 dk ~236K, 30 dk ~368K, 60 dk ~829K.
-- 250K eşiği ilk rebirth'ü 20-25 dakika bandına koyuyor; oyuncu rebirth'ten
-- önce soygun dahil bütün döngüyü bir kez görüyor.
local Rebirth = {}

Rebirth.RequirementBase = 250000
Rebirth.RequirementGrowth = 5.5
Rebirth.MultiplierPerRebirth = 0.25 -- +%25 kalıcı gelir
Rebirth.TokensBase = 1
Rebirth.TokensPerRebirth = 1
Rebirth.MaxDisplayed = 25

-- N'inci rebirth için gereken toplam servet (net worth).
function Rebirth.requirement(currentRebirths: number): number
	return math.floor(Rebirth.RequirementBase * Rebirth.RequirementGrowth ^ currentRebirths)
end

function Rebirth.multiplier(rebirths: number): number
	return 1 + Rebirth.MultiplierPerRebirth * rebirths
end

function Rebirth.tokensFor(currentRebirths: number): number
	return Rebirth.TokensBase + Rebirth.TokensPerRebirth * currentRebirths
end

return Rebirth
