-- Sistema de Leaderstats integrado com o sistema de Farming 
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
-- DataStore para salvar dados dos jogadores
local DataStoreModule = require(game:GetService("ServerScriptService").Server.DataStoreModule)
local UpdateDataBindableEvent = game:GetService("ServerStorage").BindableEvents.PlayerDataUpdate
local AddBattlePassXPEvent = ServerStorage.BindableEvents.AddBattlePassXP
local MoneyNotificationRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild("MoneyNotification")
local XPUpdateRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild("Level"):WaitForChild("XPUpdate")
local GetXPInfoRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild("Level"):WaitForChild("GetXPInfo")
local LevelUpRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild('Level'):WaitForChild("LevelUp")
local XPNotificationRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild("XPNotification")
local CratePointsUpdateRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild("CratePointsUpdate")
local CratePointsNotificationRemote = ReplicatedStorage:WaitForChild('RemoteEvents'):WaitForChild("CratePointsNotification")

local LeaderstatsService = {}

-- Cache para dados dos jogadores 
local playerDataCache = {}

--// =============================================================================
--// CONFIGURAÇÕES PADRÃO
--// =============================================================================

LeaderstatsService.DefaultData = {
	Money = 50,        -- Dinheiro inicial
	FarmingLevel = 1,   -- Nível de farming inicial
	FarmingXP = 0,      -- Experiência de farming
	PlantsHarvested = 0, -- Total de plantas colhidas
	SeedsPlanted = 0,   -- Total de sementes plantadas
	TimePlayed = 0,     -- Tempo jogado em segundos
	CratePoints = 0, -- Pontos para abrir caixas
	LastSaveTime = 0,   -- Timestamp do último save
	LastJoinedTime = 0, -- Timestamp da última vez que entrou
	FirstJoinDate = 0,  -- Data da primeira vez que o jogador entrou
}

function LeaderstatsService:CalculateXPForLevel(level)
	local calc = 250 * (level - 1) * 2  
	return (calc > 0) and calc or 50
end

function LeaderstatsService:GetFarmingLevel(player)
	if not player then return 1 end
	return self:GetPlayerStat(player, "FarmingLevel") or 1
end

function LeaderstatsService:GetFarmingXP(player)
	if not player then return 0 end
	return self:GetPlayerStat(player, "FarmingXP") or 0
end

function LeaderstatsService:FireXPUpdate(player)
	if not player then return end

	local currentXP = self:GetPlayerStat(player, "FarmingXP")
	local levelInfo = self:CalculateLevelInfoFromXP(currentXP)

	XPUpdateRemote:FireClient(player, {
		currentLevel = levelInfo.level,
		currentXP = currentXP, -- XP total 
		currentXPInLevel = levelInfo.xpInLevel,
		maxXPForCurrentLevel = levelInfo.xpForLevel,
		progress = levelInfo.progress
	})
end

--// =============================================================================
--// SISTEMA DE LEADERSTATS
--// =============================================================================

function CheckUpdates(Table)
	for cat, _ in pairs(LeaderstatsService.DefaultData) do
		if not Table[cat] then
			Table[cat] = 0
		end
	end

	for cat, _ in pairs(Table) do
		if not LeaderstatsService.DefaultData[cat] then   
			Table[cat] = nil
		end
	end

	return Table
end

--// =============================================================================
--// CONEXÕES DE EVENTOS
--// =============================================================================

