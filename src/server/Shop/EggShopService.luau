-- /ServerScriptService/Services/EggShopService.lua

local EggShopService = {}

--// Services & Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService").Server

local ItemData = require(ServerScriptService.Data.ItemData)
local LeaderstatsService = require(ServerScriptService.Player.LeaderStatsService)
local InventoryService = require(ServerScriptService.Player.InventoryService)
local StateHandler = require(ServerScriptService.General.StateHandler)
local RarityManager = require(game:GetService("ReplicatedStorage").Modules.RarityManager)
local ShopEffectManager = require(game:GetService("ReplicatedStorage").Modules.ShopEffectManager)
local EggLootData = require(ServerScriptService.Data.EggLootData)

local PlaySoundEvent = ReplicatedStorage.RemoteEvents.SoundsEffects:WaitForChild("PlaySoundForClient")

local NotifyPlayerEvent = ReplicatedStorage.RemoteEvents.Shop:WaitForChild("NotifyPlayer")
local PET_LOOT_DISPLAY_TEMPLATE = ReplicatedStorage:WaitForChild("BillboardGuis"):WaitForChild("PetLootDisplay")


--// Configuração
local EGG_MERCHANT_FOLDER = Workspace:WaitForChild("EggsMerchant")
local EGG_DISPLAY_TAG = "EggDisplaySlot"
local EGG_ANIMATION_TAG = "EggShopAnimatable"

--local EggShopStockStore = DataStoreService:GetDataStore("GlobalEggShopStock_v1")
--local EGG_STOCK_KEY = "CurrentStock"

--// Variáveis de controle
local currentStock = {} -- Tabela para rastrear o que está em cada slot. Ex: { [Part] = eggData }
local displaySlots = {} -- Lista de Parts que servem como display


--function EggShopService:SaveStockToDataStore()
--	local stockToSave = {}
--	for _, slotPart in ipairs(displaySlots) do
--		local eggData = currentStock[slotPart]
--		stockToSave[slotPart.Name] = eggData and eggData.Name or nil
--	end

--	local success, err = pcall(function()
--		EggShopStockStore:SetAsync(EGG_STOCK_KEY, stockToSave)
--	end)

--	if success then
--		print("💾 Estoque da loja de ovos salvo no DataStore.")
--	else
--		warn("❌ Erro ao salvar o estoque da loja de ovos:", err)
--	end
--end


function EggShopService:CreateEmptySign(slotPart)
	local pedestal = slotPart:FindFirstChild("Pedestal")
	if not pedestal then return end

	local emptySignPart = pedestal:FindFirstChild("EmptySign")
	if not emptySignPart then
		warn("Aviso: Part 'EmptySign' não encontrada no pedestal do slot: " .. slotPart.Name)
		return
	end
	if emptySignPart:FindFirstChild("EmptyBillboardGui") then return end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "EmptyBillboardGui"
	billboardGui.Size = UDim2.fromScale(3.5, 1.25)
	billboardGui.StudsOffset = Vector3.new(0, 1, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 30
	billboardGui.Parent = emptySignPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1) 
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Empty"
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.Parent = billboardGui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 2
	uiStroke.Color = Color3.new(0, 0, 0)
	uiStroke.Parent = textLabel
end


function EggShopService:RemoveEmptySign(slotPart)
	local pedestal = slotPart:FindFirstChild("Pedestal")
	if not pedestal then return end

	local emptySignPart = pedestal:FindFirstChild("EmptySign")
	if not emptySignPart then return end

	local billboardGui = emptySignPart:FindFirstChild("EmptyBillboardGui")
	if billboardGui then
		billboardGui:Destroy()
	end
end

--function EggShopService:LoadStockFromDataStore()
--	local success, savedStock = pcall(function()
--		return EggShopStockStore:GetAsync(EGG_STOCK_KEY)
--	end)

--	if not success then
--		warn("⚠️ Erro ao carregar o estoque da loja de ovos:", savedStock)
--		self:ClearAllDisplays()
--		return
--	end


--	currentStock = {}

--	if savedStock and type(savedStock) == "table" then
--		--print("📦 Carregando estoque da loja de ovos do DataStore...")
--		local slotMap = {}
--		for _, slotPart in ipairs(displaySlots) do
--			slotMap[slotPart.Name] = slotPart
--		end

--		-- Primeiro, popula os slots que têm itens
--		for slotName, eggName in pairs(savedStock) do
--			local slotPart = slotMap[slotName]
--			if slotPart and eggName then
--				local eggData = ItemData:GetItem("Eggs", eggName)
--				if eggData then
--					self:DisplayEggOnSlot(slotPart, eggData) 
--					--print(` -> Slot '${slotName}' carregado com: ${eggName}`)
--				else
--					warn(` -> Ovo '${eggName}' encontrado no estoque salvo, mas não existe mais no ItemData.`)
--				end
--			end
--		end
--		--print("📦 Carregamento do estoque concluído.")
--	else
--		print("📦 Nenhum estoque de ovos salvo encontrado.")
--	end
--	for _, slotPart in ipairs(displaySlots) do
--		if not currentStock[slotPart] then
--			self:ClearDisplaySlot(slotPart)
--		end
--	end
--end

