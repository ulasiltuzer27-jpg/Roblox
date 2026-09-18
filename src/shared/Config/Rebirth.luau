--!strict
-- Rebirth: coin, hazine ve yükseltmeler sıfırlanır; kalıcı çarpan ve jeton kalır.
local Rebirth = {}

Rebirth.RequirementBase = 250000
Rebirth.RequirementGrowth = 6.5
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
