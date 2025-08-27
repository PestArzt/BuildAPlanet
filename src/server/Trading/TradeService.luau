local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService").Server

local InventoryService = require(ServerScriptService.Player.InventoryService)
local StateManager = require(ServerScriptService.General.StateHandler)
local ItemData = require(ServerScriptService.Data.ItemData)
local PetDataService = require(ServerScriptService.Data.PetData) 
local TradeFolder = ReplicatedStorage.RemoteEvents.TradeSystem

-- Apenas dois remotes agora!
local TradeRemotes = {
	Action = TradeFolder:WaitForChild("PerformTradeAction"),
	State =  TradeFolder:WaitForChild("UpdateTradeState"),
}

local TradeService = {}

--// Variáveis
local activeTrades = {}
local pendingRequests = {}
local isInitialized = false

--// Funções Utilitárias
local function getSession(player)
	return activeTrades[player]
end

local function getItemKey(item)
	return item.Category .. ":" .. item.Name
end

local function cleanupSession(session)
	if not session then return end
	local p1, p2 = session.player1, session.player2

	if p1 and activeTrades[p1] then
		StateManager:RemoveStates(p1, "Trading")
		activeTrades[p1] = nil
	end
	if p2 and activeTrades[p2] then
		StateManager:RemoveStates(p2, "Trading")
		activeTrades[p2] = nil
	end
end


local function syncClientStates(session)
	if not session then return end

	-- Pacote de dados para o player1
	local stateForP1 = {
		myOffer = session.offer1,
		partnerOffer = session.offer2,
		myReady = session.ready1,
		partnerReady = session.ready2,
		myConfirmed = session.confirmed1,
		partnerConfirmed = session.confirmed2,
	}

	-- Pacote de dados para o player2 
	local stateForP2 = {
		myOffer = session.offer2,
		partnerOffer = session.offer1,
		myReady = session.ready2,
		partnerReady = session.ready1,
		myConfirmed = session.confirmed2,
		partnerConfirmed = session.confirmed1,
	}

	if session.player1 and session.player1.Parent then
		TradeRemotes.State:FireClient(session.player1, "StateUpdate", stateForP1)
	end
	if session.player2 and session.player2.Parent then
		TradeRemotes.State:FireClient(session.player2, "StateUpdate", stateForP2)
	end
end

local function resetConfirmationState(session)
	session.ready1 = false
	session.ready2 = false
	session.confirmed1 = false
	session.confirmed2 = false

end

--// Definições de Ações

local function requestTrade(requester, targetPlayer)
	if not requester or not targetPlayer or requester == targetPlayer then return end
	if StateManager:GetState(requester, "Trading") or StateManager:GetState(targetPlayer, "Trading") then return end
	if pendingRequests[targetPlayer] or pendingRequests[requester] then return end
	if targetPlayer:FindFirstChild("TurnedOffTrade") and targetPlayer.TurnedOffTrade.Value == true then return end

	local requestId = {requester = requester, target = targetPlayer}
	pendingRequests[requester] = requestId
	pendingRequests[targetPlayer] = requestId

	TradeRemotes.State:FireClient(targetPlayer, "RequestReceived", { Requester = requester })

	task.delay(30, function()
		if pendingRequests[requester] == requestId then
			pendingRequests[requester] = nil
			if pendingRequests[targetPlayer] == requestId then
				pendingRequests[targetPlayer] = nil
			end
		end
	end)
end

local function respondToRequest(responder, accepted)
	local request = pendingRequests[responder]
	if not request then return end

	local requester = request.requester
	pendingRequests[requester] = nil
	pendingRequests[responder] = nil

	if not accepted then return end

	local session = {
		player1 = requester,
		player2 = responder,
		offer1 = {}, offer2 = {},
		ready1 = false, ready2 = false,
		confirmed1 = false, confirmed2 = false,
	}

	if requester.UserId > responder.UserId then
		session.player1, session.player2 = responder, requester
	end

	activeTrades[session.player1] = session
	activeTrades[session.player2] = session

	StateManager:SetState(session.player1, "Trading", true)
	StateManager:SetState(session.player2, "Trading", true)

	-- Inicia a sessão para ambos os jogadores
	TradeRemotes.State:FireClient(session.player1, "SessionStart", { Partner = session.player2 })
	TradeRemotes.State:FireClient(session.player2, "SessionStart", { Partner = session.player1 })
