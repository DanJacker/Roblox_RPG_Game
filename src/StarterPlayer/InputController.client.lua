local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DashModule"))

local function GetDirection()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		return "Front"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		return "Back"
	end
	return "Front"
end

local function OnInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	
	if input.KeyCode == Enum.KeyCode.Q then
		local direction = GetDirection()
		task.spawn(function()
			DashModule.Execute(direction)
		end)
	end
end

UserInputService.InputBegan:Connect(OnInputBegan)
