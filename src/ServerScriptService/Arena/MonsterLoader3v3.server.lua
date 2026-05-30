-- MonsterLoader3v3 - Tu dong spawn quai vat trong map 3v3
-- Chi spawn khi tran 3v3 bat dau
-- Dat trong: ServerScriptService.Arena.MonsterLoader3v3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- ========== REQUIRE MODULE ==========
local MonsterManager3v3 = require(script.Parent:WaitForChild("MonsterManager3v3"))

-- ========== CONFIG ==========
-- Vi tri spawn quai trong map 3v3 - CHI O KHU RUNG (GIUA MAP)
-- Team1Base (Nhà XANH): -385.5, -7302.4
-- Team2Base (Nhà ĐỎ): 112.7, -7811.0
-- Trung điểm (Khu RỪNG): -136.4, -7556.7
-- Quái CHỈ spawn ở khu rừng, KHÔNG spawn gần nhà đỏ hay nhà xanh
local MONSTER_SPAWN_POSITIONS = {
	-- Khu rừng chính (giữa map, xa cả 2 base)
	Vector3.new(-136, 10, -7556),    -- Trung tâm khu rừng
	Vector3.new(-180, 10, -7520),    -- Bên trái trung tâm
	Vector3.new(-90, 10, -7590),     -- Bên phải trung tâm
	Vector3.new(-200, 10, -7600),    -- Góc trái trên
	Vector3.new(-70, 10, -7510),     -- Góc phải dưới
	Vector3.new(-150, 10, -7620),    -- Phía dưới trung tâm
	Vector3.new(-120, 10, -7490),    -- Phía trên trung tâm
	Vector3.new(-220, 10, -7550),    -- Xa trái
	Vector3.new(-50, 10, -7580),     -- Xa phải
	Vector3.new(-170, 10, -7480),    -- Góc trên trái
	Vector3.new(-100, 10, -7630),    -- Góc dưới phải
	Vector3.new(-160, 10, -7530),    -- Gần trung tâm
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

end

local function clearMonsters()
	MonsterManager3v3.ClearAllMonsters()
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
				isMatchActive = true
				task.delay(SPAWN_DELAY, spawnMonsters)
			end
		end
	end
	
	-- Lang nghe khi EndMatch duoc goi
	local originalEndMatch = _G.EndMatch
	if originalEndMatch then
		_G.EndMatch = function(matchId, reason)
			if isMatchActive then
				isMatchActive = false
				clearMonsters()
			end
			originalEndMatch(matchId, reason)
		end
	end
end

-- Cho he thong match san sang
task.wait(1)
hookMatchSystem()

-- ========== EXPORT FUNCTIONS ==========
_G.Spawn3v3Monsters = spawnMonsters
_G.Clear3v3Monsters = clearMonsters

