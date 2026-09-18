--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require("../framework")
local Config = require(ReplicatedStorage.Shared.Config)
local EventClock = require(ReplicatedStorage.Shared.Core.EventClock)

local describe, it, expect = Framework.describe, Framework.it, Framework.expect
local EVENTS = Config.ServerEvents
local CYCLE = EVENTS.CycleSeconds
local EVENT_START = CYCLE - EVENTS.EventSeconds

describe("EventClock", function()
	it("turun başında event yok", function()
		local state = EventClock.state(0)
		expect.equal(state.phase, "idle")
		expect.equal(state.secondsLeft, EVENT_START)
	end)

	it("başlangıçtan 30 saniye önce uyarı verir", function()
		local warning = EventClock.state(EVENT_START - EVENTS.WarningSeconds)
		expect.equal(warning.phase, "warning")
		local idle = EventClock.state(EVENT_START - EVENTS.WarningSeconds - 1)
		expect.equal(idle.phase, "idle")
	end)

	it("event penceresi tam süre açık kalır", function()
		expect.equal(EventClock.state(EVENT_START).phase, "active")
		expect.equal(EventClock.state(CYCLE - 1).phase, "active")
		expect.equal(EventClock.state(CYCLE).phase, "idle")
	end)

	it("aktif eventte kalan süre azalır", function()
		local start = EventClock.state(EVENT_START)
		local middle = EventClock.state(EVENT_START + 60)
		expect.equal(start.secondsLeft, EVENTS.EventSeconds)
		expect.equal(middle.secondsLeft, EVENTS.EventSeconds - 60)
	end)

	it("eventler sırayla döner", function()
		local seen = {}
		for cycle = 0, #EVENTS.List - 1 do
			local state = EventClock.state(cycle * CYCLE + EVENT_START)
			expect.equal(state.phase, "active")
			table.insert(seen, state.event.id)
		end
		expect.equal(#seen, #EVENTS.List)
		for index, event in EVENTS.List do
			expect.equal(seen[index], event.id)
		end
		-- Liste bitince başa sarar.
		local wrapped = EventClock.state(#EVENTS.List * CYCLE + EVENT_START)
		expect.equal(wrapped.event.id, EVENTS.List[1].id)
	end)

	it("iki sunucu aynı saniyede aynı eventi görür", function()
		local now = 1726670000
		local a = EventClock.state(now)
		local b = EventClock.state(now)
		expect.equal(a.event.id, b.event.id)
		expect.equal(a.phase, b.phase)
	end)

	it("event yokken etkiler nötr", function()
		local effects = EventClock.effects(0)
		expect.equal(effects.incomeMultiplier, 1)
		expect.equal(effects.stealShareMultiplier, 1)
		expect.equal(effects.crateDiscount, 0)
		expect.falsy(effects.guardsDisabled)
	end)

	it("Altın Saat geliri ikiye katlar", function()
		-- İlk turun eventi listedeki ilk event.
		local effects = EventClock.effects(EVENT_START)
		expect.equal(EVENTS.List[1].id, "golden_hour")
		expect.equal(effects.incomeMultiplier, 2)
		-- Diğer alanlar nötr kalmalı.
		expect.equal(effects.defenseMultiplier, 1)
	end)

	it("nötr etkiler çağrıldığı yerde değiştirilemez", function()
		local first = EventClock.neutralEffects()
		first.incomeMultiplier = 99
		expect.equal(EventClock.neutralEffects().incomeMultiplier, 1)
	end)
end)

return true
