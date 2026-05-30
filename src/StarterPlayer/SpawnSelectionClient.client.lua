-- Spawn Selection Client - Chọn vị trí spawn khi tìm thấy trận
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Biến
local spawnSelected = false
local selectedPosition = nil
local countdown = 10
local isUIVisible = false
local currentMatchData = nil
local playerTeam = nil -- Team của player hiện tại

-- Đợi RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
local spawnSelectEvent = remoteEvents:WaitForChild("SpawnSelect", 5)

-- Tạo ScreenGui (ẩn mặc định)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpawnSelectionGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false -- Ẩn mặc định
screenGui.Parent = PlayerGui

-- Overlay tối
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.ZIndex = 50
overlay.Parent = screenGui

-- Container chính (giống ExpandedMapFrame)
local container = Instance.new("Frame")
container.Name = "SpawnSelectionContainer"
container.Size = UDim2.new(0, 450, 0, 450) -- Giảm kích thước
container.Position = UDim2.new(0.5, -225, 0.5, -225)
container.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
container.BackgroundTransparency = 0.1
container.BorderColor3 = Color3.fromRGB(27, 42, 53)
container.BorderSizePixel = 1
container.ZIndex = 51
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 10)
containerCorner.Parent = container

-- Title (giống ExpandedMapFrame)
local title = Instance.new("TextLabel")
title.Name = "TitleLabel"
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 24
title.Font = Enum.Font.GothamBold
title.Text = "📍 CHỌN VỊ TRÍ SPAWN"
title.ZIndex = 52
title.Parent = container

-- Countdown (góc trên bên phải)
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.Size = UDim2.new(0, 50, 0, 50)
countdownLabel.Position = UDim2.new(1, -60, 0, 5)
countdownLabel.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
countdownLabel.BackgroundTransparency = 0.2
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countdownLabel.TextSize = 28
countdownLabel.Font = Enum.Font.GothamBold
countdownLabel.Text = "10"
countdownLabel.ZIndex = 52
countdownLabel.Parent = container

local countdownCorner = Instance.new("UICorner")
countdownCorner.CornerRadius = UDim.new(0.5, 0)
countdownCorner.Parent = countdownLabel

-- Minimap Frame (giống ExpandedMapCanvas)
local minimapFrame = Instance.new("ImageButton")
minimapFrame.Name = "MinimapFrame"
minimapFrame.Size = UDim2.new(1, -20, 1, -100) -- Để chỗ cho title và button
minimapFrame.Position = UDim2.new(0, 10, 0, 50)
minimapFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 45)
minimapFrame.BackgroundTransparency = 0.3
minimapFrame.BorderColor3 = Color3.fromRGB(27, 42, 53)
minimapFrame.BorderSizePixel = 1
minimapFrame.ZIndex = 52
minimapFrame.Parent = container

local minimapCorner = Instance.new("UICorner")
minimapCorner.CornerRadius = UDim.new(0, 10)
minimapCorner.Parent = minimapFrame

-- Map Image - Sử dụng minimap image cho từng mode
local mapImage = Instance.new("ImageLabel")
mapImage.Name = "MapImage"
mapImage.Size = UDim2.new(1, 0, 1, 0)
mapImage.BackgroundTransparency = 1
mapImage.Image = "rbxassetid://74637358865771" -- Minimap 1v1
mapImage.ZIndex = 53
mapImage.Parent = minimapFrame

-- Debug: Print map bounds

-- Overlay cho khu vực bị cấm (hiển thị khu vực không được chọn)
local restrictedOverlay = Instance.new("Frame")
restrictedOverlay.Name = "RestrictedOverlay"
restrictedOverlay.Size = UDim2.new(0.5, 0, 1, 0) -- Nửa map
restrictedOverlay.Position = UDim2.new(0, 0, 0, 0) -- Mặc định bên trái
restrictedOverlay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
restrictedOverlay.BackgroundTransparency = 0.7
restrictedOverlay.BorderSizePixel = 0
restrictedOverlay.Visible = false
restrictedOverlay.ZIndex = 54
restrictedOverlay.Parent = minimapFrame

-- Label hướng dẫn
local teamLabel = Instance.new("TextLabel")
teamLabel.Name = "TeamLabel"
teamLabel.Size = UDim2.new(0.5, 0, 0, 30)
teamLabel.Position = UDim2.new(0.25, 0, 0.45, 0)
teamLabel.BackgroundTransparency = 1
teamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
teamLabel.TextSize = 16
teamLabel.Font = Enum.Font.GothamBold
teamLabel.Text = ""
teamLabel.ZIndex = 55
teamLabel.Parent = minimapFrame

