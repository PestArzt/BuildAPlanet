--[[
    ADMIN PANEL SERVER - Painel Administrativo(Mod By Lorris/pedral(6/23/25)) V0.2
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

-- Serviços necessários
-- local DataStoreModule = require(game:GetService("ServerScriptService").Data.DataStoreModule)
-- local InventoryService = require(game:GetService("ServerScriptService").Player.InventoryService)
-- local ItemData = require(game:GetService("ServerScriptService").Data.ItemData)
-- local LeaderStatsService = require(game:GetService("ServerScriptService").Player.LeaderStatsService)
local MessagingService = game:GetService("MessagingService")
local CommandsModule = require(script.Parent.Commands)

local ChatMessageRemote = ReplicatedStorage:FindFirstChild("ChatMessageRemote")

-- Lista de administradores
local AdminList = require(script.Parent.AdminList)

local AdminPanelFolder = ReplicatedStorage.RemoteFunctions:FindFirstChild("Admin")
-- RemoteEvents para comunicação Cliente-Servidor
--local RequestAdminPanelRemote = AdminPanelFolder:FindFirstChild("RequestAdminPanel")
local AdminActionRemote = AdminPanelFolder:FindFirstChild("AdminAction")

local function sendMessage(player, text, color)
	ChatMessageRemote:FireClient(player, text, color)
end

Players.PlayerAdded:Connect(function(player)
	if not AdminList:IsAdmin(player.Name) then return end
	
	print("Admin "..player.Name.." joined")

	player.Chatted:Connect(function(message)

		local args = string.split(message, " ")
		local commandPrefix = string.sub(args[1], 1, 1)

		if commandPrefix == CommandsModule.Prefix then
			local command = string.gsub(args[1], CommandsModule.Prefix, "")
			table.remove(args, 1)
			sendMessage(player, "[ECCLESIA CONSOLE] ".. CommandsModule:Execute(player.Name, command, false, args), Color3.fromRGB(141, 141, 141)) 
		end

	end)

	task.delay(3, function()
		if game.ServerStorage.Admin.AdminPanelGui then
			local AdminPanel = game.ServerStorage.Admin.AdminPanelGui:Clone()
			AdminPanel.Parent = player.PlayerGui
		end

		-- Enviar mensagem de boas-vindas para admin 
		sendMessage(player, "(v0.1) Ecclesia Console has started, you are an admin. Press J to open Admin Panel", Color3.fromRGB(185, 185, 185))
	end)
end)

MessagingService:SubscribeAsync("adminAction", function(message)
	print(message.Data.PlayerName, message.Data.Action, message.Data.Data)
	CommandsModule:Execute(message.Data.PlayerName, message.Data.Action, true, message.Data.Data)
end)

AdminActionRemote.OnServerInvoke = function(player, action, ...)
	return CommandsModule:Execute(player.Name, action, false, ...)
end

-- Handler para quando jogador solicita o painel admin
--requestAdminPanelRemote.OnServerEvent:Connect(function(player)
--	-- Verificar se é admin
--	if not AdminList:IsAdmin(player.Name) then
--		return -- Não enviar dados se não for admin
--	end

--	-- Enviar dados necessários para o cliente
--	local data = {
--		Items = getAllItems(),
--		Players = getPlayersList()
--	}

--	requestAdminPanelRemote:FireClient(player, data)
--end)

-- Handler para ações administrativas


-- Quando jogador entra no jogo
