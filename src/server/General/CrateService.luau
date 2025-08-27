local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService").Server

-- Módulos e Serviços
local InventoryService = require(ServerScriptService.Player.InventoryService)
local ItemData = require(ServerScriptService.Data.ItemData)
local CrateData = require(ServerScriptService.Data.CrateData)
local BuildingService = require(ServerScriptService.Building.BuildingService) 

-- Remotes
local CrateRemotes = ReplicatedStorage:FindFirstChild("RemoteEvents"):FindFirstChild("CrateRemote")
local OpenCrateRequest = CrateRemotes:FindFirstChild("OpenCrateRequest") 
-- local ShowCrateOpening = CrateRemotes:FindFirstChild("ShowCrateOpening") 
local PlayOpeningAnimation = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Harvest"):WaitForChild("PlayOpeningAnimation")

local CrateService = {}

local function rollForItem(lootTable)
	local totalWeight = 0
	for _, item in ipairs(lootTable) do
		totalWeight += item.Weight
	end

	local randomNumber = math.random(1, totalWeight)
	local currentWeight = 0

	for _, item in ipairs(lootTable) do
		currentWeight += item.Weight
		if randomNumber <= currentWeight then
			return item -- Item sorteado!
		end
	end
end

local function onOpenCrateRequest(player, crateType, crateInstance)
	
	if not crateInstance or not crateInstance.Parent then
		return
	end

	local ownerName = crateInstance:GetAttribute("Owner")
	if not ownerName or ownerName ~= player.Name then
		warn("ACESSO NEGADO: O jogador " .. player.Name .. " tentou abrir uma caixa que pertence a " .. tostring(ownerName) .. ".")
		return 
	end


	local cratePivot = crateInstance:GetPivot()
	local crateUUID = crateInstance:GetAttribute("UUID")

	if not crateUUID then
		warn("Caixa sem UUID não pode ser aberta de forma segura. Removendo manualmente.", crateInstance:GetFullName())
		crateInstance:Destroy()
		return
	end

	local crateConfig = CrateData[crateType]
	if not crateConfig then
		warn("Jogador", player.Name, "tentou abrir uma caixa com configuração inválida:", crateType)
		return
	end

	local wonItemInfo = rollForItem(crateConfig.LootTable)
	if not wonItemInfo then
		warn("Falha ao sortear item para a caixa:", crateType); return
	end

	local itemDataMaster = ItemData:GetItem(wonItemInfo.Category, wonItemInfo.Name)
	if not itemDataMaster then
		warn("Dados mestre não encontrados para o item ganho:", wonItemInfo.Name); return
	end

	InventoryService:Add(player, {
		Name = wonItemInfo.Name,
		Category = wonItemInfo.Category,
		Stackable = itemDataMaster.Stackable,
		Quantity = 1,
		Locked = false
	})
	print("Jogador", player.Name, "ganhou:", wonItemInfo.Name, "da caixa", crateType)

	
	local success, reason = BuildingService:RemoveObject(player, crateUUID, false, false)
	if not success then
		warn("Falha ao remover a caixa via BuildingService (Motivo:", reason, "). A animação não será reproduzida.")
		if crateInstance and crateInstance.Parent then crateInstance:Destroy() end 
		return
	end
	PlayOpeningAnimation:FireClient(player, crateType, "Crates", cratePivot, wonItemInfo)
end

function CrateService:Initialize()
	OpenCrateRequest.OnServerEvent:Connect(onOpenCrateRequest)
	--print("CrateService inicializado com sucesso!")
end

return CrateService