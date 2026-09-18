--!nonstrict
-- Sunucu eventlerini duvar saatinden okur ve yayınlar. Zamanlama paylaşıldığı
-- için her sunucuda aynı anda aynı event başlar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EventClock = require(ReplicatedStorage.Shared.Core.EventClock)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local NetService = require(ServerScriptService.Server.Services.NetService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)

local EventService = {}

EventService.Started = Signal.new() -- (event)
EventService.Ended = Signal.new() -- (event)

local currentEffects = EventClock.neutralEffects()
local lastPhase = nil
local lastEventId = nil

function EventService.effects()
	return currentEffects
end

function EventService.state()
	return EventClock.state(os.time())
end

local function payloadFor(state)
	return {
		id = state.event.id,
		name = state.event.name,
		tagline = state.event.tagline,
		color = state.event.color,
		phase = state.phase,
		secondsLeft = math.floor(state.secondsLeft),
		-- İstemci indirimli fiyatı ve çarpanları gösterebilsin diye
		-- yürürlükteki etkiler de gidiyor.
		effects = currentEffects,
	}
end

local function broadcast(state)
	NetService.pushAll("EventState", payloadFor(state))
end

function EventService.pushTo(player: Player)
	NetService.push(player, "EventState", payloadFor(EventService.state()))
end

function EventService.init()
	task.spawn(function()
		while true do
			local state = EventService.state()
			currentEffects = EventClock.effects(os.time())

			local changed = state.phase ~= lastPhase or state.event.id ~= lastEventId
			if changed then
				if state.phase == "active" then
					NotificationService.announce(`⚡ {state.event.name}: {state.event.tagline}`, state.event.color)
					EventService.Started:fire(state.event)
				elseif lastPhase == "active" then
					EventService.Ended:fire(state.event)
				elseif state.phase == "warning" then
					NotificationService.announce(
						`{state.event.name} {math.ceil(state.secondsLeft)} saniye sonra başlıyor!`,
						state.event.color
					)
				end
				lastPhase = state.phase
				lastEventId = state.event.id
			end

			broadcast(state)
			task.wait(1)
		end
	end)
end

return EventService
