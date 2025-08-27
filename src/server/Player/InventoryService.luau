local InventoryService = {}
local InventoryMetatable = {__index = InventoryService}

-- Services and Dependencies
local ServerScriptService = game:GetService("ServerScriptService")
local UpdateDataBindableEvent = game:GetService("ServerStorage").BindableEvents.PlayerDataUpdate
local InventoryRemotes = game.ReplicatedStorage.RemoteEvents.Inventory
local ChangeSlotsRemote = InventoryRemotes.ChangeSlots
local EquipItemRemote = InventoryRemotes.EquipItem
local DataStoreModule = require(ServerScriptService.Server.DataStoreModule)
local ItemData = require(ServerScriptService.Server.Data.ItemData)
local InventoryUpdatedRemote = InventoryRemotes:WaitForChild("InventoryUpdated")
local ToggleItemLockRemote = InventoryRemotes:WaitForChild("ToggleItemLock")

-- Configuration
InventoryService.DataStoreName = "Inventory-v0"
InventoryService.MaxSlots = 9
InventoryService.ItemExample = {
	Name = 'String',
	Category = 'String',
	Stackable = true,
	Quantity = 1,
	Locked = false
}

-- Initialize default inventory structure
InventoryService.defaultInventory = {
	['Backpack'] = {}
}
for i = 0, InventoryService.MaxSlots do
	InventoryService.defaultInventory[tostring(i)] = {}
end

-- Helper function to get ordered hotbar slots
--local function GetOrderedHotbarSlots(inventory)
--	local slotKeys = {}
--	for i = 0, InventoryService.MaxSlots do
--		table.insert(slotKeys, tostring(i))
--	end
--	return slotKeys
--end
local function GetOrderedHotbarSlots(inventory)
	return {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}
end



