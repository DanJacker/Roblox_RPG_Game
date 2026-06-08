-- MonsterLoader3v3 - Tu dong spawn quai vat trong map 3v3
-- Chi spawn khi tran 3v3 bat dau
-- Dat trong: ServerScriptService.Arena.MonsterLoader3v3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[MonsterLoader3v3] Khoi dong...")

-- ========== REQUIRE MODULE ==========
local MonsterManager3v3 = require(script.Parent:WaitForChild("MonsterManager3v3"))
print("[MonsterLoader3v3] MonsterManager3v3 da duoc load!")

-- ========== CONFIG ==========
-- Vi tri spawn quai trong map 3v3 - CHI O KHU RUNG (GIUA MAP)
-- Team1Base (Nhà XANH): -385.5, -7302.4
-- Team2Base (Nhà ĐỎ): 112.7, -7811.0
-- Trung điểm (Khu RỪNG): -136.4, -7556.7
-- Quái CHỈ spawn ở khu rừng, KHÔNG spawn gần nhà đỏ hay nhà xanh
-- Mỗi bãi quái có thời gian hồi sinh (respawnTime) khác nhau
local MONSTER_SPAWN_POSITIONS = {
	-- Cụm TRUNG TÂM khu rừng (6 con) - Hồi sinh nhanh nhất (khu vực tranh giành)
	{ pos = Vector3.new(-136, 10, -7556), respawnTime = 8 },    -- Trung tâm rừng
	{ pos = Vector3.new(-180, 10, -7520), respawnTime = 9 },    -- Rừng trái
	{ pos = Vector3.new(-90, 10, -7520),  respawnTime = 9 },    -- Rừng phải
	{ pos = Vector3.new(-136, 10, -7600), respawnTime = 10 },   -- Rừng dưới
	{ pos = Vector3.new(-136, 10, -7500), respawnTime = 10 },   -- Rừng trên
	{ pos = Vector3.new(-200, 10, -7556), respawnTime = 11 },  -- Rừng sâu trái

	-- Cụm RỪNG TRÁI (3 con) - Hồi sinh trung bình
	{ pos = Vector3.new(-280, 10, -7500), respawnTime = 13 },  -- Rừng trái trên
	{ pos = Vector3.new(-280, 10, -7580), respawnTime = 14 },  -- Rừng trái giữa
	{ pos = Vector3.new(-280, 10, -7660), respawnTime = 15 },  -- Rừng trái dưới

	-- Cụm RỪNG PHẢI (3 con) - Hồi sinh lâu nhất (xa trung tâm)
	{ pos = Vector3.new(10, 10, -7500),   respawnTime = 13 },  -- Rừng phải trên
	{ pos = Vector3.new(10, 10, -7580),   respawnTime = 14 },  -- Rừng phải giữa
	{ pos = Vector3.new(10, 10, -7660),   respawnTime = 15 },  -- Rừng phải dưới
}

local SPAWN_DELAY = 3 -- Giay sau khi tran bat dau
local isMatchActive = false

-- ========== FUNCTIONS ==========
local function spawnMonsters()
	-- Xoa quai cu neu co
	MonsterManager3v3.ClearAllMonsters()
	
	-- Spawn quai tai cac vi tri
	for i, spawnInfo in ipairs(MONSTER_SPAWN_POSITIONS) do
		task.wait(0.5) -- Delay giua cac lan spawn
		MonsterManager3v3.SpawnMonster(spawnInfo.pos, spawnInfo.respawnTime)
	end

	print(string.format("[MonsterLoader3v3] Da spawn %d quai vat!", #MONSTER_SPAWN_POSITIONS))
end

local function clearMonsters()
	MonsterManager3v3.ClearAllMonsters()
	print("[MonsterLoader3v3] Da xoa tat ca quai vat")
end

-- ========== LANG NGHE MATCH START/END ==========
-- Hook vao he thong match
local function hookMatchSystem()
	-- Lang nghe khi StartMatch duoc goi
	local originalStartMatch = _G.StartMatch
	if originalStartMatch then
		_G.StartMatch = function(matchId, matchData)
			originalStartMatch(matchId, matchData)
			
			if matchData and matchData.mode == "3v3" then
				print("[MonsterLoader3v3] Tran 3v3 bat dau, se spawn quai sau " .. SPAWN_DELAY .. " giay...")
				isMatchActive = true
				task.delay(SPAWN_DELAY, spawnMonsters)
			end
		end
		print("[MonsterLoader3v3] Da hook vao StartMatch")
	end
	
	-- Lang nghe khi EndMatch duoc goi
	local originalEndMatch = _G.EndMatch
	if originalEndMatch then
		_G.EndMatch = function(matchId, reason)
			if isMatchActive then
				print("[MonsterLoader3v3] Tran dau ket thuc, xoa quai vat...")
				isMatchActive = false
				clearMonsters()
			end
			originalEndMatch(matchId, reason)
		end
		print("[MonsterLoader3v3] Da hook vao EndMatch")
	end
end

-- Cho he thong match san sang
task.wait(1)
hookMatchSystem()

-- ========== EXPORT FUNCTIONS ==========
_G.Spawn3v3Monsters = spawnMonsters
_G.Clear3v3Monsters = clearMonsters

print("[MonsterLoader3v3] San sang! Se spawn quai khi tran 3v3 bat dau.")