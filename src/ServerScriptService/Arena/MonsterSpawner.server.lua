-- MonsterSpawner - Spawn monster tai tung Part trong folder Spawmmonster
-- Su dung MonsterManager module de spawn va quan ly monster
-- Monster chi spawn 1 lan khi co player, MonsterManager tu respawn khi monster chet

local Players = game:GetService("Players")
local MonsterManager = require(script.Parent:FindFirstChild("MonsterManager"))

local CONFIG = {
	SPAWN_FOLDER_NAME = "Spawmmonster",
	SPAWN_DELAY = 0.5,        -- Delay giua moi lan spawn (giua cac part)
	INITIAL_DELAY = 5,        -- Delay truoc khi spawn lan dau (cho map load)

	-- ========== THOI GIAN HOI SINH THEO KHOANG CACH TU TRUNG TAM ==========
	-- Quai gan trung tam (khu rung) hoi sinh nhanh hon
	-- Quai xa trung tam hoi sinh cham hon
	MAP_CENTER = Vector3.new(-136, 3, -7556), -- Trung tam khu rung (giua map 3v3)
	RESPAWN_NEAR = 8,    -- Gan trung tam (< 100 studs): 8 giay
	RESPAWN_MID = 12,    -- Khoang trung binh (100-200 studs): 12 giay
	RESPAWN_FAR = 15,    -- Xa trung tam (> 200 studs): 15 giay
	NEAR_RANGE = 100,    -- Gio han gan
	FAR_RANGE = 200,     -- Gio han xa
}

local hasSpawned = false

-- Tim tat ca spawn part trong folder
local function collectSpawnPoints()
	local spawnPoints = {}
	local folder = workspace:FindFirstChild(CONFIG.SPAWN_FOLDER_NAME)
	if not folder then
		warn("[MonsterSpawner] Khong tim thay folder: " .. CONFIG.SPAWN_FOLDER_NAME)
		return spawnPoints
	end
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") then
			table.insert(spawnPoints, part)
		end
	end
	return spawnPoints
end

-- Spawn monster tai tung part (chi chay 1 lan)
local function spawnAtAllPoints()
	if hasSpawned then return end
	hasSpawned = true

	local spawnPoints = collectSpawnPoints()
	if #spawnPoints == 0 then
		warn("[MonsterSpawner] Khong co spawn point nao!")
		return
	end

	local count = 0
	for i, spawnPart in ipairs(spawnPoints) do
		if spawnPart and spawnPart.Parent then
			local pos = spawnPart.Position

			-- Tinh thoi gian hoi sinh dua tren khoang cach tu trung tam map
			local distFromCenter = (pos - CONFIG.MAP_CENTER).Magnitude
			local respawnTime
			if distFromCenter <= CONFIG.NEAR_RANGE then
				respawnTime = CONFIG.RESPAWN_NEAR
			elseif distFromCenter <= CONFIG.FAR_RANGE then
				respawnTime = CONFIG.RESPAWN_MID
			else
				respawnTime = CONFIG.RESPAWN_FAR
			end

			task.wait(CONFIG.SPAWN_DELAY)

			if spawnPart and spawnPart.Parent then
				local monster = MonsterManager.SpawnMonster(pos, respawnTime)
				if monster then
					count = count + 1
				end
			end
		end
	end

	print("[MonsterSpawner] Da spawn " .. count .. " monster tai " .. #spawnPoints .. " spawn point")
end

-- Spawn khi co player dau tien vao game
local function onPlayerAdded(player)
	if not hasSpawned then
		task.delay(CONFIG.INITIAL_DELAY, spawnAtAllPoints)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Spawn ngay neu da co player trong game khi script bat dau
if #Players:GetPlayers() > 0 then
	task.delay(CONFIG.INITIAL_DELAY, spawnAtAllPoints)
end