--[[
	BuildingService - Sistema de Construção e Colocação de Objetos
	Responsável por gerenciar a colocação, remoção e persistência de objetos nos planetas
	Versão: 1.3
	<Mod by Lorrys> :3
--]]

local BuildingService = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService").Server
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Dependencies
local BuildingAction = ReplicatedStorage.RemoteFunctions.Building:WaitForChild("PlaceObject")
local InventoryService = require(ServerScriptService.Player.InventoryService)
local ItemData = require(ServerScriptService.Data.ItemData)
local FarmingService = require(ServerScriptService.Building.FarmingService)
local PlantSaveData = require(ServerScriptService.Building.PlantService)
local DataStoreModule = require(ServerScriptService.DataStoreModule)
local StateHandler = require(ServerScriptService.General.StateHandler)
local ItemModels = ServerStorage:WaitForChild("ItemModels")
local objectClickedEvent = ReplicatedStorage.BindableEvents.BuildMode.ObjectClickedEvent
local objectClickedEvent = ReplicatedStorage.RemoteFunctions.Building:WaitForChild("ObjectClickedEvent")
local SetCurrentPlanetEvent = ReplicatedStorage.RemoteFunctions.Building:WaitForChild("SetCurrentPlanet")
local CrateData = require(ServerScriptService.Data.CrateData)
local UpdateClientBuffsEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UpdateClientBuffs")
local RarityManager = require(game.ReplicatedStorage.Modules.RarityManager)

-- Config
local DATA_VERSION = "1.3"
local PLANET_BUILDINGS_DATASTORE_NAME = "PlanetBuildings_v" .. DATA_VERSION
local PLANET_LAYOUT_DATASTORE_NAME = "PlanetLayout_v" .. DATA_VERSION
local PLANET_PETS_DATASTORE_NAME = "PlanetPets_vbeta" .. DATA_VERSION

local BUILDING_CONFIG = {
	MIN_DISTANCE_BETWEEN_ITEMS = 0,
	RAYCAST_DISTANCE = 1000,
}

-- Storage
local placedObjects = {}
local playerCurrentPlanet = {}
--local planetBuffs = {}

-- Types
type ObjectInfo = {
	Name: string,
	Category: string,
	Cf: { number },
	PlacedTime: number?,
	UUID: string?,
}

--local PREDEFINED_PLANET_LAYOUT = {
--	{
--		Category = "Decoration",
--		Name = "ShopNPC",
--		RelativeCFrame = CFrame.new(8, 0.5, -8) * CFrame.Angles(0, math.rad(-45), 0)
--	},
--}

--[[
	UTILITY FUNCTIONS
--]]

local function countPlayerPlacedItems(player, itemName)
	local count = 0
	for _, objectModel in ipairs(workspace.PlacedObjects:GetChildren()) do
		if objectModel:GetAttribute("Owner") == player.Name and objectModel:GetAttribute("ItemName") == itemName then
			count = count + 1
		end
	end
	return count
end

local function createCrateInfoGui(crateModel, crateType)
	local crateInfoTemplate = ReplicatedStorage.BillboardGuis:FindFirstChild("CrateInfo")
	if not crateInfoTemplate then
		warn("[BuildingService] Template 'CrateInfo' não encontrado em ReplicatedStorage/BillboardGuis")
		return
	end

	local crateConfig = CrateData[crateType]
	if not crateConfig or not crateConfig.LootTable then
		warn("[BuildingService] Configuração ou LootTable não encontrada para a caixa:", crateType)
		return
	end

	local crateGui = crateInfoTemplate:Clone()
	local itemsFrame = crateGui:WaitForChild("ItemsFrame")
	local itemDisplayTemplate = itemsFrame:WaitForChild("ItemDisplay")
	local totalWeight = 0
	for _, item in ipairs(crateConfig.LootTable) do
		totalWeight = totalWeight + (item.Weight or 0)
	end

	if totalWeight == 0 then
		return
	end

	local sortedLoot = table.clone(crateConfig.LootTable)
	table.sort(sortedLoot, function(a, b)
		return a.Weight > b.Weight
	end)

	for _, lootItem in ipairs(sortedLoot) do
		local itemMasterData = ItemData:GetItem(lootItem.Category, lootItem.Name)
		if itemMasterData and itemMasterData.ImageId then
			local itemDisplayClone = itemDisplayTemplate:Clone()
			itemDisplayClone.Image = itemMasterData.ImageId
			local chance = (lootItem.Weight / totalWeight) * 100
			itemDisplayClone.ItemChance.Text = string.format("%.1f%%", chance)

			local uiStroke = itemDisplayClone:FindFirstChildOfClass("UIStroke")
			if uiStroke and itemMasterData.Rarity then
				RarityManager:ApplyRarity(uiStroke, itemMasterData.Rarity)
			end
			itemDisplayClone.Visible = true
			itemDisplayClone.Parent = itemsFrame
		end
	end
	local crateSize = crateModel:GetExtentsSize()
	crateGui.StudsOffset = Vector3.new(0, crateSize.Y / 2 + 5.5, 0)
	crateGui.Adornee = crateModel.PrimaryPart or crateModel
	crateGui.Parent = crateModel
end

local function getPlanetModel(planetFolder)
	local planetModel = planetFolder:FindFirstChild("Planet")
	if planetModel and planetModel:IsA("Model") then
		return planetModel
	end

	for _, child in ipairs(planetFolder:GetChildren()) do
		if child:IsA("Model") then
			return child
		end
	end

	return nil
end

