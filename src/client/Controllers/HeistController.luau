--!nonstrict
-- Soygun sırasındaki istemci mantığı: tuşlar, hareket modu ve ekran akışı.
local UserInputService = game:GetService("UserInputService")

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)

local HeistController = {}

local overlay = nil
local active = false
local holding = { sneak = false, sprint = false }
local currentMode = "walk"

local function resolveMode(): string
	if holding.sneak then
		return "sneak"
	elseif holding.sprint then
		return "sprint"
	end
	return "walk"
end

local function syncMode()
	local mode = resolveMode()
	if mode == currentMode then
		return
	end
	currentMode = mode
	if active then
		Net.send("Move", { mode = mode })
	end
end

function HeistController.abort()
	Net.invoke("AbortHeist")
end

function HeistController.doorAttempt()
	if active then
		Net.send("DoorAttempt")
	end
end

function HeistController.init(heistOverlay)
	overlay = heistOverlay

	Net.on("HeistStart", function(payload)
		active = true
		State.heist = payload
		currentMode = "walk"
		overlay.start(payload)
	end)

	Net.on("HeistTick", function(payload)
		overlay.tick(payload)
	end)

	Net.on("HeistEnd", function(payload)
		active = false
		State.heist = nil
		overlay.finish(payload)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			holding.sneak = true
			syncMode()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			holding.sprint = true
			syncMode()
		elseif input.KeyCode == Enum.KeyCode.E then
			HeistController.doorAttempt()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			holding.sneak = false
			syncMode()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			holding.sprint = false
			syncMode()
		end
	end)
end

function HeistController.isActive(): boolean
	return active
end

return HeistController
