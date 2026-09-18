--!strict
-- Rebirth: coin, hazine ve yükseltmeler sıfırlanır; kalıcı çarpan ve jeton kalır.
--
-- Eşik, ilerleme simülasyonuyla ölçüldü (25 tohum, tests/specs/Progression.spec):
-- ortanca servet 10 dakikada ~445K, 15 dakikada ~1.0M, 20 dakikada ~1.66M.
-- 1M eşiği ilk rebirth'ü 15-20 dakika bandına koyuyor; oyuncu rebirth'ten
-- önce soygun dahil bütün döngüyü bir kez görüyor. Yuvarlak sayı bilinçli:
-- "1M servet" oyuncunun kafasında takip edebileceği bir hedef.
local Rebirth = {}

Rebirth.RequirementBase = 1000000
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
