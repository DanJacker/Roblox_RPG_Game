local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Modules
local PlayerData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerData"))

-- Cấu hình
local EXP_ON_NPC_DEATH = 10 -- Số EXP rơi ra khi quái/bot chết
local MIN_EXP_ORBS = 2 -- Số orb tối thiểu rơi ra
local MAX_EXP_ORBS = 4 -- Số orb tối đa rơi ra
local SPREAD_RADIUS = 3 -- Bán kính rải EXP

-- Cấu hình EXP rơi dựa trên EXP hiện có của player
local EXP_DROP_PERCENTAGE = 0.15 -- 15% EXP hiện có sẽ rơi ra
local MIN_EXP_DROP = 10 -- Tối thiểu 10 EXP rơi ra
local MAX_EXP_DROP = 100 -- Tối đa 100 EXP rơi ra

-- Tracking last attacker cho players
local playerLastAttacker = {}
-- Tracking team của player
local playerTeamStorage = {}

-- Tracking để tránh setup trùng lặp
local trackedNPCs = {}

-- Hàm tìm mặt đất bằng raycast
local function findGround(position)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    -- Raycast từ trên xuống để tìm mặt đất
    local rayResult = Workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), raycastParams)
    
    if rayResult then
        return rayResult.Position
    end
    
    -- Nếu không tìm thấy, trả về vị trí gốc
    return position
end

-- Hàm tạo Exp Orb tại vị trí
local function spawnExpOrbs(position, expValue, killer)
    local expOrbTemplate = ReplicatedStorage:FindFirstChild("ExpOrb")
    if not expOrbTemplate then
        warn("Không tìm thấy ExpOrb template!")
        return
    end
    
    -- Random số lượng orb
    local numOrbs = math.random(MIN_EXP_ORBS, MAX_EXP_ORBS)
    local expPerOrb = math.floor(expValue / numOrbs)
    
    for i = 1, numOrbs do
        -- Random vị trí xung quanh điểm chết
        local offsetX = (math.random() - 0.5) * SPREAD_RADIUS * 2
        local offsetZ = (math.random() - 0.5) * SPREAD_RADIUS * 2
        local spawnPosition = position + Vector3.new(offsetX, 0, offsetZ)
        
        -- Tìm mặt đất
        local groundPosition = findGround(spawnPosition)
        
        -- Clone Exp Orb
        local expOrb = expOrbTemplate:Clone()
        local orb = expOrb:FindFirstChild("Orb")
        
        if orb then
            -- Đặt orb trực tiếp trên mặt đất
            orb.Position = groundPosition + Vector3.new(0, 1, 0) -- 1 stud trên mặt đất
            orb.Anchored = true -- Giữ orb cố định trên mặt đất
            
            -- Cập nhật giá trị EXP cho orb
            local expValueAttr = orb:FindFirstChild("ExpValue")
            if expValueAttr then
                expValueAttr.Value = expPerOrb
            end
            
            -- Cập nhật label
            local billboardGui = orb:FindFirstChild("ExpLabel")
            if billboardGui then
                local expLabel = billboardGui:FindFirstChild("ExpText")
                if expLabel then
                    expLabel.Text = "+" .. expPerOrb .. " EXP"
                end
            end
            
            -- Lưu thông tin killer (người hạ gục)
            if killer then
                local killerAttr = Instance.new("StringValue")
                killerAttr.Name = "Killer"
                killerAttr.Value = killer.Name
                killerAttr.Parent = orb
                
                -- Lưu team của killer
                local killerTeamAttr = Instance.new("StringValue")
                killerTeamAttr.Name = "KillerTeam"
                killerTeamAttr.Value = killer.Team and killer.Team.Name or "None"
                killerTeamAttr.Parent = orb
            end
        end
        
        expOrb.Parent = Workspace
    end
end