function InventoryService:SetupPlayerBackpack(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local backpack = player:WaitForChild("Backpack")
	local equippedItemValue = backpack:WaitForChild("EquippedItem",5)
	if not backpack:FindFirstChild("EquippedItem") then
		local equippedItemValue = Instance.new("ObjectValue")
		equippedItemValue.Name = "EquippedItem"
		equippedItemValue.Parent = backpack
		--print("🔧 Estrutura 'EquippedItem' criada para {player.Name}")
	end

	if not backpack:FindFirstChild("Hotbar") then
		local hotbarFolder = Instance.new("Folder")
		hotbarFolder.Name = "Hotbar"
		hotbarFolder.Parent = backpack
		--print("🔧 Estrutura 'Hotbar' criada para {player.Name}")
	end
end

function InventoryService:ToggleItemLock(player, slotId)
	--print(string.format("[InventoryService] ToggleItemLock executado para %s com slotId: '%s' (tipo: %s)", player.Name, tostring(slotId), typeof(slotId)))

	local inventory = self:GetInventory(player)
	local item = nil

	-- Verifica se o slotId é uma string e começa com "Backpack:"
	if type(slotId) == "string" and slotId:sub(1, 9) == "Backpack:" then
		-- Extrai a parte numérica da string. string.sub é mais seguro que gsub para isso.
		local indexStr = slotId:sub(10) -- Pega tudo a partir do 10º caractere
		local success, index = pcall(tonumber, indexStr) -- Converte para número de forma segura

		-- Verifica se a conversão foi bem-sucedida e se o item existe
		if success and inventory.Backpack and inventory.Backpack[index] then
			item = inventory.Backpack[index]
		else
			-- Se a conversão falhar, avisa no console
			warn(string.format("[InventoryService] Falha ao processar slot da backpack. slotId: '%s', indexStr extraído: '%s'", slotId, indexStr))
		end
		-- Se não for um slot de backpack, tenta converter o slotId inteiro para um número (para a hotbar)
	else
		local success, slotNum = pcall(tonumber, slotId)
		if success and inventory[tostring(slotNum)] then
			item = inventory[tostring(slotNum)]
		end
	end

	-- Se um item válido foi encontrado, altera seu estado de "Locked"
	if item and next(item) ~= nil then
		item.Locked = not (item.Locked or false)

		-- Salva os dados atualizados e notifica o cliente para atualizar a UI
		DataStoreModule.GetDataStore(player, self.DataStoreName):SetData(inventory)
		InventoryUpdatedRemote:FireClient(player, inventory)
	else
		warn("[InventoryService] ToggleItemLock: Nenhum item válido encontrado para o slotId fornecido: ", slotId)
	end
end



function InventoryService:Initialize()
	ChangeSlotsRemote.OnServerEvent:Connect(function(player, slot1, slot2)
		self:ChangeSlot(player, slot1, slot2)
	end)

	EquipItemRemote.OnServerEvent:Connect(function(player, state, slot)
		self:EquipItem(state, player, slot)
	end)
	
	ToggleItemLockRemote.OnServerEvent:Connect(function(player, slotId)
		self:ToggleItemLock(player, slotId)
	end)
	
	
	UpdateDataBindableEvent.Event:Connect(function(player, dataStore, value)
		if dataStore == "Inventory-v0" then
			self:UpdatePhysicalBackpack(player)
		end
	end)

	--print("✅ InventoryService inicializado e ouvindo eventos.")
end

-- Validates and updates inventory structure
local function CheckUpdates(playerInventory)
    for cat, _ in pairs(InventoryService.defaultInventory) do
        if not playerInventory[cat] then
            playerInventory[cat] = {}
        end
    end
    
    for cat, _ in pairs(playerInventory) do
        if not InventoryService.defaultInventory[cat] then
            playerInventory[cat] = nil
        end
	end
	
    return playerInventory
end



-- Equips or unequips an item
function InventoryService:EquipItem(state, player, slot)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.Animator then return end

	local CharacterAnimate = character:FindFirstChild("Animate")

	if state then
		if player.Backpack.EquippedItem.Value then
			if player.Backpack.EquippedItem.Value:GetAttribute("Slot") == slot then return end
			self:EquipItem(false, player, nil)
		end
		
		local backpackItemData = self:GetInventory(player)[tostring(slot)]
		
		for _, backpackItem in ipairs(player.Backpack.Hotbar:GetChildren()) do
			if tostring(backpackItem:GetAttribute("Slot")) == tostring(slot) then

				--for _, part in ipairs(backpackItem:GetDescendants()) do
				--	if part:IsA("BasePart") then
				--		part.Anchored = false
				--		part.CanCollide = false 
				--		part.Massless = true 
						
				--		if part ~= backpackItem.PrimaryPart then
				--			if part.Transparency < 0.4 then part:SetAttribute("OriginalTransparency", part.Transparency) part.Transparency = 0.4 end
				--			local weld = Instance.new("WeldConstraint")
				--			weld.Name = "AutoInternalWeld"
				--			weld.Part0 = backpackItem.PrimaryPart
				--			weld.Part1 = part
				--			weld.C0 = backpackItem.PrimaryPart.CFrame:ToObjectSpace(part.CFrame)
				--			weld.Parent = backpackItem.PrimaryPart
				--		end
				--	end
				--end

				backpackItem.Parent = character
				player.Backpack.EquippedItem.Value = backpackItem

				--if backpackItemData.IsBigItem then
				--	if CharacterAnimate:FindFirstChild("HoldingBigItem") then
				--		humanoid.Animator:LoadAnimation(CharacterAnimate:FindFirstChild("HoldingBigItem")):Play()
				--	end
					
				--	local rootPart = character.HumanoidRootPart
				--	backpackItem:SetPrimaryPartCFrame(rootPart.CFrame * CFrame.new(0, 4, 0))
				--	local weld = Instance.new("WeldConstraint", backpackItem)
				--	weld.Name = "BigItemWeld"
				--	weld.Part0 = rootPart
				--	weld.Part1 = backpackItem.PrimaryPart

				--else -- Para itens pequenos
				--	if CharacterAnimate and CharacterAnimate:FindFirstChild("HoldingSmallItem") then
				--		humanoid.Animator:LoadAnimation(CharacterAnimate.HoldingSmallItem):Play()
				--	end

				--	local bboxCFrame = backpackItem:GetBoundingBox()
				--	local relPivotToCenter = backpackItem.PrimaryPart.CFrame:ToObjectSpace(bboxCFrame)
				--	local wristPos = (character["Right Arm"].CFrame * CFrame.new(0, -character["Right Arm"].Size.Y/2, 0)).Position
				--	local forwardVector = -character["Right Arm"].CFrame.UpVector
				--	local upVector = (character.PrimaryPart.CFrame.UpVector - (character.PrimaryPart.CFrame.UpVector:Dot(forwardVector))*forwardVector).Unit
				--	local itemCFrame = CFrame.lookAt(wristPos, wristPos + forwardVector, upVector)
				--	local desiredPivot = itemCFrame * relPivotToCenter:Inverse()
				--	backpackItem:PivotTo(desiredPivot)

				--	local handWeld = Instance.new("WeldConstraint")
				--	handWeld.Parent = backpackItem
				--	handWeld.Name = "HandWeld"
				--	handWeld.Part0 = character["Right Arm"]
				--	handWeld.Part1 = backpackItem.PrimaryPart
				--end
			end
		end

	else -- Desequipar
		local ItemEquipped = player.Backpack.EquippedItem.Value
		if ItemEquipped then
			ItemEquipped.Parent = player.Backpack[ItemEquipped:GetAttribute("Place")]
			
			--for _, track in ipairs(humanoid.Animator:GetPlayingAnimationTracks()) do
			--	if track.Animation.AnimationId == CharacterAnimate.HoldingBigItem.AnimationId or track.Animation.AnimationId == CharacterAnimate.HoldingSmallItem.AnimationId then 
			--		track:Stop() 
			--	end
			--end
			
			--for _, part in ipairs(ItemEquipped:GetDescendants()) do
			--	if part:IsA("BasePart") then
			--		if part:GetAttribute("OriginalTransparency") then
			--			part.Transparency = part:GetAttribute("OriginalTransparency")
			--		end
			--	end
			--end
			
			--for _, child in ipairs(ItemEquipped:GetDescendants()) do
			--	if child:IsA("BasePart") then
			--		child.Anchored = true

			--	elseif child:IsA("Weld") then
			--		child:Destroy()
			--	end
			--end

			player.Backpack.EquippedItem.Value = nil
		end
	end
end

-- Updates the physical backpack representation
function InventoryService:UpdatePhysicalBackpack(player)
	local backpack = player:WaitForChild("Backpack")
	local HotbarFolder = backpack:FindFirstChild("Hotbar")
	local inventory = self:GetInventory(player)

	if not HotbarFolder then
		HotbarFolder = Instance.new("Folder")
		HotbarFolder.Name = "Hotbar"
		HotbarFolder.Parent = player.Backpack
	end

	-- Clear existing items
	for _, item in ipairs(HotbarFolder:GetChildren()) do
		if player.Backpack.EquippedItem.Value ~= item then
			item:Destroy()
		end
	end
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("Place") == "Backpack" then
			item:Destroy()
		end
	end

	-- Recreate hotbar items
	for _, slotString in ipairs(GetOrderedHotbarSlots(inventory)) do 
		if slotString == "Backpack" then continue end 

		local itemData = inventory[slotString]
		if itemData and next(itemData) ~= nil then
			local existingItem = nil
			if player.Character:FindFirstChild(itemData.Name) and player.Character[itemData.Name]:GetAttribute("Slot") == slotString then
				existingItem = player.Character[itemData.Name]
			end

			local itemModelData = ItemData:GetItem(itemData.Category, itemData.Name)
			if not itemModelData then
				warn("Item model data not found for:", itemData.Name)
				self:Remove(player, itemData.Name, math.huge)
				continue
			end

			if existingItem then
				existingItem:SetAttribute("Quantity", itemData.Quantity)
			else
				local itemModel = ItemData:FindModel(itemModelData)
				if itemModel then
					local newItem = itemModel:Clone()
					newItem:SetAttribute("Quantity", itemData.Quantity)
					newItem:SetAttribute("Slot", slotString)
					newItem:SetAttribute("Place", "Hotbar")
					newItem:SetAttribute("Category", itemData.Category)
					newItem:SetAttribute("ImageId", itemModelData.ImageId)
					
					if itemData.Category == "Pets" then
						newItem:SetAttribute("UUID", itemData.UUID)
						newItem:SetAttribute("Level", itemData.Level)
						newItem:SetAttribute("XP", itemData.XP)
					end
					
					newItem.Parent = HotbarFolder
				else
					warn("Physical item model not found for:", itemData.Name)
					self:Remove(player, itemData.Name, math.huge)
				end
			end
		end
	end

	-- Recreate backpack items
	for slot, item in ipairs(inventory.Backpack) do
		if item and next(item) ~= nil then
			local itemModelData = ItemData:GetItem(item.Category, item.Name)
			if itemModelData then
				local itemModel = ItemData:FindModel(itemModelData)
				if itemModel then
					local newItem = itemModel:Clone()
					newItem:SetAttribute("Quantity", item.Quantity)
					newItem:SetAttribute("Slot", slot)
					newItem:SetAttribute("Place", "Backpack")
					newItem:SetAttribute("Category", item.Category)
					newItem:SetAttribute("ImageId", itemModelData.ImageId)
					
					if item.Category == "Pets" then
						newItem:SetAttribute("UUID", item.UUID)
						newItem:SetAttribute("Level", item.Level)
						newItem:SetAttribute("XP", item.XP)
					end
					newItem.Parent = backpack
				else
					warn("Physical item model not found for:", item.Name)
					self:Remove(player, item.Name, math.huge)
				end
			else
				warn("Item model data not found for:", item.Name)
				self:Remove(player, item.Name, math.huge)
			end
		end
	end
end

-- Gets item in a specific slot
function InventoryService:GetItemInSlot(player, slot)
	local inventory = self:GetInventory(player)
	return inventory[tostring(slot)]
end

-- Checks if player has a specific item
function InventoryService:HasItem(playerOrName, itemName, quantity)
	quantity = quantity or 1
	local inventory = self:GetInventory(playerOrName)
	local totalCount = 0

	local function countItem(item)
		if item and item.Name and item.Name == itemName then
			totalCount += item.Quantity
		end
	end

	for _, slotString in ipairs(GetOrderedHotbarSlots(inventory)) do
		countItem(inventory[slotString])
	end
	if inventory['Backpack'] then
		for _, currentItem in pairs(inventory['Backpack']) do
			countItem(currentItem)
		end
	end

	return totalCount >= quantity
end

-- Gets player's inventory data
function InventoryService:GetInventory(playerOrName)
	local player = playerOrName
	if typeof(playerOrName) == "string" then
		player = game.Players:FindFirstChild(playerOrName)
	end
   
	if not player or not player:IsA("Player") then
		warn("InventoryService:GetInventory - Jogador inválido ou não encontrado:", tostring(playerOrName))
		return nil 
	end

	local currentInventory = DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):GetData(InventoryService.defaultInventory)

	-- Validação inicial para dados corrompidos
	if type(currentInventory) ~= "table" then
		warn("!!! DADO DE INVENTÁRIO CORROMPIDO DETECTADO para {player.Name}. O dado era do tipo '{typeof(currentInventory)}'. Resetando para o padrão.")
		currentInventory = table.clone(InventoryService.defaultInventory) -- Usar clone para evitar modificar o original
	end
	currentInventory = CheckUpdates(currentInventory)
	
	local function validateAndHydrateItem(item)
		if type(item) ~= "table" or next(item) == nil then
			return item
		end

		local masterData = ItemData:GetItem(item.Category, item.Name)

		if not masterData then
			warn("Item obsoleto encontrado no inventário: " .. (item.Name or "N/A") .. ". Será removido na próxima limpeza.")
			return {}
		end
		if item.Rarity == nil then
			item.Rarity = masterData.Rarity
		end
		if item.Stackable == nil then
			item.Stackable = masterData.Stackable
		end
		if item.ImageId == nil then
			item.ImageId = masterData.ImageId
		end
		if item.Locked == nil then
			item.Locked = false
		end
		if masterData.Category == "Pets" then
			item.UUID = item.UUID
			item.Level = item.Level
			item.XP = item.XP
		end
		return item
	end

	for i = 0, InventoryService.MaxSlots do
		local slotKey = tostring(i)
		if currentInventory[slotKey] then
			currentInventory[slotKey] = validateAndHydrateItem(currentInventory[slotKey])
		end
	end

	-- Aplica a validação em todos os itens da backpack
	if currentInventory.Backpack and type(currentInventory.Backpack) == "table" then
		for i, item in ipairs(currentInventory.Backpack) do
			currentInventory.Backpack[i] = validateAndHydrateItem(item)
		end
	end
	-- print("Inventário 'hidratado' sendo retornado para " .. player.Name, currentInventory)

	return currentInventory
