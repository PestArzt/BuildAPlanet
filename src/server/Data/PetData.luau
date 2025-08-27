local DataStoreModule = require(game:GetService("ServerScriptService").Server.DataStoreModule)
local HttpService = game:GetService("HttpService")

local PetDataService = {}
PetDataService.DATASTORE_NAME = "PetInstanceData_v1"

local defaultPetData = {
	Level = 1,
	XP = 0,
}

-- Obtém todos os dados de pets de um jogador (do cache do DataStoreModule)
function PetDataService:GetAllPetData(player)
	local petDataStore = DataStoreModule.GetDataStore(player, self.DATASTORE_NAME)
	return petDataStore:GetData({})
end

-- Obtém dados para um pet específico. Se não existir, cria e retorna dados padrão.
function PetDataService:GetPetData(player, uuid)
	local allPetData = self:GetAllPetData(player)
	if not allPetData[uuid] then
		-- Cria dados padrão para um novo pet
		allPetData[uuid] = table.clone(defaultPetData)
		print(`[PetDataService] Criando dados padrão para o novo pet UUID: ${uuid}`)
	end
	return allPetData[uuid]
end

-- Atualiza os dados de um pet específico no cache.
function PetDataService:UpdatePetData(player, uuid, newPetData)
	local allPetData = self:GetAllPetData(player)
	allPetData[uuid] = newPetData
end

-- Limpa o UUID de um pet quando ele é "destruído" (ex: trocado por algo)
function PetDataService:DeletePetData(player, uuid)
	local allPetData = self:GetAllPetData(player)
	allPetData[uuid] = nil
end

-- Função chamada pelo DataStoreModule para preparar os dados antes do save final.
function PetDataService:PrepareForSave(player)
	local data = self:GetAllPetData(player)
	DataStoreModule.GetDataStore(player, self.DATASTORE_NAME):SetData(data)
end

function PetDataService:Initialize()
	--print("🐾 PetDataService inicializado.")
end

return PetDataService