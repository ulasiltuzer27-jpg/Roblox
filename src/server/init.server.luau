--!nonstrict
-- Sunucu açılışı. Servisler burada sırayla kurulur ve istemciden gelen
-- her eylem buradaki tabloya bağlanır -- ağ yüzeyinin tamamı tek ekranda.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Format = require(ReplicatedStorage.Shared.Core.Format)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Services = ServerScriptService.Server.Services

local AnalyticsService = require(Services.AnalyticsService)
local ArenaService = require(Services.ArenaService)
local CodeService = require(Services.CodeService)
local CrateService = require(Services.CrateService)
local DailyRewardService = require(Services.DailyRewardService)
local DataService = require(Services.DataService)
local DefenseService = require(Services.DefenseService)
local EventService = require(Services.EventService)
local HeistService = require(Services.HeistService)
local IncomeService = require(Services.IncomeService)
local LeaderboardService = require(Services.LeaderboardService)
local MonetizationService = require(Services.MonetizationService)
local NetService = require(Services.NetService)
local NotificationService = require(Services.NotificationService)
local RebirthService = require(Services.RebirthService)
local SyncService = require(Services.SyncService)
local TutorialService = require(Services.TutorialService)
local VaultService = require(Services.VaultService)
local WorldService = require(Services.WorldService)

local Actions = Remotes.Actions
local Inputs = Remotes.Inputs

local function registerActions()
	NetService.register(Actions.BuyCrates, CrateService.buy)

	NetService.register(Actions.OpenCrates, function(player, payload)
		local ok, result = CrateService.open(player, payload)
		if ok then
			TutorialService.trigger(player, "crate_opened")
		end
		return ok, result
	end)

	NetService.register(Actions.PlaceTreasure, function(player, payload)
		return VaultService.place(player, payload and payload.uid, payload and payload.slot)
	end)

	NetService.register(Actions.UnplaceTreasure, function(player, payload)
		return VaultService.unplace(player, payload and payload.uid)
	end)

	NetService.register(Actions.SellTreasures, function(player, payload)
		local uids = payload and payload.uids
		if type(uids) ~= "table" then
			return false, "Satılacak hazine seçilmedi."
		end
		return VaultService.sell(player, uids)
	end)

	NetService.register(Actions.CollectStash, function(player)
		local collected = IncomeService.collect(player)
		if collected <= 0 then
			return false, "Kasanda toplanacak bir şey yok."
		end
		TutorialService.trigger(player, "stash_collected")
		NotificationService.toast(player, `{Format.short(collected)} coin toplandı.`, "good")
		return true, { coins = collected }
	end)

	NetService.register(Actions.BuyUpgrade, DefenseService.buyUpgrade)

	NetService.register(Actions.BuyDefense, function(player, payload)
		local ok, result = DefenseService.buy(player, payload)
		if ok then
			TutorialService.trigger(player, "defense_bought")
		end
		return ok, result
	end)

	NetService.register(Actions.ListTargets, function(player)
		return true, { targets = VaultService.list(player) }
	end)

	NetService.register(Actions.StartHeist, HeistService.start)
	NetService.register(Actions.AbortHeist, HeistService.abort)
	NetService.register(Actions.ClaimDaily, DailyRewardService.claim)
	NetService.register(Actions.RedeemCode, CodeService.redeem)

	NetService.register(Actions.Rebirth, function(player, payload)
		local ok, result = RebirthService.perform(player, payload)
		if ok then
			AnalyticsService.logFunnelStep(player, 4, "İlk rebirth")
		end
		return ok, result
	end)
	NetService.register(Actions.TravelZone, RebirthService.travel)

	NetService.register(Actions.AdvanceTutorial, function(player)
		-- İstemci yeniden bağlandığında mevcut adımı ister.
		SyncService.markDirty(player)
		return true
	end)

	NetService.onInput(Inputs.Move, HeistService.setMode)
	NetService.onInput(Inputs.DoorAttempt, HeistService.doorAttempt)
end

local function main()
	-- Sıra önemli: ağ ve bildirim altyapısı önce, oyuncu verisi en son
	-- (DataService kurulur kurulmaz oyuncuları yüklemeye başlıyor).
	NetService.init()
	NotificationService.init()
	EventService.init()
	SyncService.init()
	MonetizationService.init()
	VaultService.init()
	IncomeService.init()
	HeistService.init()
	LeaderboardService.init()
	TutorialService.init()
	AnalyticsService.init()
	WorldService.init()

	registerActions()

	HeistService.Finished:connect(function(player)
		TutorialService.trigger(player, "heist_done")
	end)

	DataService.Loaded:connect(function(player)
		EventService.pushTo(player)
		LeaderboardService.pushTo(player)
	end)

	DataService.init()

	print(`[VaultHeist] sunucu hazır · {ArenaService.activeCount()} aktif soygun`)
end

main()
