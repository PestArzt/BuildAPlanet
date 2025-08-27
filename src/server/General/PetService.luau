--[[
	PetController Module v3.4
	Sistema unificado de pets com gravidade, animações e head tracking robusto.
    - Adicionado comportamento de Roam mais natural com ciclos de Idle/Wander.
    - Adicionado sistema de Ponto de Interesse (POI) para o pet olhar ao redor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local PetSystem = ReplicatedStorage:WaitForChild("PetSystem")
local EffectsFolder = ReplicatedStorage:WaitForChild("Effects")
local HeartsFX = EffectsFolder:WaitForChild("HeartsFX")    

local GravityModule = require(PetSystem.Modules.GravityModule)
local PetModelTemplate = PetSystem.Assets:WaitForChild("PigPet")
local InventoryService = require(game.ServerScriptService.Player.InventoryService) 
local ItemData = require(game.ServerScriptService.Data.ItemData)
local ResetGravityEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ResetGravityControllerEvent")
local PetDataService = require(game:GetService("ServerScriptService").Data.PetDataService)


local PetActionEvent = PetSystem.RemoteEvents:WaitForChild("PetAction")
local PetStateUpdateEvent = PetSystem.RemoteEvents:WaitForChild("PetStateUpdate")


local PetController = {}


local ActivePetsFolder = workspace:FindFirstChild("ActivePetsFolder")
if not ActivePetsFolder then
	ActivePetsFolder = Instance.new("Folder")
	ActivePetsFolder.Name = "ActivePetsFolder"
	ActivePetsFolder.Parent = workspace
end

--// Configurações

local PET_RIDE_CONFIG = {
	RIDE_SPEED = 70,
	RIDE_TURN_SPEED = 15,
	SADDLE_OFFSET = CFrame.new(0, 1, 0),
	SMOOTHING_FACTOR = 12,
	MAX_MOUNT_DISTANCE = 100
}

local FORMATION_CONFIG = {
	ENABLED = true,
	-- A distância MÍNIMA base, antes de adicionar o tamanho do pet.
	BASE_MIN_DISTANCE = 4, 
	-- A distância MÁXIMA base.
	BASE_MAX_DISTANCE = 12,
	-- Multiplicador para o "espaço pessoal". 2 = um diâmetro de distância. 3 = mais folgado.
	PET_SPACING_MULTIPLIER = 3.0, 
	ANGLE_ARC = 180,
	STOP_DISTANCE_FORMATION = 1.5,
	OFFSET_SMOOTHING = 5.0 
}

local PET_CONFIG = {
	FOLLOW_DISTANCE = 10,
	STOP_DISTANCE = 6,
	MAX_SPEED = 20,
	TURN_SPEED = 0.2,
	PATH_NODE_DISTANCE = 4,
	PATH_LOOKAHEAD = 15,
	OBSTACLE_CHECK_HEIGHT = 2,
	PATH_RECALC_INTERVAL = 0.5,
	MOVEMENT_SMOOTHING = 10,
	ROAM_CONFIG = {
		WANDER_DURATION = {Min = 8, Max = 15},
		IDLE_DURATION = {Min = 4, Max = 8},
		MAX_TURN_ANGLE = 70,
		WANDER_DISTANCE = {Min = 15, Max = 30},
		POI_SEARCH_RADIUS = 25,
		
		ANTI_STUCK_CONFIG = {
			TELEPORT_FAILSAFE_DISTANCE = 200 
		},
	},
JUMP_CONFIG = {
		ENABLED = true,
		JUMP_COOLDOWN = 0.5,
		MIN_OBSTACLE_HEIGHT = 0.5, 
		MAX_OBSTACLE_HEIGHT = 6.0, 
		JUMP_CLEARANCE = 2.5,
		JUMP_MAX_DURATION = 3.0, 
	},
	PATHFINDING_CONFIG = {
		AgentRadius = 2,
		AgentHeight = 3,
		AgentCanJump = true,
		WaypointSpacing = 4,
		Costs = {
			Jump = 5, 
		}
	},
}

local HEAD_TRACKING_CONFIG = {
	ENABLED = true,
	SMOOTHING_SPEED = 0.05,
	MAX_YAW_ANGLE = math.rad(75),
	MAX_PITCH_ANGLE = math.rad(60),
	HEAD_TRACKING_DISTANCE = 20,
}

--// Armazenamento
local ActivePets = {}


function PetController:countActivePetsForPlayer(player)
	local count = 0
	for _, petData in ipairs(ActivePets) do
		if petData.OwnerId == player.UserId then
			count = count + 1
		end
	end
	return count
end

function PetController:countActivePetsByName(player, itemName)
	local count = 0
	for _, petData in ipairs(ActivePets) do
		if petData.OwnerId == player.UserId and petData.ItemName == itemName then
			count = count + 1
		end
	end
	return count
end


local function _changePetState(petData, newState)
	if petData.State == "Sit" then
		petData.AnimTracks.Sit:Stop()
		if not petData.AnimTracks.Idle.IsPlaying then
			petData.AnimTracks.Idle:Play() 
		end
	end

	
	petData.State = newState
	petData.Model:SetAttribute("State", newState)

	petData.Path = {}
	petData.LastPathRecalc = 0
	petData.NextRoamActionTime = 0 
	petData.RoamState = "Idle" 

	if newState == "Sit" then
		petData.AnimTracks.Idle:Stop()
		petData.AnimTracks.Walk:Stop()
		petData.AnimTracks.Sit:Play()
	end
end

local function createBuffDisplayGui(model, itemData)
	if not itemData.Buffs then return end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "BuffDisplayGui" then
			child:Destroy()
		end
	end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "BuffDisplayGui"
	billboardGui.Size = UDim2.new(4, 0, 1.5, 0)
	billboardGui.StudsOffset = Vector3.new(0, model:GetExtentsSize().Y / 2 + 2, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 40
	billboardGui.Parent = model

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(255, 230, 128)
	textLabel.Parent = billboardGui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(60, 40, 0)
	uiStroke.Thickness = 1.5
	uiStroke.Parent = textLabel

	local buffText = {}
	if itemData.Buffs.MoneyBonus and itemData.Buffs.MoneyBonus > 0 then
		table.insert(buffText, string.format("💰 +%.0f%% Money", itemData.Buffs.MoneyBonus * 100))
	end
	if itemData.Buffs.GrowthSpeedBonus and itemData.Buffs.GrowthSpeedBonus > 0 then
		table.insert(buffText, string.format("🌿 +%.0f%% Growth", itemData.Buffs.GrowthSpeedBonus * 100))
	end

	textLabel.Text = table.concat(buffText, "\n")
end

function PetController:_calculateXPForPetLevel(level)
	return 50 * (level ^ 1.5)
end


-- Calcular os buffs totais do pet com base no nível
function PetController:_calculateBuffs(petMasterData, level)
	local calculatedBuffs = {}
	if not petMasterData.Buffs then return calculatedBuffs end
	
	-- O bônus é aplicado sobre o valor BASE do buff
	local levelBonusMultiplier = (level - 1) * (petMasterData.BuffIncreasePerLevel or 0)

	for buffName, baseValue in pairs(petMasterData.Buffs) do
		calculatedBuffs[buffName] = baseValue + (baseValue * levelBonusMultiplier)
	end
	return calculatedBuffs
end


--// Funções de Spawn
local function _internalSpawnPet(player, itemName, existingData, initialWorldCF, petInstanceData)
	local itemData = ItemData:GetItem("Pets", itemName)

	local petTemplate = PetSystem.Assets:FindFirstChild(itemName)
	if not petTemplate then
		warn(string.format("PetController: Modelo de template '%s' não encontrado!", itemName))
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local petModel = petTemplate:Clone()
	local petRoot = petModel:WaitForChild("HumanoidRootPart")
	petRoot.Anchored = true

	local _, size = petModel:GetBoundingBox()
	local petRadius = math.max(size.X, size.Z) / 2

	local humanoid = petModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("Modelo de pet sem Humanoide - animações não funcionarão")
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator", humanoid)
	end


	petModel:SetAttribute("Owner", player.UserId)

	if initialWorldCF then
		petModel:PivotTo(initialWorldCF)
	else
		petModel:PivotTo(rootPart.CFrame * CFrame.new(0, 0, -PET_CONFIG.FOLLOW_DISTANCE))
	end
	petModel.Parent = ActivePetsFolder 

	--if itemData and itemData.Buffs then
	--	createBuffDisplayGui(petModel, itemData)
	--end


	for _, part in ipairs(petModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Pets"
		end
	end

	local torso = petModel:WaitForChild("Torso")
	local headPart = petModel:WaitForChild("Head")
	local neckMotor = torso:FindFirstChild("Head", true) 
	if not (neckMotor and neckMotor:IsA("Motor6D") and neckMotor.Part1 == headPart) then
		neckMotor = nil 
	end
	local jumpDetectorPart = petModel:FindFirstChild("JumpDetector") or torso


	local animIds = itemData.AnimationIds
	if not animIds then
		warn("Pet " .. itemName .. " não tem uma tabela 'AnimationIds' em seu ItemData!")
		return 
	end

	local animIdle = Instance.new("Animation")
	animIdle.AnimationId = animIds.Idle
	local animWalk = Instance.new("Animation")
	animWalk.AnimationId = animIds.Walk
	local animSit = Instance.new("Animation")
	animSit.AnimationId = animIds.Sit

	local idleTrack = animator:LoadAnimation(animIdle)
	local walkTrack = animator:LoadAnimation(animWalk)
	local sitTrack = animator:LoadAnimation(animSit)
	idleTrack.Looped = true
	walkTrack.Looped = true
	sitTrack.Looped = true
	walkTrack.Priority = Enum.AnimationPriority.Action
	sitTrack.Priority = Enum.AnimationPriority.Action

	local petUUID, petLevelData

	if petInstanceData and petInstanceData.UUID then
		print(string.format("[PetController] Spawning pet '%s' from inventory for %s.", itemName, player.Name))
		petUUID = petInstanceData.UUID
		petLevelData = {
			Level = petInstanceData.Level or 1,
			XP = petInstanceData.XP or 0
		}
	elseif existingData and existingData.UUID then
		--print(string.format("[PetController] Loading existing pet '%s' (UUID: %s) from planet for %s.", itemName, existingData.UUID, player.Name))
		petUUID = existingData.UUID
		petLevelData = PetDataService:GetPetData(player, petUUID)
	else
		print(string.format("[PetController] Creating brand new pet '%s' for %s.", itemName, player.Name))
		petUUID = HttpService:GenerateGUID(false)
		petLevelData = PetDataService:GetPetData(player, petUUID) 
	end

	local calculatedBuffs = PetController:_calculateBuffs(itemData, petLevelData.Level)
	local initialState = (existingData and existingData.State) or (petInstanceData and petInstanceData.State) or "Follow"
	petModel:SetAttribute("State", initialState)
	

	local petData = {
		UUID = petUUID,
		ItemName = itemName,
		Model = petModel,
		Owner = player, 
		OwnerId = player.UserId, 
		State = initialState,
		Level = petLevelData.Level, 
		XP = petLevelData.XP,       
		MasterData = itemData,    
		CalculatedBuffs = calculatedBuffs,
		Torso = torso,
		JumpDetectorPart = jumpDetectorPart,
		Path = {},
		LastPathRecalc = 0,
		AnimTracks = { Idle = idleTrack, Walk = walkTrack, Sit = sitTrack }, -- [[Modification Em Breve Wender track]]
		IsMoving = false,
		NeckMotor = neckMotor,
		OriginalNeckC1 = neckMotor and neckMotor.C1 or nil,
		LookAtTarget = rootPart,
		RoamState = "Idle",
		NextRoamActionTime = 0,
		IsJumping = false,
		LastJumpTime = 0,
		StuckTimer = 0,
		LastPosition = petRoot.Position,
		IsPhasing = false,
		IsCosmeticHopping = false,
		CosmeticHopStartTime = 0,
		LastCosmeticHopTime = 0,
		ObstacleGracePeriodEndTime = 0,
		TargetFormationOffset = CFrame.new(),
		PetRadius = petRadius,
		JumpDirection = Vector3.new(), 
		JumpStartPosition = Vector3.new(), 
		JumpStartTime = 0, 
		JumpDuration = 0.8, 
		JumpHeight = 0,
		LastJumpObstacleModelRef = nil,
	}

	local itemData = ItemData:GetItem("Pets", itemName)
	if itemData and itemData.CanRide then
		petModel:SetAttribute("CanRide", true)
	end
	petModel:SetAttribute("PetUUID", petData.UUID)
	petModel:SetAttribute("Level", petData.Level)
	petModel:SetAttribute("XP", petData.XP)
	petModel:SetAttribute("MaxXP", PetController:_calculateXPForPetLevel(petData.Level + 1))
	petModel:SetAttribute("MaxLevel", itemData.MaxLevel or 99)
	petModel:SetAttribute("ItemName", itemName)

	petModel:SetAttribute("ImageId", itemData.ImageId or "")
	petModel:SetAttribute("BuffIncreasePerLevel", itemData.BuffIncreasePerLevel or 0)
	if itemData.Buffs then
		petModel:SetAttribute("BaseBuffs", HttpService:JSONEncode(itemData.Buffs))
	end

	if itemData.Buffs then
		createBuffDisplayGui(petModel, { Buffs = calculatedBuffs })
	end

	CollectionService:AddTag(petModel, "Pet")
	table.insert(ActivePets, petData) 

	idleTrack:Play()
end



local function dismountPet(petData)
	if not petData or petData.State ~= "Riding" or not petData.Rider then return end

	local player = petData.Rider
	local character = player.Character

	petData.Rider = nil
	petData.State = "Follow" 
	petData.IsMoving = false 

	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local ridePart = petData.Model:FindFirstChild("Rideable")
		if not ridePart then return end 
		local weld = ridePart:FindFirstChild("RiderWeld")
		if weld then weld:Destroy() end
		if humanoid then humanoid.PlatformStand = false end
	end
	ResetGravityEvent:FireClient(player) 

	print(player.Name .. " desmontou de " .. petData.ItemName)
end

local function mountPet(player, petData)
	-- Esta verificação já existe no seu código e é ótima. Ela impede o bug no nível do servidor.
	for _, anyActivePet in ipairs(ActivePets) do
		if anyActivePet.Rider == player then
			warn(player.Name .. " já está montado em um pet, não pode montar em outro.")
			return 
		end
	end

	if petData.State == "Riding" then return end 
	if not petData.Model:GetAttribute("CanRide") then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local ridePart = petData.Model:FindFirstChild("Rideable")
	if not (humanoid and rootPart and ridePart) then return end
	if petData.AnimTracks.Sit.IsPlaying then
		petData.AnimTracks.Sit:Stop()
	end
	if petData.AnimTracks.Walk.IsPlaying then
		petData.AnimTracks.Walk:Stop()
	end
	if not petData.AnimTracks.Idle.IsPlaying then
		petData.AnimTracks.Idle:Play()
	end
	
	petData.State = "Riding"
	petData.Rider = player
	petData.Path = {} --Reset da tabela

	petData.MovementInput = Vector3.new(0, 0, 0)
	petData.IsMoving = false
	humanoid.PlatformStand = true 
	rootPart.CFrame = ridePart.CFrame * PET_RIDE_CONFIG.SADDLE_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RiderWeld"
	weld.Part0 = ridePart
	weld.Part1 = rootPart
	weld.Parent = ridePart

	--print(player.Name .. " montou em " .. petData.ItemName)
end

--// Funções de Head Tracking
local function updateHeadTracking(petData)
	if not HEAD_TRACKING_CONFIG.ENABLED or not petData.NeckMotor or not petData.LookAtTarget then
		return
	end

	local neck = petData.NeckMotor
	local torso = neck.Part0 
	local originalC1 = petData.OriginalNeckC1

	local targetPosition
	if typeof(petData.LookAtTarget) == "Instance" and petData.LookAtTarget:IsA("BasePart") then
		targetPosition = petData.LookAtTarget.Position
	elseif typeof(petData.LookAtTarget) == "Vector3" then
		targetPosition = petData.LookAtTarget
	else
		neck.C1 = neck.C1:Lerp(originalC1, HEAD_TRACKING_CONFIG.SMOOTHING_SPEED)
		return
	end

	local distance = (torso.Position - targetPosition).Magnitude
	if distance > HEAD_TRACKING_CONFIG.HEAD_TRACKING_DISTANCE then
		neck.C1 = neck.C1:Lerp(originalC1, HEAD_TRACKING_CONFIG.SMOOTHING_SPEED)
		return
	end

	local targetPositionInLocalSpace = torso.CFrame:PointToObjectSpace(targetPosition + Vector3.new(0, 1, 0))
	local neckPivotInLocalSpace = neck.C0.Position
	local localLookDirection = (targetPositionInLocalSpace - neckPivotInLocalSpace)

	if localLookDirection.Magnitude < 0.1 then return end

	local localRotation = CFrame.lookAt(Vector3.zero, localLookDirection)
	local _, pitch, yaw, _ = localRotation:ToEulerAnglesYXZ()

	local clampedYaw = math.clamp(yaw, -HEAD_TRACKING_CONFIG.MAX_YAW_ANGLE, HEAD_TRACKING_CONFIG.MAX_YAW_ANGLE)
	local clampedPitch = math.clamp(-pitch, -HEAD_TRACKING_CONFIG.MAX_PITCH_ANGLE, HEAD_TRACKING_CONFIG.MAX_PITCH_ANGLE)

	local finalRotation = CFrame.fromEulerAnglesYXZ(clampedYaw, clampedPitch, 0)
	local targetC1 = originalC1 * finalRotation

	neck.C1 = neck.C1:Lerp(targetC1, HEAD_TRACKING_CONFIG.SMOOTHING_SPEED)
end

--// Funções de Pathfinding
local function findPointOfInterest(petData)
	local petRoot = petData.Model.PrimaryPart
	local searchRadius = PET_CONFIG.ROAM_CONFIG.POI_SEARCH_RADIUS

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {petData.Model, petData.Owner.Character}

	local partsInRadius = workspace:GetPartBoundsInRadius(petRoot.Position, searchRadius, params)

	local potentialTargets = {}
	for _, part in ipairs(partsInRadius) do
		if part.Anchored and not part.CanCollide and part.Transparency > 0.5 then continue end
		if part.Size.Magnitude > 50 then continue end
		table.insert(potentialTargets, part)
	end

	if #potentialTargets > 0 then
		return potentialTargets[math.random(1, #potentialTargets)]
	end

	return nil
end

local function generatePath(petData, targetPosition)
	local petRoot = petData.Model.PrimaryPart
	if not petRoot then return end

	local distanceToTarget = (petRoot.Position - targetPosition).Magnitude
	if distanceToTarget > PET_CONFIG.ROAM_CONFIG.ANTI_STUCK_CONFIG.TELEPORT_FAILSAFE_DISTANCE then
		warn("Pet " .. petData.ItemName .. " está muito longe do dono. Teleportando.")
		local ownerRoot = petData.Owner.Character and petData.Owner.Character.PrimaryPart
		if ownerRoot then
			local offset = CFrame.new(math.random(-8, 8), 0, math.random(-8, 8))
			local targetCF = ownerRoot.CFrame * offset
			local projectedPos, groundNormal = GravityModule.projectOntoSurface(targetCF.Position, {petData.Model, petData.Owner.Character})

			if projectedPos and groundNormal then
				local safeCF = CFrame.new(projectedPos + groundNormal * (petRoot.Size.Y / 2))
				petData.Model:SetPrimaryPartCFrame(safeCF)
			else
				petData.Model:SetPrimaryPartCFrame(ownerRoot.CFrame * CFrame.new(0, 3, -PET_CONFIG.FOLLOW_DISTANCE))
			end
		end
		petData.Path = {}
		return
	end

	local path = PathfindingService:CreatePath(PET_CONFIG.PATHFINDING_CONFIG)
	local success, errorMessage = pcall(function()
		path:ComputeAsync(petRoot.Position, targetPosition)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		warn("Pathfinding falhou para o pet: " .. petData.ItemName .. ". Erro: " .. tostring(errorMessage) .. ". Status: " .. tostring(path.Status))
		petData.Path = {}
		return
	end

	local waypoints = path:GetWaypoints()
	petData.Path = waypoints
	if #waypoints > 1 and (waypoints[1].Position - petRoot.Position).Magnitude < 1 then
		table.remove(waypoints, 1)
	end
end

local function generateWanderPath(petData, now)
	local petModel = petData.Model
	local petRoot = petModel.PrimaryPart
	local player = petData.Owner

	local _, groundNormal = GravityModule.projectOntoSurface(petRoot.Position, {petModel, player.Character}, "PetRaycast")
	if groundNormal then
		local currentFwd = petRoot.CFrame.LookVector
		local randomAngle = math.rad(math.random(-PET_CONFIG.ROAM_CONFIG.MAX_TURN_ANGLE, PET_CONFIG.ROAM_CONFIG.MAX_TURN_ANGLE))
		local newDir = CFrame.fromAxisAngle(groundNormal, randomAngle) * currentFwd
		local wanderDist = math.random(PET_CONFIG.ROAM_CONFIG.WANDER_DISTANCE.Min * 0.7, PET_CONFIG.ROAM_CONFIG.WANDER_DISTANCE.Max * 0.9)
		local roamTargetPos = petRoot.Position + newDir * wanderDist
		generatePath(petData, roamTargetPos)
		petData.LastPathRecalc = now
	end
end

local function FindModelRoot(part)
	if not part or not part.Parent then return nil end
	local currentAncestor = part
	while currentAncestor.Parent and currentAncestor.Parent ~= workspace do
		if currentAncestor:IsA("Model") and (currentAncestor.PrimaryPart or currentAncestor:FindFirstChildOfClass("Humanoid")) then
			return currentAncestor
		end
		currentAncestor = currentAncestor.Parent
	end
	return (currentAncestor:IsA("Model") and currentAncestor) or part
end

local function updateAndGetNaturalFormationOffset(petData, siblingPets, myIndex, dt)
	if myIndex == 0 then return petData.TargetFormationOffset end 

	local targetAngle, targetDistance
	local numPets = #siblingPets

	if numPets == 1 then
		targetAngle = 0
		local personalDistance = FORMATION_CONFIG.BASE_MIN_DISTANCE + (petData.PetRadius * FORMATION_CONFIG.PET_SPACING_MULTIPLIER)
		targetDistance = (personalDistance + FORMATION_CONFIG.BASE_MAX_DISTANCE) / 2
	else
		local arcRadians = math.rad(FORMATION_CONFIG.ANGLE_ARC)
		local baseAngle = -arcRadians/2 + (arcRadians / (numPets - 1)) * (myIndex - 1)

		local hash = (petData.UUID:byte(5) + petData.UUID:byte(10) + petData.UUID:byte(15)) % 100 / 100
		local anglePerturbation = math.rad(15) * (hash - 0.5) 
		targetAngle = baseAngle + anglePerturbation
		local personalMinDistance = FORMATION_CONFIG.BASE_MIN_DISTANCE + (petData.PetRadius * FORMATION_CONFIG.PET_SPACING_MULTIPLIER)
		local personalMaxDistance = FORMATION_CONFIG.BASE_MAX_DISTANCE + (petData.PetRadius * FORMATION_CONFIG.PET_SPACING_MULTIPLIER)
		targetDistance = personalMinDistance + (personalMaxDistance - personalMinDistance) * hash

	end

	local idealOffset = CFrame.Angles(0, targetAngle, 0) * CFrame.new(0, 0, -targetDistance)
	local lerpFactor = math.clamp(dt * FORMATION_CONFIG.OFFSET_SMOOTHING, 0, 1)
	petData.TargetFormationOffset = petData.TargetFormationOffset:Lerp(idealOffset, lerpFactor)

	return petData.TargetFormationOffset
end

local PetStates = {}

function PetStates.Follow(petData, dt, siblingPets, playerRoot, currentCF, now)
	petData.LookAtTarget = playerRoot

	if FORMATION_CONFIG.ENABLED then
		local myIndex = 0
		for i, sibling in ipairs(siblingPets) do
			if sibling.UUID == petData.UUID then
				myIndex = i
				break
			end
		end

		local formationOffsetCF = updateAndGetNaturalFormationOffset(petData, siblingPets, myIndex, dt)
		local targetWorldCF = playerRoot.CFrame * formationOffsetCF
		local targetPosition = targetWorldCF.Position
		local distanceToSlot = (targetPosition - currentCF.Position).Magnitude

		if distanceToSlot > FORMATION_CONFIG.STOP_DISTANCE_FORMATION then
			local moveDir = (targetPosition - currentCF.Position).Unit
			local goalPos = currentCF.Position + moveDir * math.min(PET_CONFIG.MAX_SPEED * dt, distanceToSlot)
			return true, moveDir, goalPos, targetPosition
		else
			return false, Vector3.zero, currentCF.Position, playerRoot.Position
		end
	else 
		local distance = (playerRoot.Position - currentCF.Position).Magnitude
		if distance > PET_CONFIG.STOP_DISTANCE then
			local moveDir = (playerRoot.Position - currentCF.Position).Unit
			local goalPos = currentCF.Position + moveDir * math.min(PET_CONFIG.MAX_SPEED * dt, distance)
			return true, moveDir, goalPos, playerRoot.Position
		end
	end

	return false, Vector3.zero, currentCF.Position, playerRoot.Position
end

function PetStates.Roam(petData, dt, siblingPets, playerRoot, currentCF, now)
	local petModel = petData.Model
	if now > petData.NextRoamActionTime then
		if petData.RoamState == "Idle" then
			petData.AnimTracks.Sit:Stop()

			petData.RoamState = "Wandering"
			local wanderTime = math.random(PET_CONFIG.ROAM_CONFIG.WANDER_DURATION.Min, PET_CONFIG.ROAM_CONFIG.WANDER_DURATION.Max)
			petData.NextRoamActionTime = now + wanderTime
			petData.LookAtTarget = nil
			generateWanderPath(petData, now)
		else 
			petData.RoamState = "Idle"
			local idleTime = math.random(PET_CONFIG.ROAM_CONFIG.IDLE_DURATION.Min, PET_CONFIG.ROAM_CONFIG.IDLE_DURATION.Max)
			petData.NextRoamActionTime = now + idleTime
			petData.Path = {}
			local poi = findPointOfInterest(petData)
			petData.LookAtTarget = poi or playerRoot

			petData.AnimTracks.Walk:Stop()
			petData.AnimTracks.Sit:Play()
		end
	end

	if #petData.Path > 0 then
		local waypoint = petData.Path[1]
		local projectedWaypointPos, _ = GravityModule.projectOntoSurface(waypoint.Position, {petModel, playerRoot.Parent}, "PetRaycast")
		local targetNodePos = projectedWaypointPos or waypoint.Position

		local moveDir = (targetNodePos - currentCF.Position).Unit
		local goalPos = currentCF.Position + moveDir * math.min(PET_CONFIG.MAX_SPEED * dt, (targetNodePos - currentCF.Position).Magnitude)

		if (targetNodePos - currentCF.Position).Magnitude < 2.5 then
			table.remove(petData.Path, 1)
		end

		return true, moveDir, goalPos, targetNodePos
	else
		local lookAt = (typeof(petData.LookAtTarget) == "Instance" and petData.LookAtTarget.Position) or petData.LookAtTarget or playerRoot.Position
		return false, Vector3.zero, currentCF.Position, lookAt
	end
end

function PetStates.Sit(petData, dt, siblingPets, playerRoot, currentCF, now)
	petData.LookAtTarget = playerRoot
	return false, Vector3.zero, currentCF.Position, nil
end

local function updatePet(petData, dt, now, siblingPets)
	local player = petData.Owner
	if not player or not player.Parent or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		if petData.Model then petData.Model:Destroy() end
		for i, pData in ipairs(ActivePets) do if pData == petData then table.remove(ActivePets, i); break end end
		return
	end
	if petData.State == "Riding" then
		if not petData.Rider or not petData.Rider.Character then
			dismountPet(petData)
			return
		end

		if petData.NeckMotor then
			petData.NeckMotor.C1 = petData.NeckMotor.C1:Lerp(petData.OriginalNeckC1, HEAD_TRACKING_CONFIG.SMOOTHING_SPEED)
		end

		local petModel = petData.Model
		local petRoot = petModel.PrimaryPart
		local currentCF = petRoot.CFrame
		local moveInput = petData.MovementInput or Vector3.new(0, 0, 0)

		local isCurrentlyMoving = moveInput.Magnitude > 0.1
		local turn = -moveInput.X * PET_RIDE_CONFIG.RIDE_TURN_SPEED * dt
		local move = -moveInput.Z * PET_RIDE_CONFIG.RIDE_SPEED * dt
		local rotationCF = CFrame.Angles(0, turn, 0)

		local targetCF
		if isCurrentlyMoving then
			local newPos = currentCF.Position + (currentCF.LookVector * move)
			local projectedPos, groundNormal = GravityModule.projectOntoSurface(newPos, {petModel, player.Character}, "PetRaycast")

			if projectedPos and groundNormal then
				local moveDirection = (currentCF * rotationCF).LookVector 
				local surfaceRotation = GravityModule.calculateSurfaceOrientation(moveDirection, groundNormal, currentCF * rotationCF)
				targetCF = CFrame.new(projectedPos + groundNormal * (petRoot.Size.Y / 2)) * surfaceRotation.Rotation
			else
				warn("Pet " .. petData.ItemName .. " perdeu contato com o chão durante a montaria. Aplicando apenas rotação.")
				targetCF = CFrame.new(currentCF.Position) * (currentCF.Rotation * rotationCF.Rotation)
			end
		else
			local projectedPos, groundNormal = GravityModule.projectOntoSurface(currentCF.Position, {petModel, player.Character}, "PetRaycast")
			if projectedPos and groundNormal then
				targetCF = CFrame.new(projectedPos + groundNormal * (petRoot.Size.Y / 2)) * currentCF.Rotation
			else
				targetCF = currentCF
			end
		end

		local lerpFactor = math.clamp(dt * PET_RIDE_CONFIG.SMOOTHING_FACTOR, 0, 1)
		petModel:SetPrimaryPartCFrame(currentCF:Lerp(targetCF, lerpFactor))

		if isCurrentlyMoving and not petData.IsMoving then
			petData.AnimTracks.Walk:Play()
			petData.IsMoving = true
		elseif not isCurrentlyMoving and petData.IsMoving then
			petData.AnimTracks.Walk:Stop()
			petData.IsMoving = false
		end
		return
	end

	local petModel = petData.Model
	local petRoot = petModel.PrimaryPart
	local playerRoot = player.Character.HumanoidRootPart
	local currentCF = petRoot.CFrame

	-- Variáveis que serão definidas pela State Machine
	local isCurrentlyMoving = false
	local moveDirection = Vector3.zero
	local goalPosition = currentCF.Position
	local goalLookAt = playerRoot.Position

	-- Executa a função do estado atual
	local currentStateFunction = PetStates[petData.State]
	if currentStateFunction then
		isCurrentlyMoving, moveDirection, goalPosition, goalLookAt = currentStateFunction(petData, dt, siblingPets, playerRoot, currentCF, now)
	end

	local jumpConfig = PET_CONFIG.JUMP_CONFIG
	local currentJumpHeightOffset = 0

	if petData.IsJumping then
		local progress = math.clamp((now - petData.JumpStartTime) / petData.JumpDuration, 0, 1)
		local alpha = math.sin(progress * math.pi) 
		currentJumpHeightOffset = petData.JumpHeight * alpha

		if progress >= 1 then
			petData.IsJumping = false
			petData.LastJumpObstacleModelRef = nil
		end
	elseif isCurrentlyMoving and jumpConfig.ENABLED and (now - petData.LastJumpTime) > jumpConfig.JUMP_COOLDOWN then
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		local ignoreList = {petModel, player.Character}
		local closestPlanet = GravityModule.findClosestPlanet(petRoot.Position)
		if closestPlanet then table.insert(ignoreList, closestPlanet) end
		overlapParams.FilterDescendantsInstances = ignoreList
		local touchingParts = workspace:GetPartsInPart(petData.JumpDetectorPart, overlapParams)

		if #touchingParts > 0 then
			local primaryObstacleModel, maxObstacleCeilingY, processedModels = nil, -math.huge, {}
			for _, part in ipairs(touchingParts) do
				if not part.CanCollide then continue end
				local model = FindModelRoot(part)
				if model and not processedModels[model] then
					processedModels[model] = true
					local boxCF, boxSize = model:GetBoundingBox()
					local modelCeilingY = boxCF.Position.Y + (boxSize.Y / 2)
					if modelCeilingY > maxObstacleCeilingY then
						maxObstacleCeilingY, primaryObstacleModel = modelCeilingY, model
					end
				end
			end
			if primaryObstacleModel and primaryObstacleModel ~= petData.LastJumpObstacleModelRef then
				local petBaseY = currentCF.Position.Y - (petRoot.Size.Y / 2)
				local requiredHeight = maxObstacleCeilingY - petBaseY
				if requiredHeight >= jumpConfig.MIN_OBSTACLE_HEIGHT and requiredHeight <= jumpConfig.MAX_OBSTACLE_HEIGHT then
					petData.IsJumping, petData.LastJumpTime, petData.JumpStartTime = true, now, now
					petData.JumpHeight = requiredHeight + jumpConfig.JUMP_CLEARANCE
					petData.LastJumpObstacleModelRef = primaryObstacleModel
				end
			end
		end
	end

	local projectedPos, groundNormal = GravityModule.projectOntoSurface(goalPosition, {petModel, player.Character}, "PetRaycast")
	local basePosition = projectedPos or goalPosition
	local finalPosition = basePosition + (groundNormal or Vector3.y) * currentJumpHeightOffset

	local targetCF
	if groundNormal then
		local finalRotation
		if goalLookAt then
			local lookAtPosFlat = CFrame.new(currentCF.Position, goalLookAt)
			finalRotation = GravityModule.calculateSurfaceOrientation(Vector3.new(), groundNormal, lookAtPosFlat).Rotation
		else
			finalRotation = GravityModule.calculateSurfaceOrientation(Vector3.new(), groundNormal, currentCF).Rotation
		end
		targetCF = CFrame.new(finalPosition + groundNormal * (petRoot.Size.Y / 2)) * finalRotation
	else
		local finalRotation = goalLookAt and CFrame.lookAt(currentCF.Position, goalLookAt).Rotation or currentCF.Rotation
		targetCF = CFrame.new(finalPosition) * finalRotation
	end

	local lerpFactor = math.clamp(dt * PET_CONFIG.MOVEMENT_SMOOTHING, 0, 1)
	local newCFrame = currentCF:Lerp(targetCF, lerpFactor)
	petModel:SetPrimaryPartCFrame(newCFrame)

	updateHeadTracking(petData)

	if isCurrentlyMoving and not petData.IsMoving then
		petData.AnimTracks.Walk:Play()
		petData.IsMoving = true
	elseif not isCurrentlyMoving and petData.IsMoving then
		petData.AnimTracks.Walk:Stop()
		petData.IsMoving = false
	end
end

--// Funções de Limpeza
local function cleanupPet(player)
	for i = #ActivePets, 1, -1 do
		local petData = ActivePets[i]
		if petData.OwnerId == player.UserId then
			if petData.Rider == player then
				dismountPet(petData)
			end
			if petData.AnimTracks then
				petData.AnimTracks.Idle:Stop()
				petData.AnimTracks.Walk:Stop()
			end
			if petData.Model then
				petData.Model:Destroy()
			end
			table.remove(ActivePets, i)
		end
	end
end

--// Funções de Comando

local function _getPetFromUUID(player, petUUID)
	if not petUUID then 
		warn("Comando de pet recebido sem UUID para o jogador: " .. player.Name)
		return nil 
	end

	for _, petData in ipairs(ActivePets) do
		if petData.OwnerId == player.UserId and petData.UUID == petUUID then
			return petData
		end
	end

	warn("Pet com UUID " .. petUUID .. " não encontrado para o jogador " .. player.Name)
	return nil
end

local function _storePet(player, petData)
	local petItem = {
		Name = petData.ItemName, 
		Category = "Pets",
		Stackable = false, 
		Quantity = 1,
		Locked = false,
		UUID = petData.UUID,
		Level = petData.Level,
		XP = petData.XP,
	}

	local success, message = InventoryService:Add(player, petItem)

	if success then
		-- Encontra o índice para remoção segura
		for i, pData in ipairs(ActivePets) do
			if pData.UUID == petData.UUID then
				if pData.Model then pData.Model:Destroy() end
				table.remove(ActivePets, i)
				break
			end
		end
	else
		warn(string.format("Falha ao guardar pet %s para %s. Motivo: %s", petData.ItemName, player.Name, message or "Inventário cheio?"))
	end
end

local function onPetAction(player, actionName, payload)
	if type(payload) ~= "table" then return end

	local petData = _getPetFromUUID(player, payload.PetUUID)
	if not petData then return end
	
	-- Bloco de segurança para comandos em pets montados
	local isRidingAction = (actionName == "Dismount" or actionName == "UpdateMovement")
	if petData.State == "Riding" and not isRidingAction then
		warn(string.format("Jogador %s tentou executar a ação '%s' em um pet montado. Ação bloqueada.", player.Name, actionName))
		return
	end

	--// ================== DISPATCHER DE AÇÕES ==================
	if actionName == "Follow" or actionName == "Roam" then
		if petData.State ~= actionName then
			_changePetState(petData, actionName)
		end

	elseif actionName == "Sit" then
		if petData.State == "Sit" then
			_changePetState(petData, "Roam")
		else
			_changePetState(petData, "Sit")
		end

	elseif actionName == "Store" then
		_storePet(player, petData)

	elseif actionName == "Mount" then
		local character = player.Character
		local petModel = petData.Model
		if not (character and character.PrimaryPart and petModel and petModel.PrimaryPart) then return end

		local distance = (character.PrimaryPart.Position - petModel.PrimaryPart.Position).Magnitude
		if distance > PET_RIDE_CONFIG.MAX_MOUNT_DISTANCE then
			warn(string.format("Falha ao montar: %s está muito longe do pet (%.1f > %.1f studs).", player.Name, distance, PET_RIDE_CONFIG.MAX_MOUNT_DISTANCE))
			return 
		end
		
		mountPet(player, petData)
		PetStateUpdateEvent:FireClient(player, "RideStarted", { PetUUID = petData.UUID })

	elseif actionName == "Dismount" then
		dismountPet(petData)
		PetStateUpdateEvent:FireClient(player, "RideEnded", { PetUUID = petData.UUID })

	elseif actionName == "UpdateMovement" then
		if petData.State == "Riding" and typeof(payload.MoveVector) == "Vector3" then
			petData.MovementInput = payload.MoveVector
		end

	elseif actionName == "Feed" then
		local plantName = payload.FoodName
		if typeof(plantName) == "string" then
			PetController:FeedPet(player, payload.PetUUID, plantName)
		end
	end
end


function PetController:FeedPet(player, petUUID, plantName)
	local BuildingService = require(script.Parent.BuildingService)
	-- pet ativo
	local petData = nil
	for _, p in ipairs(ActivePets) do
		if p.UUID == petUUID and p.OwnerId == player.UserId then
			petData = p
			break
		end
	end
	if not petData then return {success = false, message = "Pet não encontrado."} end
	if petData.Level >= (petData.MasterData.MaxLevel or 99) then
		return {success = false, message = "Este pet já atingiu o nível máximo!"}
	end
	if not InventoryService:HasItem(player, plantName, 1) then
		return {success = false, message = "Você não tem esta planta no inventário."}
	end


	local seedName = ItemData:GetSeedFromPlant(plantName)
	if not seedName then
		return {success = false, message = "Dados da planta não encontrados."}
	end
	local seedData = ItemData:GetItem("Seeds", seedName)

	if not seedData or not seedData.Experience then
		return {success = false, message = "Esta planta não concede XP."}
	end

	local removed = InventoryService:Remove(player, plantName, 1)
	if not removed then
		return {success = false, message = "Não foi possível remover o item do inventário."}
	end
	if petData.Model and petData.Model.Parent then
		local head = petData.Model:FindFirstChild("Head")
		if head then
			local existingEffect = head:FindFirstChild("FeedEffect")
			if existingEffect then
				existingEffect:Destroy()
			end
			local newEffect = HeartsFX:Clone()
			newEffect.Name = "FeedEffect"
			newEffect.Parent = head
			Debris:AddItem(newEffect, 1)
		end
	end


	petData.XP = petData.XP + seedData.Experience
	local xpNeeded = self:_calculateXPForPetLevel(petData.Level + 1)
	local maxLevel = petData.MasterData.MaxLevel or 99

	local leveledUp = false
	while petData.XP >= xpNeeded and petData.Level < maxLevel do
		petData.XP = petData.XP - xpNeeded
		petData.Level = petData.Level + 1
		xpNeeded = self:_calculateXPForPetLevel(petData.Level + 1)
		leveledUp = true
	end

	if leveledUp then
		-- Recalcula os buffs APÓS o loop
		petData.CalculatedBuffs = self:_calculateBuffs(petData.MasterData, petData.Level)


		-- Atualiza os atributos para o cliente
		if petData.Model and petData.Model.Parent then
			petData.Model:SetAttribute("CalculatedBuffs", HttpService:JSONEncode(petData.CalculatedBuffs))
			createBuffDisplayGui(petData.Model, { Buffs = petData.CalculatedBuffs })
		end
	end

	PetDataService:UpdatePetData(player, petData.UUID, {Level = petData.Level, XP = petData.XP})

	if petData.Model and petData.Model.Parent then
		petData.Model:SetAttribute("Level", petData.Level)
		petData.Model:SetAttribute("XP", petData.XP)
		petData.Model:SetAttribute("MaxXP", xpNeeded)
	end

	BuildingService:UpdateAndNotifyClientBuffs(player)

	return {success = true, message = "Pet alimentado com sucesso!"}
end

--// Funções Publics
function PetController.Initialize()
	local PhysicsService = game:GetService("PhysicsService")
	local PLANET_COLLISION_GROUP, PET_RAYCAST_GROUP = "PlanetSurface", "PetRaycast"
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLANET_COLLISION_GROUP) 
		PhysicsService:RegisterCollisionGroup(PET_RAYCAST_GROUP)    
		PhysicsService:CollisionGroupSetCollidable(PLANET_COLLISION_GROUP, PET_RAYCAST_GROUP, true)
	end)
	local function setCollisionGroupRecursive(object)
		if object:IsA("BasePart") then object.CollisionGroup = PLANET_COLLISION_GROUP end
		for _, child in ipairs(object:GetChildren()) do setCollisionGroupRecursive(child) end
	end
	for _, planetInstance in ipairs(CollectionService:GetTagged("planet")) do
		setCollisionGroupRecursive(planetInstance)
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local petsByOwner = {}
		for _, petData in ipairs(ActivePets) do
			local ownerId = petData.OwnerId
			if not petsByOwner[ownerId] then petsByOwner[ownerId] = {} end
			table.insert(petsByOwner[ownerId], petData)
		end

		for _, petList in pairs(petsByOwner) do
			table.sort(petList, function(a, b) return a.UUID < b.UUID end)
		end

	
		for _, petData in ipairs(ActivePets) do
			local siblingPets = petsByOwner[petData.OwnerId] or {}
			local success, err = pcall(updatePet, petData, dt, now, siblingPets)
			if not success then
				warn(string.format("Erro ao atualizar o pet %s (UUID: %s): %s", petData.ItemName, petData.UUID, tostring(err)))
			end
		end
	end)
	
	PetActionEvent.OnServerEvent:Connect(onPetAction)
end	
function PetController.SpawnPetForPlayer(player, itemName, petInstanceData)
	_internalSpawnPet(player, itemName, petInstanceData, nil) 
	return true, "Pet invocado com sucesso."
end
function PetController:SerializeActivePets(player, planetModel)
	local serializedData = {}
	if not planetModel then
		warn("[PetController] Não foi possível serializar pets: planetModel é nulo.")
		return serializedData
	end

	for _, petData in ipairs(ActivePets) do
		if petData.OwnerId == player.UserId and petData.Model and petData.Model.PrimaryPart and petData.Model.Parent then
			local petWorldCF = petData.Model:GetPivot()
			local relativeCF = planetModel:GetPivot():ToObjectSpace(petWorldCF)

			local simplePetData = {
				UUID = petData.UUID,
				ItemName = petData.ItemName,
				State = petData.State,
				Cf = table.pack(relativeCF:GetComponents()) 
			}
			table.insert(serializedData, simplePetData)
		end
	end
	return serializedData
end

function PetController:LoadAndSpawnPets(player, savedPetsData, planetModel)
	if not savedPetsData or #savedPetsData == 0 then return end

	if not planetModel then
		warn("[PetController] Não foi possível carregar pets: planetModel é nulo.")
		return
	end

	cleanupPet(player)

	for _, petInfo in ipairs(savedPetsData) do
		local initialWorldCF = nil
		if petInfo.Cf then
			local relativeCF = CFrame.new(table.unpack(petInfo.Cf))
			initialWorldCF = planetModel:GetPivot():ToWorldSpace(relativeCF)
		end
		_internalSpawnPet(player, petInfo.ItemName, petInfo, initialWorldCF)
	end
end
function PetController:ClearPlayerPetsAndData(player)
	cleanupPet(player)
	print(`[PetController] Pets ativos para ${player.Name} foram limpos da memória.`)
end

function PetController.GetActivePets()
	return ActivePets
end

function PetController.GetPetConfig()
	return PET_CONFIG
end

return PetController