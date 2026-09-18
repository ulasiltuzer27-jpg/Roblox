--!nonstrict
-- Liderlik tabloları (OrderedDataStore). Skorlar oturum sonunda ve
-- düzenli aralıklarla yazılır, tablo herkese yayınlanır.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NetService = require(ServerScriptService.Server.Services.NetService)

local BOARD = Config.Balance.Leaderboard

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { any } } = {}
local nameCache: { [number]: string } = {}
local available = true

local TITLES = {
	net_worth = "En Zengin Kasalar",
	heists_won = "En Çok Soygun",
	biggest_steal = "Tek Seferde En Büyük Vurgun",
}

local function scoreFor(boardId: string, profile): number
	if boardId == "net_worth" then
		return Economy.netWorth(profile)
	elseif boardId == "heists_won" then
		return profile.stats.heistsWon
	elseif boardId == "biggest_steal" then
		return profile.stats.biggestSteal
	end
	return 0
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else `Oyuncu {userId}`
	return nameCache[userId]
end

local function publish(player: Player?)
	local payload = { boards = {} }
	for _, boardId in BOARD.boards do
		table.insert(payload.boards, {
			id = boardId,
			title = TITLES[boardId] or boardId,
			entries = cache[boardId] or {},
		})
	end
	if player then
		NetService.push(player, "Leaderboard", payload)
	else
		NetService.pushAll("Leaderboard", payload)
	end
end

function LeaderboardService.pushTo(player: Player)
	publish(player)
end

local function refresh()
	if not available then
		return
	end
	for _, boardId in BOARD.boards do
		local store = stores[boardId]
		if not store then
			continue
		end
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, BOARD.topCount)
		end)
		if not ok then
			continue
		end
		local entries = {}
		for rank, entry in pages:GetCurrentPage() do
			table.insert(entries, {
				rank = rank,
				userId = tonumber(entry.key),
				name = nameFor(tonumber(entry.key)),
				value = entry.value,
			})
		end
		cache[boardId] = entries
	end
	publish()
end

local function submit(userId: number, profile)
	if not available then
		return
	end
	for _, boardId in BOARD.boards do
		local store = stores[boardId]
		if not store then
			continue
		end
		local score = math.floor(scoreFor(boardId, profile))
		if score <= 0 then
			continue
		end
		pcall(function()
			store:SetAsync(tostring(userId), score)
		end)
	end
end

function LeaderboardService.init()
	for _, boardId in BOARD.boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(`VaultHeist_{boardId}_v1`)
		end)
		if ok then
			stores[boardId] = store
		else
			available = false
		end
	end

	DataService.Released:connect(function(userId, profile)
		task.spawn(submit, userId, profile)
	end)

	DataService.Loaded:connect(function(player)
		task.delay(2, function()
			if player.Parent then
				publish(player)
			end
		end)
	end)

	task.spawn(function()
		while true do
			refresh()
			-- Skorları periyodik olarak da yaz: sunucu çökerse ilerleme kaybolmasın.
			DataService.forEachLoaded(function(player, profile)
				submit(player.UserId, profile)
			end)
			task.wait(BOARD.refreshSeconds)
		end
	end)
end

return LeaderboardService
