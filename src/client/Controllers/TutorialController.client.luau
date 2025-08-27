local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()

local TutorialData = require(ReplicatedStorage.Modules.TutorialData)
local TutorialEvent = ReplicatedStorage.RemoteEvents.TutorialRemotes.TutorialEvent
--local TutorialFunction = ReplicatedStorage.RemoteFunctions.TutorialFunc.TutorialFunction

local TutorialGUI = playerGui:WaitForChild("TutorialGUI")
local Holder = TutorialGUI:WaitForChild("Holder")
local ObjectiveLabel = Holder:WaitForChild("Objective")
local NeededLabel = Holder:WaitForChild("Needed")
local TutorialButtons = TutorialGUI:WaitForChild("TutorialButtons")
--local PlayButton = TutorialButtons:WaitForChild("PlayTutorial")
--local SkipButton = TutorialButtons:WaitForChild("SkipTutorial")
local TutorialMessages = TutorialGUI:WaitForChild("TutorialMessages")
local FinishedSound = TutorialGUI:WaitForChild("Sounds"):WaitForChild("Finished") 
local NextStageSound = TutorialGUI:WaitForChild("Sounds"):WaitForChild("NextStage") 
local confettiModule = require(playerGui:WaitForChild("Confetis"):WaitForChild("ConfetiModule"))

local currentState = nil
local currentBeam = nil
local attachment0, attachment1 = nil
local updateConnection = nil

local TutorialController = {}

--// Encontra objeto a partir do caminho fornecido
local function FindObjectFromPath(fullPath)
	local pathSegments = string.split(fullPath, ".")
	local currentObject = game
	for _, segment in ipairs(pathSegments) do
		currentObject = currentObject:WaitForChild(segment, 10)
		if not currentObject then
			warn("Não foi possível encontrar o segmento do caminho: " .. segment .. " em " .. fullPath)
			return nil
		end
	end
	return currentObject
end

--// Limpa os visuais atuais (feixe de luz e attachments)
function TutorialController:ClearVisuals()
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
	if attachment0 then
		attachment0:Destroy()
		attachment0 = nil
	end
	if attachment1 then
		attachment1:Destroy()
		attachment1 = nil
	end
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
end

--// Cria o feixe de luz para guiar o jogador
function TutorialController:CreateBeam(targetPart)
	if not targetPart or not character:FindFirstChild("Torso") then return end

	self:ClearVisuals()

	attachment0 = Instance.new("Attachment", character:WaitForChild("Torso"))
	attachment1 = Instance.new("Attachment", targetPart)

	currentBeam = Instance.new("Beam")
	currentBeam.Attachment0 = attachment0
	currentBeam.Attachment1 = attachment1
	currentBeam.Color = ColorSequence.new(Color3.new(1, 0.8, 0.2), Color3.new(1, 1, 0.8))
	currentBeam.Transparency = NumberSequence.new(0, 0.8)
	currentBeam.Width0 = 1
	currentBeam.Width1 = 0.5
	currentBeam.Segments = 10
	currentBeam.FaceCamera = true
	currentBeam.Parent = character:WaitForChild("Torso")

	updateConnection = RunService.Heartbeat:Connect(function()
		if not character or not character.Parent or not character:FindFirstChild("Torso") then
			self:ClearVisuals()
			return
		end
		if attachment0 and attachment0.Parent ~= character.Torso then
			attachment0.Parent = character.Torso
		end
	end)
end

--// Atualiza a UI e os visuais com base no estado atual
function TutorialController:UpdateState(progressData)
	local newState = progressData.State

	if newState ~= currentState and currentState and newState ~= TutorialData.STATES.COMPLETED then 
		NextStageSound:Play()                                                                 
	end

	currentState = newState
	self:ClearVisuals()

	Holder.Visible = false
	TutorialMessages.Visible = false

	if newState == TutorialData.STATES.COMPLETED then
		TutorialGUI.Enabled = true
		Holder.Visible = false
		TutorialMessages.Text = "Build Your Planet!"
		TutorialMessages.Visible = true
		FinishedSound:Play()
		confettiModule.Rain(100) 
		task.delay(2, function()
			TutorialGUI.Enabled = false
		end)
		return
	elseif newState == TutorialData.STATES.SKIPPED then
		TutorialGUI.Enabled = false
		return
	end

	local config = TutorialData:GetConfigForState(newState)
	if not config then return end

	Holder.Visible = true
	ObjectiveLabel.Text = config.Objective or "Tutorial"

	local neededText = config.Needed or ""
	if string.find(neededText, "{current}") then
		neededText = string.gsub(neededText, "{current}", tostring(progressData.Current))
		neededText = string.gsub(neededText, "{required}", tostring(progressData.Required))
	end
	NeededLabel.Text = neededText

	if config.Message then
		TutorialMessages.Text = config.Message
		TutorialMessages.Visible = true
	end

	if config.TargetPartPath then
		local targetPart = FindObjectFromPath(config.TargetPartPath)
		if targetPart then
			self:CreateBeam(targetPart)
		else
			warn(`[TutorialController] Não foi possível encontrar a parte alvo: ${config.TargetPartPath}`)
		end
	end
end

--// Inicializa o controlador do tutorial
function TutorialController:Initialize()
	character = player.Character or player.CharacterAdded:Wait()
	while not character:FindFirstChild("Torso") do
		task.wait()
	end

	TutorialGUI.Enabled = true

	TutorialEvent.OnClientEvent:Connect(function(progressData)
		self:UpdateState(progressData)
	end)
end
TutorialController:Initialize()