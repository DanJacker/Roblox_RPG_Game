-- IceShard System - Server Side
-- Handles ice shard projectile, collision detection, and damage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SkillConfig = require(ReplicatedStorage:FindFirstChild("Modules"):FindFirstChild("SkillConfig"))

-- Configuration from SkillConfig
local skillInfo = SkillConfig.Skills["IceShard"]
local ICE_SPEED = skillInfo and skillInfo.speed or 90
local ICE_DAMAGE = skillInfo and skillInfo.damage or 12
local ICE_RANGE = 100
local ICE_LIFETIME = 5
local ICE_SPIN_SPEED = 12 -- radians per second for spinning

-- Get templates
local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
local iceShardModel = assetsFolder and assetsFolder:FindFirstChild("IceShard")
local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")
local impactTemplate = effectsFolder and effectsFolder:FindFirstChild("IceShardImpactVFX")

-- RemoteEvent for client communication
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
    remoteEventsFolder = Instance.new("Folder")
    remoteEventsFolder.Name = "RemoteEvents"
    remoteEventsFolder.Parent = ReplicatedStorage
end

local iceShardRemote = remoteEventsFolder:FindFirstChild("IceShardRemote")
if not iceShardRemote then
    iceShardRemote = Instance.new("RemoteEvent")
    iceShardRemote.Name = "IceShardRemote"
    iceShardRemote.Parent = remoteEventsFolder
end

-- Track cooldowns per player
local cooldowns = {}

-- Function to create impact VFX
local function createImpactVFX(position, normal)
    if not impactTemplate then return end
    
    local impact = impactTemplate:Clone()
    impact.CFrame = CFrame.new(position)
    impact.Parent = Workspace
    
    -- Emit particles
    local particles = impact:FindFirstChild("ImpactBurst")
    if particles then
        particles:Emit(30)
    end
    
    -- Remove after effect
    task.delay(1, function()
        if impact and impact.Parent then
            impact.Parent = nil
        end
    end)
end

-- Function to apply damage to target
local function applyDamage(target, attacker)
    local character = target.Parent
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid:TakeDamage(ICE_DAMAGE)
        
        -- Notify attacker of hit
        local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
        if attackerPlayer then
            iceShardRemote:FireClient(attackerPlayer, "Hit", character.Name)
        end
    end
end

-- Function to add ice VFX to all parts in the model
local function addIceShardVFX(part)
    -- Ice sparkle effect
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "IceParticles"
    particles.Texture = "rbxassetid://7479795309"
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 220, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 150, 255)),
    })
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Lifetime = NumberRange.new(0.3, 0.5)
    particles.Rate = 50
    particles.Speed = NumberRange.new(2, 4)
    particles.SpreadAngle = Vector2.new(25, 25)
    particles.LightEmission = 0.6
    particles.Parent = part

    -- Blue point light
    local light = Instance.new("PointLight")
    light.Name = "IceGlow"
    light.Color = Color3.fromRGB(100, 200, 255)
    light.Brightness = 2
    light.Range = 10
    light.Parent = part
end

-- Function to create and launch ice shard
local function launchIceShard(player, origin, direction)
    if not iceShardModel then 
        warn("IceShard model not found in ReplicatedStorage.Assets!")
        return 
    end
    
    -- Check cooldown
    local currentTime = tick()
    local cooldownTime = skillInfo and skillInfo.cooldown or 3.5
    if cooldowns[player] and currentTime - cooldowns[player] < cooldownTime then
        return -- Still on cooldown
    end
    cooldowns[player] = currentTime
    
    -- Create ice shard from model
    local iceShard = iceShardModel:Clone()
    iceShard.Name = "ActiveIceShard"
    
    -- Setup all Parts inside the model for projectile use
    local firstPart = nil
    for _, child in iceShard:GetChildren() do
        if child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            child.CanQuery = false
            child.CanTouch = false
            child.Material = Enum.Material.Ice
            child.Color = Color3.fromRGB(100, 200, 255)
            child.Transparency = 0.15
            
            -- Add VFX to each part
            addIceShardVFX(child)
            
            if not firstPart then
                firstPart = child
            end
        end
    end
    
    if not firstPart then
        warn("IceShard model has no Parts!")
        iceShard.Parent = nil
        return
    end
    
    -- Position the model: align +X axis (pointed end) with direction, then spin
    local baseCFrame = CFrame.new(origin, origin + direction) * CFrame.Angles(0, math.rad(90), 0)
    iceShard:PivotTo(baseCFrame)
    iceShard.Parent = Workspace
    
    -- Track distance traveled
    local distanceTraveled = 0
    local startTime = tick()
    
    -- Movement loop
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not iceShard or not iceShard.Parent then
            connection:Disconnect()
            return
        end
        
        -- Check lifetime
        if tick() - startTime > ICE_LIFETIME then
            iceShard.Parent = nil
            connection:Disconnect()
            return
        end
        
        -- Move ice shard
        local moveDistance = ICE_SPEED * dt
        local currentPos = firstPart.Position
        local newPosition = currentPos + direction * moveDistance
        
        -- Check for collisions using Raycast
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {player.Character, iceShard}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local rayResult = Workspace:Raycast(currentPos, direction * moveDistance * 2, raycastParams)
        
        if rayResult then
            -- Hit something!
            createImpactVFX(rayResult.Position, rayResult.Normal)
            
            -- Check if hit a player
            if rayResult.Instance then
                applyDamage(rayResult.Instance, player.Character)
            end
            
            -- Remove ice shard
            iceShard.Parent = nil
            connection:Disconnect()
        else
            -- No collision, move the ice shard with spinning
            local elapsed = tick() - startTime
            local spinAngle = elapsed * ICE_SPIN_SPEED
            local flyCFrame = CFrame.new(newPosition, newPosition + direction) 
                * CFrame.Angles(0, math.rad(90), 0) 
                * CFrame.Angles(spinAngle, 0, 0)
            iceShard:PivotTo(flyCFrame)
            distanceTraveled = distanceTraveled + moveDistance
            
            -- Check range limit
            if distanceTraveled > ICE_RANGE then
                iceShard.Parent = nil
                connection:Disconnect()
            end
        end
    end)
end

-- Listen for ice shard requests from clients
iceShardRemote.OnServerEvent:Connect(function(player, action, ...)
    if action == "Launch" then
        local origin = ...
        local character = player.Character
        if not character then return end
        
        -- Get direction from character's HumanoidRootPart
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local direction = hrp.CFrame.LookVector
        launchIceShard(player, origin, direction)
    end
end)

-- Clean up cooldowns when players leave
Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)

print("[IceShardSystem] Loaded successfully")