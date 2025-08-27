local GlobalRestockService = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggShopService = require(game:GetService("ServerScriptService").Game.EggShopService)
local MerchantService = require(game:GetService("ServerScriptService").Game.MerchantService)
local Workspace = game:GetService("Workspace")
local remoteEventsFolderofShop = ReplicatedStorage:FindFirstChild("RemoteEvents"):FindFirstChild('Shop')
local globalRestockEvent = remoteEventsFolderofShop:FindFirstChild("GlobalRestock")
local merchantNpcHead = game:GetService("Workspace"):WaitForChild("Lobby"):WaitForChild("Merchant"):WaitForChild("MerchantNPC"):WaitForChild("Head"):WaitForChild("Time")

local eggShopTimerPart = Workspace:WaitForChild("EggsMerchant"):WaitForChild("TimeLeftEgg")

local GlobalTimerStore = DataStoreService:GetDataStore("GlobalTimersStore_v2")

local SHOP_RESTOCK_INTERVAL = 300 
local SHOP_RESTOCK_KEY = "LastShopRestockTime"
local MERCHANT_RESTOCK_INTERVAL = 14400
local MERCHANT_RESTOCK_KEY = "LastMerchantRestockTime"

GlobalRestockService.nextShopRestockTime = 0
GlobalRestockService.nextMerchantRestockTime = 0
local timerThread 
local isInitialized = false
local isShopRestocking = false
local isMerchantRestocking = false

--// Initialize the global restock service
function GlobalRestockService:Initialize()
	if isInitialized then return end
	isInitialized = true

	EggShopService:Initialize()
	MerchantService:Initialize()

	self:LoadAllRestockTimes()
	self:StartGlobalTimer()
end

--// Load last restock times from DataStore
function GlobalRestockService:LoadAllRestockTimes()
	local success, results = pcall(function()
		return {
			shop = GlobalTimerStore:GetAsync(SHOP_RESTOCK_KEY),
			merchant = GlobalTimerStore:GetAsync(MERCHANT_RESTOCK_KEY)
		}
	end)

	local currentTime = os.time()
	local lastShopTime = success and results.shop or nil
	local lastMerchantTime = success and results.merchant or nil

	-- Lógica do Shop
	if lastShopTime then
		local timeSince = currentTime - lastShopTime
		
		self.nextShopRestockTime = timeSince >= SHOP_RESTOCK_INTERVAL and currentTime or (lastShopTime + SHOP_RESTOCK_INTERVAL)
	else
		
		self.nextShopRestockTime = currentTime 
	end

	
	if lastMerchantTime then
		local timeSince = currentTime - lastMerchantTime
		if timeSince >= MERCHANT_RESTOCK_INTERVAL then
			print("⏰ O restock do Mercador está atrasado. Agendando para agora.")
			self.nextMerchantRestockTime = currentTime
		else
			self.nextMerchantRestockTime = lastMerchantTime + MERCHANT_RESTOCK_INTERVAL
		end
	else
		print("⏰ Primeira execução do Mercador. Agendando restock para agora.")
		self.nextMerchantRestockTime = currentTime
	end
end
--// Start the global timer for all restocks
function GlobalRestockService:StartGlobalTimer()
	if timerThread then task.cancel(timerThread) end

	timerThread = task.spawn(function()
		while true do
			local timeLeft = self:GetTimeUntilNextMerchantRestock()
			merchantNpcHead:SetAttribute("RestockTimeLeft", timeLeft)
			 --Essa e pros ovos
			local shopTimeLeft = self:GetTimeUntilNextShopRestock()
			eggShopTimerPart:SetAttribute("ShopRestockTimeLeft", shopTimeLeft)
			
			
			local currentTime = os.time()

			if currentTime >= self.nextShopRestockTime and not isShopRestocking then
				isShopRestocking = true

				local timeOfThisRestock = os.time()
				self.nextShopRestockTime = timeOfThisRestock + SHOP_RESTOCK_INTERVAL
				pcall(function() GlobalTimerStore:SetAsync(SHOP_RESTOCK_KEY, timeOfThisRestock) end)

				self:ExecuteShopRestock()

				isShopRestocking = false
				--print("✅ Restock da Loja Principal concluído. Próximo em " .. SHOP_RESTOCK_INTERVAL .. "s.")
			end

			if currentTime >= self.nextMerchantRestockTime and not isMerchantRestocking then
				isMerchantRestocking = true

				local timeOfThisRestock = os.time()
				self.nextMerchantRestockTime = timeOfThisRestock + MERCHANT_RESTOCK_INTERVAL
				pcall(function() GlobalTimerStore:SetAsync(MERCHANT_RESTOCK_KEY, timeOfThisRestock) end)

				MerchantService:Restock()
				self:NotifyClientsAboutRestock("The Traveling Merchant has new items!")

				isMerchantRestocking = false
				print("🛒 Restock do Mercador concluído. Próximo em " .. MERCHANT_RESTOCK_INTERVAL .. "s.")
			end

			task.wait(1) 
		end
	end)
end

--// Notify all clients about a restock event
function GlobalRestockService:NotifyClientsAboutRestock(message)
	if globalRestockEvent then
		globalRestockEvent:FireAllClients(message)
	end
end

--// Execute global restock for shops (Seeds, Decorations, Eggs)
function GlobalRestockService:ExecuteShopRestock()
	EggShopService:Restock()
	for _, player in pairs(Players:GetPlayers()) do
		if player and player.Parent then
			self:RestockPlayerPersonalItems(player)
		end
	end

	self:NotifyClientsAboutRestock("The Shops have been restocked!")
end

--// Restock personal items (Seeds, Decorations) for a specific player
function GlobalRestockService:RestockPlayerPersonalItems(player)
	local ItemData = require(game:GetService("ServerScriptService").Data.ItemData) 
	if not ItemData then warn("⚠️ ItemData module not found!") return end

	if ItemData.RestockPlayerToDefault then pcall(ItemData.RestockPlayerToDefault, ItemData, player) end
	if ItemData.RestockPlayerDecorationsToDefault then pcall(ItemData.RestockPlayerDecorationsToDefault, ItemData, player) end
end

--// Get time until next shop restock
function GlobalRestockService:GetTimeUntilNextShopRestock() 
	local currentTime = os.time()
	return math.max(0, self.nextShopRestockTime - currentTime)
end

--// Get time until next merchant restock
function GlobalRestockService:GetTimeUntilNextMerchantRestock()
	local currentTime = os.time()
	return math.max(0, self.nextMerchantRestockTime - currentTime)
end

game:BindToClose(function()
	if timerThread then task.cancel(timerThread) end
end)

_G.GlobalRestockService = GlobalRestockService

return GlobalRestockService