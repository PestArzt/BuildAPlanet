--[[
	Uma script feita por PesArztpedral / A script made by PestArztpedral
	
	Esse módulo foi criado com ideias partidas do módulo DataStore2, no entanto, feito do meu jeito
]]


local ServerScriptService = game:GetService("ServerScriptService").Server
local BuildingService, PlantSaveData, InventoryService, RocketService
local PetDataService
local UpdateDataRemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("UpdatePlayerData")
local UpdateDataBindableEvent = game:GetService("ServerStorage").BindableEvents.PlayerDataUpdate
local BackupModule = require(script.BackupHandler)
local Awaiter = require(script.Awaiter)
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

local consoleTriggered = false

local DataStoreCache = {}

LogService.MessageOut:Connect(function(message, messageType)
	if messageType == Enum.MessageType.MessageOutput then
		if message:match("^>") then
			consoleTriggered = true
			task.delay(0.1, function()
				consoleTriggered = false
			end)
		end
	end
end)

local SaveInStudio = true
local DataStoreMethods = {}

function DataStoreMethods:SetData(value)
	self.value = value

	if game.Players:GetPlayerByUserId(self.UserId) then
		local player = game.Players:GetPlayerByUserId(self.UserId)

		UpdateDataRemoteEvent:FireClient(player, self.Name, value)
		UpdateDataBindableEvent:Fire(player, self.Name, value)
	end	
end

function DataStoreMethods:GetFromRoot()
	if self.getFromRootJob then
		return self.getFromRootJob
	end
	self.getFromRootJob = self.DataController:Get():doNext(function(value)
		self.value = value
		self.foundValue = true
	end)

	return self.getFromRootJob
end

function DataStoreMethods:GetData(defaultValue)
	-- Se o valor já foi encontrado e está em cache
	if self.foundValue then
		return self.value
	end
	if not self.getFromRootJob then
		self:GetFromRoot() -- Inicia a tarefa assinc
	end

	local success, result = self.getFromRootJob:waitFor()

	if success == Awaiter.Situations.Succeed then
		--print(`[DataStore] Sucesso ao carregar '${self.Name}'.`)
		if self.value == nil and defaultValue ~= nil then
			self.value = defaultValue
		end
	else
		warn(`[DataStore] FALHA ao carregar '${self.Name}'. Usando valor padrão.`)
		self.value = defaultValue
	end
	self.foundValue = true

	return self.value
end


function DataStoreMethods:IncreaseData(value)
	self:SetData(self:GetData()+value)
end

function DataStoreMethods:SaveData()
	if self._saving then
		return Awaiter.run(function(success)
			success(false, "Already saving or saved")
		end)
	end
	self._saving = true

	return Awaiter.run(function(success)
		if game:GetService("RunService"):IsStudio() and not SaveInStudio then
			warn("Nothing was saved")
			self._saving = false
			success()
			return
		end

		if self.value == nil then
			warn("Nothing to save for "..self.Name)
			--warn("Nothing to save for "..self.Name.." ["..debug.traceback("", 2).."]")
			self._saving = false
			success(false, "No value")
			return
		end

		-- Se o valor já foi salvo, evitar novo save desnecessário
		--if self._lastSavedValue == self.value then
		--	self._alreadySaved = true
		--	self._saving = false
		--	success(false, "Value unchanged")
		--	return
		--end

		-- Chamada ao DataController:Set
		local result = self.DataController:Set(self.value)
		if not result then
			warn("SetAsync falhou para "..self.Name)
			self._saving = false
			success(false, "Set fail")
			return
		end

		result:doNext(function()
			print("Saved: "..self.Name.." value: "..tostring(self.value))
			self._lastSavedValue = self.value
			self._alreadySaved = true
			self._saving = false
			--if not game.Players:GetPlayerByUserId(self.UserId) then
			--	DataStoreCache[self.PlayerName] = nil
			--end
			success(true)
		end)
	end)	
end

