local GenericShopService = {}

--// Services & Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService").Server
local DataStoreModule = require(ServerScriptService.DataStoreModule)
local ItemData = require(ServerScriptService.Data.ItemData)
local LeaderstatsService = require(ServerScriptService.Player.LeaderStatsService)
local InventoryService = require(ServerScriptService.Player.InventoryService)
local GlobalRestockService = _G.GlobalRestockService -- Acessar o serviço global
local StateHandler = require(ServerScriptService.General.StateHandler) 
--// RemoteFunctions
local ShopAction = ReplicatedStorage.RemoteFunctions.Shop:WaitForChild('ShopAction')
--// RemoteEvents
local PlaySoundEvent = ReplicatedStorage.RemoteEvents.SoundsEffects:WaitForChild("PlaySoundForClient")

-- ========================================================
-- CONFIGURAÇÃO CENTRAL DAS LOJAS
local SHOP_CONFIG = {
	["Seeds"] = {
		dataStoreKey = "SeedStock",
		itemIdKey = "SeedId",
		getAllItemsFunc = "GetSeedsInStock",
		restockFunc = "RestockPlayerToDefault",
		purchaseStat = "ItemsPurchased"
	},
	["Decoration"] = {
		dataStoreKey = "DecorationStock",
		itemIdKey = "DecorationId",
		getAllItemsFunc = "GetDecorationsInStock",
		restockFunc = "RestockPlayerDecorationsToDefault",
		purchaseStat = "DecorationsPurchased"
	}
}

function GenericShopService:ToggleFavorite(player, itemCategory, itemName)
	local config = self:GetConfig(itemCategory)
	if not config then return { success = false, message = "Categoria inválida." } end

	local StockDataStore = DataStoreModule.GetDataStore(player, config.dataStoreKey)
	local currentStock = StockDataStore:GetData({})

	local found = false
	local newFavouriteStatus = false

	for i, itemData in ipairs(currentStock) do
		if itemData[config.itemIdKey] == itemName then
			itemData.Favourite = not (itemData.Favourite or false) 
			newFavouriteStatus = itemData.Favourite
			found = true
			break
		end
	end

	if found then
		StockDataStore:SetData(currentStock)
		return { success = true, isFavourite = newFavouriteStatus }
	else
		return { success = false, message = "Item não encontrado no estoque do jogador." }
	end
end

function GenericShopService:GetConfig(itemCategory)
	local config = SHOP_CONFIG[itemCategory]
	if not config then
		warn("GenericShopService: Tentativa de usar uma categoria de loja inválida:", itemCategory)
	end
	return config
end

function GenericShopService:GetPlayerItemData(player, itemCategory, itemName)
	local config = self:GetConfig(itemCategory)
	if not config then return nil end
	local allItemsInStock = ItemData[config.getAllItemsFunc](ItemData, player)
	for _, itemData in ipairs(allItemsInStock) do
		if itemData[config.itemIdKey] == itemName then
			return itemData
		end
	end
	return nil
end

function GenericShopService:ModifyStock(player, itemCategory, itemName, amount)
	local config = self:GetConfig(itemCategory)
	if not config then return false end
	local StockDataStore = DataStoreModule.GetDataStore(player, config.dataStoreKey)
	local currentStock = StockDataStore:GetData({})
	local found = false
	for i, itemData in ipairs(currentStock) do
		if itemData[config.itemIdKey] == itemName then
			itemData.Stock = math.max(0, itemData.Stock + amount)
			found = true
			break
		end
	end
	if found then
		StockDataStore:SetData(currentStock)
	end
	return found
end

function GenericShopService:ValidateTransaction(player, itemCategory, itemName)
	local config = self:GetConfig(itemCategory)
	if not config then return {valid = false, message = "Categoria de loja inválida"} end
	local itemInfo = ItemData:GetItem(itemCategory, itemName)
	if not itemInfo then return {valid = false, message = "Item não encontrado"} end
	if not itemInfo.IsOnShop then return {valid = false, message = "Item não está à venda"} end
	local playerLevel = LeaderstatsService:GetPlayerStat(player, "FarmingLevel")
	if playerLevel < (itemInfo.LevelRequired or 1) then
		return {valid = false, message = `Nível insuficiente. Necessário: ${itemInfo.LevelRequired}`}
	end
	local currentMoney = LeaderstatsService:GetPlayerStat(player, "Money")
	if currentMoney < itemInfo.Price then
		return {valid = false, message = "Dinheiro insuficiente"}
	end
	local playerItemData = self:GetPlayerItemData(player, itemCategory, itemName)
	if not playerItemData or playerItemData.Stock <= 0 then
		return {valid = false, message = "Item fora de estoque"}
	end
	return {valid = true, message = "Transação Válida", itemInfo = itemInfo}
