-- Match End Help Client - Mở GUI hướng dẫn bằng phím H
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Đợi GUI được tạo
local helpGui = playerGui:WaitForChild("MatchEndHelpGui", 5)

-- Lắng nghe phím H
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.H then
        if helpGui then
            helpGui.Enabled = not helpGui.Enabled
        end
    end
end)