--// =============================================================================
--// FUNÇÕES PRINCIPAIS
function EggShopService:Initialize()
	for i, part in ipairs(EGG_MERCHANT_FOLDER:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Part" then 
				part.Name = "EggDisplaySlot_"..i
				warn(`⚠️ Slot de ovo sem nome foi renomeado para '${part.Name}'. É recomendado nomear os slots manualmente no Studio.`)
			end
			table.insert(displaySlots, part)
		end
	end

	if #displaySlots == 0 then
		warn("⚠️ EggShopService: Nenhum slot de exibição de ovo encontrado na pasta EggsMerchant.")
		return
	end

	--print(`✅ EggShopService inicializado com {#displaySlots} slots de exibição.`)
	--self:LoadStockFromDataStore()
end

function EggShopService:ClearAllDisplays()
	for _, slotPart in ipairs(displaySlots) do
		self:ClearDisplaySlot(slotPart)
	end
	currentStock = {}
end
function EggShopService:ClearDisplaySlot(slotPart)
	if not slotPart or not slotPart.Parent then 
		return 
	end
	for _, child in ipairs(slotPart:GetChildren()) do
		if child:IsA("Model") and CollectionService:HasTag(child, EGG_ANIMATION_TAG) then
			child:Destroy()
			break 
		end
	end
	local prompt = slotPart:FindFirstChildOfClass("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end

	-- Atributtes clean
	slotPart:SetAttribute("EggName", nil)
	slotPart:SetAttribute("EggPrice", nil)
	local pedestal = slotPart:FindFirstChild("Pedestal")
	if pedestal then
		local lightPart = pedestal:FindFirstChild("Light")
		if lightPart then
			ShopEffectManager:Cleanup(lightPart)
		end
	end
	
	self:CreateEmptySign(slotPart)
end

function EggShopService:Restock()
	--print("🥚 Iniciando restock da loja de ovos...")
	self:ClearAllDisplays()
	math.randomseed(os.time())
	local lootPool = {}
	local allEggsData = ItemData:GetItemsInCategory("Eggs")

	if not allEggsData then
		warn("⚠️ Categoria 'Eggs' não encontrada em ItemData. Pulando restock de ovos.")
		return
	end

	for eggName, eggData in pairs(allEggsData) do
		if eggData.IsOnShop and eggData.ShopAppearanceChance > 0 then
			table.insert(lootPool, { Data = eggData, Weight = eggData.ShopAppearanceChance })
		end
	end

	if #lootPool == 0 then
		print("🥚 Nenhum ovo configurado com ShopAppearanceChance > 0. A loja de ovos ficará vazia.")
		--self:SaveStockToDataStore() 
		return
	end

	local function rollFromPool(currentPool)
		local totalWeight = 0
		for _, item in ipairs(currentPool) do
			totalWeight += item.Weight
		end

		if totalWeight <= 0 then return nil end

		local randomNumber = math.random() * totalWeight
		local currentWeight = 0

		for i, item in ipairs(currentPool) do
			currentWeight += item.Weight
			if randomNumber <= currentWeight then
				return table.remove(currentPool, i)
			end
		end
		return nil
	end

	--print(`🥚 Sorteando ovos para preencher {#displaySlots} slots...`)
	for _, slotPart in ipairs(displaySlots) do
		if #lootPool == 0 then
			print("🥚 Não há mais ovos únicos para sortear. Alguns slots podem ficar vazios.")
			break 
		end

		local rolledItem = rollFromPool(lootPool)

		if rolledItem then
			--print(` -> Slot '${slotPart.Name}' preenchido com: ${rolledItem.Data.Name}`)
			self:DisplayEggOnSlot(slotPart, rolledItem.Data)
		end
	end

	--print("🥚 Restock da loja de ovos concluído.")
	--self:SaveStockToDataStore() 
end
function EggShopService:DisplayEggOnSlot(slotPart, eggData)
	self:RemoveEmptySign(slotPart)
	local eggModel = ItemData:FindModel(eggData)
	if not eggModel then
		warn("❌ Modelo não encontrado para o ovo:", eggData.Name)
		return
	end

	local modelClone = eggModel:Clone()
	modelClone:PivotTo(slotPart.CFrame + Vector3.new(0, 2, 0))
	if modelClone.PrimaryPart then
		modelClone:PivotTo(slotPart.CFrame + Vector3.new(0, 2 + modelClone.PrimaryPart.Size.Y/2, 0))
	end
	modelClone.Parent = slotPart
	
	CollectionService:AddTag(modelClone, EGG_ANIMATION_TAG)
	
	
	local function calculatePetChances(lootTable)
		local totalWeight = 0
		for _, loot in ipairs(lootTable) do
			totalWeight = totalWeight + loot.Weight
		end
		return totalWeight
	end

	local lootInfo = EggLootData[eggData.LootTable]
	if lootInfo and lootInfo.LootTable and #lootInfo.LootTable > 0 then
		local lootDisplayGui = PET_LOOT_DISPLAY_TEMPLATE:Clone()
		lootDisplayGui.MaxDistance = math.huge
		lootDisplayGui.Enabled = false 
		local container = lootDisplayGui.Container
		local petInfoTemplate = container.PetInfoTemplate

		local totalWeight = calculatePetChances(lootInfo.LootTable)

		table.sort(lootInfo.LootTable, function(a, b) return a.Weight > b.Weight end)

		for _, petLoot in ipairs(lootInfo.LootTable) do
			local petData = ItemData:GetItem("Pets", petLoot.Name)
			if petData then
				local petFrame = petInfoTemplate:Clone()
				petFrame.Name = petLoot.Name

				-- Configura Imagem
				local petImage = petFrame:FindFirstChild("PetImage")
				if petImage then
					petImage.Image = petData.ImageId or ""
				end

				-- Configura Texto (Nome + Chance)
				local petInfoText = petFrame:FindFirstChild("PetInfoText")
				if petInfoText then
					local chance = (petLoot.Weight / totalWeight) * 100
					petInfoText.Text = string.format("%s - %.1f%%", petLoot.Name, chance)
					RarityManager:ApplyRarity(petInfoText, petData.Rarity)
				end

				petFrame.Visible = true
				petFrame.Parent = container
			end
		end

		petInfoTemplate:Destroy()
		lootDisplayGui.Parent = modelClone
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Buy"
	prompt.ObjectText = `{eggData.Name} - ${eggData.Price}`
	prompt.HoldDuration = 0.5
	prompt:SetAttribute("Theme", "EggBuyProx")
	prompt.MaxActivationDistance = 15
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = modelClone
	
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(3, 0, 1, 0)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 30
	billboardGui.Parent = modelClone
	billboardGui.StudsOffset = Vector3.new(0, -1.5, 0)

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, 0, 1, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = "$" .. eggData.Price
	priceLabel.TextColor3 = Color3.new(1, 1, 1)
	RarityManager:ApplyRarity(priceLabel, eggData.Rarity)
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.FredokaOne
	priceLabel.Parent = billboardGui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 2
	uiStroke.Color = Color3.new(0, 0, 0) 
	uiStroke.Parent = priceLabel

	local pedestal = slotPart:FindFirstChild("Pedestal")
	if pedestal then
		local lightPart = pedestal:FindFirstChild("Light")
		if lightPart and lightPart:IsA("BasePart") then
			ShopEffectManager:ApplyRarity(lightPart, eggData.Rarity)
		end
	end
	
	-- Salva os dados no slot para a função de compra
	slotPart:SetAttribute("EggName", eggData.Name)
	slotPart:SetAttribute("EggPrice", eggData.Price)
	prompt.Triggered:Connect(function(player)
		self:AttemptPurchase(player, slotPart)
	end)
	currentStock[slotPart] = eggData
end

function EggShopService:AttemptPurchase(player, slotPart)
	local eggName = slotPart:GetAttribute("EggName")
	
	if not eggName or not currentStock[slotPart] then
		return
	end

	-- Trava para evitar compras múltiplas
	if StateHandler.GetState(player, "IsShoppingEgg") then return end
	StateHandler.SetState(player, "IsShoppingEgg", true, 1)

	local eggData = currentStock[slotPart]
	local playerMoney = LeaderstatsService:GetPlayerStat(player, "Money")

	if playerMoney >= eggData.Price then
		LeaderstatsService:IncrementPlayerStat(player, "Money", -eggData.Price)
		local itemToAdd = {
			Name = eggData.Name,
			Category = "Eggs",
			Stackable = eggData.Stackable,
			Quantity = 1,
			Locked = false
		}
		InventoryService:Add(player.Name, itemToAdd)
		NotifyPlayerEvent:FireClient(player, "You bought an egg", {eggData.Name})
		PlaySoundEvent:FireClient(player, "BuySound")
		-- Remove o item da loja
		self:ClearDisplaySlot(slotPart)
		currentStock[slotPart] = nil
		
		self:SaveStockToDataStore()
	else
		NotifyPlayerEvent:FireClient(player, "Not enough money to buy", {eggData.Name})
	end

	StateHandler.RemoveStates(player, "IsShoppingEgg")
end

-- Exporta
_G.EggShopService = EggShopService
return EggShopService