-- Fireball System - Server Side
-- Handles fireball projectile, collision detection, and damage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Configuration
local FIREBALL_SPEED = 80
local FIREBALL_DAMAGE = 30
local FIREBALL_RANGE = 100
local FIREBALL_LIFETIME = 5

-- Get templates
local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")
local fireballTemplate = effectsFolder and effectsFolder:FindFirstChild("FireballVFX")
local impactTemplate = effectsFolder and effectsFolder:FindFirstChild("FireballImpactVFX")

-- RemoteEvent for client communication
local fireballRemote = ReplicatedStorage:FindFirstChild("FireballRemote")

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
    if not fireballTemplate then 
        warn("FireballVFX template not found!")
        return 
    end
    
    -- Check cooldown
    local currentTime = tick()
    if cooldowns[player] and currentTime - cooldowns[player] < 5 then
        return -- Still on cooldown
    end
    cooldowns[player] = currentTime
    
    -- Create fireball
    local fireball = fireballTemplate:Clone()
    fireball.CFrame = CFrame.new(origin, origin + direction)
    fireball.Parent = Workspace
    
    -- Track distance traveled
    local distanceTraveled = 0
    local startTime = tick()
    
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
        local newPosition = fireball.Position + direction * moveDistance
        
        -- Check for collisions using Raycast
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {player.Character, fireball}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local rayResult = Workspace:Raycast(fireball.Position, direction * moveDistance * 2, raycastParams)
        
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
            -- No collision, move the fireball
            fireball.CFrame = CFrame.new(newPosition, newPosition + direction)
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

print("Fireball System loaded!")