-- Light Beam Client - Handles input and fires ultimate beam
-- Press X to shoot a rainbow light beam from your body (Ultimate skill)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local lightBeamRemote = ReplicatedStorage:WaitForChild("LightBeamRemote")

-- Configuration
local COOLDOWN = 10 -- seconds (Lux style ultimate)

-- Track cooldown
local lastFireTime = -COOLDOWN

-- Function to fire light beam
local function fireLightBeam()
    -- Check cooldown
    local currentTime = tick()
    if currentTime - lastFireTime < COOLDOWN then
        local remaining = math.ceil(COOLDOWN - (currentTime - lastFireTime))
        print("Light Beam on cooldown: " .. remaining .. "s remaining")
        return
    end
    
    -- Fire the remote event (server will handle position)
    lightBeamRemote:FireServer("Launch")
    lastFireTime = currentTime
    
    print("LIGHT BEAM ULTIMATE LAUNCHED!")
end

-- Handle key input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Check for X key
    if input.KeyCode == Enum.KeyCode.X then
        fireLightBeam()
    end
end)

print("Light Beam Client loaded! Press X to shoot ULTIMATE rainbow beam from your body.")