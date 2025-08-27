local MerchantService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService").Server
local DataStoreService = game:GetService("DataStoreService")

local ItemData = require(ServerScriptService.Data.ItemData)
local LeaderstatsService = require(ServerScriptService.Player.LeaderStatsService)
local InventoryService = require(ServerScriptService.Player.InventoryService)
local DataStoreModule = require(ServerScriptService.DataStoreModule)

local Remotes = ReplicatedStorage.RemoteEvents
local ShopEvents = Remotes:WaitForChild('Shop')
local NotifyPlayerEvent = ShopEvents:WaitForChild("NotifyPlayer")
local MerchantRemotes = Remotes:WaitForChild("Merchant")
local PurchaseItemEvent = MerchantRemotes:WaitForChild("PurchaseItem")
local GetStockFunction = ReplicatedStorage.RemoteFunctions:WaitForChild("Merchant"):WaitForChild("GetStock")
local StockUpdatedEvent = MerchantRemotes:WaitForChild("StockUpdated")

local PlaySoundEvent = ReplicatedStorage.RemoteEvents.SoundsEffects:WaitForChild("PlaySoundForClient")

local stockStore = DataStoreService:GetDataStore("MerchantStockStore")

local ITEMS_IN_SHOP = 8
local currentStock = {}
local lastRestockTimestamp = 0

--// Collect all eligible items from ItemData for merchant
function MerchantService:GetEligibleItems()
	local eligibleItems = {}
	for categoryName, categoryData in pairs(ItemData) do
		if type(categoryData) == "table" then
			for itemName, item in pairs(categoryData) do
				if item.IsOnMerchant and item.MerchantPrice then
					table.insert(eligibleItems, {
						Name = itemName,
						Category = categoryName,
						Price = item.MerchantPrice,
						ImageId = item.ImageId,
						Rarity = item.Rarity,
					})
				end
			end
		end
	end
	return eligibleItems
end

--// Restock merchant with random selection of items
function MerchantService:Restock()
	print("🛒 [MerchantService] Gerando novo estoque e salvando...")
	local eligibleItems = self:GetEligibleItems()
	local newStock = {}

	for i = #eligibleItems, 2, -1 do
		local j = math.random(i)
		eligibleItems[i], eligibleItems[j] = eligibleItems[j], eligibleItems[i]
	end

	for i = 1, math.min(ITEMS_IN_SHOP, #eligibleItems) do
		table.insert(newStock, eligibleItems[i])
	end


	currentStock = newStock 
	lastRestockTimestamp = os.time()
	local dataToSave = {
		stock = currentStock,
		timestamp = lastRestockTimestamp
	}

	pcall(function()
		stockStore:SetAsync("CurrentStockAndTimestamp", dataToSave)
	end)

	StockUpdatedEvent:FireAllClients()
	print("🛒 [MerchantService] Restock completo. Novo estoque e timestamp salvos.")
end

--// Load or generate initial stock
function MerchantService:LoadOrGenerateStock()
	local success, savedData = pcall(function()
		return stockStore:GetAsync("CurrentStockAndTimestamp")
	end)

	if success and type(savedData) == "table" and savedData.stock and savedData.timestamp then
		--print("🛒 Estoque do mercador carregado do DataStore.")
		currentStock = savedData.stock
		lastRestockTimestamp = savedData.timestamp
	else
		print("🛒 Nenhum estoque salvo ou dados inválidos. Gerando um novo estoque imediatamente.")
		self:Restock() 
	end
end
local isPlayerPurchasing = {}

--// Handle item purchase request from player
function MerchantService:PurchaseItem(player, itemName)
	
	if isPlayerPurchasing[player.UserId] then
		return
	end
	isPlayerPurchasing[player.UserId] = true

	local itemToBuy
	for _, item in ipairs(currentStock) do
		if item.Name == itemName then
			itemToBuy = item
			break
		end
	end

	if not itemToBuy then
		NotifyPlayerEvent:FireClient(player, "This item is no longer available!", nil, Color3.fromRGB(255, 100, 100))
		isPlayerPurchasing[player.UserId] = nil -- [!] Libera o bloqueio
		return
	end


	local playerCratePoints = LeaderstatsService:GetPlayerStat(player, "CratePoints")
	if playerCratePoints < itemToBuy.Price then
		NotifyPlayerEvent:FireClient(player, "Not enough Crate Points!", nil, Color3.fromRGB(255, 100, 100))
		isPlayerPurchasing[player.UserId] = nil -- [!] Libera o bloqueio
		return
	end

	
	local playerPurchasesStore = DataStoreModule.GetDataStore(player, "MerchantPurchases")
	local purchaseData = playerPurchasesStore:GetData({timestamp = 0, items = {}})

	if purchaseData.timestamp ~= lastRestockTimestamp then
		purchaseData = {timestamp = lastRestockTimestamp, items = {}}
	end

	local purchasedItems = purchaseData.items

	if purchasedItems[itemName] then
		NotifyPlayerEvent:FireClient(player, "You have already purchased this item!", nil, Color3.fromRGB(255, 100, 100))
		isPlayerPurchasing[player.UserId] = nil -- [!] Libera o bloqueio
		return
	end

	
	-- 1. Debita o dinheiro
	LeaderstatsService:IncrementPlayerStat(player, "CratePoints", -itemToBuy.Price)

	-- 2. Adiciona o item ao inventário
	local itemToAdd = {
		Name = itemToBuy.Name,
		Category = itemToBuy.Category,
		Quantity = 1,
		Locked = false
	}
	InventoryService:Add(player, itemToAdd)

	-- 3. Atualiza os dados de compra do jogador no cache
	purchasedItems[itemName] = true
	purchaseData.items = purchasedItems
	playerPurchasesStore:SetData(purchaseData)

	-- 4. Notifica o jogador e atualiza a interface
	NotifyPlayerEvent:FireClient(player, "Purchase successful!", {itemToBuy.Name}, Color3.fromRGB(100, 255, 100))
	PlaySoundEvent:FireClient(player, "BuySound")
	StockUpdatedEvent:FireClient(player) 

	isPlayerPurchasing[player.UserId] = nil -- [!] Libera o bloqueio
end

--// Get personalized stock for specific player
local function getPlayerStock(player)
	local playerPurchasesStore = DataStoreModule.GetDataStore(player, "MerchantPurchases")
	local purchaseData = playerPurchasesStore:GetData({timestamp = 0, items = {}})
	local purchasedItems

	if purchaseData.timestamp and purchaseData.timestamp == lastRestockTimestamp then
		purchasedItems = purchaseData.items
	else
		print(`[MerchantService] Histórico de compras de ${player.Name} está desatualizado. Exibindo como novo.`)
		purchasedItems = {}
	end

	local playerSpecificStock = {}
	for i, v in ipairs(currentStock) do
		playerSpecificStock[i] = table.clone(v)
	end

	for _, itemData in ipairs(playerSpecificStock) do
		if purchasedItems[itemData.Name] then
			itemData.Sold = true
		end
	end

	return playerSpecificStock
end
--// Initialize the MerchantService
function MerchantService:Initialize()
	self:LoadOrGenerateStock() 

	PurchaseItemEvent.OnServerEvent:Connect(function(player, itemName)
		self:PurchaseItem(player, itemName)
	end)

	GetStockFunction.OnServerInvoke = function(player)
		return getPlayerStock(player)
	end
end

return MerchantService