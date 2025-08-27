--// Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Player
local player = Players.LocalPlayer

--// UI Modules
local SeedShopUI = require(ReplicatedStorage.Modules.SeedShopUi)
local DecorationShopUI = require(ReplicatedStorage.Modules.DecorationShopModule)
local NotificationManager = require(ReplicatedStorage.Modules.NotificationModule)

--// Remotes
local ShopAction = ReplicatedStorage.RemoteFunctions.Shop:WaitForChild('ShopAction')
local GlobalRestockEvent = ReplicatedStorage.RemoteEvents.Shop:WaitForChild("GlobalRestock")


--// Control
local restockConnection
local isInitialized = false -- 

-- Função para iniciar o timer da UI que é compartilhado por todas as lojas
local function StartUITimer()
	if restockConnection then restockConnection:Disconnect() end

	local tickCounter = 0
	restockConnection = RunService.Heartbeat:Connect(function()
		tickCounter += 1
		if tickCounter >= 60 then 
			tickCounter = 0
			local success, result = pcall(function()
				return ShopAction:InvokeServer("getRestockTime") -- Ação global, não precisa de categoria
			end)

			if success and result.success then
				-- Atualiza o timer em ambas as UIs (as funções internas já verificam se a UI existe)
				SeedShopUI:UpdateRestockTimer(result.timeLeft)
				DecorationShopUI:UpdateRestockTimer(result.timeLeft)
			end
		end
	end)
end


-- Função de inicialização principal
local function Initialize()
	if isInitialized then return end
	isInitialized = true

	--print("🛒 ShopInputController inicializado!")
	pcall(function() SeedShopUI:Initialize() end)
	pcall(function() DecorationShopUI:Initialize() end)

	GlobalRestockEvent.OnClientEvent:Connect(function(message)
		print("📡 Restock global notificado pelo servidor:", message)

		if SeedShopUI.IsOpen then SeedShopUI:UpdateExistingItems() end
		if DecorationShopUI.IsOpen then DecorationShopUI:UpdateExistingItems() end

		NotificationManager.ShowNotification("🛍️ A loja foi reabastecida!", Color3.fromRGB(40, 167, 69))
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.L then -- Tecla para a Loja de Sementes
			SeedShopUI:ToggleUI()
		elseif input.KeyCode == Enum.KeyCode.Y then -- Tecla para a Loja de Decorações
			DecorationShopUI:ToggleUI()
		end
	end)

	StartUITimer()
end

-- Init
task.spawn(Initialize)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player and restockConnection then
		restockConnection:Disconnect()
	end
end)