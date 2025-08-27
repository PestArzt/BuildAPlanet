local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaySoundEvent = ReplicatedStorage.RemoteEvents.SoundsEffects:WaitForChild("PlaySoundForClient")
local SoundFolder = ReplicatedStorage:WaitForChild("Sound")

local function onPlaySound(soundName)
	local sound = SoundFolder:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound:Play()
	else
		warn("Tentativa de tocar um som que não existe:", soundName)
	end
end
PlaySoundEvent.OnClientEvent:Connect(onPlaySound)