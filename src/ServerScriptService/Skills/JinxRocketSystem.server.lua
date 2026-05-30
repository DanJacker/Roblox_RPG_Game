-- Jinx Rocket System (Super Mega Death Rocket)
-- Tên lửa to dần khi bay, nổ lớn khi va chạm

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Configuration
local ROCKET_SPEED = 80
local ROCKET_DAMAGE = 150
local ROCKET_EXPLOSION_RADIUS = 20
local ROCKET_MAX_RANGE = 300
local COOLDOWN = 15
local GROWTH_RATE = 3.0 -- Tốc độ to lên (gấp đôi)

-- RemoteEvent
local rocketRemote = Instance.new("RemoteEvent")
rocketRemote.Name = "JinxRocketRemote"
rocketRemote.Parent = ReplicatedStorage

-- Track cooldowns
local cooldowns = {}

-- Function to create explosion effect
local function createExplosion(position)
    -- Vụ nổ lớn
    local explosion = Instance.new("Part")
    explosion.Name = "Explosion"
    explosion.Shape = Enum.PartType.Ball
    explosion.Size = Vector3.new(1, 1, 1)
    explosion.Color = Color3.fromRGB(255, 100, 50)
    explosion.Material = Enum.Material.Neon
    explosion.Anchored = true
    explosion.CanCollide = false
    explosion.Transparency = 0.3
    explosion.CFrame = CFrame.new(position)
    explosion.Parent = Workspace
    
    -- Light
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 150, 50)
    light.Brightness = 5
    light.Range = 50
    light.Parent = explosion
    
    -- Animation vụ nổ mở rộng
    task.spawn(function()
        for i = 1, 30 do
            local size = i * 2
            explosion.Size = Vector3.new(size, size, size)
            explosion.Transparency = 0.3 + (i / 30) * 0.7
            light.Brightness = 5 - (i / 30) * 4
            task.wait(0.02)
        end
        explosion.Parent = nil
    end)
    
    -- Damage trong bán kính
    task.wait(0.1)
    for _, target in ipairs(Workspace:GetDescendants()) do
        if target:IsA("Model") or target:IsA("BasePart") then
            local character = target:IsA("Model") and target or target.Parent
            if character and character:FindFirstChildOfClass("Humanoid") then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
                if rootPart and humanoid and humanoid.Health > 0 then
                    local distance = (rootPart.Position - position).Magnitude
                    if distance <= ROCKET_EXPLOSION_RADIUS then
                        -- Damage giảm theo khoảng cách
                        local damageMultiplier = 1 - (distance / ROCKET_EXPLOSION_RADIUS) * 0.5
                        humanoid:TakeDamage(ROCKET_DAMAGE * damageMultiplier)
                    end
                end
            end
        end
    end
end

