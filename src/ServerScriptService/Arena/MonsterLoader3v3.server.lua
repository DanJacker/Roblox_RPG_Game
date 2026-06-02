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
local MONSTER_SPAWN_POSITIONS = {
	-- Phân tán khắp map 3v3, XA cả 2 base
	-- Map3v3: X(-485 to 184), Z(-7874 to -7206)
	-- Team1Base: -385, -7302 | Team2Base: 113, -7811
	-- Giữ khoảng cách tối thiểu 120 studs từ mỗi base

	-- Khu phía TRÊN map (xa Team1Base)
	Vector3.new(-300, 10, -7380),    -- Trên trái (xa base)
	Vector3.new(-200, 10, -7350),    -- Trên giữa-trái
	Vector3.new(-100, 10, -7320),    -- Trên giữa

	-- Khu GIỮA map (khu rừng - xa cả 2 base)
	Vector3.new(-136, 10, -7556),    -- Trung tâm
	Vector3.new(-250, 10, -7500),    -- Giữa-trái
	Vector3.new(0, 10, -7500),       -- Giữa-phải

	-- Khu phía DƯỚI map (xa Team2Base)
	Vector3.new(-50, 10, -7700),     -- Dưới giữa
	Vector3.new(-150, 10, -7720),    -- Dưới giữa-trái
	Vector3.new(-200, 10, -7680),    -- Dưới trái

	-- Lane 2 bên (giữa map, xa base)
	Vector3.new(-350, 10, -7550),    -- Lane trái
	Vector3.new(50, 10, -7550),      -- Lane phải
}

local SPAWN_DELAY = 3 -- Giay sau khi tran bat dau
local isMatchActive = false

-- ========== FUNCTIONS ==========
local function spawnMonsters()
	-- Xoa quai cu neu co
	MonsterManager3v3.ClearAllMonsters()
	
	-- Spawn quai tai cac vi tri
	for i, pos in ipairs(MONSTER_SPAWN_POSITIONS) do
		task.wait(0.5) -- Delay giua cac lan spawn
		MonsterManager3v3.SpawnMonster(pos)
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