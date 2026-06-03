local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

-- Cấu hình
local MAGNET_RANGE = 25 -- Khoảng cách bắt đầu hút orb về phía player
local AUTO_COLLECT_RANGE = 3 -- Khoảng cách tự động thu thập (khi orb chạm player)
local MAGNET_SPEED = 40 -- Tốc độ hút orb (studs/giây)
local DESPAWN_TIME = 10 -- Tự xóa sau 10 giây

-- Theo dõi tất cả ExpOrb trong Workspace
local expOrbs = {}

-- Xử lý thu thập EXP
local function collectExp(orb, player)
    if not orb or not orb.Parent then return end
    if expOrbs[orb] and expOrbs[orb].isCollected then return end
    
    -- Kiểm tra: không cho player nhặt lại EXP của chính mình
    local droppedByAttr = orb:FindFirstChild("DroppedBy")
    if droppedByAttr and droppedByAttr.Value ~= "" and droppedByAttr.Value == player.Name then
        return -- Player không thể nhặt EXP của chính mình
    end
    
    -- Đánh dấu đã thu thập
    if expOrbs[orb] then
        expOrbs[orb].isCollected = true
    end
    
    -- Lấy giá trị EXP gốc
    local expValue = 10
    local expValueAttr = orb:FindFirstChild("ExpValue")
    if expValueAttr then
        expValue = expValueAttr.Value
    end
    
    -- Kiểm tra team để áp dụng multiplier
    local multiplier = 1.0 -- Mặc định 100%
    local killerAttr = orb:FindFirstChild("Killer")
    local killerTeamAttr = orb:FindFirstChild("KillerTeam")
    
    if killerAttr and killerTeamAttr then
        local killerTeam = killerTeamAttr.Value
        local collectorTeam = player.Team and player.Team.Name or "None"
        
        if killerTeam == collectorTeam then
            -- Cùng team với killer = 100%
            multiplier = 1.0
        else
            -- Khác team = 50%
            multiplier = 0.5
        end
    end
    
    -- Tính toán EXP thực tế
    local actualExp = math.floor(expValue * multiplier)
    
    -- Cộng EXP cho player và kiểm tra level up
    local playerData = PlayerData.Get(player)
    if playerData then
        local currentExp = playerData.Exp or 0
        local currentLevel = playerData.Level or 1
        local newExp = currentExp + actualExp
        
        -- Kiểm tra level up
        local expNeeded = 50 * math.pow(2, currentLevel - 1)
        if newExp >= expNeeded then
            PlayerData.Set(player, "Level", currentLevel + 1)
            PlayerData.Set(player, "Exp", newExp - expNeeded)
        else
            PlayerData.Set(player, "Exp", newExp)
        end
    end
    
    -- Phát âm thanh
    local sound = orb:FindFirstChild("CollectSound")
    if sound then
        sound:Play()
    end
    
    -- Hiệu ứng biến mất
    task.spawn(function()
        for i = 1, 10 do
            if orb and orb.Parent then
                orb.Transparency = i / 10
                orb.Size = orb.Size * 0.9
                task.wait(0.02)
            end
        end
        
        -- Xóa orb
        if orb and orb.Parent and orb.Parent.Parent then
            orb.Parent:Destroy()
        end
    end)
end

-- Xử lý khi player chạm vào orb
local function setupOrbTouch(orb)
    orb.Touched:Connect(function(hit)
        local character = hit.Parent
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if humanoid and humanoid.Health > 0 then
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                collectExp(orb, player)
            end
        end
    end)
end

-- Hệ thống tự động hút và thu thập khi player đến gần
local function updateExpOrbs()
    while true do
        for orb, data in pairs(expOrbs) do
            if not data.isCollected and orb and orb.Parent then
                -- Tìm player gần nhất trong phạm vi magnet
                local closestPlayer = nil
                local closestDistance = math.huge
                
                for _, player in Players:GetPlayers() do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        -- Kiểm tra: không hút orb của chính mình
                        local droppedByAttr = orb:FindFirstChild("DroppedBy")
                        if droppedByAttr and droppedByAttr.Value ~= "" and droppedByAttr.Value == player.Name then
                            continue -- Bỏ qua player là chủ của orb
                        end
                        
                        local hrp = player.Character.HumanoidRootPart
                        local distance = (hrp.Position - orb.Position).Magnitude
                        
                        if distance < closestDistance then
                            closestPlayer = player
                            closestDistance = distance
                        end
                    end
                end
                
                if closestPlayer and closestDistance < MAGNET_RANGE then
                    local hrp = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        if closestDistance < AUTO_COLLECT_RANGE then
                            -- Thu thập khi orb chạm player
                            collectExp(orb, closestPlayer)
                        else
                            -- Hút orb bay về phía player
                            local direction = (hrp.Position - orb.Position).Unit
                            local moveDistance = math.min(MAGNET_SPEED * 0.03, closestDistance)
                            orb.Position = orb.Position + direction * moveDistance
                        end
                    end
                end
            end
        end
        
        task.wait(0.03) -- Kiểm tra mỗi 0.03 giây cho hiệu ứng mượt hơn
    end
end

-- Theo dõi ExpOrb mới được thêm vào Workspace
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == "Orb" and descendant:IsA("BasePart") then
        local parent = descendant.Parent
        if parent and parent.Name == "ExpOrb" then
            -- Lưu thông tin orb với baseY cho hiệu ứng floating
            expOrbs[descendant] = {
                isCollected = false,
                spawnTime = tick(),
                baseY = descendant.Position.Y,
            }
            
            -- Setup touch event
            setupOrbTouch(descendant)
            
            -- Tự xóa sau một thời gian
            task.delay(DESPAWN_TIME, function()
                if expOrbs[descendant] and not expOrbs[descendant].isCollected then
                    -- Hiệu ứng fade out
                    for i = 1, 20 do
                        if descendant and descendant.Parent then
                            descendant.Transparency = i / 20
                            task.wait(0.05)
                        end
                    end
                    
                    if descendant and descendant.Parent and descendant.Parent.Parent then
                        descendant.Parent:Destroy()
                    end
                    
                    expOrbs[descendant] = nil
                end
            end)
            
        end
    end
end)

-- Quét tất cả ExpOrb hiện có khi khởi động
local function scanExistingExpOrbs()
    local count = 0
    for _, descendant in Workspace:GetDescendants() do
        if descendant.Name == "Orb" and descendant:IsA("BasePart") then
            local parent = descendant.Parent
            if parent and parent.Name == "ExpOrb" then
                -- Lưu thông tin orb với baseY cho hiệu ứng floating
                expOrbs[descendant] = {
                    isCollected = false,
                    spawnTime = tick(),
                    baseY = descendant.Position.Y,
                }
                
                -- Setup touch event
                setupOrbTouch(descendant)
                count = count + 1
            end
        end
    end
    return count
end

-- Quét ExpOrb hiện có
scanExistingExpOrbs()

-- Bắt đầu update loop
coroutine.wrap(updateExpOrbs)()