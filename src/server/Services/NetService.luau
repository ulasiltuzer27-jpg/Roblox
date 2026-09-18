--!nonstrict
-- Ağ kapısı: eylem kaydı, hız sınırlama ve hata yalıtımı.
-- Hiçbir servis doğrudan RemoteFunction'a bağlanmaz, hepsi buradan geçer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local NET = Config.Balance.Net

local NetService = {}

local bridge = nil
local actionHandlers: { [string]: (Player, any) -> (boolean, any) } = {}
local inputHandlers: { [string]: (Player, any) -> () } = {}
local buckets: { [number]: { [string]: { tokens: number, at: number } } } = {}

local function takeToken(player: Player, kind: string, rate: number, burst: number): boolean
	local playerBuckets = buckets[player.UserId]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player.UserId] = playerBuckets
	end

	local bucket = playerBuckets[kind]
	local clock = os.clock()
	if not bucket then
		bucket = { tokens = burst, at = clock }
		playerBuckets[kind] = bucket
	end

	bucket.tokens = math.min(burst, bucket.tokens + (clock - bucket.at) * rate)
	bucket.at = clock

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function NetService.register(action: string, handler: (Player, any) -> (boolean, any))
	assert(Remotes.Actions[action], `tanımsız eylem: {action}`)
	actionHandlers[action] = handler
end

function NetService.onInput(kind: string, handler: (Player, any) -> ())
	assert(Remotes.Inputs[kind], `tanımsız girdi: {kind}`)
	inputHandlers[kind] = handler
end

function NetService.push(player: Player, channel: string, payload: any)
	assert(Remotes.Channels[channel], `tanımsız kanal: {channel}`)
	bridge.push:FireClient(player, channel, payload)
end

function NetService.pushAll(channel: string, payload: any)
	assert(Remotes.Channels[channel], `tanımsız kanal: {channel}`)
	bridge.push:FireAllClients(channel, payload)
end

function NetService.init()
	bridge = Remotes.get()

	bridge.action.OnServerInvoke = function(player: Player, action: any, payload: any)
		if type(action) ~= "string" then
			return { ok = false, error = "Geçersiz istek." }
		end
		local handler = actionHandlers[action]
		if not handler then
			return { ok = false, error = "Bilinmeyen istek." }
		end
		if not takeToken(player, "action", NET.actionsPerSecond, NET.actionBurst) then
			return { ok = false, error = "Çok hızlı gidiyorsun, bir saniye bekle." }
		end

		local ok, result, extra = pcall(handler, player, payload)
		if not ok then
			warn(`[NetService] {action} hatası:`, result)
			return { ok = false, error = "Bir şeyler ters gitti." }
		end
		if result == false then
			return { ok = false, error = extra or "İşlem yapılamadı." }
		end
		return { ok = true, data = extra }
	end

	bridge.input.OnServerEvent:Connect(function(player: Player, kind: any, payload: any)
		if type(kind) ~= "string" then
			return
		end
		local handler = inputHandlers[kind]
		if not handler then
			return
		end
		if not takeToken(player, "input", NET.inputsPerSecond, NET.inputBurst) then
			return
		end
		local ok, err = pcall(handler, player, payload)
		if not ok then
			warn(`[NetService] {kind} girdisi hatası:`, err)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player.UserId] = nil
	end)
end

return NetService
