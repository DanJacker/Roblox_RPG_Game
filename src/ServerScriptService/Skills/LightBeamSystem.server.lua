-- Light Beam System (Ultimate) - Server Side
-- Handles rainbow beam projectile, collision detection, and damage
-- Beam shoots from player's body and extends forward

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration (Lux style - Final Spark)
local BEAM_SPEED = 300
local BEAM_DAMAGE = 100
local BEAM_WIDTH = 6
local BEAM_MAX_RANGE = 200
local BEAM_LIFETIME = 0.8
local COOLDOWN = 10
local CHECK_INTERVAL = 0.05
local CHANNEL_TIME = 1.5 -- Thời gian tích tụ như Lux

-- Get templates
local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")
local beamTemplate = effectsFolder and effectsFolder:FindFirstChild("LightBeamVFX")
local impactTemplate = effectsFolder and effectsFolder:FindFirstChild("LightBeamImpactVFX")
local startTemplate = effectsFolder and effectsFolder:FindFirstChild("BeamStartVFX")

-- RemoteEvent for client communication
local lightBeamRemote = ReplicatedStorage:FindFirstChild("LightBeamRemote")

-- Track cooldowns per player
local cooldowns = {}

-- Function to create impact VFX
local function createImpactVFX(position)
    if not impactTemplate then return end
    
    local impact = impactTemplate:Clone()
    impact.CFrame = CFrame.new(position)
    impact.Parent = Workspace
    
    local particles = impact:FindFirstChild("WhiteBurst")
    if particles then
        particles:Emit(20)
    end
    
    task.delay(1, function()
        if impact and impact.Parent then
            impact.Parent = nil
        end
    end)
end

-- Function to apply damage to target
local function applyDamage(target, attacker, attackerPlayer)
    local character = target.Parent
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid:TakeDamage(BEAM_DAMAGE)
        
        if attackerPlayer then
            lightBeamRemote:FireClient(attackerPlayer, "Hit", character.Name)
        end
        return true
    end
    return false
end

-- Function to check if a point is within beam path
local function isInBeamPath(point, beamStart, beamDirection, beamLength, beamWidth)
    local toPoint = point - beamStart
    local projection = toPoint:Dot(beamDirection)
    
    if projection < 0 or projection > beamLength then
        return false
    end
    
    local closestPoint = beamStart + beamDirection * projection
    local perpendicularDistance = (point - closestPoint).Magnitude
    
    return perpendicularDistance <= beamWidth
end