end

function InventoryService:Add(playerOrName, itemData) 
	local player = playerOrName
	if typeof(playerOrName) == "string" then
		player = game.Players:FindFirstChild(playerOrName)
	end
	if not player then return false, "Player not found" end

	if type(itemData) ~= "table" or not itemData.Category or not itemData.Name then
		warn("InventoryService:Add falhou. Dados do item incompletos ou inválidos.")
		return false, "Invalid item data"
	end

	local inventory = self:GetInventory(player)
	
	if not inventory then
		warn("InventoryService:Add abortado. Não foi possível obter o inventário para " .. player.Name)
		return false, "Could not get inventory"
	end

	local inventory = self:GetInventory(player)

	--if itemData.Category == "Pets" then
	--	if not itemData.UUID or itemData.Level == nil or itemData.XP == nil then
	--		warn("Tentativa de adicionar um pet ao inventário sem dados completos (UUID, Level, XP). Abortando.")
	--		return false, "Dados do pet incompletos."
	--	end
	--	table.insert(inventory['Backpack'], itemData)
	--	DataStoreModule.GetDataStore(player, self.DataStoreName):SetData(inventory)
	--	InventoryUpdatedRemote:FireClient(player, inventory)
	--	return true, "Pet adicionado com sucesso."
	--end
	
	local itemMasterData = ItemData:GetItem(itemData.Category, itemData.Name)
	if not itemMasterData then
		warn("InventoryService:Add falhou. Item mestre não encontrado para: "..itemData.Name)
		return false, "Item does not exist"
	end
	
	-- Garante que o item tenha as propriedades corretas
	itemData.Stackable = itemMasterData.Stackable
	itemData.ImageId = itemMasterData.ImageId
	itemData.Rarity = itemMasterData.Rarity

	if not itemData.Stackable and itemData.Quantity > 1 then
		itemData.Quantity = 1
	end

	local quantityRemaining = itemData.Quantity

	-- Tenta empilhar na hotbar
	if itemData.Stackable then
		for _, slotString in ipairs(GetOrderedHotbarSlots(inventory)) do
			if next(inventory[slotString]) ~= nil and itemData.Name == inventory[slotString].Name then
				inventory[slotString].Quantity += quantityRemaining
				quantityRemaining = 0
				break
			end
		end
	end

	-- Tenta empilhar na backpack
	if quantityRemaining > 0 and itemData.Stackable and inventory['Backpack'] then
		for _, currentItem in ipairs(inventory['Backpack']) do
			if itemData.Name == currentItem.Name then
				currentItem.Quantity += quantityRemaining
				quantityRemaining = 0
				break
			end
		end
	end
	

	if quantityRemaining > 0 then
		local itemToAdd = table.clone(itemData)
		itemToAdd.Quantity = quantityRemaining

		local placedInHotbar = false
		for _, slotString in ipairs(GetOrderedHotbarSlots(inventory)) do
			if next(inventory[slotString]) == nil then
				inventory[slotString] = itemToAdd
				placedInHotbar = true
				break
			end
		end

		if not placedInHotbar then
			table.insert(inventory['Backpack'], itemToAdd)
		end
	end
	
	DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
	InventoryUpdatedRemote:FireClient(player, inventory)
	return true, "Item adicionado com sucesso." 
