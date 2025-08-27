local BackUpsModule = {}
BackUpsModule.__index = BackUpsModule
	
local Awaiter = require(script.Parent.AwaiterModule)

local DataStoreService = game:GetService("DataStoreService")

function BackUpsModule:Get()
	return Awaiter.desync(function(succeed)
		succeed(self.backUpDataStore:GetSortedAsync(false, 1):GetCurrentPage()[1])
	end):doNext(function(backupKey)
		if backupKey then
			self.lastBackupKey = backupKey.value
			return Awaiter.desync(function(succeed)
				succeed(self.currentDataStore:GetAsync(backupKey.value))
			end)
		else
			warn("Nenhuma chave recente")
			return nil
		end
	end)
end

function BackUpsModule:Set(value)
	local backupKey = (self.lastBackupKey or 0) + 1
	self.lastBackupKey = backupKey
	
	return Awaiter.desync(function(success)
		self.currentDataStore:SetAsync(backupKey, value)
		self.backUpDataStore:SetAsync(backupKey, backupKey)
		
		success()
	end)
end

function BackUpsModule.new(dataStore)	
	local keyName = dataStore.UserId .. "-" .. dataStore.Name
	
	local dataStoreInfo = {
		currentDataStore = DataStoreService:GetDataStore(keyName),
		backUpDataStore = DataStoreService:GetOrderedDataStore(keyName),
		--lastBackupKey = backupKey
	}

	return setmetatable(dataStoreInfo, BackUpsModule)
end

return BackUpsModule
