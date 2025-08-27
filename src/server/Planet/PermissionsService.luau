local PermissionsService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RocketFolder = ReplicatedStorage.RemoteEvents.Rocket
local PermissionsFunction = ReplicatedStorage.RemoteFunctions:WaitForChild("Permissions")
local ForceTravelEvent = RocketFolder:WaitForChild("ForceTravelToLobby")
local NotifyPlayerEvent = ReplicatedStorage.RemoteEvents.Shop:WaitForChild("NotifyPlayer")
local DataStoreModule = require(game:GetService("ServerScriptService").Data.DataStoreModule)

local PERMISSIONS_DATASTORE_NAME = "PlanetPermissions_v1"
local RocketService 

local permissionsCache = {}



function PermissionsService:GetOwnerPermissions(ownerPlayer)
	local ownerUserId = ownerPlayer.UserId
	if permissionsCache[ownerUserId] then
		return permissionsCache[ownerUserId]
	end

	local permissionsDataStore = DataStoreModule.GetDataStore(ownerPlayer, PERMISSIONS_DATASTORE_NAME)
	local savedPermissions = permissionsDataStore:GetData({}) 

	permissionsCache[ownerUserId] = savedPermissions
	return savedPermissions
end

function PermissionsService:HasVisitorPermission(ownerPlayer, visitorPlayer)
	if not ownerPlayer or not visitorPlayer then return false end

	local ownerPermissions = self:GetOwnerPermissions(ownerPlayer)


	return ownerPermissions[tostring(visitorPlayer.UserId)] == true
end

function PermissionsService:Initialize()
	RocketService = require(script.Parent.RocketService)

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		permissionsCache[userId] = nil 
	end)

	PermissionsFunction.OnServerInvoke = function(player, action, ...)
		local params = {...}
		local ownerUserId = player.UserId

		if action == "SetVisitorPermission" then
			local targetUserId = params[1]
			local isAllowed = params[2]

			local targetPlayer = Players:GetPlayerByUserId(targetUserId)
			
			
			local ownerPermissions = PermissionsService:GetOwnerPermissions(player)
			if isAllowed then
				ownerPermissions[tostring(targetUserId)] = true
			else
				ownerPermissions[tostring(targetUserId)] = nil 
			end
			local permissionsDataStore = DataStoreModule.GetDataStore(player, PERMISSIONS_DATASTORE_NAME)
			permissionsDataStore:SetData(ownerPermissions)

			print(`[Permissions] Permissão para ${targetUserId} foi ${isAllowed and "CONCEDIDA" or "REMOVIDA"} por ${player.Name}`)
			
			if not isAllowed and targetPlayer then
				local ownedPlanet = RocketService.CheckPlayerOwnership(player)
				if ownedPlanet then
					local targetPlanetName = RocketService:GetPlayerCurrentPlanet(targetPlayer)
					if targetPlanetName and targetPlanetName == ownedPlanet.Name then
						print(`[Permissions] Ejetando ${targetPlayer.Name} do planeta de ${player.Name}.`)
						local message = "🚫 Você foi removido do planeta de " .. player.Name
						local ejectionColor = Color3.fromRGB(255, 87, 34) 
						NotifyPlayerEvent:FireClient(targetPlayer, message, nil, ejectionColor)

						
						local lobbyCFrame = RocketService:GetLivePlanetCFrame("Lobby")
						if lobbyCFrame and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
							
							task.wait(0.2) 
							targetPlayer.Character:SetPrimaryPartCFrame(lobbyCFrame)
							RocketService:UpdatePlayerLocation(targetPlayer, "Lobby") 
						end
					end
				end
			end

			return true 

		elseif action == "GetMyPlanetPermissions" then
			if not RocketService.CheckPlayerOwnership(player) then
				return nil
			end

			local ownerPermissions = PermissionsService:GetOwnerPermissions(player)
			local allowedVisitorIds = {}
			for visitorId, isAllowed in pairs(ownerPermissions) do
				if isAllowed then
					-- O DataStore salva a chave como string, então convertemos de volta se necessário
					table.insert(allowedVisitorIds, tonumber(visitorId) or visitorId)
				end
			end
			return allowedVisitorIds 
		end

		return false, "Ação desconhecida."
	end

	--print("✅ PermissionsService (COM PERSISTÊNCIA) inicializado.")
end

return PermissionsService