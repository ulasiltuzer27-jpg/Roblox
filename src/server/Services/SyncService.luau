--!nonstrict
-- Profilin istemciye giden görünümü. Servisler yalnızca markDirty çağırır;
-- gönderim sabit aralıkta toplu yapılır ki her coin artışı paket doğurmasın.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Contexts = require(ServerScriptService.Server.Services.Contexts)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NetService = require(ServerScriptService.Server.Services.NetService)

local SyncService = {}

local dirty: { [number]: boolean } = {}

local function remaining(timestamp: number?): number
	return math.max(0, (timestamp or 0) - os.time())
end

-- İstemcinin gördüğü her şey. Ham profil asla olduğu gibi gönderilmiyor:
-- makbuzlar, soyan oyuncu geçmişi gibi alanlar istemcide işe yaramaz.
function SyncService.snapshot(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	local incomePerSecond = Contexts.incomePerSecond(player, profile)
	local boosts = {}
	for kind, boost in profile.boosts do
		local left = remaining(boost.expiresAt)
		if left > 0 then
			boosts[kind] = { multiplier = boost.multiplier, secondsLeft = left }
		end
	end

	return {
		coins = math.floor(profile.coins),
		tokens = profile.tokens,
		rebirths = profile.rebirths,
		zone = profile.zone,
		crates = profile.crates,
		treasures = profile.treasures,
		placed = profile.placed,
		upgrades = profile.upgrades,
		defenses = profile.defenses,

		stash = math.floor(profile.stash),
		stashCap = math.floor(Economy.stashCap(incomePerSecond)),
		incomePerSecond = incomePerSecond,
		slots = Contexts.slots(player, profile),
		netWorth = Economy.netWorth(profile),
		luck = Contexts.luck(player, profile),

		shieldSecondsLeft = remaining(profile.shieldUntil),
		jailSecondsLeft = remaining(profile.jailUntil),
		rebirthRequirement = Config.Rebirth.requirement(profile.rebirths),

		boosts = boosts,
		gamepasses = DataService.runtime(player).gamepasses,
		daily = profile.daily,
		tutorial = profile.tutorial,
		stats = profile.stats,
	}
end

function SyncService.markDirty(player: Player)
	dirty[player.UserId] = true
end

function SyncService.markAllDirty()
	for _, player in Players:GetPlayers() do
		dirty[player.UserId] = true
	end
end

function SyncService.flush(player: Player)
	local snapshot = SyncService.snapshot(player)
	if snapshot then
		dirty[player.UserId] = nil
		NetService.push(player, "Profile", snapshot)
	end
end

function SyncService.init()
	DataService.Loaded:connect(function(player)
		SyncService.flush(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Balance.Net.syncInterval)
			for userId in dirty do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					SyncService.flush(player)
				else
					dirty[userId] = nil
				end
			end
		end
	end)
end

return SyncService
