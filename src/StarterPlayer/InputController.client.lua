local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DashModule"))

-- 4-direction dash: W=Forward, S=Backward, A=Left, D=Right
-- Default (no key) = Forward (like Blox Fruits)
local function GetDirection()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		return "Forward"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		return "Backward"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then
		return "Left"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		return "Right"
	end
	return "Forward"
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
