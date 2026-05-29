-- Team Tag Handler - Hiển thị tên player với màu team
-- 📍 LOCATION: ServerScriptService/Shared/
-- Dùng chung cho cả Lobby và Arena

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========== SHARED CONFIG ==========
local SharedConfig = require(ServerScriptService.Shared.SharedConfig)

-- Require module (vẫn ở ReplicatedStorage)
local TeamTagManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TeamTagManager"))

-- Lưu trữ connections để cleanup
local playerConnections = {}

-- Xử lý khi player spawn character
local function onCharacterAdded(player, character)
	-- Đợi character load
	task.wait(0.5)
	
	if character and character.Parent then
		TeamTagManager.CreateNameTag(player, character)
	end
end

-- Xử lý player mới tham gia
local function onPlayerAdded(player)
	-- Tắt hiển thị tên/health mặc định của Roblox (zoom theo khoảng cách)
	player.NameDisplayDistance = 0
	player.HealthDisplayDistance = 0
	
	-- Cleanup old connections
	if playerConnections[player.UserId] then
		for _, connection in ipairs(playerConnections[player.UserId]) do
			connection:Disconnect()
		end
	end
	playerConnections[player.UserId] = {}
	
	-- Lắng nghe thay đổi team
	local teamConnection = player:GetPropertyChangedSignal("Team"):Connect(function()
		print("[TeamTag] Team changed for " .. player.Name .. " -> " .. (player.Team and player.Team.Name or "nil"))
		if player.Character then
			TeamTagManager.UpdateNameTag(player, player.Character)
		end
	end)
	table.insert(playerConnections[player.UserId], teamConnection)
	print("[TeamTag] Connected team change listener for " .. player.Name)
	
	-- Xử lý character hiện tại
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	
	-- Lắng nghe khi character spawn
	local charConnection = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	table.insert(playerConnections[player.UserId], charConnection)
end

-- Lắng nghe players
Players.PlayerAdded:Connect(onPlayerAdded)

-- Xử lý players hiện tại
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

-- Cleanup khi player rời game
Players.PlayerRemoving:Connect(function(player)
	if playerConnections[player.UserId] then
		for _, connection in ipairs(playerConnections[player.UserId]) do
			connection:Disconnect()
		end
		playerConnections[player.UserId] = nil
	end
end)

print("[TeamTagHandler] Đã khởi động!")
print("[TeamTagHandler] Team1: Xanh dương, Team2: Đỏ, Lobby: Xanh lá")