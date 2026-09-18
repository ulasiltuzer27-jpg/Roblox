--!nonstrict
-- Bildirimler ve duyurular. Paylaşılabilir anlar ("Prizma çıktı!",
-- "Kasan soyuluyor!") oyunun pazarlaması olduğu için tek yerden yönetiliyor.
local MessagingService = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

local NetService = require(ServerScriptService.Server.Services.NetService)

local NotificationService = {}

local CROSS_SERVER_TOPIC = "VaultHeistAnnounce"
local crossServerReady = false

-- kind: "info" | "good" | "bad" | "warn"
function NotificationService.toast(player: Player, text: string, kind: string?)
	NetService.push(player, "Toast", { text = text, kind = kind or "info" })
end

function NotificationService.announce(text: string, color: { number }?, crossServer: boolean?)
	NetService.pushAll("Announce", { text = text, color = color })

	if crossServer and crossServerReady then
		pcall(function()
			MessagingService:PublishAsync(CROSS_SERVER_TOPIC, { text = text, color = color, from = game.JobId })
		end)
	end
end

function NotificationService.init()
	local ok = pcall(function()
		MessagingService:SubscribeAsync(CROSS_SERVER_TOPIC, function(message)
			local payload = message.Data
			if type(payload) ~= "table" or payload.from == game.JobId then
				return
			end
			NetService.pushAll("Announce", { text = payload.text, color = payload.color })
		end)
	end)
	crossServerReady = ok
	if not ok then
		-- Studio'da ya da API kapalıyken sunucu içi duyurular çalışmaya devam eder.
		warn("[NotificationService] sunucular arası duyuru kapalı")
	end
end

return NotificationService
