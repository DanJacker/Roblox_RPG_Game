-- Fireball Client - Handles input and fires fireball
-- Press Z to shoot a fireball from your hand

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local fireballRemote = ReplicatedStorage:WaitForChild("FireballRemote")

-- Configuration
local COOLDOWN = 5 -- seconds

-- Track cooldown
local lastFireTime = -COOLDOWN

-- Function to get hand position
local function getHandPosition()
    local character = player.Character
    if not character then return nil end
    
    -- Try to find right hand
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if rightHand then
        return rightHand.Position + Vector3.new(0, 1, 0)
    end
    
    -- Fallback to HumanoidRootPart position
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position + Vector3.new(0, 1.5, 0)
    end
    
    return nil
end

-- Function to fire fireball
local function fireFireball()
    -- Check cooldown
    local currentTime = tick()
    if currentTime - lastFireTime < COOLDOWN then
        local remaining = math.ceil(COOLDOWN - (currentTime - lastFireTime))
        print("Fireball on cooldown: " .. remaining .. "s remaining")
        return
    end
    
    -- Get hand position
    local handPos = getHandPosition()
    if not handPos then return end
    
    -- Fire the remote event
    fireballRemote:FireServer("Launch", handPos)
    lastFireTime = currentTime
    
    print("Fireball launched!")
end

-- Handle key input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Check for Z key
    if input.KeyCode == Enum.KeyCode.Z then
        fireFireball()
    end
end)

print("Fireball Client loaded! Press Z to shoot fireball.")