--!nonstrict
-- İstemci tarafı ağ köprüsü. Sunucuya giden her istek buradan geçer ve
-- hata durumunda kullanıcıya gösterilecek metinle döner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)

local Net = {}

local bridge = nil
local handlers: { [string]: any } = {}

export type Response = { ok: boolean, data: any?, error: string? }

function Net.invoke(action: string, payload: any?): Response
	local ok, result = pcall(function()
		return bridge.action:InvokeServer(action, payload)
	end)
	if not ok then
		return { ok = false, error = "Sunucuya ulaşılamadı." }
	end
	if type(result) ~= "table" then
		return { ok = false, error = "Beklenmeyen cevap." }
	end
	return result
end

function Net.send(kind: string, payload: any?)
	bridge.input:FireServer(kind, payload)
end

function Net.on(channel: string, handler: (any) -> ())
	local signal = handlers[channel]
	if not signal then
		signal = Signal.new()
		handlers[channel] = signal
	end
	return signal:connect(handler)
end

function Net.init()
	bridge = Remotes.get()
	bridge.push.OnClientEvent:Connect(function(channel: string, payload: any)
		local signal = handlers[channel]
		if signal then
			signal:fire(payload)
		end
	end)
end

return Net
