--[[
    PlantSaveData
    Mod By Lorris (7/12/2025) v.05
    Módulo Data para Save das Plantas
    Connections:
    FarmingService
    DataStoreModule
    ItemData
    InventoryService
    LeaderstatsService
--]]
local PlantSaveData = {}

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local DataStoreModule = require(game:GetService("ServerScriptService").Data.DataStoreModule)
local ItemData = require(game:GetService("ServerScriptService").Data.ItemData)
local PlantMutationData = require(game:GetService("ServerScriptService").Data.PlantsMutationData)
local FarmingService

local loadedPlantDataCache = {}

function PlantSaveData:Initialize()
	--print("🌱 PlantSaveData (v.04 Corrigido) inicializado")
end

function PlantSaveData:UpdatePlayerPlantData(player)
	local playerPlantsData = {}

	-- FUNÇÃO AUXILIAR PARA EVITAR REPETIÇÃO DE CÓDIGO
	local function serializePlantsInContainer(containerModel, containerUUID)
		local plantsFolder = containerModel:FindFirstChild("Plants")
		if not plantsFolder then return end

		local containerPlants = {}
		for _, plantModel in ipairs(plantsFolder:GetChildren()) do
			if plantModel:IsA("Model") and plantModel:GetAttribute("UUID") then
				local containerCFrame = containerModel:GetPivot()
				local plantCFrame = plantModel:GetPivot()
				local relativeCFrame = containerCFrame:ToObjectSpace(plantCFrame)
				local durationsAttr = plantModel:GetAttribute("StageDurations")

				local plantData = {
					UUID = plantModel:GetAttribute("UUID"),
					SeedName = plantModel:GetAttribute("Seed"),
					Category = plantModel:GetAttribute("Category") or "Seeds",
					Owner = plantModel:GetAttribute("Owner"),
					PlantedTime = plantModel:GetAttribute("PlantedTime"),
					CurrentStage = plantModel:GetAttribute("CurrentStage"),
					PlotUUID = containerUUID, 
					RelativeCF = { relativeCFrame:GetComponents() },
					StageDurations = durationsAttr and HttpService:JSONDecode(durationsAttr) or nil,
				
					IsMutated = plantModel:GetAttribute("IsMutated"),
					MutatedName = plantModel:GetAttribute("MutatedName"),
				}
				table.insert(containerPlants, plantData)
			end
		end

		if #containerPlants > 0 then
			playerPlantsData[containerUUID] = containerPlants
		end
	end

	-- Aqui e diretamente nas plots
	for _, plot in ipairs(CollectionService:GetTagged("plot")) do
		if plot:GetAttribute("Owner") == player.Name then
			local plotUUID = plot:GetAttribute("UUID")
			if plotUUID then
				serializePlantsInContainer(plot, plotUUID)
			else
				warn("❌ Plot sem UUID, pulando coleta para:", plot.Name)
			end
		end
	end

	-- So a logic do planet
	local playerPlanetModel = nil
	for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
		if planetFolder:GetAttribute("Owner") == player.Name then
			-- Função para pegar o modelo "Planet" dentro da pasta
			playerPlanetModel = planetFolder:FindFirstChild("Planet") or planetFolder:FindFirstChildOfClass("Model")
			break
		end
	end

	if playerPlanetModel then
		--identificador especial para as plantas do planeta
		local planetIdentifier = "__PLANET__" 
		serializePlantsInContainer(playerPlanetModel, planetIdentifier)
	end

	local plantsDataStore = DataStoreModule.GetDataStore(player, "PlayerPlants_VOne")
	if plantsDataStore then
		--print(string.format("ℹ️ Preparando dados de plantas para %s. {cache a ser salvo pelo DataStoreModule}", player.Name))
		plantsDataStore:SetData(playerPlantsData)
	else
		warn("❌ Não foi possível encontrar o DataStore de plantas para preparar os dados de", player.Name)
	end
end


function PlantSaveData:LoadPlayerPlants(player)
	print(string.format("🗂️ Carregando dados de plantas para %s...", player.Name))
	local plantsDataStore = DataStoreModule.GetDataStore(player, "PlayerPlants_VOne")

	-- O GetData aqui vai esperar pela conclusão (graças à lógica no DataStoreModule valeu demais pedral)
	local data = plantsDataStore:GetData({}) 

	if data and next(data) then
		loadedPlantDataCache[player.UserId] = data
		print(string.format("✅ Dados de plantas de %s carregados para a cache.", player.Name))
	else
		loadedPlantDataCache[player.UserId] = {}
		print(string.format("ℹ️ Nenhum dado de planta encontrado para %s. Cache inicializada vazia.", player.Name))
	end
end

