-- LobbyManager.lua - Quản lý player trong Lobby
-- 📍 LOCATION: ServerScriptService/Lobby/
-- Chỉ xử lý logic khi player KHÔNG trong trận đấu

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== REMOTE EVENTS (Lobby) ==========
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
    remoteEvents = Instance.new("Folder")
    remoteEvents.Name = "RemoteEvents"
    remoteEvents.Parent = ReplicatedStoragef:\roblox code\Roblox_RPG_Game
end

local JoinQueue = remoteEvents:FindFirstChild("JoinQueue")
local LeaveQueue = remoteEvents:FindFirstChild("LeaveQueue")
local QueueStatus = remoteEvents:FindFirstChild("QueueStatus")

-- ========== LOBBY STATE ==========
local playersInLobby = {}

-- ========== FUNCTIONS ==========

-- Kiểm tra player có trong lobby không
local function isInLobby(player)
    return playersInLobby[player.UserId] ~= nil
end

-- Thêm player vào lobby
local function addToLobby(player)
    playersInLobby[player.UserId] = {
        player = player,
        joinTime = tick(),
        inQueue = false,
        queueMode = nil
    }
    
    -- Gán team Lobby
    local lobbyTeam = Teams:FindFirstChild("Lobby")
    if lobbyTeam then
        player.Team = lobbyTeam
        player.Neutral = false
    end
    
end

-- Xóa player khỏi lobby
local function removeFromLobby(player)
    playersInLobby[player.UserId] = nil
end

-- Lấy thông tin lobby
local function getLobbyInfo()
    local info = {
        playerCount = 0,
        players = {}
    }
    
    for userId, data in pairs(playersInLobby) do
        info.playerCount = info.playerCount + 1
        table.insert(info.players, data.player.Name)
    end
    
    return info
end

-- ========== EVENTS ==========

-- Khi player join game
Players.PlayerAdded:Connect(function(player)
    addToLobby(player)
end)

-- Khi player leave game
Players.PlayerRemoving:Connect(function(player)
    removeFromLobby(player)
end)

-- Xử lý players đã có trong game
for _, player in ipairs(Players:GetPlayers()) do
    addToLobby(player)
end

-- ========== EXPORT ==========
_G.LobbyManager = {
    isInLobby = isInLobby,
    getLobbyInfo = getLobbyInfo,
    addToLobby = addToLobby,
    removeFromLobby = removeFromLobby
}