-- Function to launch rocket
local function launchRocket(player)
    local character = player.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Check cooldown
    local currentTime = tick()
    if cooldowns[player] and currentTime - cooldowns[player] < COOLDOWN then
        return
    end
    cooldowns[player] = currentTime
    
    local direction = hrp.CFrame.LookVector
    local startPos = hrp.Position + direction * 3 + Vector3.new(0, 1, 0)
    
    -- Create rocket (dài và nhọn như tên lửa thật)
    local rocket = Instance.new("Part")
    rocket.Name = "JinxRocket"
    rocket.Shape = Enum.PartType.Cylinder
    rocket.Size = Vector3.new(4, 1, 1) -- Dài hơn, mỏng hơn
    rocket.Color = Color3.fromRGB(255, 50, 50)
    rocket.Material = Enum.Material.Neon
    rocket.Anchored = true
    rocket.CanCollide = false
    rocket.CFrame = CFrame.new(startPos, startPos + direction) * CFrame.Angles(0, math.rad(90), 0)
    rocket.Parent = Workspace
    
    -- Đầu nhọn của tên lửa
    local rocketTip = Instance.new("Part")
    rocketTip.Name = "RocketTip"
    rocketTip.Shape = Enum.PartType.Cylinder
    rocketTip.Size = Vector3.new(1.5, 0.5, 0.5)
    rocketTip.Color = Color3.fromRGB(255, 200, 100)
    rocketTip.Material = Enum.Material.Neon
    rocketTip.Anchored = true
    rocketTip.CanCollide = false
    rocketTip.CFrame = CFrame.new(startPos + direction * 2.75, startPos + direction) * CFrame.Angles(0, math.rad(90), 0)
    rocketTip.Parent = Workspace
    
    -- Rocket light
    local rocketLight = Instance.new("PointLight")
    rocketLight.Color = Color3.fromRGB(255, 100, 50)
    rocketLight.Brightness = 2
    rocketLight.Range = 15
    rocketLight.Parent = rocket
    
    -- Track rocket parts for cleanup
    local rocketParts = {rocket, rocketTip}
    
    -- Trail (khói)
    local trail = Instance.new("Part")
    trail.Name = "RocketTrail"
    trail.Shape = Enum.PartType.Cylinder
    trail.Size = Vector3.new(1, 0.5, 0.5)
    trail.Color = Color3.fromRGB(100, 100, 100)
    trail.Material = Enum.Material.SmoothPlastic
    trail.Anchored = true
    trail.CanCollide = false
    trail.Transparency = 0.5
    trail.Parent = Workspace
    
    -- Flight
    local traveled = 0
    local currentLength = 4
    local currentWidth = 1
    
    task.spawn(function()
        while traveled < ROCKET_MAX_RANGE do
            -- Di chuyển
            local moveStep = ROCKET_SPEED * 0.03
            traveled = traveled + moveStep
            
            local newPos = startPos + direction * traveled
            rocket.CFrame = CFrame.new(newPos, newPos + direction) * CFrame.Angles(0, math.rad(90), 0)
            rocketTip.CFrame = CFrame.new(newPos + direction * (currentLength / 2 + 0.75), newPos + direction) * CFrame.Angles(0, math.rad(90), 0)
            
            -- To dần lên (như Jinx)
            currentLength = currentLength + GROWTH_RATE * 0.03
            currentWidth = currentWidth + GROWTH_RATE * 0.02
            rocket.Size = Vector3.new(currentLength, currentWidth, currentWidth)
            rocketTip.Size = Vector3.new(currentLength * 0.4, currentWidth * 0.5, currentWidth * 0.5)
            rocketLight.Range = 15 + currentLength * 2
            
            -- Trail theo sau
            trail.Size = Vector3.new(traveled * 0.3, currentWidth * 0.5, currentWidth * 0.5)
            trail.CFrame = CFrame.new(startPos + direction * (traveled / 2), startPos + direction * traveled) * CFrame.Angles(0, 0, math.rad(90))
            trail.Transparency = 0.5 + (traveled / ROCKET_MAX_RANGE) * 0.3
            
            -- Check va chạm
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {character, rocket, rocketTip, trail}
            params.FilterType = Enum.RaycastFilterType.Exclude
            
            local raycast = Workspace:Raycast(newPos - direction * moveStep, direction * moveStep * 2, params)
            if raycast then
                -- Nổ khi va chạm
                createExplosion(raycast.Position)
                for _, part in ipairs(rocketParts) do
                    if part and part.Parent then part.Parent = nil end
                end
                trail.Parent = nil
                return
            end
            
            task.wait(0.03)
        end
        
        -- Hết tầm, nổ tại vị trí cuối
        createExplosion(rocket.Position)
        for _, part in ipairs(rocketParts) do
            if part and part.Parent then part.Parent = nil end
        end
        trail.Parent = nil
    end)
end

-- Listen for rocket requests
rocketRemote.OnServerEvent:Connect(function(player, action)
    if action == "Launch" then
        launchRocket(player)
    end
end)

-- Clean up cooldowns
Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)

