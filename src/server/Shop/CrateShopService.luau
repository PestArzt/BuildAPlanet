local CrateShopService = {}

local PlayersService      = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService").Server

--// Módulos requeridos
local ItemData = require(ServerScriptService.Data.ItemData) 
local CrateData = require(ServerScriptService.Data.CrateData) 
local InventoryService = require(ServerScriptService.Player.InventoryService)

local StateHandler = require(ServerScriptService.General.StateHandler) 
local LeaderstatsService = require(ServerScriptService.Player.LeaderStatsService)

--// Remotes
local RemoteEvent  = game.ReplicatedStorage.RemoteEvents.CrateOpening
local RemoteFunction = game.ReplicatedStorage.RemoteFunctions
local CrateRE = RemoteEvent:WaitForChild("CharacterRE") 
local GetShopDataRF = RemoteFunction:WaitForChild("GetShopData")
local ClaimRewardRE = RemoteEvent:WaitForChild("ClaimRewardRE") 

--// Variáveis locais
local pendingRewards = {}

--// Função para escolher recompensa da loot table baseada no peso
local function chooseRewardFromLootTable(lootTable)
	local totalWeight = 0
	for _, item in ipairs(lootTable) do
		totalWeight += item.Weight
	end
	if totalWeight == 0 then return nil end

	local randomNumber = math.random(1, totalWeight)
	local currentWeight = 0

	for i, item in ipairs(lootTable) do
		currentWeight += item.Weight
		if randomNumber <= currentWeight then
			return item, i
		end
	end
end

--// Função para obter dados da loja para o cliente 
local function onGetShopData(player)
	--print("Servidor: Enviando dados da loja para " .. player.Name)
	local clientSafeData = {}
	for crateKey, crateInfo in pairs(CrateData) do
		if crateInfo.IsMasterCrate then 
			local masterCrateItemData = ItemData:GetItem(crateInfo.ItemCategory, crateInfo.ItemName)

			if masterCrateItemData then
				local rewardsForClient = {}
				local totalWeight = 0
				for _, rewardCrate in ipairs(crateInfo.LootTable) do
					totalWeight = totalWeight + rewardCrate.Weight
				end

				for _, rewardCrate in ipairs(crateInfo.LootTable) do
					local item = ItemData:GetItem(rewardCrate.Category, rewardCrate.Name)
					if item then
						table.insert(rewardsForClient, {
							Name = item.Name,
							ImageId = item.ImageId,
							Rarity = item.Rarity or "Common",
							Chance = math.floor((rewardCrate.Weight / totalWeight) * 100) 
						})
					end
				end
				clientSafeData[crateKey] = {
					DisplayName = crateInfo.DisplayName,
					PointsNeed = crateInfo.PointsNeed,
					ImageId = masterCrateItemData.ImageId,
					LootTable = rewardsForClient 
				}
			end
		end
	end
	return clientSafeData
end

--// Lógica para abrir caixa e definir recompensa pendente 
local function onCrateEvent(player, instruction, value)
	if instruction == "Open Crate" then
		if StateHandler:GetState(player, "OpeningCrate") then
			warn(player.Name .. " tentou girar uma nova caixa com uma operação já em andamento.")
			return
		end

		local crateInfo = CrateData[value]
		if not crateInfo or not crateInfo.IsMasterCrate then return warn("Tentativa de abrir uma caixa inválida ou não-mestra.") end

		local pointsNeeded = crateInfo.PointsNeed
		local playerPoints = LeaderstatsService:GetPlayerStat(player, "CratePoints")

		if not (playerPoints and playerPoints >= pointsNeeded) then
			CrateRE:FireClient(player, "Purchase Failed", "Insufficient Points", pointsNeeded, playerPoints or 0)
			return
		end  

		StateHandler:SetState(player, "OpeningCrate", true)
		LeaderstatsService:IncrementPlayerStat(player, "CratePoints", -pointsNeeded) 

		local success, err = pcall(function()
			local chosenReward, chosenIndex = chooseRewardFromLootTable(crateInfo.LootTable)

			if not chosenReward then
				error("Não foi possível escolher uma recompensa da loot table para a caixa: " .. value)
			end

			pendingRewards[player.UserId] = chosenReward
			print(player.Name .. " rolou e a recompensa pendente é: " .. chosenReward.Name)
			CrateRE:FireClient(player, "Open Crate", value, chosenReward.Name)
		end)
		if not success then
			warn("ERRO CRÍTICO durante a abertura da caixa para " .. player.Name .. ": " .. tostring(err))
			LeaderstatsService:IncrementPlayerStat(player, "CratePoints", pointsNeeded) 
			print("Pontos ("..pointsNeeded..") devolvidos para " .. player.Name .. " devido a um erro.")
			pendingRewards[player.UserId] = nil
			StateHandler:RemoveStates(player, "OpeningCrate")
		end
	end
end

--// Lógica para coletar recompensa pendente 
local function onClaimReward(player)
	local rewardToClaim = pendingRewards[player.UserId]

	if rewardToClaim then
		local itemMasterData = ItemData:GetItem(rewardToClaim.Category, rewardToClaim.Name)
		if itemMasterData then
			print(player.Name .. " coletou a recompensa: " .. itemMasterData.Name)
			InventoryService:Add(player, {
				Name = itemMasterData.Name,
				Category = itemMasterData.Category,
				Stackable = itemMasterData.Stackable,
				Quantity = 1,
				Locked = false
			})

			pendingRewards[player.UserId] = nil
			StateHandler:RemoveStates(player, "OpeningCrate")
		end
	else
		warn(player.Name .. " tentou coletar uma recompensa que não existe.")
		StateHandler:RemoveStates(player, "OpeningCrate")
	end
end

--// Proteção contra desconexão 
local function onPlayerRemoving(player)
	local rewardToGive = pendingRewards[player.UserId]

	if rewardToGive then
		local itemMasterData = ItemData:GetItem(rewardToGive.Category, rewardToGive.Name)
		if itemMasterData then
			print("Dando recompensa pendente para " .. player.Name .. " ao sair: " .. itemMasterData.Name)
			InventoryService:Add(player, {
				Name = itemMasterData.Name,
				Category = itemMasterData.Category,
				Stackable = itemMasterData.Stackable,
				Quantity = 1,
				Locked = false
			})

			pendingRewards[player.UserId] = nil
		end
	end
end

--// Função de init do module
function CrateShopService:Initialize()
	-- Events Connections
	GetShopDataRF.OnServerInvoke = onGetShopData
	CrateRE.OnServerEvent:Connect(onCrateEvent)
	ClaimRewardRE.OnServerEvent:Connect(onClaimReward)
	PlayersService.PlayerRemoving:Connect(onPlayerRemoving)
end

return CrateShopService