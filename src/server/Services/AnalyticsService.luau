--!nonstrict
-- Yayın sonrası bakılacak sayılar. Roblox AnalyticsService'e gönderiyoruz;
-- servis kapalıysa (Studio, eski istemci) sessizce pas geçiyor.
--
-- Neden önemli: keşfet algoritması oturum süresine ve ertesi gün dönüşe
-- bakıyor. Nerede kaybettiğini görmeden bunu düzeltemezsin.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local CrateService = require(ServerScriptService.Server.Services.CrateService)
local DataService = require(ServerScriptService.Server.Services.DataService)
local HeistService = require(ServerScriptService.Server.Services.HeistService)

local Analytics = {}

local ONBOARDING_FUNNEL = "Onboarding"

local function safe(callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		-- Analitik hiçbir zaman oynanışı bozmamalı.
		warn("[Analytics]", err)
	end
end

function Analytics.logFunnelStep(player: Player, step: number, name: string)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.logEconomy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	amount: number,
	balance: number,
	transactionType: string,
	itemSku: string?
)
	safe(function()
		AnalyticsService:LogEconomyEvent(player, flow, "coins", amount, balance, transactionType, itemSku)
	end)
end

function Analytics.init()
	DataService.Loaded:connect(function(player, profile)
		Analytics.logFunnelStep(player, 1, "Katıldı")
		if profile.stats.cratesOpened > 0 then
			Analytics.logFunnelStep(player, 2, "İlk sandık")
		end
		if profile.stats.heistsWon + profile.stats.heistsFailed > 0 then
			Analytics.logFunnelStep(player, 3, "İlk soygun")
		end
		if profile.rebirths > 0 then
			Analytics.logFunnelStep(player, 4, "İlk rebirth")
		end
	end)

	CrateService.Opened:connect(function(player, treasure)
		local profile = DataService.get(player)
		if not profile then
			return
		end
		if profile.stats.cratesOpened == 1 then
			Analytics.logFunnelStep(player, 2, "İlk sandık")
		end
		Analytics.logEconomy(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			Economy.treasureValue(treasure),
			profile.coins,
			"crate_open",
			treasure.crate
		)
	end)

	HeistService.Finished:connect(function(player, result)
		local profile = DataService.get(player)
		if not profile then
			return
		end
		if profile.stats.heistsWon + profile.stats.heistsFailed == 1 then
			Analytics.logFunnelStep(player, 3, "İlk soygun")
		end
		if result.success and result.coins > 0 then
			Analytics.logEconomy(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				result.coins,
				profile.coins,
				"heist_success",
				if result.perfect then "perfect" else "normal"
			)
		end
	end)
end

return Analytics
