--!nonstrict
-- Tanıtım kodu kullanımı. Her kod oyuncu başına bir kez.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)

local CodeService = {}

local MAX_INPUT_LENGTH = 32

function CodeService.redeem(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end

	local input = payload and payload.code
	if type(input) ~= "string" or #input == 0 or #input > MAX_INPUT_LENGTH then
		return false, "Kod girmedin."
	end

	local code = Config.Codes.find(input)
	if not code then
		return false, "Böyle bir kod yok."
	end
	if not Config.Codes.isActive(code, os.time()) then
		return false, "Bu kodun süresi dolmuş."
	end

	local key = Config.Codes.normalize(code.code)
	if profile.codes[key] then
		return false, "Bu kodu zaten kullandın."
	end

	local rewards = code.rewards
	if rewards.coins then
		profile.coins += rewards.coins
	end
	if rewards.tokens then
		profile.tokens += rewards.tokens
	end
	if rewards.crates then
		for crateId, amount in rewards.crates do
			profile.crates[crateId] = (profile.crates[crateId] or 0) + amount
		end
	end
	if rewards.shieldSeconds then
		profile.shieldUntil = math.max(profile.shieldUntil, os.time()) + rewards.shieldSeconds
	end

	profile.codes[key] = os.time()
	SyncService.markDirty(player)
	NotificationService.toast(player, `Kod kullanıldı: {code.label}`, "good")
	return true, { label = code.label }
end

return CodeService
