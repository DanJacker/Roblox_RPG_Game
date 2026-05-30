local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Modules
local PlayerData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerData"))

-- Cấu hình
local AUTO_COLLECT_RANGE = 8 -- Khoảng cách tự động thu thập
local SAME_TEAM_MULTIPLIER = 1.0 -- 100% EXP khi cùng team
local DIFFERENT_TEAM_MULTIPLIER = 0.5 -- 50% EXP khi khác team
local DESPAWN_TIME = 60 -- Tự xóa sau 60 giây

-- Tracking orbs đã setup
local setupOrbs = {}

-- Hàm thu thập EXP
local function collectExp(orb, player)
    if not orb or not orb.Parent then return end
    if setupOrbs[orb] and setupOrbs[orb].isCollected then return end
    
    -- Đánh dấu đã thu thập
    if setupOrbs[orb] then
        setupOrbs[orb].isCollected = true
    end
    
    -- Kiểm tra team
    local playerTeam = player.Team and player.Team.Name or "Lobby"
    if playerTeam ~= "Team1" and playerTeam ~= "Team2" then
        return
    end
    
    -- Lấy giá trị EXP
    local expValueAttr = orb:FindFirstChild("ExpValue")
    if not expValueAttr then return end
    
    local baseExp = expValueAttr.Value
    
    -- Lấy thông tin killer
    local killerAttr = orb:FindFirstChild("Killer")
    local killerTeamAttr = orb:FindFirstChild("KillerTeam")
    
    -- Tính toán multiplier
    local multiplier = DIFFERENT_TEAM_MULTIPLIER -- Mặc định 50%
    
    if killerAttr and killerTeamAttr then
        local killerTeam = killerTeamAttr.Value
        
        if playerTeam == killerTeam then
            multiplier = SAME_TEAM_MULTIPLIER -- 100% nếu cùng team với killer
        end
    end
    
    -- Tính EXP cuối cùng
    local finalExp = math.floor(baseExp * multiplier)
    
    -- Cộng EXP cho player
    local playerData = PlayerData.Get(player)
    if playerData then
        local currentExp = playerData.Exp or 0
        local newExp = currentExp + finalExp
        
        PlayerData.Set(player, "Exp", newExp)
        
        -- Kiểm tra level up
        local currentLevel = playerData.Level or 1
        local expNeeded = currentLevel * 100 -- 100 EXP per level
        
        if newExp >= expNeeded then
            -- Level up!
            local newLevel = currentLevel + 1
            PlayerData.Set(player, "Level", newLevel)
            PlayerData.Set(player, "Exp", newExp - expNeeded)
            
        end
        
    end
    
    -- Xóa orb
    local orbModel = orb.Parent
    if orbModel then
        orbModel:Destroy()
    end
end

-- Hàm setup orb để có thể thu thập
local function setupExpOrb(orb)
    if setupOrbs[orb] then return end
    setupOrbs[orb] = {isCollected = false}
    
    -- Tự xóa sau một thời gian
    task.delay(DESPAWN_TIME, function()
        if setupOrbs[orb] and not setupOrbs[orb].isCollected then
            -- Hiệu ứng fade out
            for i = 1, 20 do
                if orb and orb.Parent then
                    orb.Transparency = i / 20
                    task.wait(0.05)
                end
            end
            
            if orb and orb.Parent and orb.Parent.Parent then
                orb.Parent:Destroy()
            end
            
            setupOrbs[orb] = nil
        end
    end)
end

-- Hệ thống tự động thu thập khi player đến gần
local function autoCollectLoop()
    while true do
        for orb, data in pairs(setupOrbs) do
            if not data.isCollected and orb and orb.Parent then
                -- Tìm player trong phạm vi
                for _, player in Players:GetPlayers() do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = player.Character.HumanoidRootPart
                        local distance = (hrp.Position - orb.Position).Magnitude
                        
                        -- Tự động thu thập khi player đến gần
                        if distance < AUTO_COLLECT_RANGE then
                            collectExp(orb, player)
                            break -- Dừng kiểm tra player khác sau khi thu thập
                        end
                    end
                end
            end
        end
        
        task.wait(0.1) -- Kiểm tra mỗi 0.1 giây
    end
end

-- Bắt đầu auto collect loop
coroutine.wrap(autoCollectLoop)()

-- Quét tất cả ExpOrb hiện có trong Workspace
local function scanExistingOrbs()
    local count = 0
    for _, descendant in Workspace:GetDescendants() do
        if descendant.Name == "ExpOrb" and descendant:IsA("Model") then
            local orb = descendant:FindFirstChild("Orb")
            if orb then
                setupExpOrb(orb)
                count = count + 1
            end
        end
    end
end

-- Theo dõi ExpOrb mới được thêm vào Workspace
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == "ExpOrb" and descendant:IsA("Model") then
        task.wait(0.1) -- Đợi orb load xong
        
        local orb = descendant:FindFirstChild("Orb")
        if orb then
            setupExpOrb(orb)
        end
    end
end)

-- Quét orbs hiện có
scanExistingOrbs()

