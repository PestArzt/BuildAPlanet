
--// SERVIÇOS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BuildingModule = require(ReplicatedStorage.Modules.BuildingModule) 

local Player = Players.LocalPlayer

BuildingModule:Init()

local function initializeController()
	local backpack = Player:WaitForChild("Backpack")
	local equippedItemValue = backpack:WaitForChild("EquippedItem")

	equippedItemValue.Changed:Connect(function()
		if not equippedItemValue.Value and BuildingModule:IsBuildModeActive() then
			BuildingModule:ExitBuildMode()
		end
	end)
	if not equippedItemValue.Value and BuildingModule:IsBuildModeActive() then
		BuildingModule:ExitBuildMode()
	end
end

if Player.Character then
	initializeController()
else
	Player.CharacterAdded:Once(function(character)
		initializeController()
	end)
end