-- Map images cho từng mode
local MAP_IMAGES = {
	["1v1"] = "rbxassetid://74637358865771",
	["2v2"] = "rbxassetid://0", -- Placeholder cho 2v2
	["3v3"] = "rbxassetid://106595236253546"  -- Map3v3new image
}

-- Marker vị trí đã chọn
local marker = Instance.new("Frame")
marker.Name = "SpawnMarker"
marker.Size = UDim2.new(0, 20, 0, 20)
marker.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
marker.BackgroundTransparency = 0.2
marker.Visible = false
marker.ZIndex = 56 -- ZIndex cao hơn overlay
marker.Parent = minimapFrame

local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0.5, 0)
markerCorner.Parent = marker

local markerStroke = Instance.new("UIStroke")
markerStroke.Color = Color3.fromRGB(255, 255, 255)
markerStroke.Thickness = 2
markerStroke.Parent = marker

-- Confirm Button (dưới cùng)
local confirmBtn = Instance.new("TextButton")
confirmBtn.Name = "ConfirmButton"
confirmBtn.Size = UDim2.new(1, -20, 0, 40)
confirmBtn.Position = UDim2.new(0, 10, 1, -50)
confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmBtn.TextSize = 18
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.Text = "✓ XÁC NHẬN VỊ TRÍ"
confirmBtn.ZIndex = 60
confirmBtn.Visible = true
confirmBtn.Parent = container

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = confirmBtn

-- Instruction (ẩn, đã có title)
-- Instruction không cần nữa vì đã có title rõ ràng

-- Position info label (hiển thị tọa độ đã chọn)
local positionInfo = Instance.new("TextLabel")
positionInfo.Name = "PositionInfo"
positionInfo.Size = UDim2.new(1, -20, 0, 25)
positionInfo.Position = UDim2.new(0, 10, 1, -95)
positionInfo.BackgroundTransparency = 1
positionInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
positionInfo.TextSize = 14
positionInfo.Font = Enum.Font.Gotham
positionInfo.Text = "Click vào minimap để chọn vị trí"
positionInfo.ZIndex = 60
positionInfo.Parent = container

-- Hàm lấy thông tin map thực tế
local function getMapInfo(mode)
    -- Hardcoded bounds cho 1v1 map (đã kiểm tra thực tế)
    if mode == "1v1" then
        return {
            center = Vector3.new(50, 1.2, -1031.875),
            size = Vector3.new(1074, 0.4, 668),
            minX = -487,  -- 50 - 1074/2
            maxX = 587,   -- 50 + 1074/2
            minZ = -1365.875,  -- -1031.875 - 668/2
            maxZ = -697.875    -- -1031.875 + 668/2
        }
    elseif mode == "3v3" then
        -- Hardcoded bounds cho 3v3 map (PartMapPVPNew)
        return {
            center = Vector3.new(-150.46, 1.31, -7539.87),
            size = Vector3.new(669, 0.4, 668.38),
            minX = -485,  -- -150.46 - 334.5
            maxX = 184,   -- -150.46 + 334.5
            minZ = -7874, -- -7539.87 - 334.19
            maxZ = -7206  -- -7539.87 + 334.19
        }
    end
    
    -- Fallback cho các mode khác
    local mapsFolder = game.Workspace:FindFirstChild("Maps")
    if not mapsFolder then return nil end
    
    local mapFolderName = mode == "2v2" and "Map2v2" or "Map3v3"
    local mapFolder = mapsFolder:FindFirstChild(mapFolderName)
    if not mapFolder then return nil end
    
    -- Tìm part terrain của map
    local terrainPart = nil
    for _, child in ipairs(mapFolder:GetChildren()) do
        if child:IsA("BasePart") then
            terrainPart = child
            break
        end
    end
    
    if not terrainPart then return nil end
    
    local position = terrainPart.Position
    local size = terrainPart.Size
    
    return {
        center = position,
        size = size,
        minX = position.X - size.X / 2,
        maxX = position.X + size.X / 2,
        minZ = position.Z - size.Z / 2,
        maxZ = position.Z + size.Z / 2
    }
end

