local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local function safeInit(moduleName, initFunction)
	local success, result = pcall(initFunction)
	if success then
		--print("✅ " .. moduleName .. " inicializado com sucesso")
		return result
	else
		warn("❌ Erro ao inicializar " .. moduleName .. ": " .. tostring(result))
		return nil
	end
end

local function safeRequire(path, moduleName)
	local success, module = pcall(require, path)
	if success then
		return module
	else
		warn("❌ Erro ao carregar " .. moduleName .. ": " .. tostring(module))
		return nil
	end
end

--print("🚀 Iniciando serviços do cliente...")

local CratePromptHandler = safeRequire(ReplicatedStorage.Modules.PromptHandler, "CratePromptHandler")
if CratePromptHandler then
	safeInit("CratePromptHandler", function()
		CratePromptHandler:Init()
		--print("🔧 Crate prompts Inicializados")
	end)
end

local sellService
local SellServiceClient = safeRequire(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SellShopModule"), "SellServiceClient")
if SellServiceClient then
	sellService = safeInit("SellService", function()
		if not _G.SellServiceInstance then
			--print("🔧 Criando nova instância do SellService")
			_G.SellServiceInstance = SellServiceClient.new()
		else
			--print("🔧 Usando instância existente do SellService")
		end
		return _G.SellServiceInstance
	end)
end



local PetClientController = safeRequire(ReplicatedStorage.Modules.PetClientController, "PetClientController")
local petController
if PetClientController then
	petController = safeInit("PetClientController", function()
		local controller = PetClientController:Initialize() 
		--print("🐾 PetClientController inicializado")
		return controller
	end)
end



local FloatingShopModule = safeRequire(ReplicatedStorage.Modules.FloatingShopModule, "FloatingShopModule")
if FloatingShopModule then
	safeInit("FloatingShop", function()
		local floatingShop = FloatingShopModule.new()
		floatingShop:start()
		--print("🛒 FloatingShop inicializado")
		return floatingShop
	end)
end

local CrateAnimationService = safeRequire(ReplicatedStorage.Modules.OpeningAnimationService, "CrateAnimationService")
if CrateAnimationService then
	safeInit("CrateAnimationService", function()
		CrateAnimationService:Initialize()
		--print("📦 CrateAnimationModule inicializado")
	end)
end

local AnimationManager = safeRequire(ReplicatedStorage.Modules.AnimationManager, "AnimationManager")
if AnimationManager then
	safeInit("AnimationManager", function()
		AnimationManager:Initialize()
		--print("🎬 AnimationManager inicializado")
	end)
end

local EggShopAnimator = safeRequire(ReplicatedStorage.Modules.EggShopAnimation, "EggShopAnimator")
if EggShopAnimator then
	safeInit("EggShopAnimator", function()
		EggShopAnimator:Initialize()
		--print("🥚 EggShopAnimator inicializado")
	end)
end

safeInit("PlayerRemoving Connection", function()
	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player and _G.SellServiceInstance then
			local success, err = pcall(function()
				print("🧹 Limpando instância do SellService")
				_G.SellServiceInstance:Destroy()
				_G.SellServiceInstance = nil
			end)
			if not success then
				warn("❌ Erro durante cleanup: " .. tostring(err))
			end
		end
	end)
end)

print("🎯 Processo de inicialização concluído!")

local function getServiceStatus()
	local services = {
		{"CratePromptHandler", CratePromptHandler ~= nil},
		{"SellService", _G.SellServiceInstance ~= nil},
		{"FloatingShop", FloatingShopModule ~= nil},
		{"CrateAnimationService", CrateAnimationService ~= nil},
		{"AnimationManager", AnimationManager ~= nil},
		{"EggShopAnimator", EggShopAnimator ~= nil},
		{"PetClientController", petController ~= nil}
	}
	print("📊 Status dos serviços:")
	for _, service in ipairs(services) do
		local status = service[2] and "✅ Ativo" or "❌ Falhou"
		print("  " .. service[1] .. ": " .. status)
	end
end

-- getServiceStatus()