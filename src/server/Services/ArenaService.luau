--!nonstrict
-- Her soygun kendi arenasında geçer: koridorlar birbirinden uzak konumlarda
-- kurulur, böylece iki hırsız aynı anda farklı kasalara girebilir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local CORRIDOR = Config.Balance.Corridor

local ArenaService = {}

local slots: { [number]: boolean } = {}
local container: Folder? = nil

function ArenaService.container(): Folder
	if container and container.Parent then
		return container
	end
	local folder = Workspace:FindFirstChild("Heists")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Heists"
		folder.Parent = Workspace
	end
	container = folder
	return folder
end

function ArenaService.acquire(): (number?, CFrame?)
	for index = 1, CORRIDOR.maxConcurrentHeists do
		if not slots[index] then
			slots[index] = true
			local origin = CFrame.new(
				CORRIDOR.arenaOrigin[1] + (index - 1) * CORRIDOR.arenaSpacing,
				CORRIDOR.arenaOrigin[2],
				CORRIDOR.arenaOrigin[3]
			)
			return index, origin
		end
	end
	return nil, nil
end

function ArenaService.release(index: number)
	slots[index] = nil
end

function ArenaService.activeCount(): number
	local count = 0
	for _ in slots do
		count += 1
	end
	return count
end

return ArenaService
