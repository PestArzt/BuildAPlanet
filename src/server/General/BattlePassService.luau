local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService").Server

-- Módulos e Remotes
local ItemData = require(ServerScriptService.Data.ItemData)
local InventoryService = require(ServerScriptService.Player.InventoryService)
local DataStoreModule = require(ServerScriptService.DataStoreModule)
local BattlePassConfig = require(ReplicatedStorage.Modules.BattlePassConfig) 
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")


local LeaderstatsService = require(ServerScriptService.Player.LeaderStatsService)

local Remotes = ReplicatedStorage.RemoteEvents.BattlePass
local ClaimRewardRemote = Remotes.BattlePassClaimReward
local UpdateClientRemote = Remotes.BattlePassUpdateClient
local GetConfigRemote = Remotes.GetBattlePassConfig 

local AddBattlePassXPEvent = ServerStorage.BindableEvents.AddBattlePassXP


local preparedConfig = nil


local BattlePassServiceModule = {} 


local function PrepareConfigForClient()
	if preparedConfig then return preparedConfig end 

	local configCopy = {}
	configCopy.XPPerLevel = BattlePassConfig.XPPerLevel
	configCopy.MAX_LEVEL = BattlePassConfig.MAX_LEVEL
	configCopy.Rewards = table.clone(BattlePassConfig.Rewards)

	for level, rewardData in pairs(configCopy.Rewards) do
		for _, trackData in pairs(rewardData) do
			if trackData.Type == "Item" then 
				local item = ItemData:GetItem(trackData.Category, trackData.Name)
				if item then
					if not trackData.Icon and item.ImageId then
						trackData.Icon = item.ImageId
					end
					trackData.Rarity = item.Rarity 
				else
					if not trackData.Icon then trackData.Icon = "" end
					warn(`[BattlePass] Item não encontrado em ItemData: ${trackData.Name}`)
				end
			end
		end
	end

	preparedConfig = configCopy
	return preparedConfig
end



GetConfigRemote.OnServerInvoke = function(player)
	--print(`[BattlePass] Enviando configuração preparada para ${player.Name}`)
	return PrepareConfigForClient()
end

-- =============================================================================
-- LÓGICA DE DADOS 
-- =============================================================================
local function GetPlayerData(player)
	local bpDataStore = DataStoreModule.GetDataStore(player, "BattlePassData-v1")
	local bpData = bpDataStore:GetData({
		HasVIP = false,
		ClaimedFree = {},
		ClaimedVip = {},
		XP = 0, 
	})

	if bpData.HasVIP then
		return bpData
	end
	local success, hasVipGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1332959477)
	end)

	if success and hasVipGamepass then
		bpData.HasVIP = true
	
	elseif not success then
		warn(`[BattlePass] Erro ao verificar gamepass para ${player.Name}: ${hasVipGamepass}`)
	end
	return bpData
end
BattlePassServiceModule.GetPlayerData = GetPlayerData 

local function SavePlayerData(player, data)
	local dataToSave = {
		HasVIP = data.HasVIP,
		ClaimedFree = data.ClaimedFree,
		ClaimedVip = data.ClaimedVip,
		XP = data.XP, 
	}

	local bpDataStore = DataStoreModule.GetDataStore(player, "BattlePassData-v1")
	bpDataStore:SetData(dataToSave)
	bpDataStore:SaveData()
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if gamePassId == 1332959477 and wasPurchased then
		print(`[BattlePass] ${player.Name} comprou a gamepass VIP!`)
		local playerData = GetPlayerData(player)
		playerData.HasVIP = true
		SavePlayerData(player, playerData)
		UpdateClientRemote:FireClient(player, playerData)
	end
end)

