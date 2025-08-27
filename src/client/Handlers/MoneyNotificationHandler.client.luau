local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sound = script.Moneypickup

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local MoneyNotificationRemote = remoteEvents:WaitForChild('MoneyNotification')
local XPNotificationRemote = remoteEvents:WaitForChild("XPNotification")
local CratePointsNotificationRemote = remoteEvents:WaitForChild("CratePointsNotification")


local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoneyNotifications"
screenGui.Parent = playerGui

local notificationCount = 0
local NotificationConfig = {
	Money = {
		prefix = "+$",
		color = Color3.fromRGB(255, 245, 105),
		playSound = true
	},
	XP = {
		prefix = "+ ",
		suffix = " XP",
		color = Color3.fromRGB(0, 255, 255),
		playSound = false
	},
	
	CratePoints = {
		prefix = "+ ",
		suffix = "🌱 Points",
		color = Color3.fromRGB(85, 255, 85),
		playSound = false
	}
	
}


local function createNotification(amount, notificationType)
	notificationCount = notificationCount + 1
	local config = NotificationConfig[notificationType]

	local notificationText = Instance.new("TextLabel")
	notificationText.Name = notificationType .. "Text" .. notificationCount
	notificationText.Size = UDim2.new(0, 0, 0, 0)
	notificationText.Position = UDim2.new(0.85, 0, 0.5, (notificationCount - 1) * 40)
	notificationText.BackgroundTransparency = 1
	notificationText.Text = config.prefix .. amount .. (config.suffix or "")
	notificationText.TextColor3 = config.color
	notificationText.TextScaled = true
	notificationText.Font = Enum.Font.SourceSansBold
	notificationText.TextStrokeTransparency = 0
	notificationText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	notificationText.Parent = screenGui


	local enterTween = TweenService:Create(
		notificationText,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UDim2.new(0, 150, 0, 40)}
	)

	local moveTween = TweenService:Create(
		notificationText,
		TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.85, 0, 0.3, (notificationCount - 1) * 40)}
	)

	local exitTween = TweenService:Create(
		notificationText,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Size = UDim2.new(0, 0, 0, 0)
		}
	)

	if config.playSound then
		sound:Play()
	end

	enterTween:Play()
	moveTween:Play()

	task.spawn(function()
		task.wait(1)
		exitTween:Play()

		exitTween.Completed:Connect(function()
			notificationText:Destroy()
			notificationCount = math.max(0, notificationCount - 1)
		end)
	end)
end

MoneyNotificationRemote.OnClientEvent:Connect(function(amount)
	createNotification(amount, "Money")
end)

XPNotificationRemote.OnClientEvent:Connect(function(amount)
	createNotification(amount, "XP")
end)

CratePointsNotificationRemote.OnClientEvent:Connect(function(amount)
	createNotification(amount, "CratePoints")
end)