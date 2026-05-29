-- MonsterLoader - Tu dong spawn quai vat trong map 1v1
-- Dat trong: ServerScriptService.Arena.MonsterLoader

local Players = game:GetService("Players")

print("[MonsterLoader] Khoi dong...")

-- ========== REQUIRE MODULE ==========
local MonsterManager = require(script.Parent:WaitForChild("MonsterManager"))
print("[MonsterLoader] MonsterManager da duoc load!")

-- ========== CONFIG ==========
-- Tu dong lay vi tri spawn tu MonsterPartSpawn trong map 1v1
local SPAWN_DELAY = 3 -- Giay sau khi tran bat dau

-- Ham lay tat ca vi tri spawn tu MonsterPartSpawn
local function getSpawnPositions()
	local spawnPositions = {}
	
	-- Tim trong Trangtrimap
	local trangtrimap = workspace:FindFirstChild("Trangtrimap")
	if trangtrimap then
		for _, obj in ipairs(trangtrimap:GetChildren()) do
			if obj.Name == "MonsterPartSpawn" and obj:IsA("BasePart") then
				-- Spawn o giua phan tren cua part (Y + 5 de khong bi chim)
				table.insert(spawnPositions, obj.Position + Vector3.new(0, 5, 0))
			end
		end
	end
	
	-- Neu khong tim thay MonsterPartSpawn, su dung vi tri mac dinh
	if #spawnPositions == 0 then
		warn("[MonsterLoader] Khong tim thay MonsterPartSpawn! Su dung vi tri mac dinh.")
		spawnPositions = {
			Vector3.new(13, 10, -1040),
			Vector3.new(-100, 10, -1040),
			Vector3.new(130, 10, -1040),
		}
	end
	
	return spawnPositions
end

-- ========== FUNCTIONS ==========
local function spawnMonsters()
	-- Lay vi tri spawn tu MonsterPartSpawn
	local spawnPositions = getSpawnPositions()
	
	-- Spawn quai tai cac vi tri
	for i, pos in ipairs(spawnPositions) do
		task.wait(0.5) -- Delay giua cac lan spawn
		MonsterManager.SpawnMonster(pos)
	end

	print(string.format("[MonsterLoader] Da spawn %d quai vat tai %d vi tri MonsterPartSpawn!", #spawnPositions, #spawnPositions))
end

-- ========== KHOI DONG ==========
-- Chi spawn quai khi co player trong game
local function checkAndSpawnMonsters()
	local playerCount = #Players:GetPlayers()
	if playerCount > 0 then
		print(string.format("[MonsterLoader] Co %d player, spawn quai sau %d giay...", playerCount, SPAWN_DELAY))
		task.delay(SPAWN_DELAY, spawnMonsters)
	else
		print("[MonsterLoader] Khong co player, cho player join...")
		-- Lang nghe PlayerAdded de spawn khi co player
		local connection
		connection = Players.PlayerAdded:Connect(function(player)
			print("[MonsterLoader] Player " .. player.Name .. " da join, spawn quai sau " .. SPAWN_DELAY .. " giay...")
			task.delay(SPAWN_DELAY, function()
				spawnMonsters()
			end)
			connection:Disconnect() -- Chi spawn 1 lan
		end)
	end
end

checkAndSpawnMonsters()

print("[MonsterLoader] San sang!")