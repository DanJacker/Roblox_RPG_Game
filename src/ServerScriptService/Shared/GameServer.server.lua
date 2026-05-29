-- GameServer - Khởi tạo server với security
-- 📍 LOCATION: ServerScriptService/Shared/
-- Script này chạy đầu tiên, khởi tạo security và player data

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========== SHARED CONFIG ==========
local SharedConfig = require(ServerScriptService.Shared.SharedConfig)

-- ========== SECURITY: Load SecurityManager FIRST ==========
-- SecurityManager giờ ở Shared/ folder
local SecurityManager = require(ServerScriptService.Shared.SecurityManager)
SecurityManager.Init()

-- Now load PlayerData (which depends on _G.Security)
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

-- Handle new players
local function onPlayerAdded(player)
	PlayerData.Init(player)
end

-- Handle players leaving
local function onPlayerRemoving(player)
	PlayerData.Remove(player)
end

-- Events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game
for _, player in Players:GetPlayers() do
	if not PlayerData.Get(player) then
		PlayerData.Init(player)
	end
end

print("[GameServer] Server initialized with security module")
