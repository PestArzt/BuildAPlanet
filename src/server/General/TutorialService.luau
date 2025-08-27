local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService").Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Módulos e Serviços
local DataStoreModule = require(ServerScriptService.DataStoreModule)
local TutorialData = require(ReplicatedStorage.Modules.TutorialData)
local LeaderstatsService = require(ServerScriptService.Player.LeaderStatsService)
local InventoryService = require(ServerScriptService.Player.InventoryService)

-- Eventos
local TutorialEvent = ReplicatedStorage.RemoteEvents.TutorialRemotes.TutorialEvent
--local TutorialFunction = ReplicatedStorage.RemoteFunctions.TutorialFunc.TutorialFunction
local TutorialProgressEvent = ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent
local NotifyPlayerEvent = ReplicatedStorage.RemoteEvents.Shop:WaitForChild("NotifyPlayer")

local playerProgressCache = {}
local DATASTORE_NAME = "TutorialProgress_V5" 

local TutorialService = {}

function TutorialService:SetPlayerState(player, newState)
	local playerProgress = playerProgressCache[player.UserId]
	if not playerProgress or playerProgress.State == newState then return end

	print(`[TutorialService] Jogador ${player.Name} avançando de ${playerProgress.State} para ${newState}`)

	playerProgress.State = newState
	playerProgress.Progress = 0
	local config = TutorialData:GetConfigForState(newState)
	local progressData = {
		State = newState,
		Current = 0,
		Required = config and config.RequiredCount or 0,
	}

	TutorialEvent:FireClient(player, progressData)
end

-- Lida com a interação com NPCs do tutorial
function TutorialService:HandleNpcInteraction(player, npc)
	local playerProgress = playerProgressCache[player.UserId]
	if not playerProgress then return end
	if npc.Name ~= "NpcTutorial" then return end -- Só reage ao NPC do Guia

	local currentState = playerProgress.State

	-- Interação inicial
	if currentState == TutorialData.STATES.GO_TO_NPC then
		self:SetPlayerState(player, TutorialData.STATES.GO_BUY_SEED)

		-- Interação após a primeira parte (plantio)
	elseif currentState == TutorialData.STATES.FINISH_FARMING_QUEST then
		self:GiveFarmingQuestRewards(player) 
		self:SetPlayerState(player, TutorialData.STATES.BUY_DECORATION) 

		-- Interação final para completar todo o tutorial
	elseif currentState == TutorialData.STATES.FINISH_TUTORIAL_FINAL then
		self:GiveFinalTutorialRewards(player)
		self:SetPlayerState(player, TutorialData.STATES.COMPLETED)
		NotifyPlayerEvent:FireClient(player, "🎉 Tutorial Completed!", nil, Color3.fromRGB(255, 215, 0))
	end
end

-- Lida com a conclusão de tarefas baseadas em contagem (ex: comprar, plantar)
function TutorialService:UpdateProgress(player)
	local playerProgress = playerProgressCache[player.UserId]
	local config = TutorialData:GetConfigForState(playerProgress.State)
	if not config or not config.RequiredCount then return end

	playerProgress.Progress += 1
	local progressData = {
		State = playerProgress.State,
		Current = playerProgress.Progress,
		Required = config.RequiredCount,
	}
	TutorialEvent:FireClient(player, progressData) 

	if playerProgress.Progress >= config.RequiredCount then
		local currentState = playerProgress.State
		if currentState == TutorialData.STATES.GO_BUY_SEED then 
			InventoryService:Add(player, { Name = "CubePlot", Category = "Farming", Quantity = 3, Stackable = true , Locked = false })
			NotifyPlayerEvent:FireClient(player, "You received", {"3x CubePlot"}, Color3.fromRGB(118, 212, 122)) 
			self:SetPlayerState(player, TutorialData.STATES.GO_TO_PLANET)
		elseif currentState == TutorialData.STATES.PLACE_PLOTS then 
			self:SetPlayerState(player, TutorialData.STATES.PLANT_SEEDS)
		elseif currentState == TutorialData.STATES.PLANT_SEEDS then
			self:SetPlayerState(player, TutorialData.STATES.RETURN_TO_LOBBY)
		elseif currentState == TutorialData.STATES.BUY_DECORATION then
			self:SetPlayerState(player, TutorialData.STATES.GO_TO_PLANET_FOR_DECO)
		elseif currentState == TutorialData.STATES.PLACE_DECORATION then
			self:SetPlayerState(player, TutorialData.STATES.RETURN_TO_LOBBY_FINAL)
		end
	end
