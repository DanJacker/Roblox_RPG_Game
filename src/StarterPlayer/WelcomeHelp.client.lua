-- Welcome Help - Hiển thị GUI hướng dẫn khi player tham gia lần đầu
local Players = game:GetService("Players")
local PlayerSettings = game:GetService("UserSettings")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Đợi GUI được tạo
task.wait(2)

local helpGui = playerGui:FindFirstChild("MatchEndHelpGui")
if helpGui then
    -- Kiểm tra xem player đã xem hướng dẫn chưa (lưu trong UserSettings)
    local hasSeenHelp = player:GetAttribute("HasSeenMatchEndHelp")
    
    if not hasSeenHelp then
        -- Hiển thị GUI hướng dẫn
        helpGui.Enabled = true
        
        -- Đánh dấu đã xem
        player:SetAttribute("HasSeenMatchEndHelp", true)
        
        -- Tự động đóng sau 10 giây
        task.delay(10, function()
            if helpGui and helpGui.Enabled then
                helpGui.Enabled = false
            end
        end)
    end
end
