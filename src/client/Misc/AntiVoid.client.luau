local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local VOID_Y_LEVEL = -1000

local function onCharacterAdded(character)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")
	local connection
	 connection = RunService.Heartbeat:Connect(function()
			
		if not character or not humanoidRootPart then
			connection:Disconnect()
			return
		end

	if humanoidRootPart.Position.Y < VOID_Y_LEVEL then
		local spawnLocation = workspace.Lobby.others:FindFirstChild("SpawnLocation")
		if spawnLocation then
			humanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(0,5,0)
		else
			humanoidRootPart.CFrame  = CFrame.new(0,10,0)
		
		end
	end
end)


character.AncestryChanged:Connect(function()
	if not character.Parent then
		connection:Disconnect()
	end
end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