end

local function cancelTrade(player, reason)
	local session = getSession(player)
	if not session then return end

	local p1, p2 = session.player1, session.player2
	cleanupSession(session)

	if p1 then TradeRemotes.State:FireClient(p1, "SessionEnd", { Success = false, Reason = reason or "A troca foi cancelada." }) end
	if p2 then TradeRemotes.State:FireClient(p2, "SessionEnd", { Success = false, Reason = reason or "A troca foi cancelada pelo outro jogador." }) end
end
local function finalizeTrade(session)
	local p1, p2 = session.player1, session.player2
	if not p1 or not p1.Parent or not p2 or not p2.Parent then
		cleanupSession(session)
		return
	end

	-- Validação final
	for _, itemData in pairs(session.offer1) do
		if not InventoryService:HasItem(p1, itemData.Name, itemData.Quantity) then
			cancelTrade(p1, "Falha na verificação: " .. p1.Name .. " não possui mais os itens ofertados.")
			return
		end
	end
	for _, itemData in pairs(session.offer2) do
		if not InventoryService:HasItem(p2, itemData.Name, itemData.Quantity) then
			cancelTrade(p1, "Falha na verificação: " .. p2.Name .. " não possui mais os itens ofertados.")
			return
		end
	end

	-- Execução da Troca
	local success, err = pcall(function()
		for _, itemToTrade in pairs(session.offer1) do
			if itemToTrade.Category == "Pets" and itemToTrade.UUID then
				local petStats = PetDataService:GetPetData(p1, itemToTrade.UUID)
				PetDataService:UpdatePetData(p2, itemToTrade.UUID, petStats)
				PetDataService:DeletePetData(p1, itemToTrade.UUID)
				InventoryService:RemoveByUUID(p1, itemToTrade.UUID)
			else
				InventoryService:Remove(p1, itemToTrade.Name, itemToTrade.Quantity)
			end
			InventoryService:Add(p2, itemToTrade)
		end

		-- Processa a oferta do Jogador 2 para o Jogador 1
		for _, itemToTrade in pairs(session.offer2) do
			if itemToTrade.Category == "Pets" and itemToTrade.UUID then
				local petStats = PetDataService:GetPetData(p2, itemToTrade.UUID)
				PetDataService:UpdatePetData(p1, itemToTrade.UUID, petStats)
				PetDataService:DeletePetData(p2, itemToTrade.UUID)

				InventoryService:RemoveByUUID(p2, itemToTrade.UUID)
			else
				InventoryService:Remove(p2, itemToTrade.Name, itemToTrade.Quantity)
			end
			InventoryService:Add(p1, itemToTrade)
		end
	end)

	if success then
		local p1Ref, p2Ref = session.player1, session.player2
		cleanupSession(session)
		TradeRemotes.State:FireClient(p1Ref, "SessionEnd", { Success = true, Reason = "Troca concluída com sucesso!" })
		TradeRemotes.State:FireClient(p2Ref, "SessionEnd", { Success = true, Reason = "Troca concluída com sucesso!" })
	else
		warn("ERRO CRÍTICO DURANTE A FINALIZAÇÃO DA TROCA:", err)
		cancelTrade(p1, "Ocorreu um erro inesperado durante a troca. Tente novamente.")
	end
end


