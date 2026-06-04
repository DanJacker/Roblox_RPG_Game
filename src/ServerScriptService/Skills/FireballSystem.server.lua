-- Fireball System - Server Side
-- Handles fireball projectile, collision detection, and damage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Load skill config so server cooldowns match client
local SkillConfig = nil
pcall(function()
    SkillConfig = require(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("SkillConfig"))
end)

-- Configuration
local FIREBALL_SPEED = 80
local FIREBALL_DAMAGE = 30
local FIREBALL_RANGE = 100
local FIREBALL_LIFETIME = 5

-- Get templates
local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")
local fireballTemplate = effectsFolder and effectsFolder:FindFirstChild("FireballVFX")
local impactTemplate = effectsFolder and effectsFolder:FindFirstChild("FireballImpactVFX")

-- Prefer a model stored in ReplicatedStorage.Assets/FireBall if available
local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
local fireballAsset = assetsFolder and assetsFolder:FindFirstChild("FireBall")

-- RemoteEvent for client communication
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
    remoteEventsFolder = Instance.new("Folder")
    remoteEventsFolder.Name = "RemoteEvents"
    remoteEventsFolder.Parent = ReplicatedStorage
end

local fireballRemote = remoteEventsFolder:FindFirstChild("FireballRemote")
if not fireballRemote then
    fireballRemote = Instance.new("RemoteEvent")
    fireballRemote.Name = "FireballRemote"
    fireballRemote.Parent = remoteEventsFolder
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
        humanoid:TakeDamage(FIREBALL_DAMAGE)
        
        -- Notify attacker of hit (optional feedback)
        local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
        if attackerPlayer then
            fireballRemote:FireClient(attackerPlayer, "Hit", character.Name)
        end
    end
end

-- Function to create and launch fireball
local function launchFireball(player, origin, direction)
    if not fireballTemplate and not fireballAsset then
        warn("No fireball template found in Effects.FireballVFX or Assets.FireBall")
        return
    end
    
    -- Check cooldown (use SkillConfig if available)
    local currentTime = tick()
    local skillCooldown = 5
    if SkillConfig and SkillConfig.Skills and SkillConfig.Skills.Fireball and SkillConfig.Skills.Fireball.cooldown then
        skillCooldown = SkillConfig.Skills.Fireball.cooldown
    end

    if cooldowns[player] and currentTime - cooldowns[player] < skillCooldown then
        return -- Still on cooldown
    end
    cooldowns[player] = currentTime
    
    -- Create fireball: prefer `Effects.FireballVFX` visual, otherwise fallback to `Assets.FireBall`
    local fireball = nil
    if fireballTemplate then
        fireball = fireballTemplate:Clone()
        fireball.CFrame = CFrame.new(origin, origin + direction)
        fireball.Parent = Workspace
    elseif fireballAsset then
        fireball = fireballAsset:Clone()
        -- Determine mover part on the cloned asset
        local mover = nil
        if fireball:IsA("Model") then
            if fireball.PrimaryPart then
                mover = fireball.PrimaryPart
                mover.CFrame = CFrame.new(origin, origin + direction)
            else
                for _, c in ipairs(fireball:GetDescendants()) do
                    if c:IsA("BasePart") then
                        mover = c
                        mover.CFrame = CFrame.new(origin, origin + direction)
                        break
                    end
                end
            end
        elseif fireball:IsA("BasePart") then
            mover = fireball
            mover.CFrame = CFrame.new(origin, origin + direction)
        end
        fireball.Parent = Workspace

        -- If an Effects template exists, attach its visual parts to the spawned model
        if fireballTemplate then
            local vfxClone = fireballTemplate:Clone()
            -- Position vfxClone to the mover
            if mover and vfxClone then
                if vfxClone:IsA("Model") then
                    local vfxPart = vfxClone.PrimaryPart
                    if not vfxPart then
                        for _, c in ipairs(vfxClone:GetDescendants()) do
                            if c:IsA("BasePart") then
                                vfxPart = c
                                break
                            end
                        end
                    end
                    if vfxPart then
                        vfxPart.CFrame = mover.CFrame
                    end
                elseif vfxClone:IsA("BasePart") then
                    vfxClone.CFrame = mover.CFrame
                end
            end
            vfxClone.Parent = fireball

            -- Weld and cleanup: make VFX parts non-colliding and weld them to mover so they follow the model
            if mover then
                for _, p in ipairs(vfxClone:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.CanCollide = false
                        p.Anchored = false
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = p
                        weld.Part1 = mover
                        weld.Parent = p
                    end
                end
            end
        end
    end
    
    -- Track distance traveled
    local distanceTraveled = 0
    local startTime = tick()

    -- Determine mover part (BasePart used for position queries and raycasts)
    local mover = fireball
    if fireball and fireball:IsA("Model") then
        mover = fireball.PrimaryPart
        if not mover then
            for _, c in ipairs(fireball:GetDescendants()) do
                if c:IsA("BasePart") then
                    mover = c
                    break
                end
            end
        end
    end
    
    -- Movement loop
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not fireball or not fireball.Parent then
            connection:Disconnect()
            return
        end
        
        -- Check lifetime
        if tick() - startTime > FIREBALL_LIFETIME then
            fireball.Parent = nil
            connection:Disconnect()
            return
        end
        
        -- Move fireball
        local moveDistance = FIREBALL_SPEED * dt
        local currentPos = mover and mover.Position or (fireball.Position or origin)
        local newPosition = currentPos + direction * moveDistance
        
        -- Check for collisions using Raycast
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {player.Character, fireball}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local rayResult = Workspace:Raycast(currentPos, direction * moveDistance * 2, raycastParams)
        
        if rayResult then
            -- Hit something!
            createImpactVFX(rayResult.Position, rayResult.Normal)
            
            -- Check if hit a player
            if rayResult.Instance then
                applyDamage(rayResult.Instance, player.Character)
            end
            
            -- Remove fireball
            fireball.Parent = nil
            connection:Disconnect()
        else
            -- No collision, move the fireball (handle Model or BasePart)
            local newCFrame = CFrame.new(newPosition, newPosition + direction)
            if fireball:IsA("Model") then
                if fireball.PrimaryPart then
                    fireball:SetPrimaryPartCFrame(newCFrame)
                elseif mover then
                    mover.CFrame = newCFrame
                end
            elseif fireball:IsA("BasePart") then
                fireball.CFrame = newCFrame
            end
            distanceTraveled = distanceTraveled + moveDistance
            
            -- Check range limit
            if distanceTraveled > FIREBALL_RANGE then
                fireball.Parent = nil
                connection:Disconnect()
            end
        end
    end)
end

-- Listen for fireball requests from clients
fireballRemote.OnServerEvent:Connect(function(player, action, ...)
    if action == "Launch" then
        local origin = ...
        local character = player.Character
        if not character then return end
        
        -- Get direction from character's HumanoidRootPart
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local direction = hrp.CFrame.LookVector
        launchFireball(player, origin, direction)
    end
end)

-- Clean up cooldowns when players leave
Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)