function PlantSaveData:RestoreAllPlantsForPlayer(player)
	local allPlayerPlantsData = loadedPlantDataCache[player.UserId]
	if not allPlayerPlantsData or not next(allPlayerPlantsData) then
		print(string.format("ℹ️ Nenhuma planta na cache para restaurar para %s.", player.Name))
		return
	end

	local currentTime = os.time()
	for containerUUID, plotPlantsArray in pairs(allPlayerPlantsData) do
		local targetContainer = nil 
		if containerUUID == "__PLANET__" then
			for _, planetFolder in ipairs(workspace.Planets:GetChildren()) do
				if planetFolder:GetAttribute("Owner") == player.Name then
					targetContainer = planetFolder:FindFirstChild("Planet") or planetFolder:FindFirstChildOfClass("Model")
					break
				end
			end
		else
			local plots = CollectionService:GetTagged("plot")
			for _, plot in ipairs(plots) do
				if plot:GetAttribute("UUID") == containerUUID and plot:GetAttribute("Owner") == player.Name then
					targetContainer = plot
					break
				end
			end
		end

		if targetContainer then
			local plantsFolder = targetContainer:FindFirstChild("Plants")
			if not plantsFolder then
				plantsFolder = Instance.new("Folder")
				plantsFolder.Name = "Plants"
				plantsFolder.Parent = targetContainer
			end
			for _, plantData in ipairs(plotPlantsArray) do
				self:RestorePlant(plantData, plantsFolder, currentTime, targetContainer)
			end
		else
			warn(string.format("⚠️ Container de plantas com UUID/ID '%s' não encontrado no workspace para o jogador %s. As plantas não serão restauradas.", containerUUID, player.Name))
		end
	end
end


function PlantSaveData:RestorePlantsForPlot(player, targetPlot)
	--dados diretamente do cache do DataStoreModule
	local plantsDataStore = DataStoreModule.GetDataStore(player, "PlayerPlants_VOne")
	if not plantsDataStore then
		warn("❌ DataStore de plantas não inicializado para", player.Name)
		return
	end

	-- O GetData() aqui vai retornar o valor do cache que já foi carregado
	local playerPlantsData = plantsDataStore:GetData({})
	if not playerPlantsData then return end -- Se for nil, não há nada a restaurar.

	local plotUUID = targetPlot:GetAttribute("UUID")
	if not plotUUID then
		warn("⚠️ Plot", targetPlot.Name, "não tem UUID, não é possível restaurar plantas.")
		return
	end

	local plotPlants = playerPlantsData[plotUUID]
	if not plotPlants or #plotPlants == 0 then
		return
	end

	local currentTime = os.time()
	local plantsFolder = targetPlot:FindFirstChild("Plants")
	if not plantsFolder then
		warn("❌ Pasta Plants não encontrada na plot:", targetPlot.Name)
		return
	end

	for _, plantData in ipairs(plotPlants) do
		self:RestorePlant(plantData, plantsFolder, currentTime, targetPlot)
	end
end


