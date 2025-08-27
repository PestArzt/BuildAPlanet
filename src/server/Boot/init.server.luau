
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local GameFolder = ServerScriptService.Game
local DataFolder = ServerScriptService.Data

local ItemModels = ServerStorage.ItemModels
local ItemPreviews = ItemModels:Clone()
ItemPreviews.Parent = game.ReplicatedStorage
ItemPreviews.Name = "ItemPreviews"


local services = {
	GameFolder.CrateShopService,
	GameFolder.BuildingService,
	GameFolder.FarmingService,
	GameFolder.RocketService,
	GameFolder.GlobalRestockService,
	GameFolder.CrateService,
	GameFolder.SellService,
	GameFolder.GenericShopService,
	GameFolder.TradeService,
	GameFolder.PetController,
	GameFolder.PermissionsService,
	GameFolder.TutorialService,
	DataFolder.PetDataService,	
}

local successCount = 0
local failedStart = {}
for _, servicePath in ipairs(services) do

	local success, err = pcall(function()
		local serviceModule = require(servicePath)
		if serviceModule.Initialize then
			serviceModule:Initialize()
		else
			error(`O serviço {servicePath} não possui método Initialize`)
		end
	end)

	if success then
		successCount += 1
		print("✅ " .. servicePath.Name .. " inicializado com sucesso!")
	else
		table.insert(failedStart, servicePath.Name)
		warn("❌ Falha ao inicializar " .. servicePath.Name .. ": " .. tostring(err))
	end
end

print("🎯 Inicialização concluída: " .. successCount .. "/" .. #services .. " serviços carregados com sucesso!")