end

function InventoryService:FindAndRemoveByUUID(player, inventory, uuid)
	if not player or not inventory or not uuid then return nil end

	local foundItemData = nil

	-- Procura na hotbar
	for _, slotKey in ipairs(GetOrderedHotbarSlots(inventory)) do
		local item = inventory[slotKey]
		if item and item.UUID and item.UUID == uuid then
			foundItemData = table.clone(item)
			inventory[slotKey] = {} 
			break 
		end
	end

	if not foundItemData and inventory.Backpack then
		for i = #inventory.Backpack, 1, -1 do
			local item = inventory.Backpack[i]
			if item and item.UUID and item.UUID == uuid then
				foundItemData = table.clone(item) 
				table.remove(inventory.Backpack, i) 
				break 
			end
		end
	end
	if foundItemData then
		DataStoreModule.GetDataStore(player, self.DataStoreName):SetData(inventory)
		self:UpdatePhysicalBackpack(player) -- Atualiza a representação visual
	end

	return foundItemData 
end

function InventoryService:RemoveByUUID(player, uuid)
	if not player or not uuid then return false end

	local inventory = self:GetInventory(player)
	local removed = false


	for _, slotKey in ipairs(GetOrderedHotbarSlots(inventory)) do
		local item = inventory[slotKey]
		if item and item.UUID == uuid then
			inventory[slotKey] = {}
			removed = true
			break
		end
	end

	if not removed and inventory.Backpack then
		for i = #inventory.Backpack, 1, -1 do
			local item = inventory.Backpack[i]
			if item and item.UUID == uuid then
				table.remove(inventory.Backpack, i)
				removed = true
				break
			end
		end
	end

	if removed then
		DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
	end

	return removed
