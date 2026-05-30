-- HealthBarManager - Hiển thị thanh máu trên đầu bot và monster
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


-- Cấu hình
local CONFIG = {
    HEALTH_BAR_HEIGHT = 4, -- Độ cao so với đầu
    HEALTH_BAR_WIDTH = 4,
    HEALTH_BAR_SIZE_Y = 0.4,
    BACKGROUND_COLOR = Color3.fromRGB(50, 50, 50),
    HEALTH_COLOR = Color3.fromRGB(0, 255, 0),
    DAMAGE_COLOR = Color3.fromRGB(255, 0, 0),
    BOT_COLOR = Color3.fromRGB(0, 150, 255), -- Xanh dương cho bot
    MONSTER_COLOR = Color3.fromRGB(150, 0, 200), -- Tím cho monster
    PLAYER_ENEMY_COLOR = Color3.fromRGB(255, 50, 50), -- Đỏ cho player địch
}

-- Lưu trữ các health bar đã tạo (sử dụng Name làm key)
local healthBars = {}

-- Tạo thanh máu cho một character
local function createHealthBar(character, isBot, isMonster, teamName)
    if not character then
        return
    end
    
    -- Đợi character được setup đầy đủ
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    
    if not humanoid or not head then
        -- Thử lại sau 0.5 giây
        task.delay(0.5, function()
            if character and character.Parent then
                createHealthBar(character, isBot, isMonster, teamName)
            end
        end)
        return
    end
    
    -- Xóa health bar cũ nếu có
    local oldGUI = character:FindFirstChild("HealthBarGUI")
    if oldGUI then
        oldGUI:Destroy()
    end
    
    -- Tạo BillboardGui
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "HealthBarGUI"
    billboardGui.Size = UDim2.new(CONFIG.HEALTH_BAR_WIDTH, 0, CONFIG.HEALTH_BAR_SIZE_Y, 0)
    billboardGui.StudsOffset = Vector3.new(0, CONFIG.HEALTH_BAR_HEIGHT, 0)
    billboardGui.Adornee = head
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = character
    
    -- Background (nền đen)
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = CONFIG.BACKGROUND_COLOR
    background.BorderSizePixel = 0
    background.Parent = billboardGui
    
    -- Health bar (thanh máu)
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.BackgroundColor3 = isBot and CONFIG.BOT_COLOR or (isMonster and CONFIG.MONSTER_COLOR or CONFIG.HEALTH_COLOR)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = background
    
    -- Viền bo tròn
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.3, 0)
    corner.Parent = background
    
    local healthCorner = Instance.new("UICorner")
    healthCorner.CornerRadius = UDim.new(0.3, 0)
    healthCorner.Parent = healthBar
    
    -- Text hiển thị tên
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = character.Name
    nameLabel.Parent = background
    
    -- Lưu reference (sử dụng character.Name làm key)
    healthBars[character.Name] = {
        character = character,
        gui = billboardGui,
        healthBar = healthBar,
        humanoid = humanoid,
        nameLabel = nameLabel,
        isBot = isBot,
        isMonster = isMonster,
        lastHealth = humanoid.Health,
        maxHealth = humanoid.MaxHealth
    }
    
end

-- Cập nhật thanh máu
local function updateHealthBars()
    for name, data in pairs(healthBars) do
        local character = data.character
        if not character or not character.Parent then
            healthBars[name] = nil
            continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            continue
        end
        
        -- Cập nhật nếu máu thay đổi
        local currentHealth = humanoid.Health
        if data.lastHealth ~= currentHealth then
            data.lastHealth = currentHealth
            local healthPercent = currentHealth / humanoid.MaxHealth
            
            -- Cập nhật kích thước thanh máu
            if data.healthBar and data.healthBar.Parent then
                data.healthBar.Size = UDim2.new(math.max(0, healthPercent), 0, 1, 0)
                
                -- Cập nhật màu theo lượng máu
                if healthPercent > 0.6 then
                    data.healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 0.3 then
                    data.healthBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                else
                    data.healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                end
                
            end
            
            -- Xử lý khi chết
            if currentHealth <= 0 then
                if data.gui then
                    data.gui:Destroy()
                end
                healthBars[name] = nil
            end
        end
    end
end

-- Kiểm tra và tạo thanh máu cho tất cả bot/monster hiện có
local function scanAndCreateHealthBars()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local name = obj.Name
            local isBot = string.find(name, "[BOT", 1, true) ~= nil
            local isMonster = string.find(name, "[MONSTER", 1, true) ~= nil or 
                              string.find(name, "[Monster", 1, true) ~= nil or
                              obj:GetAttribute("IsMonster") or 
                              obj:GetAttribute("IsPatrolMonster")
            
            if (isBot or isMonster) and not healthBars[obj.Name] then
                createHealthBar(obj, isBot, isMonster, obj:GetAttribute("Team"))
            end
        end
    end
end

-- Theo dõi character mới được thêm vào workspace
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") then
        task.wait(0.2) -- Đợi character được setup đầy đủ
        
        local name = descendant.Name
        local isBot = string.find(name, "[BOT", 1, true) ~= nil
        local isMonster = string.find(name, "[MONSTER", 1, true) ~= nil or 
                          string.find(name, "[Monster", 1, true) ~= nil or
                          descendant:GetAttribute("IsMonster") or 
                          descendant:GetAttribute("IsPatrolMonster")
        
        if isBot or isMonster then
            createHealthBar(descendant, isBot, isMonster, descendant:GetAttribute("Team"))
        end
    end
end)

-- Xử lý khi character bị xóa
workspace.DescendantRemoving:Connect(function(descendant)
    if descendant:IsA("Model") and healthBars[descendant.Name] then
        healthBars[descendant.Name] = nil
    end
end)

-- Quét và tạo thanh máu cho tất cả bot/monster hiện có
scanAndCreateHealthBars()

-- Cập nhật thanh máu mỗi frame
RunService.Heartbeat:Connect(updateHealthBars)


-- Debug: In ra số lượng health bars
spawn(function()
    while task.wait(5) do
        local count = 0
        for _ in pairs(healthBars) do
            count = count + 1
        end
    end
end)
