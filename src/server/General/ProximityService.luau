local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ProximityHandler = {}

-- CONFIG
local INTERACTION_DISTANCE = 8 
local SHOP_CONFIGS = { 
	Seeds = { npcName = "ShopNPC" },
	Decorations = { npcName = "DecorationNPC" }
}

local playerStates = {} 


local ProximityUpdateEvent = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("ProximityUpdateEvent")

function ProximityHandler:findClosestNPC(player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return nil, nil end

	local playerPos = character.HumanoidRootPart.Position
	local closestNPC, closestShopType, closestDist = nil, nil, INTERACTION_DISTANCE
	for shopType, config in pairs(SHOP_CONFIGS) do
		for _, npc in pairs(workspace.Npcs:GetChildren()) do
			if npc.Name == config.npcName and npc:FindFirstChild("HumanoidRootPart") then
				local distance = (playerPos - npc.HumanoidRootPart.Position).Magnitude
				if distance < closestDist then
					closestNPC = npc
					closestShopType = shopType
					closestDist = distance
				end
			end
		end
	end

	return closestNPC, closestShopType
end


function ProximityHandler:Initialize()
	local function checkPlayersProximity()
		for _, player in ipairs(Players:GetPlayers()) do
			local closestNPC, shopType = self:findClosestNPC(player)
			if closestNPC ~= playerStates[player] then

				playerStates[player] = closestNPC
				ProximityUpdateEvent:FireClient(player, shopType, closestNPC)

				local npcName = closestNPC and closestNPC.Name or "nenhum"
				--print(`Servidor: Proximidade de {player.Name} atualizada para {npcName} (Tipo: {shopType or "nil"})`)
			end
		end
	end
	RunService.Heartbeat:Connect(checkPlayersProximity)
	Players.PlayerAdded:Connect(function(player)
		playerStates[player] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	--print("Proximity Service [SERVER] iniciado.")
end

return ProximityHandler