-- Hàm chuyển đổi click position sang world position
local function mapToWorldPosition(clickX, clickY, mode)
    local mapInfo = getMapInfo(mode)
    
    if not mapInfo then
        -- Fallback: sử dụng giá trị mặc định
        local mapSize = Vector3.new(200, 0, 200)
        local worldX = (clickX - 0.5) * mapSize.X
        local worldZ = (clickY - 0.5) * mapSize.Z
        return Vector3.new(worldX, 10, worldZ)
    end
    
    -- Chuyển đổi từ UI coordinates (0-1) sang world coordinates
    -- LƯU Ý: Map image bị flip ngược chiều X nên cần đảo ngược clickX
    -- clickX = 0 (bên trái UI) -> maxX (bên phải thế giới)
    -- clickX = 1 (bên phải UI) -> minX (bên trái thế giới)
    local worldX = mapInfo.maxX - clickX * (mapInfo.maxX - mapInfo.minX)
    local worldZ = mapInfo.maxZ - clickY * (mapInfo.maxZ - mapInfo.minZ)
    
    -- Y = 20 để spawn an toàn trên mặt đất
    local worldY = 20
    
    
    return Vector3.new(worldX, worldY, worldZ)
end

-- Hàm kiểm tra vị trí click có hợp lệ cho team không
local function isValidClickPosition(clickX, clickY)
    -- Team1 (Đội xanh): nửa phải map (clickX >= 0.5)
    -- Team2 (Đội đỏ): nửa trái map (clickX <= 0.5)
    
    if playerTeam then
        local teamName = playerTeam.Name
        if teamName == "Team1" then
            -- Đội xanh chỉ được chọn nửa phải
            return clickX >= 0.5
        elseif teamName == "Team2" then
            -- Đội đỏ chỉ được chọn nửa trái
            return clickX <= 0.5
        end
    end
    
    -- Mặc định cho phép tất cả
    return true
end

-- Hàm cập nhật marker
local function updateMarker(clickX, clickY)
    marker.Visible = true
    -- Sử dụng UDim2 với scale (0-1) thay vì pixel offset
    marker.Position = UDim2.new(clickX, -10, clickY, -10)
    
    -- Lấy mode hiện tại
    local mode = currentMatchData and currentMatchData.mode or "1v1"
    selectedPosition = mapToWorldPosition(clickX, clickY, mode)
    spawnSelected = true
    
    -- Cập nhật position info
    if positionInfo then
        positionInfo.Text = string.format("Vị trí: (%.1f, %.1f, %.1f)", selectedPosition.X, selectedPosition.Y, selectedPosition.Z)
    end
    
    -- Animation marker
    local tween = TweenService:Create(marker, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = UDim2.new(0, 25, 0, 25)})
    tween:Play()
    tween.Completed:Wait()
    TweenService:Create(marker, TweenInfo.new(0.2), {Size = UDim2.new(0, 20, 0, 20)}):Play()
    
end

-- Click vào minimap
minimapFrame.MouseButton1Click:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    local framePos = minimapFrame.AbsolutePosition
    local frameSize = minimapFrame.AbsoluteSize
    
    -- Tính toán vị trí click (0-1)
    local clickX = (mousePos.X - framePos.X) / frameSize.X
    local clickY = (mousePos.Y - framePos.Y) / frameSize.Y
    
    -- Kiểm tra vị trí hợp lệ cho team
    if not isValidClickPosition(clickX, clickY) then
        -- Hiển thị thông báo lỗi
        local teamSide = playerTeam and playerTeam.Name == "Team1" and "PHẢI (bên phải)" or "TRÁI (bên trái)"
        
        -- Flash màu đỏ để báo lỗi
        local originalColor = minimapFrame.BackgroundColor3
        minimapFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        task.wait(0.2)
        minimapFrame.BackgroundColor3 = originalColor
        return
    end
    
    updateMarker(clickX, clickY)
end)

-- Confirm button
confirmBtn.MouseButton1Click:Connect(function()
    if spawnSelected and selectedPosition then
        -- Gửi vị trí spawn đến server
        spawnSelectEvent:FireServer({
            action = "selectSpawn",
            position = selectedPosition
        })
        
        
        -- Ẩn UI
        screenGui.Enabled = false
        spawnSelected = false
        
        -- Dừng countdown
        countdown = 0
    else
        -- Flash nút để báo chưa chọn vị trí
        local originalColor = confirmBtn.BackgroundColor3
        confirmBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(0.2)
        confirmBtn.BackgroundColor3 = originalColor
    end
end)

