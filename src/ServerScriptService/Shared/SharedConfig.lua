-- SharedConfig.lua - Cấu hình dùng chung giữa Lobby và Arena
-- ModuleScript này được require bởi cả Lobby và Arena scripts

local SharedConfig = {}

-- ========== GAME MODES ==========
SharedConfig.MODES = {
    ["1v1"] = {
        name = "1v1",
        displayName = "Solo (1v1)",
        playersNeeded = 2,
        maxPlayers = 2,
        description = "Đấu đơn - 1 vs 1"
    },
    ["2v2"] = {
        name = "2v2",
        displayName = "Duo (2v2)",
        playersNeeded = 4,
        maxPlayers = 4,
        description = "Đấu đôi - 2 vs 2"
    },
    ["3v3"] = {
        name = "3v3",
        displayName = "Squad (3v3)",
        playersNeeded = 6,
        maxPlayers = 6,
        description = "Đấu đội - 3 vs 3"
    }
}

-- ========== MATCH SETTINGS ==========
SharedConfig.MATCH = {
    duration = 300, -- 5 phút
    spawnSelectionTime = 10, -- 10 giây chọn spawn
    respawnTime = 5, -- 5 giây hồi sinh
    timeout = 60 -- 60 giây chờ queue
}

-- ========== RANK SETTINGS ==========
SharedConfig.RANK = {
    tiersPerRank = 3,
    pointsPerTier = 100,
    noBotRankIndex = 6, -- Kim Cương trở lên không có bot
    rankTierRange = 3 -- ±3 tier cho matchmaking
}

-- ========== TEAMS ==========
SharedConfig.TEAMS = {
    LOBBY = "Lobby",
    TEAM1 = "Team1",
    TEAM2 = "Team2"
}

-- ========== ARENA SPAWNS ==========
-- Spawn points trong từng map (gần base)
-- Y-coordinate = 35 để spawn an toàn trên mặt đất (dựa trên spawn points thực tế)
SharedConfig.ARENA_SPAWNS = {
    ["1v1"] = {
        team1 = CFrame.new(-327, 35, -1041), -- Cập nhật theo spawn point thực tế
        team2 = CFrame.new(417, 35, -1040), -- Cập nhật theo spawn point thực tế
        -- Path đến spawn points trong map
        spawnPaths = {
            team1 = "Workspace.Maps.Map1v1.Spawns.Team1Spawn",
            team2 = "Workspace.Maps.Map1v1.Spawns.Team2Spawn"
        }
    },
    ["2v2"] = {
        team1 = CFrame.new(-291, 35, -1947),
        team2 = CFrame.new(317, 35, -1855),
        spawnPaths = {
            team1 = {"Workspace.Maps.Map2v2.Spawns.Team1Spawn1", "Workspace.Maps.Map2v2.Spawns.Team1Spawn2"},
            team2 = {"Workspace.Maps.Map2v2.Spawns.Team2Spawn1", "Workspace.Maps.Map2v2.Spawns.Team2Spawn2"}
        }
    },
    ["3v3"] = {
        -- Spawn points cho 3v3 map
        team1 = CFrame.new(-478, 5, -7209), -- Team 1 spawn (gần Team1Spawn1)
        team2 = CFrame.new(174, 5, -7862), -- Team 2 spawn (gần Team2Spawn1)
        spawnPaths = {
            team1 = {"Workspace.Maps.Map3v3.Spawns.Team1Spawn1", "Workspace.Maps.Map3v3.Spawns.Team1Spawn2", "Workspace.Maps.Map3v3.Spawns.Team1Spawn3"},
            team2 = {"Workspace.Maps.Map3v3.Spawns.Team2Spawn1", "Workspace.Maps.Map3v3.Spawns.Team2Spawn2", "Workspace.Maps.Map3v3.Spawns.Team2Spawn3"}
        }
    }
}

-- ========== MAP PATHS ==========
SharedConfig.MAP_PATHS = {
    ["1v1"] = "Workspace.Maps.Map1v1",
    ["2v2"] = "Workspace.Maps.Map2v2",
    ["3v3"] = "Workspace.Maps.Map3v3"
}

-- ========== HELPER FUNCTIONS ==========

-- Lấy config mode
function SharedConfig.GetModeConfig(mode)
    return SharedConfig.MODES[mode]
end

-- Lấy số players cần thiết cho mode
function SharedConfig.GetPlayersNeeded(mode)
    local config = SharedConfig.MODES[mode]
    return config and config.playersNeeded or 0
end

-- Kiểm tra mode hợp lệ
function SharedConfig.IsValidMode(mode)
    return SharedConfig.MODES[mode] ~= nil
end

return SharedConfig