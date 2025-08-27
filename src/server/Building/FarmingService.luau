local FarmingService = {}

local FarmingAction = game.ReplicatedStorage.RemoteFunctions.Farming:WaitForChild("FarmingAction")
local DataStoreModule = require(game:GetService("ServerScriptService").Data.DataStoreModule)
local InventoryService = require(game:GetService("ServerScriptService").Player.InventoryService)
local LeaderstatsService = require(game:GetService("ServerScriptService").Player.LeaderStatsService)
local ItemData = require(game:GetService("ServerScriptService").Data.ItemData)
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StateHandler = require(game:GetService("ServerScriptService").Game.StateHandler)
local ItemModels = game:GetService("ServerStorage").ItemModels
local EggLootData = require(game:GetService("ServerScriptService").Data.EggLootData)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HarvestFolder = ReplicatedStorage.RemoteEvents.Harvest
local PlayAnimationEvent = HarvestFolder:WaitForChild("HarvestAnimations")
local PlayOpeningAnimation = HarvestFolder:WaitForChild("PlayOpeningAnimation")
local PlantMutationData = require(game:GetService("ServerScriptService").Data.PlantsMutationData)

local activePlants = {}

local PlantSaveData = require(game:GetService("ServerScriptService").Data.PlantSaveData)

FarmingService.activePlants = activePlants


local BuildingService 



