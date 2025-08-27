
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local chatMessageRemote = ReplicatedStorage:WaitForChild("ChatMessageRemote")
local TextChatService = game:GetService("TextChatService")

function toInteger(color)
	return math.floor(color.r*255)*256^2+math.floor(color.g*255)*256+math.floor(color.b*255)
end

function toHex(color)
	local int = toInteger(color)

	local current = int
	local final = ""

	local hexChar = {
		"A", "B", "C", "D", "E", "F"
	}

	repeat local remainder = current % 16
		local char = tostring(remainder)

		if remainder >= 10 then
			char = hexChar[1 + remainder - 10]
		end

		current = math.floor(current/16)
		final = final..char
	until current <= 0

	return "#"..string.reverse(final)
end

chatMessageRemote.OnClientEvent:Connect(function(text, color)
	
	local playerGui = player:WaitForChild("PlayerGui")
	
	local success, err = pcall(function()
		TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(`<font color='{toHex(color)}'>{text}</font>`)
	end)

	
	if not success then
		print("[INVENTÁRIO] " .. text)
	end
end)