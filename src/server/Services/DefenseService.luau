--!nonstrict
-- Kasa savunmalarının satın alınması ve yükseltilmesi.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local DefenseService = {}

function DefenseService.buy(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local defenseId = payload and payload.defenseId
	if type(defenseId) ~= "string" or not Config.Defenses.ById[defenseId] then
		return false, "Böyle bir savunma yok."
	end

	local defense = Config.Defenses.get(defenseId)
	local level = profile.defenses[defenseId] or 0
	if level >= defense.maxLevel then
		return false, `{defense.name} zaten en üst seviyede.`
	end

	local cost = Config.Defenses.upgradeCost(defenseId, level)
	if profile.coins < cost then
		return false, `{Format.short(cost)} coin gerekiyor.`
	end

	profile.coins -= cost
	profile.defenses[defenseId] = level + 1

	SyncService.markDirty(player)
	VaultService.Changed:fire(player.UserId)
	NotificationService.toast(player, `{defense.name} seviye {level + 1}`, "good")
	return true, { defenseId = defenseId, level = level + 1 }
end

function DefenseService.buyUpgrade(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local upgradeId = payload and payload.upgradeId
	if type(upgradeId) ~= "string" or not Config.Upgrades.ById[upgradeId] then
		return false, "Böyle bir yükseltme yok."
	end

	local upgrade = Config.Upgrades.get(upgradeId)
	local level = profile.upgrades[upgradeId] or 0
	if level >= upgrade.maxLevel then
		return false, `{upgrade.name} zaten en üst seviyede.`
	end

	local cost = Config.Upgrades.cost(upgradeId, level)
	if profile.coins < cost then
		return false, `{Format.short(cost)} coin gerekiyor.`
	end

	profile.coins -= cost
	profile.upgrades[upgradeId] = level + 1

	SyncService.markDirty(player)
	NotificationService.toast(player, `{upgrade.name} seviye {level + 1}`, "good")
	return true, { upgradeId = upgradeId, level = level + 1 }
end

return DefenseService
