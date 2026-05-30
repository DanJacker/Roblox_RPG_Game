-- MatchTeleporter - Dịch chuyển player đến spawn point khi vào trận
-- 📍 LOCATION: ServerScriptService/Arena/
-- Xử lý teleport player đến đúng map và spawn point khi trận đấu bắt đầu

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- ========== SHARED CONFIG ==========
local SharedConfig = require(ServerScriptService.Shared.SharedConfig)

-- ========== STATE ==========
local activeMatchSpawns = {} -- Lưu spawn points đang sử dụng cho mỗi match

-- ========== HELPER FUNCTIONS ==========

-- Lấy spawn point theo path
local function getSpawnByPath(path)
    local parts = string.split(path, ".")
    local current = game
    
    for _, part in ipairs(parts) do
        if current then
            current = current:FindFirstChild(part)
        else
            return nil
        end
    end
    
    return current
end

-- Lấy danh sách spawn points cho team
local function getTeamSpawnPoints(mode, teamName)
    local config = SharedConfig.ARENA_SPAWNS[mode]
    if not config then return nil end
    
    local spawnPaths = config.spawnPaths
    if not spawnPaths then return nil end
    
    local teamPaths = spawnPaths[teamName]
    if not teamPaths then return nil end
    
    -- Nếu là string (1v1), trả về array 1 phần tử
    if type(teamPaths) == "string" then
        local spawn = getSpawnByPath(teamPaths)
        return spawn and {spawn} or nil
    end
    
    -- Nếu là array (2v2, 3v3)
    if type(teamPaths) == "table" then
        local spawns = {}
        for _, path in ipairs(teamPaths) do
            local spawn = getSpawnByPath(path)
            if spawn then
                table.insert(spawns, spawn)
            end
        end
        return #spawns > 0 and spawns or nil
    end
    
    return nil
end

-- Teleport player đến spawn point
local function teleportPlayerToSpawn(player, spawnPoint)
    -- Kiểm tra xem player có custom spawn position không
    if _G.SpawnSelectionServer then
        local customSpawnPos = _G.SpawnSelectionServer.getSpawnPosition(player.UserId)
        if customSpawnPos then
            
            -- Nếu player không có character, spawn character trước
            if not player.Character then
                player:LoadCharacter()
                -- Đợi character spawn
                local startTime = tick()
                while not player.Character and (tick() - startTime) < 5 do
                    task.wait(0.1)
                end
                if not player.Character then
                    warn("[MatchTeleporter] " .. player.Name .. " không thể spawn character!")
                    return false
                end
            end
            
            -- Teleport đến custom spawn position (thêm Y offset để an toàn)
            local safePos = customSpawnPos + Vector3.new(0, 3, 0)
            local spawnCFrame = CFrame.new(safePos)
            player.Character:PivotTo(spawnCFrame)
            return true
        end
    end
    
    -- Nếu không có custom spawn, sử dụng spawn point mặc định
    -- Nếu player không có character, spawn character trước
    if not player.Character then
        player:LoadCharacter()
        -- Đợi character spawn
        local startTime = tick()
        while not player.Character and (tick() - startTime) < 5 do
            task.wait(0.1)
        end
        if not player.Character then
            warn("[MatchTeleporter] " .. player.Name .. " không thể spawn character!")
            return false
        end
    end
    
    local spawnPos = spawnPoint.Position
    local spawnCFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
    
    player.Character:PivotTo(spawnCFrame)
    
    return true
end

-- ========== MAIN FUNCTIONS ==========

-- Teleport tất cả players trong match đến spawn points
function TeleportPlayersToMatch(matchId, mode, team1, team2)
    
    -- Lấy spawn points cho mỗi team
    local team1Spawns = getTeamSpawnPoints(mode, "team1")
    local team2Spawns = getTeamSpawnPoints(mode, "team2")
    
    if not team1Spawns or not team2Spawns then
        warn("[MatchTeleporter] Không tìm thấy spawn points cho mode " .. mode)
        -- Fallback: sử dụng CFrame từ config
        local config = SharedConfig.ARENA_SPAWNS[mode]
        if config then
            -- Teleport team1
            for i, playerData in ipairs(team1) do
                if not playerData.isBot then
                    local player = Players:GetPlayerByUserId(playerData.playerId)
                    if player then
                        -- Kiểm tra custom spawn position
                        local customSpawnPos = nil
                        if _G.SpawnSelectionServer then
                            customSpawnPos = _G.SpawnSelectionServer.getSpawnPosition(player.UserId)
                        end
                        
                        if customSpawnPos then
                            -- Sử dụng custom spawn position (thêm Y offset)
                            if player.Character then
                                local safePos = customSpawnPos + Vector3.new(0, 3, 0)
                                player.Character:PivotTo(CFrame.new(safePos))
                            end
                        else
                            -- Sử dụng default spawn
                            if player.Character then
                                local offset = Vector3.new(0, 3, (i - 1) * 5 - (#team1 - 1) * 2.5)
                                player.Character:PivotTo(config.team1 + offset)
                            end
                        end
                    end
                end
            end
            -- Teleport team2
            for i, playerData in ipairs(team2) do
                if not playerData.isBot then
                    local player = Players:GetPlayerByUserId(playerData.playerId)
                    if player then
                        -- Kiểm tra custom spawn position
                        local customSpawnPos = nil
                        if _G.SpawnSelectionServer then
                            customSpawnPos = _G.SpawnSelectionServer.getSpawnPosition(player.UserId)
                        end
                        
                        if customSpawnPos then
                            -- Sử dụng custom spawn position (thêm Y offset)
                            if player.Character then
                                local safePos = customSpawnPos + Vector3.new(0, 3, 0)
                                player.Character:PivotTo(CFrame.new(safePos))
                            end
                        else
                            -- Sử dụng default spawn
                            if player.Character then
                                local offset = Vector3.new(0, 3, (i - 1) * 5 - (#team2 - 1) * 2.5)
                                player.Character:PivotTo(config.team2 + offset)
                            end
                        end
                    end
                end
            end
        end
        return
    end
    
    
    -- Lưu spawn points đang sử dụng
    activeMatchSpawns[matchId] = {
        team1 = team1Spawns,
        team2 = team2Spawns
    }
    
    -- Teleport Team1
    for i, playerData in ipairs(team1) do
        if not playerData.isBot then
            local player = Players:GetPlayerByUserId(playerData.playerId)
            if player then
                local spawnIndex = ((i - 1) % #team1Spawns) + 1
                local spawnPoint = team1Spawns[spawnIndex]
                teleportPlayerToSpawn(player, spawnPoint)
            end
        end
    end
    
    -- Teleport Team2
    for i, playerData in ipairs(team2) do
        if not playerData.isBot then
            local player = Players:GetPlayerByUserId(playerData.playerId)
            if player then
                local spawnIndex = ((i - 1) % #team2Spawns) + 1
                local spawnPoint = team2Spawns[spawnIndex]
                teleportPlayerToSpawn(player, spawnPoint)
            end
        end
    end
    
end

-- Cleanup spawn points khi match kết thúc
function CleanupMatchSpawns(matchId)
    activeMatchSpawns[matchId] = nil
end

-- ========== EXPORT ==========
_G.MatchTeleporter = {
    TeleportPlayersToMatch = TeleportPlayersToMatch,
    CleanupMatchSpawns = CleanupMatchSpawns,
    GetTeamSpawnPoints = getTeamSpawnPoints
}

