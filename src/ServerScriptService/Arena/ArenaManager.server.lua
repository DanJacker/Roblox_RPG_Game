-- ArenaManager.lua - Quản lý logic trong Arena (khi đang chơi)
-- 📍 LOCATION: ServerScriptService/Arena/
-- Chỉ xử lý logic khi player ĐANG trong trận đấu

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- ========== ARENA CONFIG ==========
local ARENA_CONFIG = {
    ["1v1"] = {
        playersNeeded = 2,
        spawnPositions = {
            team1 = CFrame.new(750, 10, 1000),
            team2 = CFrame.new(1250, 10, 1000)
        },
        mapPath = "Workspace.Maps.Map1v1_Lab"
    },
    ["2v2"] = {
        playersNeeded = 4,
        spawnPositions = {
            team1 = CFrame.new(-20, 2, -5),
            team2 = CFrame.new(20, 2, 5)
        },
        mapPath = "Workspace.Maps.Map2v2"
    },
    ["3v3"] = {
        playersNeeded = 6,
        spawnPositions = {
            team1 = CFrame.new(-25, 2, -10),
            team2 = CFrame.new(25, 2, 10)
        },
        mapPath = "Workspace.Maps.Map3v3"
    }
}

-- ========== ARENA STATE ==========
local activeArenas = {} -- arenaId -> arenaData
local playerArenas = {} -- playerId -> arenaId

-- ========== FUNCTIONS ==========

-- Lấy config arena theo mode
local function getArenaConfig(mode)
    return ARENA_CONFIG[mode]
end

-- Kiểm tra player có trong arena không
local function isInArena(player)
    return playerArenas[player.UserId] ~= nil
end

-- Lấy arena của player
local function getPlayerArena(player)
    local arenaId = playerArenas[player.UserId]
    if arenaId then
        return activeArenas[arenaId]
    end
    return nil
end

-- Tạo arena mới
local function createArena(matchId, mode, players)
    local config = getArenaConfig(mode)
    if not config then
        warn("[ArenaManager] Mode không hợp lệ: " .. tostring(mode))
        return nil
    end
    
    local arenaData = {
        matchId = matchId,
        mode = mode,
        players = players,
        startTime = tick(),
        status = "active",
        config = config
    }
    
    activeArenas[matchId] = arenaData
    
    -- Đánh dấu player đang trong arena
    for _, playerData in ipairs(players) do
        if playerData.player then
            playerArenas[playerData.playerId] = matchId
        end
    end
    
    return arenaData
end

-- Hủy arena
local function destroyArena(matchId)
    local arena = activeArenas[matchId]
    if not arena then return end
    
    -- Xóa player khỏi arena
    for _, playerData in ipairs(arena.players) do
        playerArenas[playerData.playerId] = nil
    end
    
    activeArenas[matchId] = nil
end

-- Teleport player đến arena spawn
local function teleportToArenaSpawn(player, teamName, mode)
    local config = getArenaConfig(mode)
    if not config then return end
    
    local spawnCFrame = teamName == "Team1" and config.spawnPositions.team1 or config.spawnPositions.team2
    
    if player.Character then
        player.Character:PivotTo(spawnCFrame)
    end
end

-- ========== EXPORT ==========
_G.ArenaManager = {
    getArenaConfig = getArenaConfig,
    isInArena = isInArena,
    getPlayerArena = getPlayerArena,
    createArena = createArena,
    destroyArena = destroyArena,
    teleportToArenaSpawn = teleportToArenaSpawn,
    ARENA_CONFIG = ARENA_CONFIG
}

