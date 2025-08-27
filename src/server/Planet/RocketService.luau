local RocketService = {}
local RemoteFunctions = game:GetService("ReplicatedStorage").RemoteFunctions.Rocket
local Players = game:GetService("Players")
local BuildingService = require(game:GetService("ServerScriptService").Game.BuildingService)
local CollectionService = game:GetService("CollectionService") 
local HttpService = game:GetService("HttpService") 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local objectClickedEvent = ReplicatedStorage.RemoteFunctions.Building:WaitForChild("ObjectClickedEvent")
local PlanetOwnershipChangedEvent = ReplicatedStorage.RemoteEvents.Permissions:WaitForChild("PlanetOwnershipChanged")
local UpdateLocationEvent = ReplicatedStorage.RemoteEvents.Rocket:WaitForChild("UpdatePlayerLocation")

local PlaySoundEvent = ReplicatedStorage.RemoteEvents.SoundsEffects:WaitForChild("PlaySoundForClient")


RocketService.PlayerLocations = {}

RocketService.PlanetsList = {
	{
		Name = "Lobby",
		Position = workspace.Lobby.Rocket.Base.Position,
		IsLobby = true 
	}
}

function CheckPlayerOwnership(player)
	if not player or not player.Name then
		return nil
	end
	for i, planet in ipairs(RocketService.PlanetsList) do
		if planet.Owner and player.Name == planet.Owner then
			return planet
		end
	end
	return nil
end


function RocketService:GetPlayerCurrentPlanet(player)
	return self.PlayerLocations[player.UserId]
end

-- Função para atualizar a imagem do jogador no planeta
function UpdatePlanetOwnerDisplay(planet, player)
	if not planet.Folder then return end
	local planetOwnerGui = planet.Folder:FindFirstChild("PlanetOwnerGui")
	if not planetOwnerGui then return end

	local billboardGui = planetOwnerGui:FindFirstChildOfClass("BillboardGui")
	if not billboardGui then return end

	local playerDisplay = billboardGui:FindFirstChild("PlayerDisplay")
	if not playerDisplay or not playerDisplay:IsA("ImageLabel") then return end

	if player then
		-- Jogador possui o planeta - ativar BillboardGui e mostrar avatar
		billboardGui.Enabled = true
		playerDisplay.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=420&height=420&format=png"
	else
		-- Planeta não tem dono - desativar BillboardGui
		billboardGui.Enabled = false
		playerDisplay.Image = ""
	end
end
-- Função para obter a posição ATUAL da plataforma de um planeta
function GetLivePlanetCFrame(planetName) -- Renomeado para maior clareza
	for _, planet in ipairs(RocketService.PlanetsList) do
		if planet.Name == planetName then
			if planet.IsLobby then 
				return CFrame.new(planet.Position) 
			end

			local platform = planet.Folder and planet.Folder:FindFirstChild("Platform")
			if platform and platform.PrimaryPart then -- Garante que tem PrimaryPart
				return platform:GetPivot() -- GetPivot() retorna o CFrame
			else
				return CFrame.new(planet.Position) -- Fallback
			end
		end
	end
	return nil
end


-- Função para obter configuração da câmera para um planeta
function GetPlanetCameraConfig(planetName)
	local planetCF = GetLivePlanetCFrame(planetName) -- Usa a nova função
	if planetCF then
		return {
			Position = planetCF.Position + Vector3.new(0, 15, 25),
			
			LookAt = planetCF.Position,
		
			LandingCFrame = planetCF 
		}
	end
	-- Fallback padrão
	return {
		Position = Vector3.new(0, 15, 25),
		LookAt = Vector3.new(0, 0, 0),
		LandingCFrame = CFrame.new(0, 0, 0)
	}
end

function RocketService:ClearPlayerPlanetOwnership(player)
	if not player then return end

	local ownedPlanet = self.CheckPlayerOwnership(player)
	if ownedPlanet then
		print(`[RocketService] Limpando dados do planeta {ownedPlanet.Name} para o jogador que saiu: {player.Name}`)
		ownedPlanet.Owner = nil
		if ownedPlanet.Folder then
			ownedPlanet.Folder:SetAttribute("Owner", nil)
		end
		self.UpdatePlanetOwnerDisplay(ownedPlanet, nil)
	end

	if self.PlayerLocations[player.UserId] then
		self.PlayerLocations[player.UserId] = nil
	end
end

