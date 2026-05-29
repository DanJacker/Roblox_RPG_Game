print("[CombatServer] Script starting...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Ensure CombatRemote exists
local combatRemote = ReplicatedStorage:FindFirstChild("CombatRemote")
if not combatRemote then
	combatRemote = Instance.new("RemoteEvent")
	combatRemote.Name = "CombatRemote"
	combatRemote.Parent = ReplicatedStorage
end

-- Server-side damage handler
local function onCombatRequest(player, target, damage)
    if not player or not target then return end
    
    -- ========== TEAM CHECK - Ngăn friendly fire ==========
    local attackerTeam = player.Team and player.Team.Name
    local targetTeam = nil
    
    if target:IsA("Player") then
        targetTeam = target.Team and target.Team.Name
    elseif target:IsA("Model") then
        targetTeam = target:GetAttribute("Team")
        if not targetTeam then
            for _, managerName in ipairs({"BotManager", "BotManager1v1", "BotManager2v2", "BotManager3v3"}) do
                if _G[managerName] and _G[managerName].GetActiveBots then
                    local activeBots = _G[managerName].GetActiveBots()
                    for bot, data in pairs(activeBots) do
                        if bot == target or bot.Name == target.Name then
                            targetTeam = data.team
                            break
                        end
                    end
                    if targetTeam then break end
                end
            end
        end
    end
    
    -- Ngăn đánh cùng team
    if attackerTeam and targetTeam and attackerTeam == targetTeam then
        print("[CombatServer] BLOCKED friendly fire: " .. player.Name .. " tried to hit " .. tostring(target.Name))
        return
    end
    -- ===========================================================
    
    local targetHumanoid = nil
    local targetRootPart = nil
    
    if target:IsA("Player") then
        local targetCharacter = target.Character
        if targetCharacter then
            targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
            targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
        end
    elseif target:IsA("Model") then
        targetHumanoid = target:FindFirstChildOfClass("Humanoid")
        targetRootPart = target:FindFirstChild("HumanoidRootPart")
    end
    
    if not targetHumanoid or not targetRootPart then return end
    if targetHumanoid.Health <= 0 then return end
    
    local attackerCharacter = player.Character
    if not attackerCharacter then return end
    
    local attackerRootPart = attackerCharacter:FindFirstChild("HumanoidRootPart")
    if attackerRootPart then
        local distance = (attackerRootPart.Position - targetRootPart.Position).Magnitude
        if distance > 15 then return end
    end
    
    targetHumanoid:TakeDamage(damage)
end

combatRemote.OnServerEvent:Connect(function(player, target, damage)
	onCombatRequest(player, target, damage)
end)

print("[CombatServer] Loaded!")print("[CombatServer] Script starting...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ========== DAMAGE MULTIPLIER CONFIGURATION ==========
-- Thay đổi giá trị này để điều chỉnh sát thương lên bot/monster
local DAMAGE_MULTIPLIERS = {
	BOT = 2.0,      -- Sát thương khi đánh Bot (2.0 = gấp đôi)
	MONSTER = 2.5,  -- Sát thương khi đánh Monster (2.5 = gấp 2.5 lần)
	PLAYER = 1.0,   -- Sát thương khi đánh Player (1.0 = giữ nguyên)
}
-- ========================================================

print("[CombatServer] Services loaded")

-- Ensure CombatRemote exists
local combatRemote = ReplicatedStorage:FindFirstChild("CombatRemote")
print("[CombatServer] Looking for CombatRemote: " .. tostring(combatRemote))

if not combatRemote then
	combatRemote = Instance.new("RemoteEvent")
	combatRemote.Name = "CombatRemote"
	combatRemote.Parent = ReplicatedStorage
	print("[CombatServer] Created CombatRemote event")
else
	print("[CombatServer] Found existing CombatRemote")
end

-- Server-side damage handler
local function onCombatRequest(player, target, damage)
    -- Validate the request
    if not player or not target then
        warn("[CombatServer] Invalid request: player=" .. tostring(player) .. ", target=" .. tostring(target))
        return
    end
    
    print("[CombatServer] Processing attack from " .. player.Name .. " to " .. tostring(target.Name or target.ClassName))
    
    -- ========== TEAM CHECK - Ngăn friendly fire ==========
    local attackerTeam = player.Team and player.Team.Name
    local targetTeam = nil
    
    -- Kiểm tra team của target
    if target:IsA("Player") then
        targetTeam = target.Team and target.Team.Name
    elseif target:IsA("Model") then
        -- Lấy team từ attribute hoặc BotManager
        targetTeam = target:GetAttribute("Team")
        if not targetTeam then
            for _, managerName in ipairs({"BotManager", "BotManager1v1", "BotManager2v2", "BotManager3v3"}) do
                if _G[managerName] and _G[managerName].GetActiveBots then
                    local activeBots = _G[managerName].GetActiveBots()
                    for bot, data in pairs(activeBots) do
                        if bot == target or bot.Name == target.Name then
                            targetTeam = data.team
                            break
                        end
                    end
                    if targetTeam then break end
                end
            end
        end
    end
    
    -- Ngăn đánh cùng team
    if attackerTeam and targetTeam and attackerTeam == targetTeam then
        print("[CombatServer] BLOCKED friendly fire: " .. player.Name .. " (" .. attackerTeam .. ") tried to hit " .. tostring(target.Name) .. " (" .. targetTeam .. ")")
        return
    end
    -- ===========================================================
    
    local targetHumanoid = nil
    local targetRootPart = nil
    local targetName = ""
    local isBot = false
    local isMonster = false
    local botTeam = nil
    
    -- Check if target is a Player or a Model (NPC/Rig)
    if target:IsA("Player") then
        -- Target is a Player
        local targetCharacter = target.Character
        if not targetCharacter then
            warn("[CombatServer] Target player has no character")
            return
        end
        
        targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
        targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
        targetName = target.Name
        
    elseif target:IsA("Model") then
        -- Target is an NPC/Rig (could be a bot or monster)
        targetHumanoid = target:FindFirstChildOfClass("Humanoid")
        targetRootPart = target:FindFirstChild("HumanoidRootPart")
        targetName = target.Name
        
        print("[CombatServer] Target is Model: " .. targetName .. ", Humanoid: " .. tostring(targetHumanoid ~= nil) .. ", RootPart: " .. tostring(targetRootPart ~= nil))
        
        -- Check if this is a bot or monster
        -- Bot names: [BOT-1v1], [BOT-2v2], [BOT-3v3], [BOT]
        if string.find(targetName, "[BOT", 1, true) then
            isBot = true
            -- Get bot team from attribute or BotManager
            botTeam = target:GetAttribute("Team")
            
            -- Fallback: Get team from BotManager (check all variants)
            if not botTeam then
                for _, managerName in ipairs({"BotManager", "BotManager1v1", "BotManager2v2", "BotManager3v3"}) do
                    if _G[managerName] and _G[managerName].GetActiveBots then
                        local activeBots = _G[managerName].GetActiveBots()
                        for bot, data in pairs(activeBots) do
                            if bot == target or bot.Name == targetName then
                                botTeam = data.team
                                print("[CombatServer] Found bot team from " .. managerName .. ": " .. tostring(botTeam))
                                break
                            end
                        end
                        if botTeam then break end
                    end
                end
            end
            
            print("[CombatServer] Bot detected: " .. targetName .. " | Team: " .. tostring(botTeam))
        elseif string.find(targetName, "[MONSTER", 1, true) or string.find(targetName, "[Monster", 1, true) or target:GetAttribute("IsPatrolMonster") or target:GetAttribute("IsMonster") then
            isMonster = true
            print("[CombatServer] Monster detected: " .. targetName)
        end
        
    else
        warn("[CombatServer] Invalid target type: " .. target.ClassName)
        return
    end
    
    -- Validate Humanoid and RootPart
    if not targetHumanoid then
        warn("[CombatServer] Target has no Humanoid")
        return
    end
    
    if not targetRootPart then
        warn("[CombatServer] Target has no HumanoidRootPart")
        return
    end
    
    -- Check if target is already dead
    if targetHumanoid.Health <= 0 then
        warn("[CombatServer] Target is already dead (HP: " .. targetHumanoid.Health .. ")")
        return
    end
    
    -- Validate attacker has a character
    local attackerCharacter = player.Character
    if not attackerCharacter then
        warn("[CombatServer] Attacker has no character")
        return
    end
    
    -- Validate range (server-side check for security)
    local attackerRootPart = attackerCharacter:FindFirstChild("HumanoidRootPart")
    
    if attackerRootPart then
        local distance = (attackerRootPart.Position - targetRootPart.Position).Magnitude
        local maxRange = 15 -- Increased range for better hit detection
        
        print("[CombatServer] Distance check: " .. string.format("%.2f", distance) .. " studs (max: " .. maxRange .. ")")
        
        if distance > maxRange then
            warn("[CombatServer] Target out of range (server validation): " .. string.format("%.2f", distance) .. " > " .. maxRange)
            return
        end
    else
        warn("[CombatServer] Attacker has no HumanoidRootPart")
        return
    end
    
    -- Apply damage with multiplier for bots/monsters
    local finalDamage = damage
    local multiplierUsed = 1.0
    
    if isBot then
        finalDamage = damage * DAMAGE_MULTIPLIERS.BOT
        multiplierUsed = DAMAGE_MULTIPLIERS.BOT
    elseif isMonster then
        finalDamage = damage * DAMAGE_MULTIPLIERS.MONSTER
        multiplierUsed = DAMAGE_MULTIPLIERS.MONSTER
    end
    
    local oldHealth = targetHumanoid.Health
    targetHumanoid:TakeDamage(finalDamage)
    local newHealth = targetHumanoid.Health
    
    if multiplierUsed > 1.0 then
        print("[CombatServer] " .. player.Name .. " dealt " .. finalDamage .. " damage to " .. targetName .. " (base: " .. damage .. " x" .. multiplierUsed .. " multiplier) (HP: " .. oldHealth .. " -> " .. newHealth .. ")")
    else
        print("[CombatServer] " .. player.Name .. " dealt " .. finalDamage .. " damage to " .. targetName .. " (HP: " .. oldHealth .. " -> " .. newHealth .. ")")
    end
    
    -- Set last attacker for KillTracker (chỉ nếu target là player)
    if not isBot and not isMonster and _G.SetLastAttacker then
        _G.SetLastAttacker(target, player)
    end
    
    -- Check if target died
    if targetHumanoid.Health <= 0 then
        print(targetName .. " was defeated by " .. player.Name)
        
        -- Record kill for player killing bot
        if isBot and _G.MatchEndConditions then
            _G.MatchEndConditions.RecordKill(player, {name = targetName, team = botTeam})
            print("[CombatServer] Recorded kill: " .. player.Name .. " killed bot " .. targetName)
        end
        
        -- Record kill for player killing monster
        if isMonster and _G.MatchEndConditions then
            _G.MatchEndConditions.RecordKill(player, {name = targetName, team = "Monster"})
            print("[CombatServer] Recorded kill: " .. player.Name .. " killed monster " .. targetName)
        end
        
        -- Record kill for MVPSystem
        if _G.MVPSystem and (isBot or isMonster) then
            _G.MVPSystem.RecordKill(player.Name, targetName)
        end
    end
end

-- Connect the remote event
combatRemote.OnServerEvent:Connect(function(player, target, damage)
	print("[CombatServer] Received attack from " .. player.Name .. " to " .. (target and target.Name or "nil") .. " for " .. tostring(damage) .. " damage")
	onCombatRequest(player, target, damage)
end)

print("Combat Server Loaded!")