function BattlePassServiceModule:ResetPlayerData(playerIdentifier)
	local name, userId
	local playerObject = nil

	if typeof(playerIdentifier) == "Instance" and playerIdentifier:IsA("Player") then
		playerObject = playerIdentifier
		name = playerIdentifier.Name
		userId = playerIdentifier.UserId
	elseif typeof(playerIdentifier) == "string" then
		name = playerIdentifier
		playerObject = Players:FindFirstChild(playerIdentifier)
		if playerObject then
			userId = playerObject.UserId
		else
			local success, result = pcall(function()
				userId = Players:GetUserIdFromNameAsync(playerIdentifier)
			end)
			if not success or not userId then
				warn(`[BattlePass] Não foi possível encontrar UserId para o jogador: ${playerIdentifier} (erro: ${result or "não encontrado"})`)
				return "Erro: Jogador não encontrado ou UserId inválido."
			end
		end
	else
		warn("[BattlePass] Tipo de identificador de jogador inválido para ResetPlayerData:", typeof(playerIdentifier))
		return "Erro: Identificador de jogador inválido."
	end

	if not userId then
		return "Erro: Não foi possível identificar o jogador."
	end
	local bpDataStore = DataStoreModule.GetDataStore({Name = name, UserId = userId}, "BattlePassData-v1")
	local defaultBattlePassData = {
		HasVIP = false,
		ClaimedFree = {},
		ClaimedVip = {},
		XP = 0, 
	}
	bpDataStore:SetData(defaultBattlePassData)
	bpDataStore:SaveData() 
	if playerObject then
		UpdateClientRemote:FireClient(playerObject, GetPlayerData(playerObject))
	end

	return "Sucesso"
end



local function GiveReward(player, rewardData)
	if rewardData.Type == "Item" then
		local itemMasterData = ItemData:GetItem(rewardData.Category, rewardData.Name)
		if not itemMasterData then
			warn(`[BattlePass] Item "${rewardData.Name}" não encontrado no ItemData!`)
			return
		end
		InventoryService:Add(player, {
			Name = rewardData.Name, Category = rewardData.Category,
			Stackable = itemMasterData.Stackable, Quantity = rewardData.Amount,
			Locked = false 
		})
		print(`[BattlePass] Deu item: ${rewardData.Amount}x ${rewardData.Name} para ${player.Name}`)

	elseif rewardData.Type == "Currency" then
		LeaderstatsService:IncrementPlayerStat(player, rewardData.Name, rewardData.Amount)
		print(`[BattlePass] Deu moeda: ${rewardData.Amount} de ${rewardData.Name} para ${player.Name}`)
	end
end

-- =============================================================================
-- EVENTOS
-- =============================================================================
ClaimRewardRemote.OnServerEvent:Connect(function(player, level, isVip)
	local playerData = GetPlayerData(player) 
	local levelInfo = BattlePassConfig:GetLevelInfo(playerData.XP)

	-- Validações
	if level > levelInfo.Level then
		warn(`[BattlePass] ${player.Name} tentou resgatar recompensa do nível ${level} sem ter XP suficiente.`)
		return
	end
	if isVip and not playerData.HasVIP then
		warn(`[BattlePass] ${player.Name} tentou resgatar recompensa VIP sem ter o passe.`)
		return
	end

	local rewardTable = BattlePassConfig.Rewards[level][isVip and "Vip" or "Free"]
	local claimedTable = isVip and playerData.ClaimedVip or playerData.ClaimedFree

	if table.find(claimedTable, level) then
		warn(`[BattlePass] ${player.Name} tentou resgatar uma recompensa já resgatada.`)
		return
	end

	GiveReward(player, rewardTable)
	table.insert(claimedTable, level)
	SavePlayerData(player, playerData) 
	UpdateClientRemote:FireClient(player, GetPlayerData(player))
end)

AddBattlePassXPEvent.Event:Connect(function(player, amount)
	if not player or not player:IsA("Player") then return end

	local bpData = GetPlayerData(player)
	bpData.XP = (bpData.XP or 0) + amount
	SavePlayerData(player, bpData)

	--print(`[BattlePass] ${player.Name} ganhou ${amount} BP XP. Total: ${bpData.XP}`)
	UpdateClientRemote:FireClient(player, bpData) 
end)



Players.PlayerAdded:Connect(function(player)
	task.wait(2) 
	local playerData = GetPlayerData(player)
	UpdateClientRemote:FireClient(player, playerData)
end)



-- Inicia a preparação da config no startup do servidor
PrepareConfigForClient()
--print("✅ BattlePassService integrado e inicializado com sucesso!")
return BattlePassServiceModule