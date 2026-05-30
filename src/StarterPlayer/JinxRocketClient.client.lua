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
        return
    end
    rocketRemote:FireServer("Launch")
    lastFireTime = currentTime
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.C then
        fireRocket()
    end
end)

