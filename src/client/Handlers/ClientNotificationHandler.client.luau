local ReplicatedStorage = game:GetService("ReplicatedStorage")
local favoriteStockSound = ReplicatedStorage:FindFirstChild("Sound"):FindFirstChild("FavoriteStockSound")
local NotificationManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NotificationModule"))

local ShopEvents = ReplicatedStorage.RemoteEvents:WaitForChild('Shop')
local NotifyPlayerEvent = ShopEvents:WaitForChild("NotifyPlayer")
NotifyPlayerEvent.OnClientEvent:Connect(function(message, itemNames, color)
	local fullMessage = message 

	if itemNames and #itemNames > 0 then
		fullMessage = fullMessage .. ": " .. table.concat(itemNames, ", ")
	end

	local notificationColor = color or Color3.fromRGB(255, 193, 7)
	NotificationManager.ShowNotification(fullMessage, notificationColor)

	if message:find("⭐") then 
		favoriteStockSound:Play()
	end
end)