local function getPlayerPlanetModel(player)
	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			return getPlanetModel(planetFolder)
		end
	end
	return nil
end

local function addClickDetector(model, ownerPlayer)
	if not model or not ownerPlayer then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("ClickDetector") then
					child:Destroy()
				end
			end

			local clickDetector = Instance.new("ClickDetector")
			clickDetector.MaxActivationDistance = 128
			clickDetector.Parent = part

			clickDetector.MouseClick:Connect(function(clickedPlayer)
				if clickedPlayer == ownerPlayer then
					objectClickedEvent:FireClient(ownerPlayer, model)
				end
			end)
		end
	end
end

local function setSafeAttributes(object, objectData)
	local safeAttributes = {
		UUID = objectData.UUID,
		ItemName = objectData.ItemName,
		Owner = objectData.Owner,
		PlacedTime = objectData.PlacedTime,
		Category = objectData.Category,
	}

	for attributeName, value in pairs(safeAttributes) do
		if value ~= nil then
			object:SetAttribute(attributeName, value)
		end
	end

	if objectData.Position then
		object:SetAttribute("PositionX", objectData.Position.X)
		object:SetAttribute("PositionY", objectData.Position.Y)
		object:SetAttribute("PositionZ", objectData.Position.Z)
	end
end

function BuildingService:CheckCanRemove(player, objectUUID)
	local objectData = nil
	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			local planetObjects = placedObjects[planetFolder.Name]
			if planetObjects and planetObjects[objectUUID] then
				objectData = planetObjects[objectUUID]
				break
			end
		end
	end

	if not objectData then
		return false, "ObjectNotFound"
	end
	if objectData.Owner ~= player.Name then
		return false, "NotOwner"
	end

	if objectData.Category == "Farming" then
		local model = objectData.Model
		if model and model:FindFirstChild("Plants") and #model.Plants:GetChildren() > 0 then
			return false, "HasPlants"
		end
	end

	return true, "CanRemove"
end
local function serializePlanet(planetName)
	local data = {}
	local planetObjects = placedObjects[planetName]

	if not planetObjects then
		return data
	end

	local planetFolder = workspace.Planets:FindFirstChild(planetName)
	if not planetFolder then
		return data
	end

	local planetModel = getPlanetModel(planetFolder)
	if not planetModel then
		warn("❌ Modelo do planeta não encontrado dentro da pasta:", planetName)
		return data
	end

	for uuid, objectData in pairs(planetObjects) do
		if objectData.Model and objectData.Model.Parent then
			local currentCFrame = objectData.Model:GetPivot()
			local relativeCF = planetModel:GetPivot():ToObjectSpace(currentCFrame)

			local info: ObjectInfo = {
				Name = objectData.ItemName,
				Category = objectData.Category,
				Cf = table.pack(relativeCF:GetComponents()),
				PlacedTime = objectData.PlacedTime,
				UUID = objectData.UUID,
			}
			table.insert(data, info)
		end
	end

	return data
end

local function getNormalCFrame(RayCast)
	local up = RayCast.Normal
	local arbitrary = math.abs(up:Dot(Vector3.new(0, 1, 0))) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = up:Cross(arbitrary).Unit
	local forward = right:Cross(up).Unit
	local rotationCFrame = CFrame.Angles(0, math.rad(90), 0)
	return CFrame.fromMatrix(RayCast.Position, right, up) * rotationCFrame
end

--[[
	Cria a BillboardGui para exibir os buffs de uma decoração.
 --]]
