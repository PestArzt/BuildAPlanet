local SellService = {}

-- Referências (mantidas)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules (mantidos)
local DataStoreModule = require(game:GetService("ServerScriptService").Data.DataStoreModule)
local ItemData = require(game:GetService("ServerScriptService").Data.ItemData)
local LeaderstatsService = require(game:GetService("ServerScriptService").Player.LeaderStatsService)
local InventoryService = require(game:GetService("ServerScriptService").Player.InventoryService)
local BuildingService = require(ServerScriptService.Game.BuildingService)
-- RemoteFunctions
local SellAction = game.ReplicatedStorage.RemoteFunctions.Shop:WaitForChild('SellAction')


--RemoteEvents
local PlaySoundEvent = ReplicatedStorage.RemoteEvents.SoundsEffects:WaitForChild("PlaySoundForClient")

--// =============================================================================
--// Utils
local function getItemData(itemName)
	local categories = {"Plants", "PlantsMutation", "Seeds", "Decoration", "Farming"}
	for _, category in ipairs(categories) do
		local itemData = ItemData:GetItem(category, itemName) 
		if itemData then
			return itemData, category
		end
	end
	return nil, nil
end


local function getSellPrice(player, itemName)
	if not player or not itemName or type(itemName) ~= "string" then return 0, 0 end

	local itemData = getItemData(itemName)
	if not itemData then return 0, 0 end

	local category = itemData.Category 
	local basePrice = 0

	if itemData.SellingPrice then
		basePrice = itemData.SellingPrice
	elseif category == "Seeds" and itemData.Price then
		basePrice = math.floor(itemData.Price * 0.5)
	end

	if basePrice <= 0 then return 0, 0 end

	if category == "Plants" or category == "PlantsMutation" then
		local playerBuffs = BuildingService:GetPlayerBuffs(player)
		if playerBuffs and playerBuffs.MoneyBonus then
			local moneyMultiplier = 1 + (playerBuffs.MoneyBonus or 0)
			local finalPrice = math.floor(basePrice * moneyMultiplier)
			return basePrice, finalPrice 
		end
	end

	return basePrice, basePrice
end


--// =============================================================================
--// FUNÇÕES PRINCIPAIS 
--  Retorna todos os itens vendáveis do inventário do jogador
function SellService:GetSellableItems(player)
	local inventory = InventoryService:GetInventory(player)
	local sellableItems = {}
	local consolidatedItems = {}

	local function processItem(item)
		if item and item.Name then
			local masterItemData, _ = getItemData(item.Name)
			local basePrice, finalPrice = getSellPrice(player, item.Name)

			if masterItemData and finalPrice > 0 then
				if consolidatedItems[item.Name] then
					consolidatedItems[item.Name].Quantity += item.Quantity
					consolidatedItems[item.Name].Locked = consolidatedItems[item.Name].Locked or (item.Locked == true)
				else
					consolidatedItems[item.Name] = {
						Name = item.Name,
						Quantity = item.Quantity,
						BaseSellPrice = basePrice,  
						FinalSellPrice = finalPrice,
						ImageId = masterItemData.ImageId or "",
						Locked = item.Locked or false,
						Rarity = masterItemData.Rarity or "Common" 
					}
				end
			end
		end
	end

	for i = 0, InventoryService.MaxSlots do
		processItem(inventory[tostring(i)])
	end
	if inventory.Backpack then
		for _, item in ipairs(inventory.Backpack) do
			processItem(item)
		end
	end

	for _, itemData in pairs(consolidatedItems) do
		table.insert(sellableItems, itemData)
	end

	return {success = true, items = sellableItems}
end


function SellService:SellSingleItem(player, itemToSell)
	if not itemToSell or type(itemToSell) ~= "table" then
		return {success = false, message = "Dados inválidos."}
	end

	local itemName = itemToSell.Name
	local quantityToSell = itemToSell.Quantity

	if not itemName or type(quantityToSell) ~= "number" or quantityToSell <= 0 then
		return {success = false, message = "Quantidade ou nome inválido."}
	end
	if not InventoryService:HasItem(player, itemName, quantityToSell) then
		return {success = false, message = "Você não tem " .. quantityToSell .. "x " .. itemName .. "."}
	end

	local _, finalSellPrice = getSellPrice(player, itemName)
	if finalSellPrice <= 0 then
		return {success = false, message = "Este item não pode ser vendido."}
	end

	local totalValue = finalSellPrice * quantityToSell
	InventoryService:Remove(player, itemName, quantityToSell)
	LeaderstatsService:IncrementPlayerStat(player, "Money", totalValue)
	
	PlaySoundEvent:FireClient(player, "SellSound")

	return {success = true, message = string.format("Vendido %dx %s!", quantityToSell, itemName)}
end

function SellService:SellAllItems(player)
	local sellableData = self:GetSellableItems(player) 

	if not sellableData or not sellableData.success or #sellableData.items == 0 then
		return {success = false, message = "Nenhum item vendável encontrado."}
	end

	local totalSaleValue = 0
	local itemsSold = 0
	for _, itemData in ipairs(sellableData.items) do
		if not itemData.Locked then
			totalSaleValue += itemData.FinalSellPrice * itemData.Quantity
			InventoryService:Remove(player, itemData.Name, itemData.Quantity)
			itemsSold += 1 
		end
	end

	if totalSaleValue > 0 then
		LeaderstatsService:IncrementPlayerStat(player, "Money", totalSaleValue)
		PlaySoundEvent:FireClient(player, "SellSound") 
		return {success = true, message = string.format("Itens vendidos por %d moedas!", totalSaleValue)}
	else
		return {success = false, message = "Nenhum item destravado para vender."}
	end
end




--// =============================================================================
--// INICIALIZAÇÃO 
--// =============================================================================

function SellService:Initialize()
	SellAction.OnServerInvoke = function(player, action, ...)
		if action == "getSellableItems" then
			return self:GetSellableItems(player)
		elseif action == "sellSingleItem" then 
			local itemToSell = ...
			return self:SellSingleItem(player, itemToSell)
		elseif action == "sellAllItems" then 
			return self:SellAllItems(player)
		end
		return {success = false, message = "Ação inválida"}
	end
end
return SellService