function PlantSaveData:RestorePlant(plantData, plantsFolder, currentTime, targetPlot)
	FarmingService = FarmingService or require(game:GetService("ServerScriptService").Game.FarmingService)
	if not plantsFolder or not targetPlot then return end
	local itemCategory = plantData.Category or "Seeds" 
	local seedData = ItemData:GetItem(itemCategory, plantData.SeedName)
	if not seedData then
		warn("❌ Dados do item não encontrados ao restaurar:", plantData.SeedName, "na categoria", itemCategory, ". A planta não será restaurada.")
		return
	end
	local stageDurations = plantData.StageDurations 
	if not stageDurations then
		warn("⚠️ Dados de planta antigos detectados para " .. plantData.UUID .. ". Gerando durações dinamicamente.")
		stageDurations = {}
		for i, stageInfo in ipairs(seedData.Stages) do
			local duration = stageInfo.Duration
			if type(duration) == "table" then
				stageDurations[i] = math.random(duration[1], duration[2])
			else

				stageDurations[i] = duration or 0
			end
		end
	end
	local isMutated = plantData.IsMutated and plantData.MutatedName and plantData.MutatedName ~= ""

	local finalStageModel, finalStage, timeIntoCurrentStage

	if isMutated then
		finalStageModel = PlantMutationData:FindMutationModel(plantData.MutatedName) 
		finalStage = #seedData.Stages 
		timeIntoCurrentStage = 0
	else 
		local timeElapsed = currentTime - (plantData.PlantedTime or currentTime)
		local savedStage = plantData.CurrentStage or 1
		local calculatedStage
		calculatedStage, timeIntoCurrentStage = self:CalculateStageFromTime(seedData, timeElapsed, stageDurations)

		finalStage = math.max(savedStage, calculatedStage)
		finalStage = math.max(1, math.min(finalStage, #seedData.Stages))
		finalStageModel = ItemData:FindModel(seedData, finalStage)
	end

	if not finalStageModel then
		warn("❌ Modelo não encontrado para o estágio", finalStage, "da seed", plantData.SeedName)
		return
	end

	local newPlant = finalStageModel:Clone()
	newPlant.Parent = plantsFolder


	local plotCFrame = targetPlot:GetPivot()
	if plantData.RelativeCF then
		local relativeCFrame = CFrame.new(table.unpack(plantData.RelativeCF))
		newPlant:PivotTo(plotCFrame * relativeCFrame)
	else
		warn("❌ Dados de posição da planta ausentes (RelativeCF):", plantData.UUID, ". A planta não será restaurada.")
		newPlant:Destroy()
		return
	end
	newPlant:SetAttribute("UUID", plantData.UUID)
	newPlant:SetAttribute("Seed", plantData.SeedName)
	newPlant:SetAttribute("Owner", plantData.Owner)
	newPlant:SetAttribute("PlantedTime", plantData.PlantedTime)
	newPlant:SetAttribute("CurrentStage", finalStage)
	newPlant:SetAttribute("Category", plantData.Category or "Seeds") 
	newPlant:SetAttribute("StageDurations", HttpService:JSONEncode(stageDurations))
	newPlant:SetAttribute("IsMutated", isMutated)
	newPlant:SetAttribute("MutatedName", plantData.MutatedName or "")


	if finalStage == #seedData.Stages then
		self:AddHarvestPrompt(newPlant, seedData, isMutated, plantData.MutatedName)
	end
	local restoredPlantData = {
		UUID = plantData.UUID,
		Seed = seedData,
		Model = newPlant,
		Owner = plantData.Owner,
		PlantedTime = plantData.PlantedTime,
		CurrentStage = finalStage,
		SoilModel = targetPlot,
		Position = newPlant:GetPivot(),
		StageDurations = stageDurations,
		TimeIntoCurrentStage = (finalStage > (plantData.CurrentStage or 1)) and timeIntoCurrentStage or 0,
		IsMutated = isMutated,
		MutatedName = isMutated and plantData.MutatedName or nil,
	}

	FarmingService:RegisterAndContinueGrowth(restoredPlantData)
end

function PlantSaveData:CalculateStageFromTime(seedData, timeElapsed, stageDurations)
	if not seedData or not seedData.Stages or not stageDurations then
		warn("❌ Dados de seed ou durações inválidos para cálculo de estágio")
		return 1, 0 -- Retorna stage 1 e 0 tempo decorrido
	end

	local timeIntoCurrentStage = math.max(0, timeElapsed)
	local currentStage = 1
	local maxStage = #seedData.Stages

	for stage = 1, maxStage - 1 do
		local duration = stageDurations[stage]
		if not duration then break end

		if timeIntoCurrentStage >= duration then
			timeIntoCurrentStage = timeIntoCurrentStage - duration
			currentStage = stage + 1
		else
			-- se não entrou no if significa que o tempo ainda não passou da duração do estágio, então sai do loop
			break
		end
	end

	-- so pra garantir
	if currentStage >= maxStage then
		currentStage = maxStage
		timeIntoCurrentStage = 0
	end

	return currentStage, timeIntoCurrentStage
end

function PlantSaveData:AddHarvestPrompt(plantModel, seedData, isMutated, mutatedName)
	-- Remover prompts existentes
	for _, existingPrompt in ipairs(plantModel:GetDescendants()) do
		if existingPrompt:IsA("ProximityPrompt") then
			existingPrompt:Destroy()
		end
	end
	-- Criar novo prompt
	local cropInteraction = Instance.new("ProximityPrompt")
	cropInteraction.Parent = plantModel
	cropInteraction.ActionText = "Harvest"
	cropInteraction.ObjectText = seedData.Name
	cropInteraction.HoldDuration = 0.1
	cropInteraction.RequiresLineOfSight = false
	cropInteraction.Style = Enum.ProximityPromptStyle.Custom
	if isMutated and mutatedName then
		cropInteraction.ActionText = "Colher Tesouro"
		cropInteraction.ObjectText = mutatedName
		cropInteraction:SetAttribute("Theme", "StarProx")
	else
	if seedData.Category == "Eggs" then
		cropInteraction.ActionText = "Chocar"
		cropInteraction:SetAttribute("Theme", "EggHatchProx")
	else
		cropInteraction.ActionText = "Harvest"
		cropInteraction:SetAttribute("Theme", "SeedCollectprox")
	end
end
	cropInteraction.Triggered:Connect(function(triggeringPlayer)
		local FarmingService = require(game:GetService("ServerScriptService").Game.FarmingService)
		local plantData = FarmingService.activePlants[plantModel:GetAttribute("UUID")]
		if plantData then
			FarmingService:HarvestPlant(triggeringPlayer, plantData)
		end
	end)
end

function PlantSaveData:SaveAllPlayerPlants()
	for _, player in ipairs(Players:GetPlayers()) do
		self:UpdatePlayerPlantData(player)
	end
end


-- Função para ser chamada quando uma planta é removida/colhida
function PlantSaveData:OnPlantRemoved(plantUUID, ownerName)
	local player = Players:FindFirstChild(ownerName)
	if player then
		self:UpdatePlayerPlantData(player)
		local plantsDataStore = DataStoreModule.GetDataStore(player, "PlayerPlants_VOne")
		if plantsDataStore then
			plantsDataStore:SaveData()
		end
	end
end

function PlantSaveData:ClearCacheForPlayer(player)
	if not player then return end
	if loadedPlantDataCache[player.UserId] then
		loadedPlantDataCache[player.UserId] = nil
		print(string.format("🗑️ Cache de plantas para %s foi limpa após o salvamento.", player.Name))
	end
end

return PlantSaveData