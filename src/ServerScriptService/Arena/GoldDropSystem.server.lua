local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Cấu hình
local GOLD_ON_NPC_DEATH = 15 -- Số vàng rơi ra khi quái/bot chết
local GOLD_ON_PLAYER_DEATH = 20 -- Số vàng rơi ra khi player chết
local MIN_GOLD_ORBS = 3 -- Số orb tối thiểu rơi ra
local MAX_GOLD_ORBS = 6 -- Số orb tối đa rơi ra
local SPREAD_RADIUS = 3 -- Bán kính rải vàng

-- Tracking last attacker cho players
local playerLastAttacker = {}
-- Tracking team của player (sử dụng biến global thay vì attribute)
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

-- Hàm tạo Gold Orb tại vị trí
local function spawnGoldOrbs(position, goldValue, killer)
    local goldOrbTemplate = ReplicatedStorage:FindFirstChild("GoldOrb")
    if not goldOrbTemplate then
        warn("Không tìm thấy GoldOrb template!")
        return
    end
    
    -- Random số lượng orb
    local numOrbs = math.random(MIN_GOLD_ORBS, MAX_GOLD_ORBS)
    local goldPerOrb = math.floor(goldValue / numOrbs)
    
    for i = 1, numOrbs do
        -- Random vị trí xung quanh điểm chết
        local offsetX = (math.random() - 0.5) * SPREAD_RADIUS * 2
        local offsetZ = (math.random() - 0.5) * SPREAD_RADIUS * 2
        local spawnPosition = position + Vector3.new(offsetX, 0, offsetZ)
        
        -- Tìm mặt đất
        local groundPosition = findGround(spawnPosition)
        
        -- Clone Gold Orb
        local goldOrb = goldOrbTemplate:Clone()
        local orb = goldOrb:FindFirstChild("Orb")
        
        if orb then
            -- Đặt orb trực tiếp trên mặt đất
            orb.Position = groundPosition + Vector3.new(0, 1, 0) -- 1 stud trên mặt đất
            orb.Anchored = true -- Giữ orb cố định trên mặt đất
            
            -- Cập nhật giá trị vàng cho orb
            local goldValueAttr = orb:FindFirstChild("GoldValue")
            if goldValueAttr then
                goldValueAttr.Value = goldPerOrb
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
        
        goldOrb.Parent = Workspace
    end
end

-- Xử lý khi player chết (RƠI VÀNG)
local function onPlayerDeath(player)
    -- Lấy team từ biến global (đã được lưu trước đó)
    local playerTeam = playerTeamStorage[player.UserId] or "Lobby"
    
    -- Debug: In ra giá trị team
    
    -- Kiểm tra team - chỉ Team1 và Team2 rơi vàng
    if playerTeam ~= "Team1" and playerTeam ~= "Team2" then
        playerLastAttacker[player.UserId] = nil
        playerTeamStorage[player.UserId] = nil
        return
    end
    
    -- Lấy thông tin killer
    local killer = playerLastAttacker[player.UserId]
    
    -- Lấy vị trí chết
    if player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            spawnGoldOrbs(hrp.Position, GOLD_ON_PLAYER_DEATH, killer)
            if killer then
            else
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
        spawnGoldOrbs(hrp.Position, GOLD_ON_NPC_DEATH, killer)
        if killer then
        else
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
            
            -- Lưu team ngay khi health thay đổi (trước khi chết)
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
            
            -- Lưu team ngay khi health thay đổi (trước khi chết)
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

