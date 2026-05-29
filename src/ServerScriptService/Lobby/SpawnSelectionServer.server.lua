-- Spawn Selection Server - Helper functions cho spawn selection
-- Lưu ý: MatchManager đã xử lý spawn selection logic, script này chỉ cung cấp helper functions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Lưu trữ spawn positions (được sử dụng bởi MatchTeleporter)
local spawnPositions = {}

-- Export API để các script khác có thể sử dụng
_G.SpawnSelectionServer = {
    getSpawnPosition = function(playerId)
        return spawnPositions[playerId]
    end,
    setSpawnPosition = function(playerId, position)
        spawnPositions[playerId] = position
        print("[SpawnSelectionServer] Lưu spawn position cho player " .. tostring(playerId) .. ": " .. tostring(position))
    end,
    clearSpawnPosition = function(playerId)
        spawnPositions[playerId] = nil
    end
}

print("[SpawnSelectionServer] ✅ Spawn Selection Server đã khởi động!")