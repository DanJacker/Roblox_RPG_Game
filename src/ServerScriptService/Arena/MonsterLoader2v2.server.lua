-- MonsterLoader2v2 - Tu dong spawn quai vat trong map 2v2
-- Chi spawn khi tran 2v2 bat dau
-- Dat trong: ServerScriptService.Arena.MonsterLoader2v2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[MonsterLoader2v2] Khoi dong...")

-- ========== REQUIRE MODULE ==========
local MonsterManager2v2 = require(script.Parent:WaitForChild("MonsterManager2v2"))
print("[MonsterLoader2v2] MonsterManager2v2 da duoc load!")

-- ========== CONFIG ==========
-- Vi tri spawn quai trong map 2v2 (8 vi tri)
local MONSTER_SPAWN_POSITIONS = {
	-- Nhom giua map
	Vector3.new(13, 10, -2040),    -- Giua map chinh
	Vector3.new(-50, 10, -2040),  -- Trai giua
	Vector3.new(76, 10, -2040),    -- Phai giua
	
	-- Nhom tren
	Vector3.new(13, 10, -2120),    -- Giua tren
	Vector3.new(-50, 10, -2120),  -- Trai tren
	
	-- Nhom duoi
	Vector3.new(13, 10, -1960),    -- Giua duoi
	Vector3.new(76, 10, -1960),   -- Phai duoi
	
	-- Nhom gan Team1
	Vector3.new(-100, 10, -2040),  -- Gan Team1
}

local SPAWN_DELAY = 3 -- Giay sau khi tran bat dau
local isMatchActive = false

-- ========== FUNCTIONS ==========
local function spawnMonsters()
	-- Xoa quai cu neu co
	MonsterManager2v2.ClearAllMonsters()
	
	-- Spawn quai tai cac vi tri
	for i, pos in ipairs(MONSTER_SPAWN_POSITIONS) do
		task.wait(0.5) -- Delay giua cac lan spawn
		MonsterManager2v2.SpawnMonster(pos)
	end

	print(string.format("[MonsterLoader2v2] Da spawn %d quai vat!", #MONSTER_SPAWN_POSITIONS))
end

local function clearMonsters()
	MonsterManager2v2.ClearAllMonsters()
	print("[MonsterLoader2v2] Da xoa tat ca quai vat")
end

-- ========== LANG NGHE MATCH START/END ==========
-- Hook vao he thong match
local function hookMatchSystem()
	-- Lang nghe khi StartMatch duoc goi
	local originalStartMatch = _G.StartMatch
	if originalStartMatch then
		_G.StartMatch = function(matchId, matchData)
			originalStartMatch(matchId, matchData)
			
			if matchData and matchData.mode == "2v2" then
				print("[MonsterLoader2v2] Tran 2v2 bat dau, se spawn quai sau " .. SPAWN_DELAY .. " giay...")
				isMatchActive = true
				task.delay(SPAWN_DELAY, spawnMonsters)
			end
		end
		print("[MonsterLoader2v2] Da hook vao StartMatch")
	end
	
	-- Lang nghe khi EndMatch duoc goi
	local originalEndMatch = _G.EndMatch
	if originalEndMatch then
		_G.EndMatch = function(matchId, reason)
			if isMatchActive then
				print("[MonsterLoader2v2] Tran dau ket thuc, xoa quai vat...")
				isMatchActive = false
				clearMonsters()
			end
			originalEndMatch(matchId, reason)
		end
		print("[MonsterLoader2v2] Da hook vao EndMatch")
	end
end

-- Cho he thong match san sang
task.wait(1)
hookMatchSystem()

-- ========== EXPORT FUNCTIONS ==========
_G.Spawn2v2Monsters = spawnMonsters
_G.Clear2v2Monsters = clearMonsters

print("[MonsterLoader2v2] San sang! Se spawn quai khi tran 2v2 bat dau.")