end

-- Recompensas
function TutorialService:GiveFarmingQuestRewards(player)
	LeaderstatsService:IncrementPlayerStat(player, "Money", 1000)
	print(`[TutorialService] Recompensa da missão de fazenda entregue para ${player.Name}`)
end

function TutorialService:GiveFinalTutorialRewards(player)
	local rewardItem = { Name = "LuckyBlock", Category = "Crates", Stackable = true, Quantity = 1, Locked = false }
	InventoryService:Add(player, rewardItem)
	--print(`[TutorialService] Recompensa final do tutorial entregue para ${player.Name}`)
end

function TutorialService:SetupPlayerTutorial(player)
	local dataStore = DataStoreModule.GetDataStore(player, DATASTORE_NAME)
	local savedData = dataStore:GetData({ State = TutorialData.STATES.NOT_STARTED, Progress = 0 })

	playerProgressCache[player.UserId] = savedData

	if savedData.State == TutorialData.STATES.NOT_STARTED then
		savedData.State = TutorialData.STATES.GO_TO_NPC 
	end

	if savedData.State ~= TutorialData.STATES.COMPLETED and savedData.State ~= TutorialData.STATES.SKIPPED then
		local config = TutorialData:GetConfigForState(savedData.State)
		local progressData = {
			State = savedData.State,
			Current = savedData.Progress or 0,
			Required = config and config.RequiredCount or 0
		}
		TutorialEvent:FireClient(player, progressData)
	else
		TutorialEvent:FireClient(player, { State = savedData.State })
	end
end

function TutorialService:TeardownPlayerTutorial(player)
	if playerProgressCache[player.UserId] then
		--print(`[TutorialService] Salvando dados e limpando cache para ${player.Name}`)
		local dataStore = DataStoreModule.GetDataStore(player, DATASTORE_NAME)
		dataStore:SetData(playerProgressCache[player.UserId])
		playerProgressCache[player.UserId] = nil
	end
end

-- ==================== INICIALIZAÇÃO E EVENTOS ====================
function TutorialService:Initialize()
	TutorialProgressEvent.Event:Connect(function(player, eventType, ...)
		local args = {...}
		local playerProgress = playerProgressCache[player.UserId]
		if not playerProgress then return end

		local currentState = playerProgress.State

		if eventType == "ItemPurchased" then
			local category = args[1]
			if (category == "Seeds" or category == "Eggs") and currentState == TutorialData.STATES.GO_BUY_SEED then
				self:UpdateProgress(player)
			elseif category == "Decoration" and currentState == TutorialData.STATES.BUY_DECORATION then
				self:UpdateProgress(player)
			end
		elseif eventType == "ArrivedAtPlanet" then
			if currentState == TutorialData.STATES.GO_TO_PLANET then
				self:SetPlayerState(player, TutorialData.STATES.PLACE_PLOTS) 
			elseif currentState == TutorialData.STATES.GO_TO_PLANET_FOR_DECO then
				self:SetPlayerState(player, TutorialData.STATES.PLACE_DECORATION)
			end
		elseif eventType == "PlotPlaced" and currentState == TutorialData.STATES.PLACE_PLOTS then 
			self:UpdateProgress(player)
		elseif eventType == "PlantPlaced" and currentState == TutorialData.STATES.PLANT_SEEDS then
			self:UpdateProgress(player)
		elseif eventType == "DecorationPlaced" and currentState == TutorialData.STATES.PLACE_DECORATION then
			self:UpdateProgress(player)
		elseif eventType == "ArrivedAtLobby" then
			if currentState == TutorialData.STATES.RETURN_TO_LOBBY then
				self:SetPlayerState(player, TutorialData.STATES.FINISH_FARMING_QUEST)
			elseif currentState == TutorialData.STATES.RETURN_TO_LOBBY_FINAL then
				self:SetPlayerState(player, TutorialData.STATES.FINISH_TUTORIAL_FINAL)
			end
		end
	end)


	Workspace.Quests.NpcTutorial.QuestTrigger.ProximityPrompt.Triggered:Connect(function(player)
		self:HandleNpcInteraction(player, Workspace.Quests.NpcTutorial)
	end)

	Players.PlayerAdded:Connect(function(player) self:SetupPlayerTutorial(player) end)
	Players.PlayerRemoving:Connect(function(player) self:TeardownPlayerTutorial(player) end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:SetupPlayerTutorial(player) end)
	end
end

return TutorialService