-- Xử lý khi player chết (RƠI EXP DỰA TRÊN EXP HIỆN CÓ)
local function onPlayerDeath(player)
    -- Lấy team từ biến global
    local playerTeam = playerTeamStorage[player.UserId] or "Lobby"
    
    -- Kiểm tra team - chỉ Team1 và Team2 rơi EXP
    if playerTeam ~= "Team1" and playerTeam ~= "Team2" then
        print("[ExpDrop] " .. player.Name .. " (" .. playerTeam .. ") không rơi EXP")
        playerLastAttacker[player.UserId] = nil
        playerTeamStorage[player.UserId] = nil
        return
    end
    
    -- Lấy thông tin killer
    local killer = playerLastAttacker[player.UserId]
    
    -- Lấy EXP hiện có của player
    local playerData = PlayerData.Get(player)
    local currentExp = 0
    if playerData then
        currentExp = playerData.Exp or 0
    end
    
    -- Tính toán EXP rơi ra dựa trên EXP hiện có
    local expToDrop = math.floor(currentExp * EXP_DROP_PERCENTAGE)
    
    -- Áp dụng giới hạn
    expToDrop = math.max(MIN_EXP_DROP, expToDrop) -- Tối thiểu
    expToDrop = math.min(MAX_EXP_DROP, expToDrop) -- Tối đa
    
    -- Lấy vị trí chết
    if player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            spawnExpOrbs(hrp.Position, expToDrop, killer)
            if killer then
                print("[ExpDrop] " .. player.Name .. " (" .. playerTeam .. ") đã bị " .. killer.Name .. " hạ gục")
                print("[ExpDrop] EXP hiện có: " .. currentExp .. " -> Rơi ra: " .. expToDrop .. " EXP (" .. (EXP_DROP_PERCENTAGE * 100) .. "%)")
            else
                print("[ExpDrop] " .. player.Name .. " (" .. playerTeam .. ") đã chết")
                print("[ExpDrop] EXP hiện có: " .. currentExp .. " -> Rơi ra: " .. expToDrop .. " EXP (" .. (EXP_DROP_PERCENTAGE * 100) .. "%)")
            end
        end
    end
    
    -- Xóa tracking
    playerLastAttacker[player.UserId] = nil
    playerTeamStorage[player.UserId] = nil
end

-- Xử lý khi NPC/Quái vật chết
local function onNPCDeath(npcModel)
    if not npcModel then return end
    
    -- Lấy thông tin killer từ attribute
    local killer = nil
    local lastAttackerAttr = npcModel:FindFirstChild("LastAttacker")
    if lastAttackerAttr then
        killer = Players:FindFirstChild(lastAttackerAttr.Value)
    end
    
    local hrp = npcModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        spawnExpOrbs(hrp.Position, EXP_ON_NPC_DEATH, killer)
        if killer then
            print("[ExpDrop] " .. npcModel.Name .. " đã bị " .. killer.Name .. " tiêu diệt, rơi " .. EXP_ON_NPC_DEATH .. " EXP")
        else
            print("[ExpDrop] " .. npcModel.Name .. " đã bị tiêu diệt, rơi " .. EXP_ON_NPC_DEATH .. " EXP")
        end
    end
end

-- Theo dõi Humanoid.Died event cho player
local function setupPlayerDeathDetection(player)
    -- Lưu team vào biến global khi player thay đổi team
    player:GetPropertyChangedSignal("Team"):Connect(function()
        local team = player.Team and player.Team.Name or "Lobby"
        if team == "Team1" or team == "Team2" then
            playerTeamStorage[player.UserId] = team
            print("[ExpDrop] " .. player.Name .. " team saved: " .. team)
        end
    end)
    
    -- Lưu team ban đầu
    local currentTeam = player.Team and player.Team.Name or "Lobby"
    if currentTeam == "Team1" or currentTeam == "Team2" then
        playerTeamStorage[player.UserId] = currentTeam
    end
    
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            -- Theo dõi khi bị tấn công để lưu last attacker
            humanoid.Touched:Connect(function(hit)
                local attackerCharacter = hit.Parent
                local attacker = Players:GetPlayerFromCharacter(attackerCharacter)
                if attacker and attacker ~= player then
                    -- Lưu player tấn công cuối cùng
                    playerLastAttacker[player.UserId] = attacker
                end
            end)
            
            -- Lưu team ngay khi health thay đổi
            humanoid.HealthChanged:Connect(function(health)
                if health < 50 then
                    local team = player.Team and player.Team.Name or "Lobby"
                    if team == "Team1" or team == "Team2" then
                        playerTeamStorage[player.UserId] = team
                    end
                end
            end)
            
            humanoid.Died:Connect(function()
                onPlayerDeath(player)
            end)
        end
    end)
    
    -- Xử lý character hiện tại (nếu có)
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Theo dõi khi bị tấn công
            humanoid.Touched:Connect(function(hit)
                local attackerCharacter = hit.Parent
                local attacker = Players:GetPlayerFromCharacter(attackerCharacter)
                if attacker and attacker ~= player then
                    playerLastAttacker[player.UserId] = attacker
                end
            end)
            
            -- Lưu team ngay khi health thay đổi
            humanoid.HealthChanged:Connect(function(health)
                if health < 50 then
                    local team = player.Team and player.Team.Name or "Lobby"
                    if team == "Team1" or team == "Team2" then
                        playerTeamStorage[player.UserId] = team
                    end
                end
            end)
            
            humanoid.Died:Connect(function()
                onPlayerDeath(player)
            end)
        end
    end