end



-- Removes an item from player's inventory
function InventoryService:Remove(playerOrName, itemName, quantity)
	local player = playerOrName
	if typeof(playerOrName) == "string" then
		player = game.Players:FindFirstChild(playerOrName)
	end
	if not player then return false end

	if not self:HasItem(player, itemName, quantity) then
		warn("Tentativa de remover item que o jogador não possui em quantidade suficiente:", itemName, quantity)
		return false
	end

	local inventory = self:GetInventory(player)
	local quantityToRemove = quantity

	for _, slotString in ipairs(GetOrderedHotbarSlots(inventory)) do
		local slotItem = inventory[slotString]
		if slotItem and slotItem.Name == itemName then
			if slotItem.Quantity > quantityToRemove then
				slotItem.Quantity -= quantityToRemove
				quantityToRemove = 0
				break
			else
				quantityToRemove -= slotItem.Quantity
				inventory[slotString] = {}
				if quantityToRemove <= 0 then break end
			end
		end
	end


	if quantityToRemove > 0 and inventory['Backpack'] then
		for i = #inventory['Backpack'], 1, -1 do
			local currentItem = inventory['Backpack'][i]
			if currentItem and currentItem.Name == itemName then
				if currentItem.Quantity > quantityToRemove then
					currentItem.Quantity -= quantityToRemove
					quantityToRemove = 0
					break
				else
					quantityToRemove -= currentItem.Quantity
					table.remove(inventory['Backpack'], i)
					if quantityToRemove <= 0 then break end
				end
			end
		end
	end

	DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
	InventoryUpdatedRemote:FireClient(player, inventory)
	return true