function RocketService:Initialize()
	-- Carregar planetas do workspace
	for i, Planet in ipairs(workspace.Planets:GetChildren()) do
		local platformModel = Planet:FindFirstChild("Platform") 
		if platformModel then
			table.insert(RocketService.PlanetsList, {
				Name = Planet.Name,
				Folder = Planet,
				Position = platformModel:GetPivot().Position, 
				Owner = nil
			})
		end
	end

	-- Verificar planetas que já têm donos ao inicializar
	for i, planet in ipairs(RocketService.PlanetsList) do
		if planet.IsLobby then continue end

		local ownerAttribute = planet.Folder:GetAttribute("Owner")
		if ownerAttribute then
			local player = Players:FindFirstChild(ownerAttribute)
			if player then
				planet.Owner = ownerAttribute
				UpdatePlanetOwnerDisplay(planet, player)
			else
				planet.Folder:SetAttribute("Owner", nil)
				UpdatePlanetOwnerDisplay(planet, nil)
			end
		else
			UpdatePlanetOwnerDisplay(planet, nil)
		end
	end
	--Players.PlayerRemoving:Connect(function(player)
	--	local ownedPlanet = CheckPlayerOwnership(player)
	--	if ownedPlanet then
	--		print(`[RocketService] Limpando dados do planeta {ownedPlanet.Name} para o jogador que saiu: {player.Name}`)
	--		ownedPlanet.Owner = nil
	--		if ownedPlanet.Folder then
	--			ownedPlanet.Folder:SetAttribute("Owner", nil)
	--		end
	--		UpdatePlanetOwnerDisplay(ownedPlanet, nil)
	--	end
	--	RocketService.PlayerLocations[player.UserId] = nil
	--end)

	UpdateLocationEvent.OnServerEvent:Connect(function(player, destinationName)
		RocketService:UpdatePlayerLocation(player, destinationName)
	end)
	
	RemoteFunctions.PlanetsFunction.OnServerInvoke = function(player, action, ...)
		local params = {...}
		if action == "GetPlanetsList" then
			local PermissionsService = require(script.Parent.PermissionsService)
			local filteredList = {}
			local playerOwnsPlanet = CheckPlayerOwnership(player)

			local function createPlanetEntry(planet)
				return {
					Name = planet.Name,
					Position = GetLivePlanetCFrame(planet.Name).Position, 
					Owner = planet.Owner,
					IsLobby = planet.IsLobby or false
				}
			end

			for _, planet in ipairs(RocketService.PlanetsList) do
				if planet.IsLobby then
					table.insert(filteredList, createPlanetEntry(planet))
					continue
				end
				if playerOwnsPlanet and planet.Name == playerOwnsPlanet.Name then
					table.insert(filteredList, createPlanetEntry(planet))
					continue
				end
				if not planet.Owner and not playerOwnsPlanet then
					table.insert(filteredList, createPlanetEntry(planet))
					continue
				end
				if planet.Owner and planet.Owner ~= player.Name then
					local ownerPlayer = Players:FindFirstChild(planet.Owner)
					if ownerPlayer and PermissionsService:HasVisitorPermission(ownerPlayer, player) then
						table.insert(filteredList, createPlanetEntry(planet))
					end
				end
			end

			return filteredList

		elseif action == "GetCameraConfig" then
			local planetName = params[1]
			if planetName then
				return GetPlanetCameraConfig(planetName)
			end
			return nil

		elseif action == "OwnPlanet" then
			if CheckPlayerOwnership(player) then
				return false, "AlreadyOwnAPlanet"
			end

			for i, planet in ipairs(RocketService.PlanetsList) do
				if planet.IsLobby then continue end

				if params[1] == planet.Name then
					planet.Owner = player.Name
					planet.Folder:SetAttribute("Owner", player.Name)
					local platform = planet.Folder:FindFirstChild("Platform")
					if platform then
						local platformUUID = platform:GetAttribute("UUID") or "Platform_" .. HttpService:GenerateGUID(false)

						platform:SetAttribute("UUID", platformUUID)
						platform:SetAttribute("Owner", player.Name)
						platform:SetAttribute("ItemName", "Plataforma de Pouso")
						platform:SetAttribute("Category", "Special")
						platform:SetAttribute("CannotStore", true) 

						if not CollectionService:HasTag(platform, "built_item") then
							CollectionService:AddTag(platform, "built_item")
						end
						print(`[RocketService] Plataforma do planeta ${planet.Name} configurada para o jogador ${player.Name}.`)
						
						if platform.PrimaryPart then
							-- Remove qualquer detector antigo
							for _, child in ipairs(platform.PrimaryPart:GetChildren()) do
								if child:IsA("ClickDetector") then child:Destroy() end
							end
							-- Adiciona o novo
							local clickDetector = Instance.new("ClickDetector")
							clickDetector.MaxActivationDistance = 128
							clickDetector.Parent = platform.PrimaryPart

							clickDetector.MouseClick:Connect(function(clickedPlayer)
								-- A plataforma pertence ao 'player' desta função
								if clickedPlayer == player then
									objectClickedEvent:FireClient(player, platform)
								end
							end)
						end
					end
					RocketService.PlayerLocations[player.UserId] = planet.Name
					UpdatePlanetOwnerDisplay(planet, player)
					BuildingService:LoadPlanet(player, planet.Name)
					PlanetOwnershipChangedEvent:FireClient(player) 

					return true, "Planeta " .. planet.Name .. " agora é seu!"
				end
			end
			return false, "Planeta não encontrado"
		end
		
	end
	--print("RocketService inicializado com " .. #RocketService.PlanetsList .. " planetas")
end



function RocketService:UpdatePlayerLocation(player, destinationName)
	if not player or not destinationName then return end
	print(`[RocketService] Atualizando localização de ${player.Name} para ${destinationName}`)
	self.PlayerLocations[player.UserId] = destinationName
	
	PlaySoundEvent:FireClient(player, "TeleportSound")
	
	-- faz parte do tutorial
	if destinationName == "Lobby" then
		ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent:Fire(player, "ArrivedAtLobby")
	else
		ReplicatedStorage.BindableEvents.Tutorial.TutorialProgressEvent:Fire(player, "ArrivedAtPlanet")
	end
end


RocketService.CheckPlayerOwnership = CheckPlayerOwnership
RocketService.UpdatePlanetOwnerDisplay = UpdatePlanetOwnerDisplay

return RocketService