-- Function to create and launch light beam from player's body
local function launchLightBeam(player)
    if not beamTemplate then 
        warn("LightBeamVFX template not found!")
        return 
    end
    
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
    
    -- Beam starts from player's body/chest
    local direction = hrp.CFrame.LookVector
    local beamStartPos = hrp.Position + Vector3.new(0, 1, 0) -- Chest height
    
    -- === LUX STYLE: Channeling phase với vòng tròn mở rộng ===
    local channelEffect = Instance.new("Part")
    channelEffect.Name = "LuxChannelEffect"
    channelEffect.Shape = Enum.PartType.Cylinder
    channelEffect.Size = Vector3.new(0.5, 1, 1)
    channelEffect.Color = Color3.fromRGB(255, 255, 200)
    channelEffect.Material = Enum.Material.Neon
    channelEffect.Anchored = true
    channelEffect.CanCollide = false
    channelEffect.Transparency = 0.5
    channelEffect.Parent = Workspace
    
    -- Vòng tròn cảnh báo (như Lux)
    local warningRing = Instance.new("Part")
    warningRing.Name = "WarningRing"
    warningRing.Shape = Enum.PartType.Cylinder
    warningRing.Size = Vector3.new(0.1, 1, 1)
    warningRing.Color = Color3.fromRGB(255, 200, 100)
    warningRing.Material = Enum.Material.Neon
    warningRing.Anchored = true
    warningRing.CanCollide = false
    warningRing.Transparency = 0.7
    warningRing.Parent = Workspace
    
    -- Channeling animation
    local channelStartTime = tick()
    local channelTask = task.spawn(function()
        while tick() - channelStartTime < CHANNEL_TIME do
            local elapsed = tick() - channelStartTime
            local progress = elapsed / CHANNEL_TIME
            
            -- Vòng tròn đứng dọc mở rộng dần
            local ringSize = 5 + progress * 15
            warningRing.Size = Vector3.new(0.1, ringSize, ringSize)
            -- Vòng tròn đứng dọc, xoay 90 độ
            local ringPos = beamStartPos + direction * 5
            warningRing.CFrame = CFrame.new(ringPos, ringPos + direction) * CFrame.Angles(0, math.rad(90), 0)
            warningRing.Transparency = 0.7 - progress * 0.3
            
            -- Hiệu ứng tích tụ (hướng giống vòng tròn)
            channelEffect.Size = Vector3.new(0.5 + progress * 2, 2 + progress * 3, 2 + progress * 3)
            channelEffect.CFrame = CFrame.new(beamStartPos, beamStartPos + direction) * CFrame.Angles(0, math.rad(90), 0)
            channelEffect.Transparency = 0.5 - progress * 0.2
            
            task.wait(0.03)
        end
    end)
    
    -- Đợi channel xong
    task.wait(CHANNEL_TIME)
    
    -- Xóa hiệu ứng channel
    if channelEffect and channelEffect.Parent then channelEffect.Parent = nil end
    if warningRing and warningRing.Parent then warningRing.Parent = nil end
    
    -- Create beam start glow effect
    local startGlow = nil
    if startTemplate then
        startGlow = startTemplate:Clone()
        startGlow.CFrame = CFrame.new(beamStartPos)
        startGlow.Parent = Workspace
    end
    
    -- Create beam - LUX STYLE (to hơn, đẹp hơn)
    local beam = Instance.new("Part")
    beam.Name = "LightBeam"
    beam.Shape = Enum.PartType.Block
    beam.Size = Vector3.new(BEAM_WIDTH, BEAM_WIDTH, 1)
    beam.Color = Color3.fromRGB(255, 255, 200) -- Màu vàng như Lux
    beam.Material = Enum.Material.Neon
    beam.Anchored = true
    beam.CanCollide = false
    beam.Transparency = 0.1
    beam.Parent = Workspace
    
    -- Add glow effect mạnh hơn
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 255, 200)
    light.Brightness = 2
    light.Range = 25
    light.Parent = beam
    
    -- Track damaged targets
    local damagedTargets = {}
    
    -- Beam expansion with optimized checking
    local startTime = tick()
    local currentLength = 0
    local lastCheckTime = 0
    
    task.spawn(function()
        while task.wait(0.03) do
            local elapsed = tick() - startTime
            
            if elapsed > BEAM_LIFETIME or not beam or not beam.Parent then
                if beam and beam.Parent then
                    beam.Parent = nil
                end
                if startGlow and startGlow.Parent then
                    startGlow.Parent = nil
                end
                break
            end
            
            -- Expand beam - hình chữ nhật kéo dài về phía trước
            currentLength = math.min(currentLength + BEAM_SPEED * 0.03, BEAM_MAX_RANGE)
            -- Block: Z = chiều dài (hướng về phía trước)
            beam.Size = Vector3.new(BEAM_WIDTH, BEAM_WIDTH, currentLength)
            -- Position beam so tail starts at player body
            local beamCenter = beamStartPos + direction * (currentLength / 2)
            -- LookVector (-Z) hướng về phía trước
            beam.CFrame = CFrame.new(beamCenter, beamCenter - direction)
            
            -- Check for enemies (less frequently for performance)
            if tick() - lastCheckTime >= CHECK_INTERVAL then
                lastCheckTime = tick()
                
                -- Check players
                for _, targetPlayer in ipairs(Players:GetPlayers()) do
                    if targetPlayer ~= player and targetPlayer.Character then
                        local targetChar = targetPlayer.Character
                        if not damagedTargets[targetChar] then
                            local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                            local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
                            
                            if targetHrp and humanoid and humanoid.Health > 0 then
                                if isInBeamPath(targetHrp.Position, beamStartPos, direction, currentLength, BEAM_WIDTH) then
                                    humanoid:TakeDamage(BEAM_DAMAGE)
                                    damagedTargets[targetChar] = true
                                    createImpactVFX(targetHrp.Position)
                                    lightBeamRemote:FireClient(player, "Hit", targetChar.Name)
                                end
                            end
                        end
                    end
                end
                
                -- Check NPCs/Bots
                local npcsFolder = Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots") or Workspace:FindFirstChild("Monsters")
                if npcsFolder then
                    for _, npc in ipairs(npcsFolder:GetChildren()) do
                        if not damagedTargets[npc] then
                            local humanoid = npc:FindFirstChildOfClass("Humanoid")
                            local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc.PrimaryPart
                            
                            if humanoid and humanoid.Health > 0 and rootPart then
                                if isInBeamPath(rootPart.Position, beamStartPos, direction, currentLength, BEAM_WIDTH) then
                                    humanoid:TakeDamage(BEAM_DAMAGE)
                                    damagedTargets[npc] = true
                                    createImpactVFX(rootPart.Position)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Listen for light beam requests from clients
lightBeamRemote.OnServerEvent:Connect(function(player, action)
    if action == "Launch" then
        launchLightBeam(player)
    end
end)

-- Clean up cooldowns when players leave
Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)

print("Light Beam System loaded! (Ultimate - shoots from body)")