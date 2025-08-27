local EcclesiaConsole = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local DataStoreService = game:GetService("DataStoreService")
local DataStoreModule = require(ServerScriptService.Data.DataStoreModule) 
local InventoryService = require(ServerScriptService.Player.InventoryService)
local ItemData = require(ServerScriptService.Data.ItemData)
local LeaderStatsService = require(ServerScriptService.Player.LeaderStatsService)
local MessagingService = game:GetService("MessagingService")
local GlobalRestockService = require(ServerScriptService.Game.GlobalRestockService)
local AdminList = require(script.Parent.AdminList) 
local BattlePassServiceModule = require(ServerScriptService.Game.BattlePassService) 
local BuildingService = require(ServerScriptService.Game.BuildingService)
local FarmingService = require(ServerScriptService.Game.FarmingService)

local AdminPanelFolder = ReplicatedStorage.RemoteFunctions:FindFirstChild("Admin")
local AdminActionRemote = AdminPanelFolder:FindFirstChild("AdminAction")

EcclesiaConsole.Prefix = "/"

local function findPlayer(searchString)
	if not searchString or searchString == "" then return nil end

	for _, player in pairs(Players:GetPlayers()) do
		if string.lower(player.Name):find(string.lower(searchString)) then
			return player
		end
	end
	return nil
end

-- Função para obter lista de todos os itens do ItemData
local function getAllItems()
	return ItemData
end

-- Função para obter lista de jogadores
local function getPlayersList()
	local playerList = {}
	for _, player in pairs(Players:GetPlayers()) do
		table.insert(playerList, {
			Name = player.Name,
			DisplayName = player.DisplayName,
			UserId = player.UserId
		})
	end
	return playerList
end

function forceSavingDataStore(userId, dataStoreName)
	if not userId then
		print("forceSavingDataStore: Tentativa de salvar sem UserId.")
		return
	end

	local store = DataStoreService:GetDataStore(dataStoreName)
	local dataStoreController = DataStoreModule.GetDataStore({UserId = userId}, dataStoreName)
	local data = dataStoreController:GetData()
	if data then
		local success, err = pcall(function()
			store:SetAsync(tostring(userId), data)
		end)
		if not success then
			warn("Erro ao forçar save para "..tostring(userId)..": "..err)
		end
	end
end


