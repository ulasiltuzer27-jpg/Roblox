--!nonstrict
-- İlk 60 saniye. Oyuncu ne yapacağını okumadan anlamalı ve ilk ödülünü
-- hemen almalı; adımlar gerçek oynanış olaylarıyla ilerliyor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Services.DataService)
local NetService = require(ServerScriptService.Server.Services.NetService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)

local TutorialService = {}

local STEPS = {
	{
		trigger = "crate_opened",
		title = "Sandığını aç",
		hint = "Sandık Dükkanı'na git ve ücretsiz Ahşap Sandığını aç.",
		reward = { coins = 250 },
	},
	{
		trigger = "stash_collected",
		title = "Birikimini topla",
		hint = "Hazinen para üretiyor. Kasandaki birikimi topla -- toplamadığın para çalınabilir.",
		reward = { coins = 500 },
	},
	{
		trigger = "defense_bought",
		title = "Kasanı koru",
		hint = "Bir Lazer Izgarası kur. Savunmasız kasa kolay hedef.",
		reward = { crates = { wood = 2 } },
	},
	{
		trigger = "heist_done",
		title = "Bir kasa soy",
		hint = "Soygun Panosu'ndan bir kasa seç ve koridoru geç.",
		reward = { coins = 2500, crates = { iron = 1 } },
	},
}

TutorialService.Steps = STEPS

local function push(player: Player, profile)
	local step = STEPS[profile.tutorial.step]
	NetService.push(player, "Tutorial", {
		done = profile.tutorial.done or step == nil,
		step = profile.tutorial.step,
		total = #STEPS,
		title = if step then step.title else nil,
		hint = if step then step.hint else nil,
	})
end

local function grant(player: Player, profile, reward)
	if reward.coins then
		profile.coins += reward.coins
	end
	if reward.crates then
		for crateId, amount in reward.crates do
			profile.crates[crateId] = (profile.crates[crateId] or 0) + amount
		end
	end
end

function TutorialService.trigger(player: Player, triggerName: string)
	local profile = DataService.get(player)
	if not profile or profile.tutorial.done then
		return
	end

	local step = STEPS[profile.tutorial.step]
	if not step or step.trigger ~= triggerName then
		return
	end

	grant(player, profile, step.reward)
	profile.tutorial.step += 1
	if profile.tutorial.step > #STEPS then
		profile.tutorial.done = true
		NotificationService.toast(player, "Eğitim tamam! Artık kasan senin.", "good")
	else
		NotificationService.toast(player, `Adım tamam: {step.title}`, "good")
	end

	SyncService.markDirty(player)
	push(player, profile)
end

function TutorialService.init()
	DataService.Loaded:connect(function(player, profile)
		push(player, profile)
	end)
end

return TutorialService