local function createBuffDisplayGui(model, itemData)
	if not itemData.Buffs then
		return
	end

	-- Remove GUI existente para evitar duplicação
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "BuffDisplayGui" then
			child:Destroy()
		end
	end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "BuffDisplayGui"
	billboardGui.Size = UDim2.new(4, 0, 1.5, 0)
	billboardGui.StudsOffset = Vector3.new(0, model:GetExtentsSize().Y / 2 + 2, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 40
	billboardGui.Parent = model

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(255, 230, 128)
	textLabel.Parent = billboardGui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(60, 40, 0)
	uiStroke.Thickness = 1.5
	uiStroke.Parent = textLabel

	local buffText = {}
	if itemData.Buffs.MoneyBonus > 0 then
		table.insert(buffText, string.format("💰 +%.0f%% Money", itemData.Buffs.MoneyBonus * 100))
	end
	if itemData.Buffs.GrowthSpeedBonus > 0 then
		table.insert(buffText, string.format("🌿 +%.0f%% Growth", itemData.Buffs.GrowthSpeedBonus * 100))
	end

	textLabel.Text = table.concat(buffText, "\n")
end

local function createPlotBuffGui(model, itemData)
	if not itemData.GrowthBonus or itemData.GrowthBonus <= 1 then
		return
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "PlotBuffGui" then
			child:Destroy()
		end
	end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "PlotBuffGui"
	billboardGui.Size = UDim2.new(4, 0, 1, 0)
	local modelSize = model:GetExtentsSize()
	billboardGui.StudsOffset = Vector3.new(0, modelSize.Y / 2 + 0.5, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 50
	billboardGui.Parent = model

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(130, 255, 130) -- Verde claro para crescimento
	textLabel.Parent = billboardGui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(0, 60, 0) -- Verde escuro
	uiStroke.Thickness = 1.5
	uiStroke.Parent = textLabel

	-- Calcula a porcentagem do bônus (ex: 1.25 -> +25%)
	local bonusPercentage = (itemData.GrowthBonus - 1) * 100
	textLabel.Text = string.format("🌱 +%.0f%% Crescimento", bonusPercentage)
end

--[[
+ 	Recalcula os buffs totais para o planeta de um jogador e armazena no cache.
+ --]]
function BuildingService:UpdateAndNotifyClientBuffs(player)
	if player and player.Parent then
		local currentBuffs = self:GetPlayerBuffs(player)
		UpdateClientBuffsEvent:FireClient(player, currentBuffs)
	end
end

function BuildingService:GetPlayerBuffs(player)
	local PetController = require(ServerScriptService.General.PetService)
	local totalBuffs = { MoneyBonus = 0, GrowthSpeedBonus = 0 }
	local ownedPlanetName = nil
	for _, pFolder in ipairs(workspace.Planets:GetChildren()) do
		if pFolder:GetAttribute("Owner") == player.Name then
			ownedPlanetName = pFolder.Name
			break
		end
	end

	-- 1. Buffs de Decorações
	if ownedPlanetName and placedObjects[ownedPlanetName] then
		for uuid, objectData in pairs(placedObjects[ownedPlanetName]) do
			if objectData.ItemData and objectData.ItemData.Buffs then
				totalBuffs.MoneyBonus += (objectData.ItemData.Buffs.MoneyBonus or 0)
				totalBuffs.GrowthSpeedBonus += (objectData.ItemData.Buffs.GrowthSpeedBonus or 0)
			end
		end
	end

	-- 2. Buffs de Pets Ativos
	local activePets = PetController.GetActivePets()
	for _, petData in ipairs(activePets) do
		if petData.OwnerId == player.UserId and petData.CalculatedBuffs then
			totalBuffs.MoneyBonus += (petData.CalculatedBuffs.MoneyBonus or 0)
			totalBuffs.GrowthSpeedBonus += (petData.CalculatedBuffs.GrowthSpeedBonus or 0)
		end
	end

	return totalBuffs
end
--[[
	CORE FUNCTIONS
--]]

function BuildingService:UpdateObjectPosition(player, objectUUID, newCFrame)
	local objectData = nil
	local planetName = nil
	local foundInPlacedObjects = false

	-- 1. Tentar encontrar nos objetos colocados pelo jogador
	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			local planetObjects = placedObjects[planetFolder.Name]
			if planetObjects and planetObjects[objectUUID] then
				objectData = planetObjects[objectUUID]
				planetName = planetFolder.Name
				foundInPlacedObjects = true
				break
			end
		end
	end

	local targetModel = nil
	if not objectData then
		for _, item in ipairs(CollectionService:GetTagged("built_item")) do
			if item:GetAttribute("UUID") == objectUUID then
				targetModel = item
				break
			end
		end
	else
		targetModel = objectData.Model
	end

	if not targetModel then
		return false, "ObjectNotFound"
	end

	-- 3. Verificar propriedade
	if targetModel:GetAttribute("Owner") ~= player.Name then
		return false, "NotOwner"
	end

	-- 4. Atualizar posição do modelo
	if targetModel and targetModel.Parent then
		targetModel:PivotTo(newCFrame)
	end

	-- 5. Atualizar dados
	if foundInPlacedObjects then
		-- Atualiza a tabela 'placedObjects' se for um item normal
		objectData.Position = newCFrame.Position
		objectData.Rotation = newCFrame.Rotation
	end

	-- Atualizar atributos no modelo (para ambos os tipos de objeto)
	targetModel:SetAttribute("PositionX", newCFrame.Position.X)
	targetModel:SetAttribute("PositionY", newCFrame.Position.Y)
	targetModel:SetAttribute("PositionZ", newCFrame.Position.Z)

	--print(`✅ Posição do objeto {objectUUID} atualizada para: {newCFrame.Position}`)
	return true, "PositionUpdated"
end

function BuildingService:LoadPlanet(player, planetName)
	local PetController = require(ServerScriptService.General.PetService)
	if not Players:GetPlayerByUserId(player.UserId) then
		return
	end

	local planetFolder = workspace.Planets:FindFirstChild(planetName)
	if not planetFolder then
		warn("❌ Pasta do planeta não encontrada:", planetName)
		return
	end

	playerCurrentPlanet[player.UserId] = planetName

	local planetModel = getPlanetModel(planetFolder)
	if not planetModel then
		warn("❌ Modelo do planeta não encontrado:", planetName)
		return
	end

	if not placedObjects[planetName] then
		placedObjects[planetName] = {}
	end

	local layoutDataStore = DataStoreModule.GetDataStore(player, PLANET_LAYOUT_DATASTORE_NAME)
	local layoutData = layoutDataStore:GetData({})

	if layoutData and layoutData.Platform then
		local platformModel = planetFolder:FindFirstChild("Platform")
		if platformModel and layoutData.Platform.Cf then
			print(`[BuildingService] Restaurando posição da plataforma para ${player.Name}`)
			local relativeCF = CFrame.new(table.unpack(layoutData.Platform.Cf))
			local worldCF = planetModel:GetPivot():ToWorldSpace(relativeCF)
			platformModel:PivotTo(worldCF)
		end
	end

	local buildingDataStore = DataStoreModule.GetDataStore(player, PLANET_BUILDINGS_DATASTORE_NAME)
	local data = buildingDataStore:GetData({})

	-- Limpar objetos existentes
	for uuid, objectData in pairs(placedObjects[planetName]) do
		if objectData.Model and objectData.Model.Parent then
			objectData.Model:Destroy()
		end
	end
	placedObjects[planetName] = {}

	-- Recriar objetos salvos
	if data and #data > 0 then
		print(`✅ Carregando {#data} objetos do DataStoreModule para o planeta {planetName}`)
		for _, objectInfo in ipairs(data) do
			local itemData = ItemData:GetItem(objectInfo.Category, objectInfo.Name)
			if not itemData then
				warn(`❌ ItemData não encontrado: {objectInfo.Category}/{objectInfo.Name}`)
				continue
			end
			local itemModel = ItemData:FindModel(itemData)
			if not itemModel then
				warn(`❌ Modelo não encontrado: {objectInfo.Name}`)
				continue
			end
			local newObject = itemModel:Clone()
			local relativeCF = CFrame.new(table.unpack(objectInfo.Cf))
			local worldCF = planetModel:GetPivot():ToWorldSpace(relativeCF)
			newObject:PivotTo(worldCF)
			newObject.Parent = workspace.PlacedObjects
			local newUUID = objectInfo.UUID or HttpService:GenerateGUID(true)
			local objectData = {
				UUID = newUUID,
				ItemName = objectInfo.Name,
				ItemData = itemData,
				Model = newObject,
				Owner = player.Name,
				PlacedTime = objectInfo.PlacedTime or os.time(),
				Position = worldCF.Position,
				Rotation = worldCF.Rotation,
				Category = objectInfo.Category,
			}
			setSafeAttributes(newObject, objectData)
			local categoryTags = { Farming = "plot", Decoration = "decoration" }
			if categoryTags[objectInfo.Category] then
				CollectionService:AddTag(newObject, categoryTags[objectInfo.Category])
			end
			CollectionService:AddTag(newObject, "built_item")
			if objectInfo.Category == "Farming" then
				if itemData.MaxPlants then
					newObject:SetAttribute("MaxPlants", itemData.MaxPlants)
				end
				if itemData.GrowthBonus then
					newObject:SetAttribute("GrowthBonus", itemData.GrowthBonus)
				end
				if not newObject:FindFirstChild("Plants") then
					Instance.new("Folder", newObject).Name = "Plants"
				end

				createPlotBuffGui(newObject, itemData)
			end
			if objectInfo.Category == "Crates" then
				local crateConfig = CrateData[objectInfo.Name]
				if crateConfig then
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Open"
					prompt.RequiresLineOfSight = false
					prompt.ObjectText = crateConfig.DisplayName
					prompt.Style = Enum.ProximityPromptStyle.Custom
					prompt.HoldDuration = 2
					prompt:SetAttribute("Theme", "StarProx")
					prompt:SetAttribute("IsCrate", true)
					prompt.Parent = newObject.PrimaryPart or newObject
					newObject:SetAttribute("CrateType", objectInfo.Name)
					task.spawn(function()
						prompt.Enabled = false
						task.wait(0.1)
						prompt.Enabled = true
					end)
					createCrateInfoGui(newObject, objectInfo.Name)
				end
			end
			if itemData.Buffs then
				createBuffDisplayGui(newObject, itemData)
			end
			placedObjects[planetName][newUUID] = objectData
			addClickDetector(newObject, player)
		end
	else
		print("ℹ️ Nenhum dado de construção encontrado no DataStoreModule para o jogador")
	end

	print("♻️ Todos os objetos de construção carregados. Iniciando restauração de plantas...")
	PlantSaveData:LoadPlayerPlants(player)
	PlantSaveData:RestoreAllPlantsForPlayer(player)

	local petDataStore = DataStoreModule.GetDataStore(player, PLANET_PETS_DATASTORE_NAME)
	local savedPets = petDataStore:GetData({})
	if savedPets and next(savedPets) then
		print(`[BuildingService] Carregando ${#savedPets} pets para ${player.Name}`)
		PetController:LoadAndSpawnPets(player, savedPets, planetModel)
	else
		print(`[BuildingService] Nenhum pet salvo encontrado para ${player.Name}.`)
	end
	self:UpdateAndNotifyClientBuffs(player)

	SetCurrentPlanetEvent:FireClient(player, planetName)
	print(`✅ Planetas sincronizados - {planetName} carregado para {player.Name}`)
end

function BuildingService:SaveAllPlayerData(player)
	if not player then
		return
	end
	print(`[BuildingService] Preparando dados de construção e layout para ${player.Name}...`)

	local planetFolderToSave = nil
	local planetModelToSave = nil

	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			planetFolderToSave = planetFolder
			planetModelToSave = getPlanetModel(planetFolder)
			break
		end
	end

	print(
		`[BuildingService Debug] Planeta encontrado para salvar: ${tostring(
			planetFolderToSave and planetFolderToSave.Name
		)}`
	)

	if planetModelToSave then
		local layoutDataStore = DataStoreModule.GetDataStore(player, PLANET_LAYOUT_DATASTORE_NAME)
		local layoutData = {}

		local platformModel = planetFolderToSave:FindFirstChild("Platform")
		if platformModel then
			local relativeCF = planetModelToSave:GetPivot():ToObjectSpace(platformModel:GetPivot())

			-- Prepara os dados para salvar
			layoutData.Platform = {
				Cf = table.pack(relativeCF:GetComponents()),
			}
			print(`[BuildingService] Dados de layout (plataforma) preparados para ${player.Name}.`)
		end

		layoutDataStore:SetData(layoutData)

		local buildingData = {}
		for _, objectModel in ipairs(workspace.PlacedObjects:GetChildren()) do
			if objectModel:GetAttribute("Owner") == player.Name then
				local currentCFrame = objectModel:GetPivot()
				local relativeCF = planetModelToSave:GetPivot():ToObjectSpace(currentCFrame)

				local info: ObjectInfo = {
					Name = objectModel:GetAttribute("ItemName"),
					Category = objectModel:GetAttribute("Category"),
					Cf = table.pack(relativeCF:GetComponents()),
					PlacedTime = objectModel:GetAttribute("PlacedTime"),
					UUID = objectModel:GetAttribute("UUID"),
				}
				table.insert(buildingData, info)
			end
		end

		local buildingDataStore = DataStoreModule.GetDataStore(player, PLANET_BUILDINGS_DATASTORE_NAME)
		buildingDataStore:SetData(buildingData)

		if #buildingData == 0 then
			print(`[BuildingService Debug] Nenhum objeto de construção encontrado para salvar.`)
		end
		local serializedPets = {}
		local activePetsFolder = workspace:FindFirstChild("ActivePetsFolder")
		if activePetsFolder then
			print(`[DEBUG] Verificando pets para salvar para o jogador ${player.Name} (ID: ${player.UserId})`)
			for _, petModel in ipairs(activePetsFolder:GetChildren()) do
				local petOwnerId = petModel:GetAttribute("Owner")
				if petOwnerId == player.UserId then
					print("   >> CORRESPONDEU! Serializando pet...")
					local petWorldCF = petModel:GetPivot()
					local relativeCF = planetModelToSave:GetPivot():ToObjectSpace(petWorldCF)

					local simplePetData = {
						UUID = petModel:GetAttribute("PetUUID"),
						ItemName = petModel:GetAttribute("ItemName") or petModel.Name,
						State = petModel:GetAttribute("State") or "Follow",
						Cf = table.pack(relativeCF:GetComponents()),
					}
					table.insert(serializedPets, simplePetData)
				end
			end
		end

		local petDataStore = DataStoreModule.GetDataStore(player, PLANET_PETS_DATASTORE_NAME)
		petDataStore:SetData(serializedPets)

		if #serializedPets > 0 then
			print(`[BuildingService] ${#serializedPets} pets serializados e preparados no cache para ${player.Name}.`)
		end
	else
		print("[BuildingService Debug] Nenhum planeta encontrado para o jogador. Nada a salvar.")
	end

	print(`[BuildingService] Dados de construção, layout e pets preparados no cache.`)
end

function BuildingService:PlaceItem(player, itemData, isServer)
	local PetController = require(ServerScriptService.General.PetService)
	if StateHandler.GetState(player, "IsBuilding") then
		return false, "Cooldown"
	end
	StateHandler.SetState(player, "IsBuilding", true, 0.2)

	if not itemData or not itemData.Category or not itemData.ItemName or not itemData.CFrame then
		warn(`[BuildingService] PlaceItem negado para ${player.Name} devido a dados inválidos ou nulos.`)
		return false, "InvalidData"
	end
	-- Encontrar planeta do jogador
	local currentPlanet = nil
	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			currentPlanet = planetFolder
			break
		end
	end
	if not currentPlanet then
		return false, "NoPlanetFound"
	end

	local category, itemName, cframe = itemData.Category, itemData.ItemName, itemData.CFrame

	-- Validar item
	local itemDataInfo = ItemData:GetItem(category, itemName)
	if not itemDataInfo then
		return false, "ItemNotFound"
	end
	if itemDataInfo.PlacementLimit and itemDataInfo.PlacementLimit > 0 and category ~= "Pets" then
		local currentCount = countPlayerPlacedItems(player, itemName)
		if currentCount >= itemDataInfo.PlacementLimit then
			return false, "PlacementLimitReached"
		end
	end

	if not itemDataInfo.Placeable then
		return false, "NotPlaceable"
	end

	-- Verificar inventário
	if not isServer and not InventoryService:HasItem(player, itemDataInfo.Name) then
		return false, "NoItemInInventory"
	end

	if category == "Pets" then
		if itemDataInfo.PlacementLimit and itemDataInfo.PlacementLimit > 0 then
			local currentPetCount = PetController:countActivePetsByName(player, itemName)
			if currentPetCount >= itemDataInfo.PlacementLimit then
				return false, "PlacementLimitReached"
			end
		end

		local inventoryItemUUID = itemData.InventoryUUID
		if not inventoryItemUUID then
			warn(`[BuildingService] Tentativa de colocar pet por ${player.Name} sem InventoryUUID.`)
			return false, "MissingInventoryUUID"
		end
		local inventory = InventoryService:GetInventory(player)
		local petInstanceData = InventoryService:FindAndRemoveByUUID(player, inventory, inventoryItemUUID)

		if not petInstanceData then
			return false, "ItemNotInInventory"
		end
		local success, message = PetController.SpawnPetForPlayer(player, itemName, petInstanceData, cframe)

		if success then
			local hasMore = InventoryService:HasItem(player, itemDataInfo.Name)
			self:UpdateAndNotifyClientBuffs(player)
			return true, { message = message }, hasMore
		else
			InventoryService:Add(player, petInstanceData)
			return false, message
		end
	else
		local result, rayOrMessage = self:ValidatePlacement(player, cframe.Position, itemDataInfo)
		if not result then
			return false, rayOrMessage
		end

		-- Plantar semente
		if itemDataInfo.Stages then
			local soilModel = nil
			local hitInstance = rayOrMessage.Instance
			if
				hitInstance:FindFirstAncestorOfClass("Model")
				and hitInstance:FindFirstAncestorOfClass("Model"):HasTag("plot")
			then
				soilModel = hitInstance:FindFirstAncestorOfClass("Model")
			elseif CollectionService:HasTag(hitInstance, "planet") then
				soilModel = getPlayerPlanetModel(player)
				if not soilModel:FindFirstChild("Plants") then
					local plantsFolder = Instance.new("Folder")
					plantsFolder.Name = "Plants"
					plantsFolder.Parent = soilModel
				end
			end
			if not soilModel then
				return false, "InvalidSoil"
			end
			local success, result = FarmingService:NewPlant(player, itemDataInfo, soilModel, cframe)
			if success then
				local hasMore = InventoryService:HasItem(player, itemDataInfo.Name)
				return true, result, hasMore
			else
				InventoryService:Add(player, {
					Name = itemDataInfo.Name,
					Category = itemDataInfo.Category,
					Quantity = 1,
					Stackable = itemDataInfo.Stackable,
					Locked = false,
				})
				return false, result
			end
		else
			-- Colocar item comum
			if not isServer then
				local removed = InventoryService:Remove(player, itemDataInfo.Name, 1)
				if not removed then
					return false, "NoItemInInventory"
				end
			end
			local hasMore = InventoryService:HasItem(player, itemDataInfo.Name)

			local itemModel = ItemData:FindModel(itemDataInfo)
			if not itemModel then
				return false, "NoItemModel"
			end

			local newUUID = itemData.UUID or HttpService:GenerateGUID(true)
			local newObject = itemModel:Clone()
			newObject.Parent = workspace.PlacedObjects
			newObject:PivotTo(cframe)

			-- Configurar tags
			local categoryTags = { Farming = "plot", Decoration = "decoration" }
			if categoryTags[itemDataInfo.Category] then
				CollectionService:AddTag(newObject, categoryTags[itemDataInfo.Category])
				if itemDataInfo.Category == "Farming" then
					if itemDataInfo.MaxPlants then
						newObject:SetAttribute("MaxPlants", itemDataInfo.MaxPlants)
					end
					if itemDataInfo.GrowthBonus then
						newObject:SetAttribute("GrowthBonus", itemDataInfo.GrowthBonus)
					end
					if not newObject:FindFirstChild("Plants") then
						Instance.new("Folder", newObject).Name = "Plants"
					end

					createPlotBuffGui(newObject, itemDataInfo)
				end
			end
			CollectionService:AddTag(newObject, "built_item")

			local objectData = {
				UUID = newUUID,
				ItemName = itemName,
				ItemData = itemDataInfo,
				Model = newObject,
				Owner = player.Name,
				PlacedTime = os.time(),
				Position = cframe.Position,
				Rotation = cframe.Rotation,
				Category = itemDataInfo.Category,
			}

			if not placedObjects[currentPlanet.Name] then
				placedObjects[currentPlanet.Name] = {}
			end

			setSafeAttributes(newObject, objectData)
			placedObjects[currentPlanet.Name][newUUID] = objectData
			addClickDetector(newObject, player)

			if itemDataInfo.Category == "Decoration" then
				ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent:Fire(
					player,
					"DecorationPlaced",
					itemName
				)
			end

			if itemDataInfo.Category == "Farming" and itemName == "CubePlot" then
				ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent:Fire(player, "PlotPlaced", itemName)
			end

			if itemDataInfo.Buffs then
				createBuffDisplayGui(newObject, itemDataInfo)
				self:UpdateAndNotifyClientBuffs(player)
			end
			if itemDataInfo.Category == "Crates" then
				local crateConfig = CrateData[itemName]
				if crateConfig then
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Open"
					prompt.RequiresLineOfSight = false
					prompt.ObjectText = crateConfig.DisplayName
					prompt.Style = Enum.ProximityPromptStyle.Custom
					prompt.HoldDuration = 2
					prompt:SetAttribute("Theme", "StarProx")
					prompt:SetAttribute("IsCrate", true)
					prompt.Parent = newObject.PrimaryPart or newObject
					newObject:SetAttribute("CrateType", itemName)
					task.spawn(function()
						prompt.Enabled = false
						task.wait(0.1)
						prompt.Enabled = true
					end)
					createCrateInfoGui(newObject, itemName)
				end
			end
			return true, objectData, hasMore
		end
	end
end
function BuildingService:ValidatePlacement(player, position, itemDataInfo)
	local positionVector3
	if typeof(position) == "CFrame" then
		positionVector3 = position.Position
	else
		positionVector3 = position
	end

	local playerPlanet = getPlayerPlanetModel(player)
	if not playerPlanet then
		warn("ValidatePlacement: Planeta do jogador não encontrado para " .. player.Name)
		return false, "NoPlanetFound"
	end

	local planetCenter = playerPlanet:GetPivot().Position
	local directionFromCenter = (positionVector3 - planetCenter).Unit
	local rayOrigin = positionVector3 + directionFromCenter * 5
	local rayDirection = -directionFromCenter * 15
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.FilterDescendantsInstances = { player.Character }

	local raycast = workspace:Raycast(rayOrigin, rayDirection, rayParams)
	if not raycast then
		return false, "NoGroundHit"
	end

	local hitInstance = raycast.Instance
	local hitModel = hitInstance:FindFirstAncestorOfClass("Model")
	local isHittingPlot = hitModel and hitModel:HasTag("plot")
	local isHittingPlanet = CollectionService:HasTag(hitInstance, "planet")
	local isHittingPlaceableSurface = CollectionService:HasTag(hitInstance, "PlaceableSurface")

	if itemDataInfo.Category == "Seeds" then
		-- Sementes só podem ir em plots
		if not isHittingPlot then
			return false, "SeedsOnlyOnPlots"
		end
	elseif itemDataInfo.Category == "Eggs" then
		-- Ovos podem ir em plots ou no planeta
		if not isHittingPlot and not isHittingPlanet then
			return false, "EggsOnlyOnPlotsOrPlanet"
		end
	elseif itemDataInfo.Category == "Decoration" or itemDataInfo.Category == "Crates" then
		-- Decorações têm suas próprias regras
		if not isHittingPlot and not isHittingPlanet and not isHittingPlaceableSurface then
			return false, "InvalidSurfaceForDecoration"
		end
	else
		-- Itens de Farming (como as próprias plots)
		if not isHittingPlanet and not (hitModel and hitModel:HasTag("plot")) then
			return false, "InvalidSurface"
		end
	end

	-- Validação de Propriedade (se está colocando no seu próprio terreno)
	local ownerFound = false
	local ownerAttributeSource = hitModel or hitInstance:FindFirstAncestorWithTag("planet")
	if ownerAttributeSource and ownerAttributeSource:GetAttribute("Owner") == player.Name then
		ownerFound = true
	-- Se o raycast atingiu o planeta diretamente, precisamos subir na hierarquia para encontrar a pasta do planeta
	elseif isHittingPlanet then
		local planetFolder = hitInstance:FindFirstAncestor(".Planets")
		if planetFolder and planetFolder:GetAttribute("Owner") == player.Name then
			ownerFound = true
		end
	end
	if hitModel and hitModel:GetAttribute("Owner") ~= player.Name then
		ownerFound = false
	end

	if not ownerFound then
		local planetFolderOwner = getPlayerPlanetModel(player)
		if planetFolderOwner and planetFolderOwner.Parent:GetAttribute("Owner") == player.Name then
			ownerFound = true
		else
			return false, "NotYourPlot"
		end
	end
	if isHittingPlot then
		if itemDataInfo.Category == "Seeds" or itemDataInfo.Category == "Eggs" then
			if FarmingService:IsPositionTooClose(hitModel, raycast.Position) then
				return false, "TooClose"
			end
			local currentPlants = FarmingService:CountPlantsInPlot(hitModel)
			local maxPlants = hitModel:GetAttribute("MaxPlants") or 20
			if currentPlants >= maxPlants then
				return false, "PlotFull"
			end
		end
	end

	return true, raycast
end

function BuildingService:RemoveMultipleObjects(player, objectUUIDs, forceRemove)
	if type(objectUUIDs) ~= "table" then
		return false, "InvalidData"
	end

	forceRemove = (forceRemove == true)

	if StateHandler.GetState(player, "IsRemovingMultiple") then
		return false, "Cooldown"
	end
	StateHandler.SetState(player, "IsRemovingMultiple", true, 1.0)

	local successes = 0
	local failures = 0

	for _, uuid in ipairs(objectUUIDs) do
		local success, reason = self:_internalRemoveSingleObject(player, uuid, forceRemove, true)
		if success then
			successes = successes + 1
		else
			warn(`[BuildingService] Falha ao remover objeto ${uuid} para ${player.Name}: ${reason}`)
			failures = failures + 1
		end
	end

	print(
		`[BuildingService] ${player.Name} guardou ${successes} itens (Forçado: ${tostring(forceRemove)}). Falhas: ${failures}.`
	)
	return true, { succeeded = successes, failed = failures }
end

function BuildingService:_internalRemoveSingleObject(player, objectUUID, forceRemove, returnToInventory)
	local objectData = nil
	local planetName = nil
	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			local planetObjects = placedObjects[planetFolder.Name]
			if planetObjects and planetObjects[objectUUID] then
				objectData = planetObjects[objectUUID]
				planetName = planetFolder.Name
				break
			end
		end
	end

	if not objectData then
		return false, "ObjectNotFound"
	end
	if objectData.Owner ~= player.Name then
		return false, "NotOwner"
	end
	if objectData.Model and objectData.Model:GetAttribute("CannotStore") then
		return false, "CannotBeStored"
	end
	if objectData.Category == "Farming" and not forceRemove then
		local model = objectData.Model
		if model and model:FindFirstChild("Plants") and #model.Plants:GetChildren() > 0 then
			return false, "HasPlants"
		end
	end

	if objectData.Category == "Farming" then
		if objectData.Model then
			FarmingService:RemoveAllPlantsFromPlot(objectData.Model)
		end
	end

	if objectData.Model and objectData.Model.Parent then
		objectData.Model:Destroy()
	end
	if planetName and placedObjects[planetName] and placedObjects[planetName][objectUUID] then
		placedObjects[planetName][objectUUID] = nil
	end
	if objectData.ItemData and objectData.ItemData.Buffs then
		self:UpdateAndNotifyClientBuffs(player)
	end
	if returnToInventory and objectData.ItemData and not objectData.Model:GetAttribute("CannotStore") then
		local itemToAdd = {
			Name = objectData.ItemData.Name,
			Category = objectData.ItemData.Category,
			Stackable = objectData.ItemData.Stackable or false,
			Quantity = 1,
			Locked = false,
		}
		InventoryService:Add(player, itemToAdd)
	end

	return true, "ObjectRemoved"
end

function BuildingService:RemoveObject(player, objectUUID, forceRemove, returnToInventory)
	if StateHandler.GetState(player, "IsRemoving") then
		return false, "Cooldown"
	end
	StateHandler.SetState(player, "IsRemoving", true, 0.5)
	return self:_internalRemoveSingleObject(player, objectUUID, forceRemove, returnToInventory)
end

--[[
	PLANET MANAGEMENT
--]]

function BuildingService:OnPlayerChangePlanet(player, fromPlanet, toPlanet)
	if toPlanet then
		self:LoadPlanet(player, toPlanet)
	end
end

function BuildingService:SetPlayerCurrentPlanet(player, planetName)
	local previousPlanet = playerCurrentPlanet[player.UserId]
	playerCurrentPlanet[player.UserId] = planetName
	self:LoadPlanet(player, planetName)
end

--[[
	GETTER FUNCTIONS
--]]

function BuildingService:GetPlayerObjects(player, planetName)
	local playerObjects = {}

	if not planetName then
		planetName = playerCurrentPlanet[player.UserId]
	end

	if planetName and placedObjects[planetName] then
		for uuid, objectData in pairs(placedObjects[planetName]) do
			if objectData.Owner == player.Name then
				playerObjects[uuid] = objectData
			end
		end
	end

	return playerObjects
end

function BuildingService:GetAllPlacedObjects()
	return placedObjects
end

function BuildingService:ClearPlayerObjects(player)
	local PetController = require(ServerScriptService.General.PetService)
	local objectsToRemove = {}
	for planetName, objects in pairs(placedObjects) do
		for uuid, objectData in pairs(objects) do
			if objectData.Owner == player.Name then
				table.insert(objectsToRemove, {
					planetName = planetName,
					uuid = uuid,
					model = objectData.Model,
				})
			end
		end
	end

	for _, data in ipairs(objectsToRemove) do
		if data.model and data.model.Parent then
			data.model:Destroy()
		end
		if placedObjects[data.planetName] and placedObjects[data.planetName][data.uuid] then
			placedObjects[data.planetName][data.uuid] = nil
		end
	end
	print(`[BuildingService] Foram limpos ${#objectsToRemove} objetos para o jogador ${player.Name}`)
	PetController:ClearPlayerPetsAndData(player)
end
--[[
	INITIALIZATION
--]]

function BuildingService:Initialize()
	--print(`🏗️ BUILDING SERVICE v{script:GetAttribute("version")} HAS STARTED`)

	-- Criar pasta de objetos
	if not workspace:FindFirstChild("PlacedObjects") then
		Instance.new("Folder", workspace).Name = "PlacedObjects"
	end

	-- Configurar decorações
	for _, decoration in ipairs(ItemModels.Decoration:GetChildren()) do
		if decoration:IsA("Model") and not decoration:GetAttribute("Decoration") then
			decoration:SetAttribute("Decoration", decoration.Name)
			decoration:SetAttribute("Category", "Decoration")
		end
	end

	-- Configurar plots
	for _, plot in ipairs(ItemModels.Farming:GetChildren()) do
		if plot:IsA("Model") and not plot:GetAttribute("Plot") then
			plot:SetAttribute("Plot", plot.Name)
			plot:SetAttribute("Category", "Farming")
			local plotData = ItemData:GetItem("Farming", plot.Name)
			if plotData and plotData.MaxPlants then
				plot:SetAttribute("MaxPlants", plotData.MaxPlants)
			else
				plot:SetAttribute("MaxPlants", 20)
			end
		end
	end

	-- Configurar sementes
	for _, seed in ipairs(ItemModels.Seeds:GetChildren()) do
		if seed:IsA("Model") and not seed:GetAttribute("Category") then
			seed:SetAttribute("Category", "Seeds")
		end
	end

	-- Configurar remote functions
	BuildingAction.OnServerInvoke = function(player, action, ...)
		if not player then
			return
		end
		local args = { ... }

		if action == "PlaceObject" then
			return BuildingService:PlaceObject(player, unpack(args))
		elseif action == "UpdateObjectPosition" then
			return BuildingService:UpdateObjectPosition(player, unpack(args))
		elseif action == "PlaceItem" then
			-- PlaceItem espera (player, itemData, isServer)
			local itemDataFromClient = args[1]
			return BuildingService:PlaceItem(player, itemDataFromClient, false)
		elseif action == "GetItemClientData" then
			-- GetItemClientData espera (player, category, itemName)
			local category, itemName = args[1], args[2]
			local itemData = ItemData:GetItem(category, itemName)
			if not itemData then
				return nil
			end

			local previewModelPath = nil
			if itemData.Path then
				previewModelPath = itemData.Path
			elseif itemData.Stages and itemData.Stages[1] and itemData.Stages[1].ModelPath then
				previewModelPath = itemData.Stages[1].ModelPath
			end

			local clientSafeData = {
				Name = itemData.Name,
				Category = itemData.Category,
				PlacementLimit = itemData.PlacementLimit,
				ModelPath = previewModelPath,
			}
			return clientSafeData
		elseif action == "CheckCanRemove" then
			return BuildingService:CheckCanRemove(player, unpack(args))
		elseif action == "ValidatePlacement" then
			local success, result = pcall(function()
				return BuildingService:ValidatePlacement(player, unpack(args))
			end)
			return success and result or false
		elseif action == "RemoveObject" then
			return BuildingService:RemoveObject(player, unpack(args))
		elseif action == "RemoveMultipleObjects" then
			return BuildingService:RemoveMultipleObjects(player, unpack(args))
		end
	end

	-- Configurar eventos de jogador(off)
	Players.PlayerAdded:Connect(function(player) end)
end

return BuildingService