-- Countdown timer
local countdownRunning = false
local function startCountdown()
    if countdownRunning then return end
    countdownRunning = true
    countdown = 10
    
    while countdown > 0 and screenGui.Enabled do
        countdownLabel.Text = tostring(countdown)
        
        -- Đổi màu khi còn ít thời gian
        if countdown <= 3 then
            countdownLabel.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        else
            countdownLabel.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        end
        
        task.wait(1)
        countdown = countdown - 1
    end
    
    -- Hết thời gian - spawn random hoặc vị trí đã chọn
    if screenGui.Enabled then
        if not spawnSelected then
            -- Random position trong khu vực được phép
            local randomX, randomZ
            if playerTeam and playerTeam.Name == "Team1" then
                -- Đội xanh: nửa phải (0.5 to 1)
                randomX = math.random() * 0.5 + 0.5
            elseif playerTeam and playerTeam.Name == "Team2" then
                -- Đội đỏ: nửa trái (0 to 0.5)
                randomX = math.random() * 0.5
            else
                randomX = math.random()
            end
            randomZ = math.random()
            
            local mode = currentMatchData and currentMatchData.mode or "1v1"
            selectedPosition = mapToWorldPosition(randomX, randomZ, mode)
        end
        
        -- Gửi vị trí đến server
        spawnSelectEvent:FireServer({
            action = "selectSpawn",
            position = selectedPosition
        })
        
        -- Ẩn UI
        screenGui.Enabled = false
        spawnSelected = false
    end
    
    countdownRunning = false
end

-- Hàm hiển thị UI chọn spawn
local function showSpawnSelection(matchData)
    currentMatchData = matchData
    isUIVisible = true
    spawnSelected = false
    selectedPosition = nil
    marker.Visible = false
    
    -- Reset position info
    if positionInfo then
        positionInfo.Text = "Click vào minimap để chọn vị trí"
    end
    
    -- Lấy team của player
    playerTeam = player.Team
    
    -- Cập nhật map image dựa trên mode
    if matchData and matchData.mode then
        local mapImageId = MAP_IMAGES[matchData.mode] or MAP_IMAGES["1v1"]
        mapImage.Image = mapImageId
    end
    
    -- Hiển thị overlay khu vực bị cấm dựa trên team
    if playerTeam then
        restrictedOverlay.Visible = true
        if playerTeam.Name == "Team1" then
            -- Đội xanh: bị cấm bên trái, overlay ở bên trái
            restrictedOverlay.Position = UDim2.new(0, 0, 0, 0)
            restrictedOverlay.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            teamLabel.Text = "ĐỘI XANH\nChọn bên PHẢI →"
            teamLabel.Position = UDim2.new(0.25, 0, 0.45, 0)
        elseif playerTeam.Name == "Team2" then
            -- Đội đỏ: bị cấm bên phải, overlay ở bên phải
            restrictedOverlay.Position = UDim2.new(0.5, 0, 0, 0)
            restrictedOverlay.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            teamLabel.Text = "ĐỘI ĐỎ\nChọn bên TRÁI ←"
            teamLabel.Position = UDim2.new(0.25, 0, 0.45, 0)
        end
    else
        restrictedOverlay.Visible = false
        teamLabel.Text = ""
    end
    
    -- Ẩn minimap khi đang chọn spawn
    local minimapGui = PlayerGui:FindFirstChild("MinimapGui")
    if minimapGui then
        minimapGui.Enabled = false
    end
    
    -- Hiển thị UI
    screenGui.Enabled = true
    
    -- Cập nhật title với thông tin trận và team
    if matchData and matchData.mode then
        local teamInfo = ""
        if playerTeam then
            if playerTeam.Name == "Team1" then
                teamInfo = " (ĐỘI XANH - Bên phải)"
            elseif playerTeam.Name == "Team2" then
                teamInfo = " (ĐỘI ĐỎ - Bên trái)"
            end
        end
        title.Text = "📍 CHỌN VỊ TRÍ SPAWN - " .. matchData.mode:upper() .. teamInfo
    end
    
    -- Bắt đầu countdown
    task.spawn(startCountdown)
    
end

-- Hàm ẩn UI
local function hideSpawnSelection()
    isUIVisible = false
    screenGui.Enabled = false
    
    -- Ẩn overlay
    restrictedOverlay.Visible = false
    teamLabel.Text = ""
    
    -- Hiển thị lại minimap
    local minimapGui = PlayerGui:FindFirstChild("MinimapGui")
    if minimapGui then
        minimapGui.Enabled = true
    end
end

-- Lắng nghe khi bắt đầu chọn spawn
spawnSelectEvent.OnClientEvent:Connect(function(data)
    if data.action == "startSelection" then
        showSpawnSelection(data)
    elseif data.action == "endSelection" then
        screenGui.Enabled = false
        isUIVisible = false
        
        -- Ẩn overlay
        restrictedOverlay.Visible = false
        teamLabel.Text = ""
        
        -- Hiển thị lại minimap
        local minimapGui = PlayerGui:FindFirstChild("MinimapGui")
        if minimapGui then
            minimapGui.Enabled = true
        end
    end
end)