end

-- Theo dõi Humanoid.Died event cho NPC/Quái vật
local function setupNPCDeathDetection(npcModel)
    -- Kiểm tra nếu đã được track rồi
    if trackedNPCs[npcModel] then
        return
    end
    
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    if humanoid then
        trackedNPCs[npcModel] = true
        
        -- Theo dõi khi bị tấn công để lưu last attacker
        humanoid.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                -- Lưu tên player tấn công cuối cùng
                local lastAttackerAttr = npcModel:FindFirstChild("LastAttacker")
                if not lastAttackerAttr then
                    lastAttackerAttr = Instance.new("StringValue")
                    lastAttackerAttr.Name = "LastAttacker"
                    lastAttackerAttr.Parent = npcModel
                end
                lastAttackerAttr.Value = player.Name
            end
        end)
        
        humanoid.Died:Connect(function()
            onNPCDeath(npcModel)
            -- Xóa khỏi tracking sau khi chết
            trackedNPCs[npcModel] = nil
        end)
        print("[ExpDrop] Đã setup theo dõi cho: " .. npcModel.Name)
    end
end

-- Quét tất cả NPC hiện có trong Workspace
local function scanExistingNPCs()
    local count = 0
    for _, descendant in Workspace:GetDescendants() do
        if descendant:IsA("Model") then
            local humanoid = descendant:FindFirstChildOfClass("Humanoid")
            if humanoid then
                -- Kiểm tra nếu không phải là player character
                local isPlayer = false
                for _, player in Players:GetPlayers() do
                    if player.Character == descendant then
                        isPlayer = true
                        break
                    end
                end
                
                if not isPlayer then
                    setupNPCDeathDetection(descendant)
                    count = count + 1
                end
            end
        end
    end
    print("[ExpDrop] Đã quét và setup " .. count .. " NPC/bot hiện có")
end

-- Theo dõi NPC mới được thêm vào Workspace
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") then
        task.wait(0.1) -- Đợi model load xong
        
        -- Kiểm tra nếu không phải là player character
        local isPlayer = false
        for _, player in Players:GetPlayers() do
            if player.Character == descendant then
                isPlayer = true
                break
            end
        end
        
        if not isPlayer then
            local humanoid = descendant:FindFirstChildOfClass("Humanoid")
            if humanoid then
                setupNPCDeathDetection(descendant)
            end
        end
    end
end)

-- Setup cho tất cả players
Players.PlayerAdded:Connect(setupPlayerDeathDetection)
for _, player in Players:GetPlayers() do
    setupPlayerDeathDetection(player)
end

-- Quét NPC hiện có
scanExistingNPCs()

print("[ExpDropSystem] Đã khởi động thành công!")
print("[ExpDropSystem] EXP rơi khi quái chết: " .. EXP_ON_NPC_DEATH)
print("[ExpDropSystem] EXP rơi khi player chết: " .. (EXP_DROP_PERCENTAGE * 100) .. "% EXP hiện có")
print("[ExpDropSystem] Giới hạn: " .. MIN_EXP_DROP .. " - " .. MAX_EXP_DROP .. " EXP")