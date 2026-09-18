--!strict
-- Basit senkron signal. BindableEvent kullanmıyoruz: tablo referansları
-- bozulmadan geçsin ve testlerde Roblox API'sine ihtiyaç olmasın diye.
local Signal = {}
Signal.__index = Signal

export type Connection = { disconnect: (Connection) -> () }
export type Signal = typeof(setmetatable({} :: { _handlers: { (...any) -> () } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.connect(self: Signal, handler: (...any) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection
	connection = {
		disconnect = function()
			local index = table.find(self._handlers, handler)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
	return connection
end

function Signal.fire(self: Signal, ...: any)
	-- Kopya üstünde geziyoruz: handler içinde disconnect çağrılırsa liste bozulmasın.
	local snapshot = table.clone(self._handlers)
	for _, handler in snapshot do
		handler(...)
	end
end

function Signal.destroy(self: Signal)
	table.clear(self._handlers)
end

return Signal
