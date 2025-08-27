
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Módulos e GUIs
local Icon = require(ReplicatedStorage.Modules.Icon)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Referências para os frames que serão controlados
local mainGui = playerGui:WaitForChild("Main")
local permissionsGui = playerGui:WaitForChild("PermissionsGui") 
local configFrame = mainGui:WaitForChild("Config")
local partyFrame = permissionsGui:WaitForChild("MainFrame")

-- Efeitos compartilhados
local Camera = workspace.CurrentCamera
local FOVIncrease = TweenService:Create(Camera, TweenInfo.new(0.2), {FieldOfView = 85})
local FOVReset = TweenService:Create(Camera, TweenInfo.new(0.2), {FieldOfView = 70})

local function bounceFrame(frame)
	local orig = frame.Position
	local down = orig + UDim2.new(0, 0, 0.03, 0)
	frame:TweenPosition(down, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true, function()
		frame:TweenPosition(orig, Enum.EasingDirection.Out, Enum.EasingStyle.Bounce, 0.2, true)
	end)
end


local configIcon = Icon.new()
	:setImage(116441437117475) 
	:setLabel("Config")
	:setCaption("Settings")
	:autoDeselect(true)

configIcon:bindToggleItem(configFrame)

configIcon.selected:Connect(function()
	FOVIncrease:Play()
	bounceFrame(configFrame)
end)

configIcon.deselected:Connect(function()
	FOVReset:Play()
end)


local partyIcon = Icon.new()
	:setImage(112652480540009) 
	:setLabel("Party")
	:setCaption("Planet Perms")
	:autoDeselect(true)

partyIcon:bindToggleItem(partyFrame)

partyIcon.selected:Connect(function()
	FOVIncrease:Play()
	bounceFrame(partyFrame)
end)

partyIcon.deselected:Connect(function()
	FOVReset:Play()
end)


configFrame.Visible = false
partyFrame.Visible = false