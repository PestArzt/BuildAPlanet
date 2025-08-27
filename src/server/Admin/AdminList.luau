local AdminList = {}
AdminList.Admins = {
	["PestArztpedral"] = {Rank = "Admin"},
	["DRAGOMMIL1234"] = {Rank = "Admin"},
	["LeoMuitoQuente"] = {Rank = "Admin"},
	["DINOGAMERR40"] = {Rank = "Admin"},
	["LeletoDM"] = {Rank = "Admin"},
	["vitor15974"] = {Rank = "Admin"}
}

local DataStoreService = game:GetService("DataStoreService")
local AdminDataStore = DataStoreService:GetDataStore("AdminList")

function CheckUpdates()
	local AdminDataStoreList = AdminDataStore:GetAsync("MainList")
	
	if next(AdminDataStoreList) == nil then
		AdminDataStore:SetAsync("MainList", AdminList.Admins)
		print("creating new list")
		return AdminList.Admins
	end
	
	for i, v in AdminDataStoreList do
		if not table.find(AdminList.Admins, i) then
			AdminList.Admins[i] = {Rank = v.Rank}
		end
	end
end

function AdminList:IsAdmin(playerName)
	CheckUpdates()
	if self.Admins[playerName] then
		return self.Admins[playerName]
	end
	return false
end

function AdminList:AddAdmin(playerName, rank)
	CheckUpdates()
	self.Admins[playerName] = {Rank = rank}
	AdminDataStore:SetAsync("MainList", AdminList.Admins)
end

function AdminList:RemoveAdmin(playerName)
	CheckUpdates()
	self.Admins[playerName] = nil
	AdminDataStore:SetAsync("MainList", AdminList.Admins)
end

return AdminList
