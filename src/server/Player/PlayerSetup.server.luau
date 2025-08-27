-- ===================================================================
-- SERVIÇOS E MÓDULOS
-- ===================================================================
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService").Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local chatMessageRemote = ReplicatedStorage:FindFirstChild("ChatMessageRemote")

local DataStoreModule = require(ServerScriptService.DataStoreModule)
local ItemData = require(ServerScriptService.Data.ItemData)
-- local PlantSaveData = require(ServerScriptService.Building.PlantService)
local LeaderStatsService = require(ServerScriptService.Player.LeaderStatsService)
local InventoryService = require(ServerScriptService.Player.InventoryService)
-- local ProximityHandler = require(ServerScriptService..ProximityHandler)
local PlantMutationData = require(ServerScriptService.Data.PlantsMutationData)
-- ===================================================================
-- INICIALIZAÇÃO DE SERVIÇOS GLOBAIS
LeaderStatsService:Initialize()
-- PlantSaveData:Initialize()
-- ProximityHandler:start()
InventoryService:Initialize()
--print("✅ Serviços globais (LeaderStats, PlantSaveData) inicializados.")

-- ===================================================================
-- CONFIGURAÇÃO DE REMOTE FUNCTIONS
local function getDefaultInventory()
	return {
		["1"] = {},
		["2"] = {},
		["3"] = {},
		["4"] = {},
		["5"] = {},
		["6"] = {},
		["7"] = {},
		["8"] = {},
		["9"] = {},
		["0"] = {},
		Backpack = {},
	}
end

local GetDataFunction = RemoteFunctions:WaitForChild("GetPlayerData")
GetDataFunction.OnServerInvoke = function(player, dataStoreName)
	if dataStoreName == InventoryService.DataStoreName then
		return InventoryService:GetInventory(player)
	end
	local playerDS = DataStoreModule.GetDataStore(player, dataStoreName)
	local data = playerDS and playerDS:GetData(nil)

	if data then
		return data
	else
		if dataStoreName == InventoryService.DataStoreName then
			print(
				string.format(
					"AVISO: Dados do inventário para %s não encontrados. Retornando inventário padrão.",
					player.Name
				)
			)
			return getDefaultInventory()
		else
			return 0
		end
	end
end

local getItemDataFunction = RemoteFunctions:FindFirstChild("GetItemData")
getItemDataFunction.OnServerInvoke = function(player)
	local combinedData = {}
	for k, v in pairs(ItemData) do
		combinedData[k] = v
	end
	combinedData["PlantsMutation"] = PlantMutationData.PlantsMutation

	return combinedData
end

-- Ferramenta de debug
local DebugTracker = DataStoreModule.DebugTracker
if DebugTracker then
	DebugTracker.OnInvoke = function(dataStoreName, player)
		return DataStoreModule.GetDataStore(player, dataStoreName)
	end
end
-- ===================================================================
-- PONTO ÚNICO DE INICIALIZAÇÃO DO JOGADOR
Players.PlayerAdded:Connect(function(player)
	-- A linha abaixo apenas prepara o objeto DataStore, não carrega os dados ainda
	local InventoryDataStore = DataStoreModule.new(InventoryService.DataStoreName, player)
	InventoryService:SetupPlayerBackpack(player)
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local initialInventory = InventoryService:GetInventory(player)
		local InitialInventoryLoaded = RemoteEvents.Inventory:WaitForChild("InitialInventoryLoaded")
		InitialInventoryLoaded:FireClient(player, initialInventory)
		InventoryService:UpdatePhysicalBackpack(player)
	end)
	task.delay(1, function()
		chatMessageRemote:FireClient(
			player,
			`Welcome to Build a Planet! Game version: {game.ServerStorage.GameVersion.Value}`,
			Color3.fromRGB(170, 170, 170)
		)
		print(string.format("✅ Configuração para %s concluída.", player.Name))
	end)
end)