function LeaderstatsService:Initialize()

	-- Quando jogador entra
	Players.PlayerAdded:Connect(function(player)
		-- Criar leaderstats primeiro
		local leaderstats = self:CreateLeaderStats(player)
		if self:GetPlayerStat(player, "FirstJoinDate") == 0 then
			self:SetPlayerStat(player, "FirstJoinDate", os.date())
		end
		local playerStatsDataStore = DataStoreModule.GetDataStore(player, "PlayerStats-v0")
		UpdateDataBindableEvent.Event:Connect(function(plr, dataStore, value)
			if plr == player and dataStore == "PlayerStats-v0" then
				self:UpdateLeaderStats(player)
			end
		end)

		task.wait(1)
		self:FireXPUpdate(player)
		local initialPoints = self:GetPlayerStat(player, "CratePoints") or 0
		CratePointsUpdateRemote:FireClient(player, initialPoints)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:SetPlayerStat(player, "LastSaveTime", os.time())
	end)
	

	task.spawn(function()
		while task.wait(300) do
			-- Salvar automaticamente todos os jogadores
			print("[SERVER] AUTOSAVING ALL PLAYER STATS")
			for _, player in pairs(Players:GetPlayers()) do
				if player and player.Parent then
					self:SavePlayerStats(player)
					self:SetPlayerStat(player, "LastSaveTime", os.time())
				end
			end
		end
	end)

	-- Contador de tempo jogado
	task.spawn(function()
		while task.wait(1) do
			for _, player in pairs(Players:GetPlayers()) do
				if player and player.Parent then
					self:IncrementPlayerStat(player, "TimePlayed", 1)
				end
			end
		end
	end)

	--print("✅ LeaderstatsService inicializado com sucesso!")
	GetXPInfoRemote.OnServerEvent:Connect(function(player)
		self:FireXPUpdate(player)
	end)

end

function LeaderstatsService:CreateLeaderStats(player)
	
	local PlayerStats = CheckUpdates(DataStoreModule.GetDataStore(player, "PlayerStats-v0"):GetData(self.DefaultData))
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Dinheiro
	local money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Value = PlayerStats.Money
	money.Parent = leaderstats

	-- Nível de Farming
	local farmingLevel = Instance.new("NumberValue")
	farmingLevel.Name = "Farming Level"
	farmingLevel.Value = PlayerStats.FarmingLevel
	farmingLevel.Parent = leaderstats

	local cratePoints = Instance.new("NumberValue")
	cratePoints.Name = "Crate Points" 
	cratePoints.Value = PlayerStats.CratePoints
	cratePoints.Parent = player 

	
	return leaderstats
end

function LeaderstatsService:UpdateLeaderStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false
	end
	leaderstats["Money"].Value = self:GetPlayerStat(player, "Money")
	leaderstats["Farming Level"].Value = self:GetPlayerStat(player, "FarmingLevel")
	
	local cratePointsStat = player:FindFirstChild("Crate Points")
	if cratePointsStat then
		cratePointsStat.Value = self:GetPlayerStat(player, "CratePoints")
	end

	
	return true
end

--// =============================================================================
--// SISTEMA DE EXPERIÊNCIA E NÍVEL
--// =============================================================================
function LeaderstatsService:FireLevelUp(player, oldLevel, newLevel, levelReward)
	if not player then return end
	
	-- Enviar dados do level up para o cliente
	LevelUpRemote:FireClient(player, {
		oldLevel = oldLevel,
		newLevel = newLevel,
		levelReward = levelReward,
		timestamp = os.time()
	})
	
	print(string.format("🎉 %s ➡️ %d! (Recompensa: %d moedas)", 
		player.Name, newLevel, levelReward))
end

function LeaderstatsService:LevelUp(player, newLevel)
	if not player then return end

	local oldLevel = self:GetPlayerStat(player, "FarmingLevel")
	self:SetPlayerStat(player, "FarmingLevel", newLevel)

	-- Recompensa por subir de nível
	local levelReward = newLevel * 5 -- 50 moedas por nível
	self:IncrementPlayerStat(player, "Money", levelReward)


	-- Atualizar cliente com novos dados de XP
	self:FireXPUpdate(player)
	
	 self:FireLevelUp(player, oldLevel, newLevel, levelReward)
end