end

function GenericShopService:BuyItem(player, itemCategory, itemName)

	if StateHandler.GetState(player, "IsShopping") then
		return {success = false, message = "Aguarde um momento antes de comprar novamente."}
	end
	StateHandler.SetState(player, "IsShopping", true, 0.1)

	local validation = self:ValidateTransaction(player, itemCategory, itemName)
	if not validation.valid then
		StateHandler.RemoveStates(player, "IsShopping")
		return {success = false, message = validation.message}
	end

	local itemInfo = validation.itemInfo
	local price = itemInfo.Price
	local currentMoney = LeaderstatsService:GetPlayerStat(player, "Money")
	LeaderstatsService:IncrementPlayerStat(player, "Money", -price)

	if LeaderstatsService:GetPlayerStat(player, "Money") ~= currentMoney - price then
		LeaderstatsService:SetPlayerStat(player, "Money", currentMoney)
		StateHandler.RemoveStates(player, "IsShopping")
		return {success = false, message = "Falha no pagamento"}
	end

	if not self:ModifyStock(player, itemCategory, itemName, -1) then
		LeaderstatsService:SetPlayerStat(player, "Money", currentMoney)
		StateHandler.RemoveStates(player, "IsShopping")
		return {success = false, message = "Falha ao atualizar estoque"}
	end
	local itemToSend = {
		Name = itemInfo.Name,
		Category = itemCategory,
		Stackable = itemInfo.Stackable,
		Quantity = 1,
		Locked = false
	}

	InventoryService:Add(player.Name, itemToSend) 
	self:UpdatePurchaseStats(player, price, itemCategory)
	PlaySoundEvent:FireClient(player, "BuySound") 
	--logia do tutoras
	local TutorialProgressEvent = ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent
	TutorialProgressEvent:Fire(player, "ItemPurchased", itemCategory)
	return {success = true, message = `{itemInfo.Name} comprado com sucesso!`}
end

function GenericShopService:UpdatePurchaseStats(player, price, itemCategory)
	local PlayerStats = DataStoreModule.GetDataStore(player, "PlayerStats-v0")
	local currentStats = PlayerStats:GetData({})
	currentStats.TotalSpent = (currentStats.TotalSpent or 0) + price
	currentStats.ItemsPurchased = (currentStats.ItemsPurchased or 0) + 1
	local config = self:GetConfig(itemCategory)
	if config and config.purchaseStat then
		local statName = config.purchaseStat
		currentStats[statName] = (currentStats[statName] or 0) + 1
	end
	PlayerStats:SetData(currentStats)
end
--// =============================================================================
--// CONEXÃO DA REMOTE FUNCTION 
--// =============================================================================
function GenericShopService:Initialize()
	ShopAction.OnServerInvoke = function(player, action, itemCategory, ...)
		local args = {...}

		-- Ações globais que NÃO precisam de uma categoria
		if action == "getRestockTime" then
			-- A categoria é ignorada para esta ação, então a pega de `itemCategory`
			return {success = true, timeLeft = GlobalRestockService:GetTimeUntilNextShopRestock()}
		elseif action == "getPlayerMoney" then
			-- A categoria é ignorada
			return {success = true, money = LeaderstatsService:GetPlayerStat(player, "Money")}
		end

		-- A partir daqui, todas as ações PRECISAM de uma categoria válida
		local config = self:GetConfig(itemCategory)
		if not config then
			return {success = false, message = "Ação '" .. tostring(action) .. "' requer uma categoria de loja válida. Categoria recebida: " .. tostring(itemCategory)}
		end

		if action == "buyItem" then
			local itemName = args[1]
			return self:BuyItem(player, itemCategory, itemName)
			
		elseif action == "toggleFavorite" then
			local itemName = args[1]
			return self:ToggleFavorite(player, itemCategory, itemName)
			
		elseif action == "getAllItems" then
			local allItems = ItemData[config.getAllItemsFunc](ItemData, player)
			-- Retorna a chave "items" para ser genérico no cliente
			return {success = true, items = allItems}
		elseif action == "validateTransaction" then
			local itemName = args[1]
			return self:ValidateTransaction(player, itemCategory, itemName)
		end

		return {success = false, message = "Ação desconhecida: " .. tostring(action)}
	end
end

_G.GenericShopService = GenericShopService

return GenericShopService