function EcclesiaConsole:Execute(playerName, action, isFromMessage, ...)
	--print(playerName, action, isFromMessage, ...)
	action = string.lower(action)
	if not AdminList:IsAdmin(playerName) then
		return {"error", "Você não tem permissão para usar comandos administrativos!"}
	end

	local params = { ... }
	if next(params) ~= nil and typeof(params[1]) == "table" then
		params = params[1] 
	end


	if action == "shutdown" then
		local reason = params and params[1] or "Servidor sendo reiniciado"
		for _, p in pairs(Players:GetPlayers()) do
			if p:FindFirstChild("PlayerGui") then
				-- (O código de notificação de shutdown )
				local gui = p.PlayerGui:FindFirstChild("AdminNotification")
				if gui then gui:Destroy() end
				local screenGui = Instance.new("ScreenGui")
				screenGui.Name = "AdminNotification"
				screenGui.Parent = p.PlayerGui

				local frame = Instance.new("Frame")
				frame.Size = UDim2.new(0, 400, 0, 200)
				frame.Position = UDim2.new(0.5, -200, 0.5, -100)
				frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				frame.BorderSizePixel = 0
				frame.Parent = screenGui

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 10)
				corner.Parent = frame

				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(1, 0, 0, 50)
				title.Position = UDim2.new(0, 0, 0, 0)
				title.BackgroundTransparency = 1
				title.Text = "AVISO DO SERVIDOR"
				title.TextColor3 = Color3.fromRGB(255, 100, 100)
				title.TextScaled = true
				title.Font = Enum.Font.GothamBold
				title.Parent = frame

				local message_label = Instance.new("TextLabel")
				message_label.Size = UDim2.new(1, -20, 1, -60)
				message_label.Position = UDim2.new(0, 10, 0, 50)
				message_label.BackgroundTransparency = 1
				message_label.Text = reason .. "\n\nServidor será desligado em 5 segundos!"
				message_label.TextColor3 = Color3.fromRGB(255, 255, 255)
				message_label.TextScaled = true
				message_label.Font = Enum.Font.Gotham
				message_label.TextWrapped = true
				message_label.Parent = frame
			end
		end
		task.delay(5, game.Shutdown)
		return "Servidor será desligado em 5 segundos! Motivo: " .. reason
	elseif action == "restock" then
		GlobalRestockService:ForceRestock()
		return "Restock global forçado com sucesso!"
	end


	local success = false
	local message = ""

	local targetPlayer = nil       -- Será o objeto Player se estiver NESTE servidor
	local targetUserId = nil       -- Será o UserId (número) se o jogador existir (online ou offline)
	local targetPlayerName = params and params[1] or nil -- O nome do jogador alvo (string)
	local isPlayerInServer = false -- Flag para saber se está neste servidor
	local isPlayerPlaying = false  -- Flag para saber se está em QUALQUER servidor do jogo

	if targetPlayerName then
		targetPlayer = findPlayer(targetPlayerName) 

		if targetPlayer then
			
			targetUserId = targetPlayer.UserId
			isPlayerInServer = true
			isPlayerPlaying = true
		else
		
			local pcallSuccess, userId = pcall(function() return Players:GetUserIdFromNameAsync(targetPlayerName) end)
			if pcallSuccess and userId then
				targetUserId = userId
				
				local pcallSuccess_tp, _, _, _, jobId = pcall(function() return TeleportService:GetPlayerPlaceInstanceAsync(userId) end)
				if pcallSuccess_tp and jobId then
					isPlayerPlaying = true
				end
			end
		end
	end


	if isPlayerPlaying and not isPlayerInServer and not isFromMessage then
		MessagingService:PublishAsync("adminAction", {PlayerName = playerName, Action = action, Data = params})
		return "Jogador está em outro servidor. Enviando comando..."
	end



	if action == "additem" then
		if not targetUserId then 
			message = "Jogador '" .. (targetPlayerName or "nil") .. "' não encontrado!"
		else
			local itemTable = ItemData:GetItem(params[2], params[3])
			if itemTable then
				local itemCopy = table.clone(itemTable)
				itemCopy.Quantity = tonumber(params[4]) or 1
				itemCopy.Locked = false

				if targetPlayer then 
					InventoryService:Add(targetPlayer, itemCopy)
					success = true
					message = "Item '" .. itemTable.Name .. "' (x" .. itemCopy.Quantity .. ") adicionado ao inventário de " .. targetPlayer.Name .. "!"
				else
		
					message = "Erro: Adicionar item a jogadores offline ainda não é suportado."
				end
			else
				message = "Item '" .. tostring(params[3]) .. "' não encontrado na categoria '" .. tostring(params[2]) .. "'!"
			end
		end
	elseif action == "resetbp" then
		if not targetPlayer then 
			message = "Erro: Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."
		else
			local resetResult = BattlePassServiceModule:ResetPlayerData(targetPlayer)
			if resetResult == "Sucesso" then
				success = true
				message = "Battle Pass de " .. targetPlayer.Name .. " resetado com sucesso!"
			else
				message = "Erro ao resetar Battle Pass: " .. resetResult
			end
		end
	elseif action == "removeitem" then
		if not targetPlayer then 
			message = "Erro: Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."
		else
			InventoryService:Remove(targetPlayer, params[2], tonumber(params[3]) or math.huge)
			success = true
			message = "Item '" .. params[2] .. "' removido do inventário de " .. targetPlayer.Name .. "!"
		end
	elseif action == "resetstats" then
		if not targetPlayer then 
			message = "Erro: Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."
		else
			LeaderStatsService:SetPlayerStat(targetPlayer, "Money", LeaderStatsService.DefaultData.Money)
			LeaderStatsService:SetPlayerStat(targetPlayer, "FarmingLevel", LeaderStatsService.DefaultData.FarmingLevel)
			LeaderStatsService:SetPlayerStat(targetPlayer, "FarmingXP", LeaderStatsService.DefaultData.FarmingXP)
			success = true
			message = "Stats de " .. targetPlayer.Name .. " resetados com sucesso!"
		end
	elseif action == "clearinventory" then
		if not targetPlayer then 
			message = "Erro: Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."
		else
			InventoryService:ClearInventory(targetPlayer)
			success = true
			message = "Inventário de " .. targetPlayer.Name .. " foi limpo!"
		end
	elseif action == "showinventory" then
		if not targetPlayer then 
			return {error = "Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."}
		end
		return InventoryService:GetInventory(targetPlayer)
	elseif action == "setstat" then
		if not targetPlayer then 
			message = "Erro: Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."
		else
			LeaderStatsService:SetPlayerStat(targetPlayer, params[2], tonumber(params[3]))
			success = true
			message = "Estatística '" .. params[2] .. "' de " .. targetPlayer.Name .. " definida como " .. params[3]
		end
	elseif action == "refreshdata" then
		return { Items = getAllItems(), Players = getPlayersList() }
	elseif action == "kick" then
		if not targetPlayer then 
			message = "Erro: Jogador '" .. (targetPlayerName or "nil") .. "' não está neste servidor."
		else
			local reason = params[2] or "Kicked by admin"
			targetPlayer:Kick(reason)
			success = true
			message = "Jogador " .. targetPlayer.Name .. " foi expulso do servidor! Motivo: " .. reason
		end
	elseif action == "ban" then
		if not targetUserId then 
			message = "Jogador '" .. (targetPlayerName or "nil") .. "' não encontrado!"
		else
			local reason = params[2] or "Banned by admin"
			local BanDataStore = DataStoreService:GetDataStore("BannedPlayers")
			local pcallSuccess_ban, error_ban = pcall(function()
				BanDataStore:SetAsync(tostring(targetUserId), {
					Reason = reason, BannedBy = playerName, Timestamp = os.time()
				})
			end)

			if pcallSuccess_ban then
				if targetPlayer then -- Se estiver online, kicka.
					targetPlayer:Kick("Você foi banido do servidor. Motivo: " .. reason)
				end
				success = true
				message = "Jogador " .. targetPlayerName .. " foi banido! Motivo: " .. reason
			else
				message = "Erro ao banir jogador: " .. tostring(error_ban)
			end
		end
	elseif action == "clearplanet" then
		if not targetPlayer then -- Este comando só funciona para jogadores online
			message = "Erro: O jogador '" .. (targetPlayerName or "nil") .. "' precisa estar neste servidor para ter o planeta limpo."
		else
			FarmingService:ClearAllPlayerPlants(targetPlayer)
			BuildingService:ClearPlayerObjects(targetPlayer)
			success = true
			message = "Planeta de " .. targetPlayer.Name .. " foi completamente limpo!"
		end
	elseif action == "tpto" then
		message = "Comando click-teleport usado pelo painel administrativo local."
	elseif action == "tp" then
		if not params or #params < 2 then
			message = "Uso: /tp <jogador1> <jogador2> ou /tp <jogador> <x> <y> <z>"
		else
			local player1 = findPlayer(params[1])
			if not player1 then
				message = "Jogador '" .. params[1] .. "' não encontrado!"
			else
				local player2 = findPlayer(params[2])
				if player2 then
					if player1.Character and player1.Character:FindFirstChild("HumanoidRootPart") and player2.Character and player2.Character:FindFirstChild("HumanoidRootPart") then
						player1.Character.HumanoidRootPart.CFrame = player2.Character.HumanoidRootPart.CFrame
						success = true
						message = player1.Name .. " foi teleportado para " .. player2.Name
					else
						message = "Um dos jogadores não tem personagem válido!"
					end
				else
					local x, y, z = tonumber(params[2]), tonumber(params[3]), tonumber(params[4])
					if x and y and z then
						if player1.Character and player1.Character:FindFirstChild("HumanoidRootPart") then
							player1.Character.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
							success = true
							message = player1.Name .. " foi teleportado para (" .. x .. ", " .. y .. ", " .. z .. ")"
						else
							message = "Jogador não tem personagem válido!"
						end
					else
						message = "Coordenadas inválidas ou jogador de destino não encontrado!"
					end
				end
			end
		end
	else
		message = `Comando não encontrado.`
	end

	return message
end

return EcclesiaConsole

