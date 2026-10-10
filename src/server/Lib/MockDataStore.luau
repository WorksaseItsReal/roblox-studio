--[[
	MockDataStore
	=============
	DataStore en mémoire utilisé UNIQUEMENT en Studio quand l'accès aux API n'est
	pas activé (Game Settings > Security > Enable Studio Access to API Services).
	Il reproduit la sémantique utile d'UpdateAsync / GetAsync / SetAsync :
	les valeurs sont copiées en profondeur, comme une vraie sérialisation.
]]

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[deepCopy(key)] = deepCopy(inner)
	end
	return copy
end

function MockDataStore.new()
	return setmetatable({ _data = {} }, MockDataStore)
end

function MockDataStore:GetAsync(key: string): any
	task.wait() -- simule la latence (une vraie requête cède toujours)
	return deepCopy(self._data[key])
end

function MockDataStore:SetAsync(key: string, value: any)
	task.wait()
	self._data[key] = deepCopy(value)
end

function MockDataStore:UpdateAsync(key: string, transform: (any) -> any): any
	task.wait()
	local result = transform(deepCopy(self._data[key]))
	if result ~= nil then
		self._data[key] = deepCopy(result)
	end
	return deepCopy(self._data[key])
end

return MockDataStore