local DataStoreMetaTable = {}
DataStoreMetaTable.__index =  DataStoreMethods

local DataStoreModule = {}

if not script:FindFirstChild("DebugTracker") then
	DataStoreModule.DebugTracker = Instance.new("BindableFunction")
	DataStoreModule.DebugTracker.Parent = script
	DataStoreModule.DebugTracker.Name = "DebugTracker"
else
	DataStoreModule.DebugTracker = script.DebugTracker
end

local function SavePlayerSequentially(player)
	if not BuildingService then
		BuildingService = require(ServerScriptService.Building.BuildingService)
		PlantSaveData = require(ServerScriptService.Building.PlantService)
		InventoryService = require(ServerScriptService.Player.InventoryService)
		RocketService = require(ServerScriptService.Planet.RocketService)
		PetDataService = require(ServerScriptService.Data.PetData)
		print("[SAVE HANDLER] Módulos de serviço carregados sob demanda.")
	end

	print(string.format("[SAVE HANDLER] Iniciando sequência de salvamento para %s...", player.Name))
	if BuildingService then
		print("[SAVE HANDLER] -> Preparando dados de construção...")
		local buildSuccess, buildError = pcall(BuildingService.SaveAllPlayerData, BuildingService, player)
		if not buildSuccess then
			warn(`[SAVE HANDLER] -> ERRO ao preparar dados de construção: ${buildError}`)
		end
	end

	if PlantSaveData then
		print("[SAVE HANDLER] -> Preparando dados de plantas...")
		local plantSuccess, plantError = pcall(PlantSaveData.UpdatePlayerPlantData, PlantSaveData, player)
		if not plantSuccess then
			warn(`[SAVE HANDLER] -> ERRO ao preparar dados de plantas: ${plantError}`)
		end
	end
	
	if PetDataService then
		print("[SAVE HANDLER] -> Preparando dados de pets...")
		local petSuccess, petError = pcall(PetDataService.PrepareForSave, PetDataService, player)
		if not petSuccess then
			warn(`[SAVE HANDLER] -> ERRO ao preparar dados de pets: ${petError}`)
		end
	end

	local saveJobs = {}
	local playerStores = DataStoreCache[player.Name]

	if playerStores then
		print("[SAVE HANDLER] -> Preparando para commitar dados no DataStore...")
		for dataStoreName, dataStore in pairs(playerStores) do
			print("    -> Adicionando job de save para a store: " .. dataStoreName)
			table.insert(saveJobs, dataStore:SaveData())
		end
	else
		warn(`[SAVE HANDLER] -> Nenhum DataStore encontrado no cache para o jogador ${player.Name}. Nada foi salvo.`)
	end


	return Awaiter.all(saveJobs)
end

function DataStoreModule.GetDataStore(player, dataStoreName)
	return DataStoreCache[player.Name] and DataStoreCache[player.Name][dataStoreName]
		or DataStoreModule.new(dataStoreName, player)
end

function DataStoreModule.new(dataStoreName, player)

	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn(string.format("DataStoreModule.new foi chamado com um argumento inválido para 'player'. Esperado: Player, Recebido: %s", typeof(player)))
		debug.traceback() --
		return nil 
	end
	if not DataStoreCache[player.Name] then
		DataStoreCache[player.Name] = {}
	end

	if DataStoreCache[player.Name][dataStoreName] then
		return DataStoreCache[player.Name][dataStoreName]
	end

	print("Creating new dataStore: "..dataStoreName.." for player "..player.Name)

	--if not DataStoreCache[player] then
	--	DataStoreCache[player] = {}
	--end

	local DataStore = {}
	DataStore.Name = dataStoreName
	DataStore.PlayerName = player.Name
	DataStore.UserId = player.UserId
	DataStore.DataController = BackupModule.new(DataStore)

	setmetatable(DataStore, DataStoreMetaTable)

	if not DataStoreCache[player.Name] then DataStoreCache[player.Name] = {} end

	DataStoreCache[player.Name][dataStoreName] = DataStore

	local saving = false
	return DataStore
	--end
