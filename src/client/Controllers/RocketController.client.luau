--[[
    Mod By Lorris (6/29/2025) v.02
    LocalScript para controlar foguetes (Integrado)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Módulos
local RocketModule = require(ReplicatedStorage.Modules:WaitForChild("RocketModule"))
--local DestinationsModule = require(ReplicatedStorage.Modules:WaitForChild("DestinationsModule"))


local RemoteFunctions = ReplicatedStorage.RemoteFunctions.Rocket

local GUIModule = require(ReplicatedStorage.Modules:WaitForChild("GUIModule"))

-- Variáveis da GUI
local isInitialized = false
local isGUIOpen = false

-- Variáveis do highlight
local rocketHighlight = nil

local isPlayerNearRocket = false

-- Função para encontrar o foguete
local function findRocket()
	local rocket = workspace.Lobby:FindFirstChild("Rocket")
	if not rocket then
		rocket = workspace:FindFirstChild("Rocket")
	end
	return rocket
end

-- Função para criar highlight no foguete
local function createRocketHighlight()
	if rocketHighlight then return end

	local rocket = findRocket()
	if not rocket then return end

	rocketHighlight = Instance.new("Highlight")
	rocketHighlight.Name = "RocketHighlight_" .. player.Name
	rocketHighlight.Adornee = rocket
	rocketHighlight.FillColor = Color3.fromRGB(0, 255, 255) -- Azul ciano
	rocketHighlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- Branco
	rocketHighlight.FillTransparency = 0.8
	rocketHighlight.OutlineTransparency = 0
	rocketHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	rocketHighlight.Parent = rocket
end

-- Função para remover highlight do foguete
local function removeRocketHighlight()
	if rocketHighlight then
		rocketHighlight:Destroy()
		rocketHighlight = nil
	end
end

-- Função para inicializar a GUI
local function initializeGUI()
	if isInitialized then return end
	GUIModule:Proximity()
	isInitialized = true
end

-- Função para verificar se está próximo do foguete
local function isNearRocket()
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return false
	end

	local rocket = findRocket()
	if not rocket or not rocket.PrimaryPart then
		return false
	end

	local distance = (player.Character.HumanoidRootPart.Position - rocket.PrimaryPart.Position).Magnitude
	return distance <= 30
end

-- Função para atualizar proximidade do foguete
local function updateRocketProximity()
	if not player.Character then return end

	local nearRocket = isNearRocket()

	-- Se mudou o estado de proximidade
	if nearRocket ~= isPlayerNearRocket then
		isPlayerNearRocket = nearRocket

		if nearRocket then
			createRocketHighlight()
		else
			removeRocketHighlight()
		end
	end
end


-- Conectar eventos do jogador
player.CharacterAdded:Connect(function()
	task.wait(1) 
	initializeGUI()

end)

if player.Character then
	task.wait(1)
	initializeGUI()
end

-- Loop principal para atualizar proximidade
RunService.Heartbeat:Connect(updateRocketProximity)

-- Limpeza quando jogador sai
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		removeRocketHighlight()
	end
end)

-- Scripts de debug comentados (descomente se necessário)
--UserInputService.InputBegan:Connect(function(input, gameProcessed)
--    if gameProcessed then return end
--
--    -- Tecla L para listar destinos (debug)
--    if input.KeyCode == Enum.KeyCode.L then
--        print("=== DESTINOS DISPONÍVEIS ===")
--        local destinations = DestinationsModule.GetAllDestinations()
--        for name, data in pairs(destinations) do
--            print(name .. " - " .. data.DisplayName .. " - Posição: " .. tostring(data.Position))
--        end
--    end
--
--    -- Tecla K para voo direto ao Planet1 (debug)
--    if input.KeyCode == Enum.KeyCode.K then
--        if isNearRocket() then
--            local success, message = RocketModule:FlyTo("Planet1")
--            if success then
--                GUIModule:ShowNotification("✅ Debug", message or "Voo iniciado!")
--            else
--                GUIModule:ShowNotification("❌ Debug", message or "Falha no voo!")
--            end
--        else
--            GUIModule:ShowNotification("❌ Debug", "Você precisa estar próximo do foguete!")
--        end
--    end
--end)