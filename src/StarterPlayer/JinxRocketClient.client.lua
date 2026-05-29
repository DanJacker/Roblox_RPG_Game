-- Jinx Rocket Client - Press C to fire
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COOLDOWN = 15
local lastFireTime = 0

local rocketRemote = ReplicatedStorage:WaitForChild("JinxRocketRemote")

local function fireRocket()
    local currentTime = tick()
    if currentTime - lastFireTime < COOLDOWN then
        local remaining = math.ceil(COOLDOWN - (currentTime - lastFireTime))
        print("Jinx Rocket on cooldown: " .. remaining .. "s remaining")
        return
    end
    rocketRemote:FireServer("Launch")
    lastFireTime = currentTime
    print("JINX ROCKET LAUNCHED!")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.C then
        fireRocket()
    end
end)

print("Jinx Rocket Client loaded! Press C to fire")