end

-- Clears player's inventory
function InventoryService:ClearInventory(playerOrName)
	local player = playerOrName
	if typeof(playerOrName) == "string" then
		player = game.Players:FindFirstChild(playerOrName)
	end
	if not player then return end

	local inventory = InventoryService.defaultInventory
	DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
end
-- Changes items between slots
function InventoryService:ChangeSlot(player, slot1, slot2)
	local inventory = self:GetInventory(player)

	-- Moving to backpack
	if slot2 == "Backpack" then
		local itemToMove = inventory[tostring(slot1)]
		if not itemToMove or next(itemToMove) == nil then return false end 

		inventory[tostring(slot1)] = {}

		-- Try to stack with existing items in backpack
		local foundStack = false
		if inventory['Backpack'] and type(inventory['Backpack']) == "table" then
			for i, currentItem in ipairs(inventory['Backpack']) do
				if next(currentItem) ~= nil and itemToMove.Name == currentItem.Name and currentItem.Stackable then
					inventory['Backpack'][i].Quantity += itemToMove.Quantity
					foundStack = true
					break
				end
			end
		end

		if not foundStack then
			table.insert(inventory['Backpack'], itemToMove)
		end

		DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
		self:UpdatePhysicalBackpack(player)
		return true
	end

	-- Helper functions for slot parsing
	local function isBackpackSlot(slot)
		return typeof(slot) == "string" and string.sub(slot, 1, 9) == "Backpack:"
	end

	local function parseSlot(slot)
		if isBackpackSlot(slot) then
			local index = tonumber(string.sub(slot, 10))
			return "Backpack", index
		else
			return tostring(slot), nil
		end
	end

	local slotKey1, index1 = parseSlot(slot1)
	local slotKey2, index2 = parseSlot(slot2)

	local item1 = slotKey1 == "Backpack" and (inventory.Backpack[index1] or {}) or inventory[slotKey1]
	local item2 = slotKey2 == "Backpack" and (inventory.Backpack[index2] or {}) or inventory[slotKey2]

	-- Check if items can be stacked
	if next(item1) ~= nil and next(item2) ~= nil and item1.Name == item2.Name and item1.Stackable then
		if slotKey2 == "Backpack" then
			inventory.Backpack[index2].Quantity += item1.Quantity
			inventory.Backpack[index2].Locked = item1.Locked or item2.Locked 
		else
			inventory[slotKey2].Quantity += item1.Quantity
			inventory[slotKey2].Locked = item1.Locked or item2.Locked
		end


		if slotKey1 == "Backpack" then
			table.remove(inventory.Backpack, index1)
		else
			inventory[slotKey1] = {}
		end

		DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
		self:UpdatePhysicalBackpack(player)
		InventoryUpdatedRemote:FireClient(player, inventory)
		return true
	end

	-- Swap items between slots
	if slotKey1 == "Backpack" then
		if next(item2) ~= nil then
			inventory.Backpack[index1] = item2
		else
			table.remove(inventory.Backpack, index1)
		end
	else
		inventory[slotKey1] = item2 or {}
	end

	if slotKey2 == "Backpack" then
		if next(item1) ~= nil then
			inventory.Backpack[index2] = item1
		else
			if index2 then 
				table.remove(inventory.Backpack, index2)
			end
		end
	else
		inventory[slotKey2] = item1 or {}
	end

	-- Clean up hotbar slots that might contain arrays
	for i = 1, InventoryService.MaxSlots do
		local key = tostring(i)
		if typeof(inventory[key]) == "table" and #inventory[key] > 0 then
			warn(`Slot {key} da hotbar contém array, convertendo para item direto.`)
			inventory[key] = inventory[key][1]
		end
	end

	-- Clean up empty backpack slots
	if inventory.Backpack then
		for i = #inventory.Backpack, 1, -1 do
			local item = inventory.Backpack[i]
			if not item or next(item) == nil then
				table.remove(inventory.Backpack, i)
			end
		end
	end

	DataStoreModule.GetDataStore(player, InventoryService.DataStoreName):SetData(inventory)
	self:UpdatePhysicalBackpack(player)
	InventoryUpdatedRemote:FireClient(player,inventory)
	return true
end

function InventoryService:PrepareDataForSave(player)
	if not player or not player.Parent then return end

	local currentInventory = self:GetInventory(player)

	local inventoryDataStore = DataStoreModule.GetDataStore(player, InventoryService.DataStoreName)
	if inventoryDataStore then
		inventoryDataStore:SetData(currentInventory)
	end
end

return setmetatable(InventoryService, InventoryService)