--!nonstrict
-- Rebirth: ilerlemeyi sıfırlar, kalıcı çarpan ve jeton verir, yeni bölge açar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Validate = require(ReplicatedStorage.Shared.Core.Validate)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local RebirthService = {}

local REBIRTH_SHIELD_SECONDS = 600

function RebirthService.perform(player: Player): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local netWorth = Economy.netWorth(profile)
	if not Economy.canRebirth(netWorth, profile.rebirths) then
		local needed = Config.Rebirth.requirement(profile.rebirths)
		return false, `Rebirth için {Format.short(needed)} servet gerekiyor.`
	end

	local tokens = Config.Rebirth.tokensFor(profile.rebirths)
	profile.rebirths += 1
	profile.tokens += tokens

	-- Sıfırlananlar: para, hazineler, yükseltmeler. Savunmalar kalır ki
	-- rebirth sonrası kasan savunmasız kalmasın.
	profile.coins = Config.Balance.Economy.startingCoins
	profile.stash = 0
	profile.treasures = {}
	profile.placed = {}
	profile.upgrades = {}
	profile.crates = table.clone(Config.Balance.Economy.starterCrates)
	profile.shieldUntil = os.time() + REBIRTH_SHIELD_SECONDS

	SyncService.markDirty(player)
	VaultService.Changed:fire(player.UserId)

	NotificationService.announce(
		`♻️ {player.DisplayName} {profile.rebirths}. rebirth'ünü yaptı! (x{Config.Rebirth.multiplier(profile.rebirths)} gelir)`,
		{ 255, 200, 64 }
	)
	return true, { rebirths = profile.rebirths, tokens = tokens }
end

function RebirthService.travel(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local zoneId = Validate.oneOf(payload and payload.zoneId, Config.Zones.ById)
	if not zoneId then
		return false, "Böyle bir bölge yok."
	end
	if not Config.Zones.isUnlocked(zoneId, profile.rebirths) then
		local zone = Config.Zones.get(zoneId)
		return false, `{zone.name} için {zone.requiredRebirths} rebirth gerekiyor.`
	end

	profile.zone = zoneId
	SyncService.markDirty(player)
	return true, { zone = zoneId }
end

return RebirthService