local function CreatePlantProgressGui(plantModel, plantData)
	local existingGui = plantModel:FindFirstChild("PlantProgressGui")
	if existingGui then
		existingGui:Destroy()
	end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "PlantProgressGui"
	billboardGui.Parent = plantModel
	billboardGui.Size = UDim2.new(2, 0,1, 0)
	billboardGui.StudsOffset = Vector3.new(0, 2, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 30

	-- Label para mostrar a porcentagem
	local label = Instance.new("TextLabel")
	label.Parent = billboardGui
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "0%"
	label.TextColor3 = Color3.new(0.705882, 1, 0.741176)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	local uistroke  = Instance.new("UIStroke")
	uistroke.Parent = label
	uistroke.Color = Color3.new(0, 0, 0)

	-- Ref Saves
	billboardGui:SetAttribute("PlantUUID", plantData.UUID)
	billboardGui:SetAttribute("PlantedTime", plantData.PlantedTime)
	billboardGui:SetAttribute("CurrentStage", plantData.CurrentStage)

	return billboardGui
end

local function rollForItem(lootTable)
	local totalWeight = 0
	for _, item in ipairs(lootTable) do
		totalWeight += (item.Weight or 0)
	end

	if totalWeight == 0 then return nil end

	local randomNumber = math.random(1, totalWeight)
	local currentWeight = 0

	for _, item in ipairs(lootTable) do
		currentWeight += item.Weight
		if randomNumber <= currentWeight then
			return item -- Item sorteado
		end
	end
end

-- Função para atualizar a porcentagem 
local function UpdatePlantProgress(plantModel, plantData)
	local billboardGui = plantModel:FindFirstChild("PlantProgressGui")
	if not billboardGui then return end

	local label = billboardGui:FindFirstChild("TextLabel")
	if not label then return end

	local stages = plantData.Seed.Stages
	if not stages or plantData.CurrentStage >= #stages then
		billboardGui:Destroy()
		return
	end

	local durations = plantData.StageDurations
	if not durations then
		warn("Durações pré-calculadas não encontradas para a planta " .. plantData.UUID)
		billboardGui:Destroy()
		return
	end

	-- 1 Calcula o tempo total necessário para amadurecer 
	local totalDurationToMature = 0
	for i = 1, #stages - 1 do
		totalDurationToMature = totalDurationToMature + (durations[i] or 0)
	end
	if totalDurationToMature <= 0 then
		billboardGui:Destroy()
		return
	end



	-- 2 > Calcular o tempo que já passou desde o plantio
	local elapsedTime = os.time() - plantData.PlantedTime

	-- 3 > Calcular a porcentagem
	local percentage = math.min(100, (elapsedTime / totalDurationToMature) * 100)

	-- Atualizar texto
	if percentage >= 100 then
		label.Text = "99.9%"
	else
		label.Text = string.format("%.1f%%", percentage)
	end

	if percentage < 33 then
		label.TextColor3 = Color3.fromRGB(255, 100, 100)
	elseif percentage < 66 then
		label.TextColor3 = Color3.fromRGB(255, 255, 100)
	else
		label.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
end


function FarmingService:Initialize()
	--print(`🧑‍🌾 FARMING SERVICE v{script:GetAttribute("version")} HAS STARTED`)

	PlantSaveData:Initialize()
	
	-- Configurar atributos das plantas
	for _, plant in ipairs(ItemModels.Plants:GetChildren()) do
		if plant:IsA("Folder") then
			for _, stage in ipairs(plant:GetChildren()) do
				if stage:IsA("Model") then
					stage:SetAttribute("Plant", plant.Name)
				end
			end
		end
	end

	-- Inicializar plots com MaxPlants
	local plots = CollectionService:GetTagged("plot")
	for _, plot in ipairs(plots) do
		local plotType = plot:GetAttribute("PlotType") or "BasicPlot"
		local plotData = ItemData:GetItem("Farming", plotType)

		if plotData and plotData.MaxPlants then
			plot:SetAttribute("MaxPlants", plotData.MaxPlants)
		else
			plot:SetAttribute("MaxPlants", 20)
			warn(`Plot {plot.Name} não encontrada no ItemData, usando MaxPlants padrão: 20`)
		end
	end
end


function FarmingService:RegisterAndContinueGrowth(plantData)
	activePlants[plantData.UUID] = plantData

	local totalStages = #plantData.Seed.Stages
	if plantData.CurrentStage < totalStages then
		-- Cria a BillboardGui de progresso
		local billboardGui = CreatePlantProgressGui(plantData.Model, plantData)
		plantData.ProgressGui = billboardGui

		task.spawn(function()
			while activePlants[plantData.UUID] and plantData.Model and plantData.Model.Parent do
				UpdatePlantProgress(plantData.Model, plantData)
				task.wait(1)
			end
		end)

		-- Inicia ou continua o ciclo de crescimento para os próximos estágios
		self:GrowCycle(plantData, plantData.TimeIntoCurrentStage)
	end
end

function FarmingService:CountPlantsInPlot(soilModel)
	local count = 0
	for plantUUID, plantData in pairs(activePlants) do
		if plantData.SoilModel == soilModel then
			count = count + 1
		end
	end
	return count
end

local function getNormalCFrame(RayCast)
	local up = RayCast.Normal
	local arbitrary = math.abs(up:Dot(Vector3.new(0, 1, 0))) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = up:Cross(arbitrary).Unit
	local forward = right:Cross(up).Unit
	local rotationCFrame = CFrame.Angles(0, math.rad(90), 0)
	return CFrame.fromMatrix(RayCast.Position, right, up) * rotationCFrame
end

function FarmingService:IsPositionTooClose(soilModel, newPosition)
	for _, plantData in pairs(activePlants) do
		if plantData.SoilModel == soilModel then
			local distance = (newPosition - plantData.Position.Position).Magnitude
			if distance < 1.8 then -- Distância mínima entre as plantas
				return true
			end
		end
	end
	return false
end

function FarmingService:NewPlant(player, seedData, soilModel, cframe)
	if not BuildingService then
				BuildingService = require(game:GetService("ServerScriptService").Game.BuildingService)
			end

	
	if not soilModel or not soilModel:FindFirstChild("Plants") then
		warn("❌ Erro: InvalidSoilModel recebido pelo FarmingService")
		return false, "InvalidSoilModel"
	end
	
	if soilModel:HasTag("plot") then
		if soilModel:GetAttribute("Owner") ~= player.Name then
			warn(`❌ [FarmingService] Tentativa de plantio negada. ${player.Name} não é dono de ${soilModel.Name}.`)
			return false, "NotYourPlot"
		end
		if self:CountPlantsInPlot(soilModel) >= (soilModel:GetAttribute("MaxPlants") or 20) then
			return false, "PlotFull"
		end
	else 
	end
	-- Buscar modelo da planta (o primeiro estágio é a semente)
	local seedModel = ItemData:FindModel(seedData, 1)
	if not seedModel then 
		warn("❌ Erro: Modelo da seed não encontrado para", seedData.Name)
		return false, "NoSeedModel" 
	end

	-- Remover item do inventário
	InventoryService:Remove(player, seedData.Name, 1)

	-- Criar planta
	local newUUID = HttpService:GenerateGUID(true)
	local newPlant = seedModel:Clone()
	newPlant.Parent = soilModel:FindFirstChild("Plants")

	-- Posicionar a planta
	if newPlant.PrimaryPart then
		newPlant:PivotTo(cframe)
	else 
		newPlant:MoveTo(cframe.Position) 
	end

	local playerBuffs = BuildingService:GetPlayerBuffs(player)
	local globalGrowthBonus = playerBuffs.GrowthSpeedBonus or 0

	local plotGrowthBonus = 0
	if soilModel:HasTag("plot") then
		local plotItemDataName = soilModel:GetAttribute("ItemName")
		if plotItemDataName then
			local plotItemData = ItemData:GetItem("Farming", plotItemDataName)
			if plotItemData and plotItemData.GrowthBonus then
				plotGrowthBonus = plotItemData.GrowthBonus - 1 
			end
		end
	end

	local totalGrowthMultiplier = 1 + globalGrowthBonus + plotGrowthBonus

	local stageDurations = {}
	for i, stageData in ipairs(seedData.Stages) do
		local duration = stageData.Duration
		local baseDuration = 0 
		if type(duration) == "table" then
			baseDuration = math.random(duration[1], duration[2])
		else
			baseDuration = duration or 0
		end
		stageDurations[i] = baseDuration / totalGrowthMultiplier
	end

	local plantData = {
		UUID = newUUID,
		Seed = seedData,
		Model = newPlant,
		Owner = player.Name,
		PlantedTime = os.time(),
		CurrentStage = 1,
		SoilModel = soilModel,
		Position = cframe,
		StageDurations = stageDurations,
		IsMutated = false, 
		MutatedName = nil,  
	}

	-- Definir atributos
	newPlant:SetAttribute("UUID", newUUID)
	newPlant:SetAttribute("Seed", seedData.Name)
	newPlant:SetAttribute("Owner", player.Name)
	newPlant:SetAttribute("PlantedTime", os.time())
	newPlant:SetAttribute("CurrentStage", 1)
	newPlant:SetAttribute("IsMutated", false)
	newPlant:SetAttribute("MutatedName", "")
	newPlant:SetAttribute("Category", seedData.Category)
	newPlant:SetAttribute("StageDurations", HttpService:JSONEncode(stageDurations))

	self:RegisterAndContinueGrowth(plantData)

-- faz parte do tutorial?

	ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent:Fire(player, "PlantPlaced", seedData.Name)
	return true, plantData
end

function FarmingService:GrowCycle(plantData, initialTimeIntoStage)
	initialTimeIntoStage = initialTimeIntoStage or 0 

	task.spawn(function()
		local durations = plantData.StageDurations

		for stage = plantData.CurrentStage, #plantData.Seed.Stages - 1 do
			if not activePlants[plantData.UUID] or not plantData.Model or not plantData.Model.Parent then
				warn("🚫 Planta removida durante crescimento:", plantData.UUID)
				return
			end

			local duration = durations[stage]
			local waitTime = duration

			if stage == plantData.CurrentStage and initialTimeIntoStage > 0 then
				waitTime = math.max(0, duration - initialTimeIntoStage)
				--print(string.format("Crescimento retomado. Estágio %d. Duração: %.1fs. Tempo decorrido: %.1fs. Esperando por: %.1fs", stage, duration, initialTimeIntoStage, waitTime))
			end

			task.wait(waitTime)
			initialTimeIntoStage = 0 

			if activePlants[plantData.UUID] then
				FarmingService:GrowPlant(plantData, stage + 1)
			else
				return
			end
		end
	end)
end

function FarmingService:GrowPlant(plantData, stage)
	-- Verificar se a planta ainda existe
	if not activePlants[plantData.UUID] or not plantData.Model or not plantData.Model.Parent then
		warn("🚫 Tentativa de crescer planta inexistente:", plantData.UUID)
		return
	end

	-- Se já está no estágio correto
	if plantData.CurrentStage >= stage then
		return
	end

	local newStageModel = ItemData:FindModel(plantData.Seed, stage)
	if not newStageModel then 
		warn("❌ Modelo não encontrado para estágio", stage)
		return 
	end

	if stage == #plantData.Seed.Stages then
		local didMutate = false 
		-- Apenas  mutações  se categoria "Seeds"
		if plantData.Seed.Category == "Seeds" then
			local originalPlantName = plantData.Seed.Plant
			local originalPlantData = ItemData:GetItem("Plants", originalPlantName)

			if originalPlantData and originalPlantData.PossibleMutations then
				for _, mutationInfo in ipairs(originalPlantData.PossibleMutations) do
					if math.random() <= mutationInfo.Chance then
						local mutationData = PlantMutationData:GetMutation(mutationInfo.Name) 
						if mutationData then
							local player = Players:FindFirstChild(plantData.Owner)
							local NotifyPlayerEvent = ReplicatedStorage.RemoteEvents.Shop:FindFirstChild("NotifyPlayer")
							if player and NotifyPlayerEvent then
								local message = string.format("✨ Mutação! Sua %s virou uma %s!", originalPlantName, mutationData.Name)
								NotifyPlayerEvent:FireClient(player, message, nil, Color3.fromRGB(255, 215, 0))
							end
							newStageModel = PlantMutationData:FindMutationModel(mutationInfo.Name) 
							plantData.IsMutated = true
							plantData.MutatedName = mutationData.Name
							didMutate = true
							break 
						end
					end
				end
			end
		end
		if not didMutate then
			newStageModel = ItemData:FindModel(plantData.Seed, stage)
		end
	else
		newStageModel = ItemData:FindModel(plantData.Seed, stage)
	end

	if not newStageModel then 
		warn("❌ Modelo não encontrado para estágio", stage)
		return 
	end
	-- Destruir modelo antigo
	if plantData.Model then
		plantData.Model:Destroy()
	end

	local tempModel = newStageModel:Clone()
	tempModel.Parent = plantData.SoilModel.Plants

	-- atributos necessários
	tempModel:SetAttribute("UUID", plantData.UUID)
	tempModel:SetAttribute("Seed", plantData.Seed.Name)
	tempModel:SetAttribute("Owner", plantData.Owner)
	tempModel:SetAttribute("PlantedTime", plantData.PlantedTime)
	tempModel:SetAttribute("CurrentStage", stage)
	tempModel:SetAttribute("IsMutated", plantData.IsMutated) 
	tempModel:SetAttribute("MutatedName", plantData.MutatedName or "") 
	tempModel:SetAttribute("Category", plantData.Seed.Category)
	tempModel:SetAttribute("StageDurations", HttpService:JSONEncode(plantData.StageDurations))
	-- Posicionar modelo
	local currentPlantPosition = plantData.Model and plantData.Model:GetPivot() or plantData.Position
	if tempModel.PrimaryPart then
		tempModel:PivotTo(currentPlantPosition)
	else 
		tempModel:MoveTo(currentPlantPosition.Position)
	end

	-- Se é o último estágio, adicionar ProximityPrompt
	if stage == #plantData.Seed.Stages then
		for _, existingPrompt in ipairs(tempModel:GetDescendants()) do
			if existingPrompt:IsA("ProximityPrompt") then
				existingPrompt:Destroy()
			end
		end

		local cropInteraction = Instance.new("ProximityPrompt")
		cropInteraction.Parent = tempModel
		cropInteraction.ActionText = "Harvest"
		cropInteraction.ObjectText = plantData.Seed.Name
		cropInteraction.HoldDuration = 0.1
		cropInteraction.RequiresLineOfSight = false
		cropInteraction.Style = Enum.ProximityPromptStyle.Custom
		if plantData.IsMutated then
			cropInteraction.ActionText = "Golden"
			cropInteraction.ObjectText = plantData.MutatedName
			cropInteraction:SetAttribute("Theme", "StarProx") 
		else
			cropInteraction.ActionText = "Harvest"
			cropInteraction.ObjectText = plantData.Seed.Name
			if plantData.Seed.Category == "Eggs" then
				cropInteraction.ActionText = "Chocar" 
				cropInteraction:SetAttribute("Theme", "EggHatchProx") 
			else
				cropInteraction:SetAttribute("Theme", "SeedCollectprox") 
			end
		end

		cropInteraction.Triggered:Connect(function(triggeringPlayer)
			FarmingService:HarvestPlant(triggeringPlayer, plantData)
		end)
		task.spawn(function()
			task.wait(0.1) 
			cropInteraction.Enabled = false
			task.wait(0.05)
			cropInteraction.Enabled = true
		end)
	end
	
	if plantData.Model and plantData.Model:FindFirstChild("PlantProgressGui") then
		plantData.Model:FindFirstChild("PlantProgressGui"):Destroy()
	end

	-- Se não é o último estágio, criar nova GUI
	if stage < #plantData.Seed.Stages then
		local billboardGui = CreatePlantProgressGui(tempModel, plantData)
		plantData.ProgressGui = billboardGui

		-- Iniciar loop de atualização para o novo modelo
		task.spawn(function()
			while activePlants[plantData.UUID] and tempModel.Parent do
				UpdatePlantProgress(tempModel, plantData)
				task.wait(1)
			end
		end)
	end

	plantData.Model = tempModel
	plantData.CurrentStage = stage

	-- Salvar progresso de crescimento
	local player = Players:FindFirstChild(plantData.Owner)
	if player then
		task.spawn(function()
			task.wait(0.5)
			PlantSaveData:UpdatePlayerPlantData(player)
		end)
	end
end

function FarmingService:HarvestPlant(player, plantData)
	if not BuildingService then
		BuildingService = require(game:GetService("ServerScriptService").Game.BuildingService)
	end
	if StateHandler.GetState(player, "IsHarvesting") then
		return
	end
	StateHandler.SetState(player, "IsHarvesting", true, 0.2)

	if player.Name ~= plantData.Owner then
		print("❌ Jogador", player.Name, "tentou interagir com um objeto que não é seu.")
		return
	end

	-- Lógica de recompensa para MUTAÇÃO
	if plantData.IsMutated and plantData.MutatedName then
		local mutationData = PlantMutationData:GetMutation(plantData.MutatedName) 
		if mutationData then
			PlayAnimationEvent:FireClient(player, "Harvest") 
			LeaderstatsService:IncrementPlayerStat(player, "FarmingXP", (plantData.Seed.Experience or 0) * 5)
			InventoryService:Add(player, {
				Name = mutationData.Name,
				Category = "PlantsMutation", 
				Stackable = mutationData.Stackable,
				Quantity = 1,
				Locked = false
			})
		end
	else
		local itemInfo = plantData.Seed

		-- Lógica de recompensa para OVO
		if itemInfo.Category == "Eggs" then
			local eggPivot = plantData.Model and plantData.Model:GetPivot() or plantData.Position
			local lootTableName = itemInfo.LootTable
			if not lootTableName then
				warn("❌ Ovo '"..tostring(itemInfo.Name).."' não tem uma LootTable definida."); return
			end
			local eggLootConfig = EggLootData[lootTableName]
			if not eggLootConfig or not eggLootConfig.LootTable then
				warn("❌ Tabela de loot '"..tostring(lootTableName).."' não encontrada."); return
			end
			local wonPetInfo = rollForItem(eggLootConfig.LootTable)
			if not wonPetInfo then
				warn("❌ Falha ao sortear pet do ovo:", itemInfo.Name); return
			end
			local petItemData = ItemData:GetItem(wonPetInfo.Category, wonPetInfo.Name)
			if not petItemData then
				warn("❌ Dados do pet ganho não encontrados:", wonPetInfo.Name); return
			end
			local newPetInstanceData = {
				Name = petItemData.Name,
				Category = "Pets",
				Stackable = false,  
				Quantity = 1,
				Locked = false,
				UUID = HttpService:GenerateGUID(false),
				Level = 1,      
				XP = 0         
			}
			InventoryService:Add(player, newPetInstanceData)
			print(string.format("🥚 %s chocou um %s e ganhou um %s!", player.Name, itemInfo.Name, petItemData.Name))
			LeaderstatsService:IncrementPlayerStat(player, "FarmingXP", itemInfo.Experience or 0)


			PlayOpeningAnimation:FireClient(player, itemInfo.Name, itemInfo.Category, eggPivot, wonPetInfo)

			-- Lógica de recompensa para PLANTA NORMAL
		else
			PlayAnimationEvent:FireClient(player, "Harvest")

			local playerBuffs = BuildingService:GetPlayerBuffs(player)
			local moneyMultiplier = 1 + (playerBuffs.MoneyBonus or 0)

			local reward = math.floor(itemInfo.HarvestValue * moneyMultiplier)
			local xp = itemInfo.Experience or 0
			local cratePoints = itemInfo.HarvestCratePoints or 0

			LeaderstatsService:IncrementPlayerStat(player, "Money", reward)
			LeaderstatsService:IncrementPlayerStat(player, "FarmingXP", xp)
			LeaderstatsService:IncrementPlayerStat(player, "CratePoints", cratePoints)

			local plantName = itemInfo.Plant
			if plantName then
				local plantItemData = ItemData:GetItem("Plants", plantName)
				if plantItemData then
					InventoryService:Add(player, {
						Name = plantItemData.Name,
						Category = plantItemData.Category,
						Stackable = plantItemData.Stackable,
						Quantity = 1,
						Locked = false
					})
				else
					warn("❌ Dados da planta '"..tostring(plantName).."' para colheita não encontrados no ItemData.")
				end
			end
		end
	end

	if plantData.Model then
		plantData.Model:Destroy()
	end
	activePlants[plantData.UUID] = nil

	PlantSaveData:OnPlantRemoved(plantData.UUID, plantData.Owner)
end
-- Função para limpar planta específica
function FarmingService:RemovePlant(plantUUID)
	local plantData = activePlants[plantUUID]
	if plantData then
		if plantData.Model then
			plantData.Model:Destroy()
		end
		activePlants[plantUUID] = nil

		-- Notificar PlantSaveData
		PlantSaveData:OnPlantRemoved(plantUUID, plantData.Owner)
	end
end

function FarmingService:RemoveAllPlantsFromPlot(plotModel)
	local plantsToRemove = {}
	for plantUUID, plantData in pairs(activePlants) do
		if plantData.SoilModel == plotModel then
			table.insert(plantsToRemove, plantUUID)
		end
	end

	-- Remove cada planta encontrada
	for _, plantUUID in ipairs(plantsToRemove) do
		self:RemovePlant(plantUUID)
	end
	print(`[FarmingService] Todas as ${#plantsToRemove} plantas foram removidas da plot ${plotModel.Name}.`)
end
local function FindPlanetAroundPosition(position, rayDistance, rayCount)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = CollectionService:GetTagged("planet")
	rayParams.IgnoreWater = true

	rayDistance = rayDistance or 1000
	rayCount = rayCount or 32

	local phi = math.pi * (3 - math.sqrt(5))

	for i = 0, rayCount - 1 do
		local y = 1 - (i / (rayCount - 1)) * 2
		local radius = math.sqrt(1 - y * y)
		local theta = phi * i

		local direction = Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
		local raycast = workspace:Raycast(position, direction * rayDistance, rayParams)

		if raycast and raycast.Instance then
			return raycast.Instance, raycast
		end
	end

	return nil, nil
end

function FarmingService:ValidatePlacement(player, position)
	local currentPlanet, hit = FindPlanetAroundPosition(position.Position, 5, 64)
	if not currentPlanet then return false, "NoPlanetFound" end

	local planetCenter = currentPlanet:IsA("BasePart") and currentPlanet.Position or currentPlanet:GetPivot().Position

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local ignoredObjects = {player.Character}

	local previewFolder = workspace:FindFirstChild("PreviewModels")
	if previewFolder then table.insert(ignoredObjects, previewFolder) end

	for _, obj in pairs(CollectionService:GetTagged("preview")) do
		table.insert(ignoredObjects, obj)
	end

	for _, plantData in pairs(activePlants) do
		if plantData.Model and plantData.Model.Parent then
			table.insert(ignoredObjects, plantData.Model)
		end
	end

	rayParams.FilterDescendantsInstances = ignoredObjects

	local directionOut = (position.Position - planetCenter).Unit
	local raycast = workspace:Raycast(
		position.Position + directionOut * 0.5, 
		-directionOut * 1000, 
		rayParams
	)

	if not raycast then return false, "NoGroundHit" end

	local finalRaycast = workspace:Raycast(
		getNormalCFrame(raycast).Position + raycast.Normal.Unit * 0.5,
		-raycast.Normal.Unit * 1000,
		rayParams
	)
	if not finalRaycast then return false, "NoGroundHit" end
	local model = finalRaycast.Instance:FindFirstAncestorOfClass("Model")
	if not model or not model:HasTag("plot") or not model:FindFirstChild("Plants") then
		return false, "InvalidPlot"
	end
	if model:GetAttribute("Owner") ~= player.Name then
		return false, "NotYourPlot"
	end
	if self:CountPlantsInPlot(model) >= (model:GetAttribute("MaxPlants") or 20) then
		return false, "PlotFull"
	end
	local plantingPosition = getNormalCFrame(finalRaycast).Position
	for _, plantData in pairs(activePlants) do
		if plantData.SoilModel == model and 
			(plantingPosition - plantData.Position.Position).Magnitude < 1.8 then
			return false, "TooClose"
		end
	end
	return true, finalRaycast
end

function FarmingService:ClearAllPlayerPlants(player)
	if not player then return end

	local plantsToRemove = {}
	for plantUUID, plantData in pairs(activePlants) do
		if plantData.Owner == player.Name then
			table.insert(plantsToRemove, plantUUID)
		end
	end

	if #plantsToRemove > 0 then
		print(`[FarmingService] Limpando ${#plantsToRemove} plantas para o jogador ${player.Name}...`)
		for _, plantUUID in ipairs(plantsToRemove) do
			self:RemovePlant(plantUUID)
		end
	end
end


return FarmingService