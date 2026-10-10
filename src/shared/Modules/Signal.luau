--[[
	Signal
	======
	Mini implémentation d'événements entre modules (évite les BindableEvents et
	la copie des tables qu'ils imposent). Chaque handler s'exécute dans son
	propre thread : une erreur dans un handler n'empêche pas les autres.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Once: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self = setmetatable({
		_handlers = {},
	}, Signal)
	return (self :: any) :: Signal
end

function Signal:Connect(handler)
	local connection = { Connected = true }
	local handlers = self._handlers

	function connection.Disconnect(conn)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local index = table.find(handlers, conn)
		if index then
			table.remove(handlers, index)
		end
	end

	connection._handler = handler
	table.insert(handlers, connection)
	return connection
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Copie : un handler peut se déconnecter pendant l'itération
	local snapshot = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._handlers) do
		connection:Disconnect()
	end
end

return Signal
