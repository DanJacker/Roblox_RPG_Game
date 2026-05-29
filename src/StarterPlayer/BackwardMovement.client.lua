local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local isMovingBackward = false

-- Xử lý khi nhân vật spawn
local function OnCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	
	-- Mặc định bật auto rotate
	humanoid.AutoRotate = true
end

-- Xử lý di chuyển lùi
local function UpdateMovement()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	if isMovingBackward then
		-- Tắt auto rotate để không quay đầu
		humanoid.AutoRotate = false
	end
end

-- Detect khi ấn S
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.S then
		isMovingBackward = true
		
		-- Tắt auto rotate ngay lập tức
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.AutoRotate = false
			end
		end
	end
end)

-- Detect khi thả S
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.S then
		isMovingBackward = false
		
		-- Bật lại auto rotate
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.AutoRotate = true
			end
		end
	end
end)

-- Lắng nghe khi nhân vật spawn
player.CharacterAdded:Connect(OnCharacterAdded)

-- Xử lý nhân vật hiện tại nếu có
if player.Character then
	OnCharacterAdded(player.Character)
end