function LeaderstatsService:CheckFarmingLevel(player)
	if not player then return false end

	local currentXP = self:GetPlayerStat(player, "FarmingXP")
	local currentLevel = self:GetPlayerStat(player, "FarmingLevel")

	local levelInfo = self:CalculateLevelInfoFromXP(currentXP)

	-- Verificar se subiu de nível
	if levelInfo.level > currentLevel then
		self:LevelUp(player, levelInfo.level)
	end
end

function LeaderstatsService:CalculateLevelInfoFromXP(xp)
	local level = 1
	local totalXPAtLevelStart = 0
	while true do
		local xpNeededForThisLevel = self:CalculateXPForLevel(level + 1)

		-- Verifica se o jogador já passou deste nível
		if totalXPAtLevelStart + xpNeededForThisLevel <= xp then
			totalXPAtLevelStart = totalXPAtLevelStart + xpNeededForThisLevel
			level = level + 1
		else
			-- O jogador está neste nível. Retorna as informações.
			local xpInCurrentLevel = xp - totalXPAtLevelStart
			local progress = xpInCurrentLevel / xpNeededForThisLevel

			return {
				level = level,
				xpInLevel = xpInCurrentLevel,
				xpForLevel = xpNeededForThisLevel,
				progress = progress
			}
		end
	end
end
--// =============================================================================
--// ESTATÍSTICAS GERAIS
--// =============================================================================

-- Sistema para estatísticas extras
function LeaderstatsService:GetPlayerStat(player, statName)
	if not player then return end
	
	local PlayerStats = DataStoreModule.GetDataStore(player, "PlayerStats-v0")
	local CurrentStats = PlayerStats:GetData()
	
	if not CurrentStats[statName] then return end

	return CurrentStats[statName]
end

function LeaderstatsService:SetPlayerStat(player, statName, value)
	if not player then return end

	local PlayerStats = DataStoreModule.GetDataStore(player, "PlayerStats-v0")
	local CurrentStats = PlayerStats:GetData()

	if not CurrentStats[statName] then  print("DEBUG: SetPlayerStat exiting early! Stat not found:", statName) return end

	if typeof(CurrentStats[statName]) == "string" then
		CurrentStats[statName] = tostring(value)
	elseif typeof(CurrentStats[statName]) == "number" then
		CurrentStats[statName] = tonumber(value)
	else
		CurrentStats[statName] = value
	end

	if statName == "FarmingXP" then
		self:CheckFarmingLevel(player)
		-- Atualizar cliente com novos dados de XP
		self:FireXPUpdate(player)
	end	

	if statName == "CratePoints" then
		CratePointsUpdateRemote:FireClient(player, value)
	end
	
	
	PlayerStats:SetData(CurrentStats)
	UpdateDataBindableEvent:Fire(player, "PlayerStats-v0", CurrentStats)
end
function LeaderstatsService:IncrementPlayerStat(player, statName, amount)
	if not player then return end

	if typeof(self:GetPlayerStat(player, statName)) == "number" then
		local oldValue = self:GetPlayerStat(player, statName)
		local newValue = oldValue + (tonumber(amount) or 1)
		self:SetPlayerStat(player, statName, newValue) 

		if statName == "Money" and amount > 0 then
			MoneyNotificationRemote:FireClient(player, amount)
		end

		if statName == "FarmingXP" and amount > 0 then
			XPNotificationRemote:FireClient(player, amount)
			AddBattlePassXPEvent:Fire(player, amount)
		end
		
		if statName == "CratePoints" and amount > 0 then
			CratePointsNotificationRemote:FireClient(player, amount)
		end
		
	else
		warn("The format you are trying to increase is not valid")
		return "NotAValidType"
	end
end
function LeaderstatsService:SavePlayerStats(player)
	local PlayerStats = DataStoreModule.GetDataStore(player, "PlayerStats-v0")
	local CurrentStats = PlayerStats:GetData()
	
	PlayerStats:SaveData()	
end

-- Exportar para uso global
_G.LeaderstatsService = LeaderstatsService

return LeaderstatsService