--!nonstrict
-- İstemcinin tek doğruluk kaynağı. Sunucudan gelen anlık görüntü burada
-- tutulur; paneller State.Changed'e abone olup kendini yeniler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local Net = require(script.Parent.Net)

local State = {}

State.profile = nil
State.event = nil
State.targets = {}
State.leaderboard = {}
State.tutorial = nil
State.heist = nil

State.Changed = Signal.new()
State.EventChanged = Signal.new()
State.TargetsChanged = Signal.new()
State.LeaderboardChanged = Signal.new()
State.TutorialChanged = Signal.new()

function State.has(): boolean
	return State.profile ~= nil
end

function State.refreshTargets()
	task.spawn(function()
		local response = Net.invoke("ListTargets")
		if response.ok and response.data then
			State.targets = response.data.targets
			State.TargetsChanged:fire(State.targets)
		end
	end)
end

function State.init()
	Net.on("Profile", function(snapshot)
		if snapshot.partial and State.profile then
			-- Hafif paket yalnızca sayıları taşır; envanteri ezmesin.
			for key, value in snapshot do
				if key ~= "partial" then
					State.profile[key] = value
				end
			end
		else
			State.profile = snapshot
		end
		State.Changed:fire(State.profile)
	end)

	Net.on("EventState", function(payload)
		State.event = payload
		State.EventChanged:fire(payload)
	end)

	Net.on("Leaderboard", function(payload)
		State.leaderboard = payload.boards
		State.LeaderboardChanged:fire(State.leaderboard)
	end)

	Net.on("Tutorial", function(payload)
		State.tutorial = payload
		State.TutorialChanged:fire(payload)
	end)
end

return State
