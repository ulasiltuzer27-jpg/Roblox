--!nonstrict
-- Tüm ağ trafiği üç kapıdan geçer:
--   Action (RemoteFunction)  istemci -> sunucu, cevap bekleyen istekler
--   Input  (RemoteEvent)     istemci -> sunucu, soygun sırasındaki sık sinyaller
--   Push   (RemoteEvent)     sunucu -> istemci, durum ve bildirim yayını
-- Tek noktadan geçmesi hız sınırlama ve doğrulamayı tek yerde topluyor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "VaultHeistNet"
local TIMEOUT = 20

-- İstemcinin sunucudan isteyebilecekleri.
Remotes.Actions = {
	BuyCrates = "BuyCrates",
	OpenCrates = "OpenCrates",
	PlaceTreasure = "PlaceTreasure",
	UnplaceTreasure = "UnplaceTreasure",
	SellTreasures = "SellTreasures",
	CollectStash = "CollectStash",
	BuyUpgrade = "BuyUpgrade",
	BuyDefense = "BuyDefense",
	ListTargets = "ListTargets",
	StartHeist = "StartHeist",
	AbortHeist = "AbortHeist",
	ClaimDaily = "ClaimDaily",
	Rebirth = "Rebirth",
	TravelZone = "TravelZone",
	AdvanceTutorial = "AdvanceTutorial",
}

-- Soygun sırasında sık gönderilen, cevap beklemeyen sinyaller.
-- Kontrol noktası bilerek yok: ilerlemeyi sunucu, karakterin kendi
-- konumundan okuyor. İstemciye güvenilen tek şey hareket modu tercihi.
Remotes.Inputs = {
	Move = "Move", -- { mode = "sneak" | "walk" | "sprint" }
	DoorAttempt = "DoorAttempt", -- kilit zamanlamasında tuşa basıldı
}

-- Sunucudan istemciye yayın kanalları.
Remotes.Channels = {
	Profile = "Profile", -- tam ya da kısmi profil güncellemesi
	Toast = "Toast", -- köşede beliren kısa bildirim
	Announce = "Announce", -- sunucu geneli duyuru
	CrateResult = "CrateResult", -- sandık açma animasyonu için sonuç
	EventState = "EventState", -- aktif sunucu eventi
	Vaults = "Vaults", -- soyulabilir kasa listesi
	HeistStart = "HeistStart", -- koridor düzeni + oturum bilgisi
	HeistTick = "HeistTick", -- alarm, kalan süre, kontrol noktası
	HeistEnd = "HeistEnd", -- sonuç ekranı
	Robbed = "Robbed", -- "kasanı soyuyorlar" uyarısı
	Leaderboard = "Leaderboard",
	Tutorial = "Tutorial",
}

local function buildFolder(): Folder
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local action = Instance.new("RemoteFunction")
	action.Name = "Action"
	action.Parent = folder

	local input = Instance.new("RemoteEvent")
	input.Name = "Input"
	input.Parent = folder

	local push = Instance.new("RemoteEvent")
	push.Name = "Push"
	push.Parent = folder

	folder.Parent = ReplicatedStorage
	return folder
end

export type Bridge = {
	action: RemoteFunction,
	input: RemoteEvent,
	push: RemoteEvent,
}

local cached: Bridge? = nil

function Remotes.get(): Bridge
	if cached then
		return cached
	end

	local folder
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or buildFolder()
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, TIMEOUT)
		assert(folder, "ağ klasörü sunucudan gelmedi")
	end

	cached = {
		action = folder:WaitForChild("Action", TIMEOUT) :: RemoteFunction,
		input = folder:WaitForChild("Input", TIMEOUT) :: RemoteEvent,
		push = folder:WaitForChild("Push", TIMEOUT) :: RemoteEvent,
	}
	return cached
end

return Remotes
