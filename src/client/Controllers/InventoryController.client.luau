--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Variables
local Player = Players.LocalPlayer
local UpdatePlayerData = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UpdatePlayerData")
local InventoryGUI = Player.PlayerGui:WaitForChild("InventorySystem")
local Hotbar = InventoryGUI:WaitForChild("MainFrame"):WaitForChild("Hotbar")

--// Modules
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)

--// Initial Setup
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
InventoryGUI.Enabled = true

-- Pre-set attributes for hotbar slots, as they are static
for i, slot in ipairs(Hotbar:GetChildren()) do
	if slot:IsA("Frame") then
		slot:SetAttribute("OriginalSize", slot.Size)
		slot:SetAttribute("OriginalColor", slot.BackgroundColor3)
		slot:SetAttribute("OriginalTransparency", slot.Transparency)
	end
end

-- Initialize the module

InventoryModule:InitializeHotbarEvents()

--// Connections
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.B then
		InventoryModule:ToggleBackpack()
	end

	-- Hotbar keybinds (1-9, 0)
	local numberKeys = {
		[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
		[Enum.KeyCode.Zero] = 0,
	}

	local slotNumber = numberKeys[input.KeyCode]
	if slotNumber then
		InventoryModule:Equip(slotNumber)
	end
end)

-- Listen for data updates from the server
UpdatePlayerData.OnClientEvent:Connect(function(dataStoreName, value)
	if dataStoreName == "Inventory-v0" then
		InventoryModule:UpdateInventoryData(value)
	end
end)