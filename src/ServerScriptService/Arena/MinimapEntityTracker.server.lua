-- MinimapEntityTracker - Theo dõi và gửi vị trí quái/bot cho minimap
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[MinimapTracker] Đang khởi động...")

-- Remote Event
local MinimapEntityUpdate = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("MinimapEntityUpdate")

-- Cấu hình
local UPDATE_INTERVAL = 0.5 -- Cập nhật mỗi 0.5 giây

-- Theo dõi trận đấu hiện tại
local currentMatchMode = nil
local matchActive = false

-- Lấy danh sách bot đang hoạt động
local function getActiveBots()
    local BotManager = _G.BotManager
    if BotManager and BotManager.GetActiveBots then
        return BotManager.GetActiveBots()
    end
    return {}
end

-- Lấy danh sách quái đang hoạt động
local function getActiveMonsters()
    local monsters = {}
    
    -- Kiểm tra Elite Boss trước
    local BossManager = _G.BossManager
    if BossManager then
        local boss = BossManager.GetActiveBoss()
        if boss and boss.Parent then
            local hrp = boss:FindFirstChild("HumanoidRootPart")
            local humanoid = boss:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                table.insert(monsters, {
                    name = "ELITE_BOSS",
                    position = hrp.Position,
                    health = humanoid.Health,
                    maxHealth = humanoid.MaxHealth,
                    isBoss = true
                })
            end
        end
    end
    
    -- Sử dụng _G.PatrolMonster.GetActive() nếu có
    local PatrolMonster = _G.PatrolMonster
    if PatrolMonster and PatrolMonster.GetActive then
        for _, monster in pairs(PatrolMonster.GetActive()) do
            if monster and monster.Parent then
                local hrp = monster:FindFirstChild("HumanoidRootPart")
                local humanoid = monster:FindFirstChildOfClass("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    table.insert(monsters, {
                        name = monster.Name,
                        position = hrp.Position,
                        health = humanoid.Health,
                        maxHealth = humanoid.MaxHealth
                    })
                end
            end
        end
        return monsters
    end
    
    -- Fallback: Tìm trong PatrolMonsters folder
    local patrolFolder = workspace:FindFirstChild("PatrolMonsters")
    if patrolFolder then
        for _, monster in ipairs(patrolFolder:GetChildren()) do
            if monster:IsA("Model") and monster:FindFirstChild("HumanoidRootPart") then
                local hrp = monster.HumanoidRootPart
                local humanoid = monster:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    table.insert(monsters, {
                        name = monster.Name,
                        position = hrp.Position,
                        health = humanoid.Health,
                        maxHealth = humanoid.MaxHealth
                    })
                end
            end
        end
    end
    
    -- Tìm trong Maps folder (quái trong map)
    local mapsFolder = workspace:FindFirstChild("Maps")
    if mapsFolder then
        for _, mapFolder in ipairs(mapsFolder:GetChildren()) do
            for _, obj in ipairs(mapFolder:GetDescendants()) do
                if obj:IsA("Model") then
                    -- Kiểm tra nếu là quái (có attribute IsPatrolMonster hoặc tên chứa MONSTER)
                    if obj:GetAttribute("IsPatrolMonster") or string.find(obj.Name, "%[MONSTER%]") or string.find(obj.Name, "Beast") then
                        local hrp = obj:FindFirstChild("HumanoidRootPart")
                        local humanoid = obj:FindFirstChildOfClass("Humanoid")
                        if hrp and humanoid and humanoid.Health > 0 then
                            table.insert(monsters, {
                                name = obj.Name,
                                position = hrp.Position,
                                health = humanoid.Health,
                                maxHealth = humanoid.MaxHealth
                            })
                        end
                    end
                end
            end
        end
    end
    
    return monsters
end

-- Gửi cập nhật cho tất cả players
local function sendEntityUpdate()
    if not matchActive then return end
    
    -- Lấy danh sách bot
    local bots = {}
    for bot, data in pairs(getActiveBots()) do
        if bot and bot.Parent then
            local hrp = bot:FindFirstChild("HumanoidRootPart")
            local humanoid = bot:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                table.insert(bots, {
                    name = bot.Name,
                    position = hrp.Position,
                    team = data.team or "Unknown",
                    health = humanoid.Health,
                    maxHealth = humanoid.MaxHealth
                })
            end
        end
    end
    
    -- Lấy danh sách quái
    local monsters = getActiveMonsters()
    
    -- Gửi cho tất cả players trong trận
    for _, player in ipairs(Players:GetPlayers()) do
        local playerTeam = player.Team and player.Team.Name
        if playerTeam == "Team1" or playerTeam == "Team2" then
            MinimapEntityUpdate:FireClient(player, {
                bots = bots,
                monsters = monsters
            })
        end
    end
end

-- Update loop
local function startUpdateLoop()
    while true do
        if matchActive then
            sendEntityUpdate()
        end
        task.wait(UPDATE_INTERVAL)
    end
end

-- Hook vào MatchManager để biết khi nào trận bắt đầu/kết thúc
task.spawn(function()
    while not _G.MatchManager do
        task.wait(0.5)
    end
    
    local MatchManager = _G.MatchManager
    print("[MinimapTracker] MatchManager found, hooking events...")
    
    -- Hook vào StartMatch
    local originalStartMatch = MatchManager.StartMatch
    if originalStartMatch then
        MatchManager.StartMatch = function(matchId, matchData)
            currentMatchMode = matchData and matchData.mode
            matchActive = true
            print("[MinimapTracker] Match started: " .. tostring(currentMatchMode))
            return originalStartMatch(matchId, matchData)
        end
    end
    
    -- Hook vào EndMatch
    local originalEndMatch = MatchManager.EndMatch
    if originalEndMatch then
        MatchManager.EndMatch = function(matchId, reason)
            matchActive = false
            print("[MinimapTracker] Match ended")
            return originalEndMatch(matchId, reason)
        end
    end
end)

-- Bắt đầu update loop
task.spawn(startUpdateLoop)

print("[MinimapTracker] Đã khởi động thành công!")