end

local playersBeingSaved = {}
local function SaveAllPlayerData(player)
	if playersBeingSaved[player.UserId] then
		print(`[SAVE HANDLER] Salvamento para ${player.Name} já está em andamento. Chamada duplicada ignorada.`)
		return
	end
	playersBeingSaved[player.UserId] = true
	print(`[SAVE HANDLER] Iniciando processo de salvamento e limpeza para ${player.Name}... Bloqueio ativado.`)

	local saveJob = SavePlayerSequentially(player)


	saveJob:doNext(function()
		print(`[SAVE HANDLER] Salvamento para ${player.Name} bem-sucedido. Iniciando limpeza de cache e objetos.`)
		if BuildingService then
			BuildingService:ClearPlayerObjects(player) 
		end
		if PlantSaveData then
			PlantSaveData:ClearCacheForPlayer(player) 
		end
		if RocketService then
			RocketService:ClearPlayerPlanetOwnership(player)
		end
		if DataStoreCache[player.Name] then
			DataStoreCache[player.Name] = nil
			print(`[CACHE] Cache de dados para ${player.Name} foi limpo.`)
		end
	end)

	
	saveJob:ending(function()
		playersBeingSaved[player.UserId] = nil
		--print(`[SAVE HANDLER] Processo para ${player.Name} finalizado. Bloqueio liberado.`)
	end)

	
	return saveJob
end


game.Players.PlayerRemoving:Connect(function(player)
	SaveAllPlayerData(player)
end)
game:BindToClose(function()
	if RunService:IsStudio() and not SaveInStudio then return end 

	print("[SAVE HANDLER] BindToClose ativado. Salvando todos os jogadores restantes...")

	local finalSaveJobs = {}
	local playersToSave = game.Players:GetPlayers()

	for _, player in ipairs(playersToSave) do
		
		local job = SaveAllPlayerData(player)
		if job then
			table.insert(finalSaveJobs, job)
		end
	end

	if #finalSaveJobs > 0 then
		print(`[BindToClose] Esperando ${#finalSaveJobs} jogadores terminarem de salvar...`)
		local success, result = Awaiter.all(finalSaveJobs):waitFor()

		if success == Awaiter.Situations.Succeed then
			print("[BindToClose] Todos os jogadores foram salvos com sucesso!")
		else
			warn("[BindToClose] Ocorreu um erro durante o salvamento final: " .. tostring(result))
		end
	end

	print("[SAVE HANDLER] Desligamento concluído após salvar todos os jogadores.")
end)



local function SavePlayerData_Periodic(player)
	if playersBeingSaved[player.UserId .. "_autosave"] then
		return
	end
	playersBeingSaved[player.UserId .. "_autosave"] = true
	print(`[AutoSave] Iniciando salvamento periódico para ${player.Name}...`)

	local saveJob = SavePlayerSequentially(player)
	saveJob:ending(function()
		print(`[AutoSave] Salvamento periódico para ${player.Name} concluído.`)
		playersBeingSaved[player.UserId .. "_autosave"] = nil
	end)

	return saveJob
end

local AUTO_SAVE_INTERVAL = 60 

coroutine.wrap(function()
	while task.wait(AUTO_SAVE_INTERVAL) do
		local playersToSave = game.Players:GetPlayers()

		if #playersToSave > 0 then
			print(`[AutoSave] Disparando salvamento periódico para ${#playersToSave} jogadores...`)

			for _, player in ipairs(playersToSave) do
				task.spawn(function()
					local success, err = pcall(function()
						SavePlayerData_Periodic(player)
					end)

					if not success then
						warn(`[AutoSave] Falha ao iniciar auto-save para ${player.Name}: ${tostring(err)}`)
					end
				end)
			end
		end
	end
end)()


return setmetatable(DataStoreModule, DataStoreModule)
