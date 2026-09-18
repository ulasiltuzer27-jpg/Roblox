--!strict
-- Sunucu eventleri duvar saatinden türetilir: bütün sunucularda aynı anda
-- aynı event başlar, arkadaşına "gel, Altın Saat var" demek anlamlı olur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerEvents = require(ReplicatedStorage.Shared.Config.ServerEvents)

local EventClock = {}
local EVENTS = ServerEvents

export type Phase = "idle" | "warning" | "active"

export type State = {
	phase: Phase,
	event: ServerEvents.ServerEvent,
	secondsLeft: number, -- aktifse bitişe, değilse başlangıca kalan süre
	startsAt: number,
	endsAt: number,
}

local function eventForCycle(cycleIndex: number)
	local index = (cycleIndex % #EVENTS.List) + 1
	return EVENTS.List[index]
end

function EventClock.state(now: number): State
	local cycle = EVENTS.CycleSeconds
	local cycleIndex = math.floor(now / cycle)
	local position = now % cycle
	local eventStart = cycle - EVENTS.EventSeconds

	if position >= eventStart then
		local startsAt = (cycleIndex * cycle) + eventStart
		return {
			phase = "active",
			event = eventForCycle(cycleIndex),
			secondsLeft = (startsAt + EVENTS.EventSeconds) - now,
			startsAt = startsAt,
			endsAt = startsAt + EVENTS.EventSeconds,
		}
	end

	local startsAt = (cycleIndex * cycle) + eventStart
	local secondsLeft = startsAt - now
	return {
		phase = if secondsLeft <= EVENTS.WarningSeconds then "warning" else "idle",
		event = eventForCycle(cycleIndex),
		secondsLeft = secondsLeft,
		startsAt = startsAt,
		endsAt = startsAt + EVENTS.EventSeconds,
	}
end

export type Effects = {
	incomeMultiplier: number,
	mutationLuck: number,
	rarityLuck: number,
	stealShareMultiplier: number,
	defenseMultiplier: number,
	guardsDisabled: boolean,
	crateDiscount: number,
}

local NEUTRAL: Effects = {
	incomeMultiplier = 1,
	mutationLuck = 1,
	rarityLuck = 1,
	stealShareMultiplier = 1,
	defenseMultiplier = 1,
	guardsDisabled = false,
	crateDiscount = 0,
}

function EventClock.neutralEffects(): Effects
	return table.clone(NEUTRAL)
end

function EventClock.effects(now: number): Effects
	local state = EventClock.state(now)
	local effects = table.clone(NEUTRAL)
	if state.phase ~= "active" then
		return effects
	end
	for key, value in state.event.effects do
		(effects :: any)[key] = value
	end
	return effects
end

return EventClock
