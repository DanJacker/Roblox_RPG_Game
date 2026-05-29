local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashModule = require(ReplicatedStorage:WaitForChild("DashModule"))

local function GetDirection()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		return "Front"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		return "Back"
	end
	return nil
end

local function OnInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	
	if input.KeyCode == Enum.KeyCode.LeftShift then
		local direction = GetDirection()
		if direction then
			task.spawn(function()
				DashModule.Execute(direction)
			end)
		end
	end
end

UserInputService.InputBegan:Connect(OnInputBegan)
