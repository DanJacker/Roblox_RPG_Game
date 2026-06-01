local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local currentCharacter = player.Character
local humanoid

local function updateHumanoidReference(character)
	currentCharacter = character
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
end

local function refreshHumanoid()
	if not humanoid and currentCharacter then
		humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = true
		end
	end
end

RunService.Heartbeat:Connect(function()
	refreshHumanoid()
	if humanoid then
		humanoid.AutoRotate = true
	end
end)

player.CharacterAdded:Connect(function(character)
	updateHumanoidReference(character)
end)

if player.Character then
	updateHumanoidReference(player.Character)
end