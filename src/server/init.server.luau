local ServerStorage = game:GetService("ServerStorage")

local ItemModels = ServerStorage.ItemModels
local ItemPreviews = ItemModels:Clone()
ItemPreviews.Parent = game.ReplicatedStorage
ItemPreviews.Name = "ItemPreviews"

local services = {
	script.General.ProximityService,
	script.Shop.CrateShopService,
	script.Building.BuildingService,
	script.Building.FarmingService,
	script.Planet.RocketService,
	script.Shop.GlobalRestockService,
	script.General.CrateService,
	script.Shop.SellingService,
	script.Shop.GenericShopService,
	script.Trading.TradeService,
	script.General.PetService,
	script.Planet.PermissionsService,
	script.General.TutorialService,
	script.Building.PlantService,
	script.Data.PetData,
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