local function addItem(player, slotId, quantity)
	local session = getSession(player)
	if not session then return end

	local inventory = InventoryService:GetInventory(player)
	local item
	if type(slotId) == "string" and slotId:sub(1, 9) == "Backpack:" then
		local index = tonumber(slotId:sub(10))
		item = (index and inventory.Backpack) and inventory.Backpack[index]
	else
		item = inventory[tostring(slotId)]
	end
	if not item or next(item) == nil or item.Locked then return end

	local masterItemData = ItemData:GetItem(item.Category, item.Name)
	if masterItemData and masterItemData.CannotStore == true then return end

	local offer = (player == session.player1) and session.offer1 or session.offer2
	local itemKey = getItemKey(item) -- Usa a nova função getItemKey

	local amountInOffer = offer[itemKey] and offer[itemKey].Quantity or 0
	local amountToAdd = math.min(quantity, item.Quantity - amountInOffer)
	if amountToAdd <= 0 then return end

	if offer[itemKey] then
		offer[itemKey].Quantity += amountToAdd
	else
		local tradeItem = {
			Name = item.Name,
			Category = item.Category,
			Stackable = item.Stackable,
			Quantity = amountToAdd,
			Locked = item.Locked,
			ImageId = item.ImageId,
			Rarity = item.Rarity
		}
		if item.Category == "Pets" and item.UUID then
			local currentPetData = PetDataService:GetPetData(player, item.UUID)
			
			tradeItem.UUID = item.UUID
			tradeItem.Level = currentPetData.Level 
			tradeItem.XP = currentPetData.XP       
		end
		offer[itemKey] = tradeItem
	end

	resetConfirmationState(session)
	syncClientStates(session)
end

local function removeItem(player, itemKey)
	local session = getSession(player)
	if not session then return end
	local offer = (player == session.player1) and session.offer1 or session.offer2

	if offer[itemKey] then
		offer[itemKey] = nil
		resetConfirmationState(session)
		syncClientStates(session)
	end
end

local function setReady(player, isReady)
	local session = getSession(player)
	if not session then return end

	local isPlayer1 = (player == session.player1)
	if not isReady then
		-- Se um jogador cancela o "pronto", reseta o estado de ambos
		session.ready1 = false
		session.ready2 = false
		session.confirmed1 = false
		session.confirmed2 = false
		syncClientStates(session)
		return
	end

	-- Se o jogador está clicando para ficar pronto/confirmar (isReady é true)
	if isPlayer1 then
		if not session.ready1 then
			-- Primeiro clique: Marcar como pronto
			session.ready1 = true
		elseif session.ready1 and session.ready2 then
			-- Segundo clique (e o parceiro já está pronto): Marcar como confirmado
			session.confirmed1 = true
		end
	else -- É o player2
		if not session.ready2 then
			session.ready2 = true
		elseif session.ready1 and session.ready2 then
			session.confirmed2 = true
		end
	end

	-- Checa se a troca deve ser finalizada
	if session.confirmed1 and session.confirmed2 then
		finalizeTrade(session)
	else
		syncClientStates(session)
	end
end

--// Tabela de Actions
local actions = {
	Request = function(player, data)
		requestTrade(player, data.Target)
	end,
	Respond = function(player, data)
		respondToRequest(player, data.Accepted)
	end,
	AddItem = function(player, data)
		addItem(player, data.SlotId, data.Quantity)
	end,
	RemoveItem = function(player, data)
		removeItem(player, data.ItemKey)
	end,
	SetReady = function(player, data)
		setReady(player, data.IsReady)
	end,
	Cancel = function(player)
		cancelTrade(player)
	end,
}

--// Inicialização do Serviço
function TradeService:Initialize()
	if isInitialized then return end
	isInitialized = true 
	TradeRemotes.Action.OnServerEvent:Connect(function(player, actionName, data)
		local handler = actions[actionName]
		if handler then
			handler(player, data)
		else
			warn("Ação de troca desconhecida recebida de", player.Name, ":", actionName)
		end
	end)

	Players.PlayerRemoving:Connect(function(player) 
		if getSession(player) then
			cancelTrade(player, "O outro jogador saiu do jogo.") 
		end
	end)
end

return TradeService