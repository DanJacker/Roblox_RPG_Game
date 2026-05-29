-- MonsterLoaderPVP - Tu dong spawn quai vat trong map PartMapPVPNew (3v3)
-- Giong co che voi map 1v1
-- Dat trong: ServerScriptService.Arena.MonsterLoaderPVP

local Players = game:GetService("Players")

print("[MonsterLoaderPVP] Khoi dong...")

-- ========== REQUIRE MODULE ==========
local MonsterManager3v3 = require(script.Parent:WaitForChild("MonsterManager3v3"))
print("[MonsterLoaderPVP] MonsterManager3v3 da duoc load!")

-- ========== CONFIG ==========
local SPAWN_DELAY = 3 -- Giay sau khi tran bat dau
local MAX_MONSTERS = 12 -- So luong quai toi da cho map 3v3
local MONSTERS_PER_LANE = 4 -- So quai spawn moi lan spawn (chia deu cho 3 duong)

-- Ham lay vi tri spawn theo tung duong
local function getSpawnPositionsByLane()
	local lanes = {
		Left = {},
		Middle = {},
		Right = {}
	}
	
	-- Tim trong Trangtrimap
	local trangtrimap = workspace:FindFirstChild("Trangtrimap")
	if trangtrimap then
		for _, obj in ipairs(trangtrimap:GetChildren()) do
			-- Chi lay cac MonsterPartSpawn_PVP (cho PartMapPVPNew)
			if string.find(obj.Name, "MonsterPartSpawn_PVP") and obj:IsA("BasePart") then
				-- Xac dinh duong dua vao ten
				if string.find(obj.Name, "_Left_") then
					table.insert(lanes.Left, obj.Position + Vector3.new(0, 5, 0))
				elseif string.find(obj.Name, "_Middle_") then
					table.insert(lanes.Middle, obj.Position + Vector3.new(0, 5, 0))
				elseif string.find(obj.Name, "_Right_") then
					table.insert(lanes.Right, obj.Position + Vector3.new(0, 5, 0))
				end
			end
		end
	end
	
	return lanes
end

-- Ham chon random vi tri spawn tu cac duong
local function getRandomSpawnPositions(count)
	local lanes = getSpawnPositionsByLane()
	local selectedPositions = {}
	local usedPositions = {}
	
	-- Chia deu so quai cho 3 duong
	local perLane = math.floor(count / 3)
	local extra = count % 3
	
	-- Spawn cho moi duong
	for laneName, positions in pairs(lanes) do
		local laneCount = perLane
		if extra > 0 then
			laneCount = laneCount + 1
			extra = extra - 1
		end
		
		-- Random chon vi tri trong duong
		local availablePositions = {}
		for _, pos in ipairs(positions) do
			table.insert(availablePositions, pos)
		end
		
		-- Shuffle positions
		for i = #availablePositions, 2, -1 do
			local j = math.random(i)
			availablePositions[i], availablePositions[j] = availablePositions[j], availablePositions[i]
		end
		
		-- Chon so luong can thiet
		for i = 1, math.min(laneCount, #availablePositions) do
			table.insert(selectedPositions, availablePositions[i])
		end
	end
	
	return selectedPositions
end

-- ========== FUNCTIONS ==========
local function spawnMonsters()
	-- Lay vi tri spawn random tu 3 duong
	local spawnPositions = getRandomSpawnPositions(MONSTERS_PER_LANE * 3)
	
	-- Spawn quai tai cac vi tri da chon
	for i, pos in ipairs(spawnPositions) do
		task.wait(0.3) -- Delay giua cac lan spawn
		MonsterManager3v3.SpawnMonster(pos)
	end

	print(string.format("[MonsterLoaderPVP] Da spawn %d quai vat random o 3 duong!", #spawnPositions))
end

local function clearMonsters()
	MonsterManager3v3.ClearAllMonsters()
	print("[MonsterLoaderPVP] Da xoa tat ca quai vat")
end

-- ========== LANG NGHE MATCH START/END ==========
local isMatchActive = false

local function hookMatchSystem()
	-- Lang nghe khi StartMatch duoc goi
	local originalStartMatch = _G.StartMatch
	if originalStartMatch then
		_G.StartMatch = function(matchId, matchData)
			originalStartMatch(matchId, matchData)
			
			if matchData and matchData.mode == "3v3" then
				print("[MonsterLoaderPVP] Tran 3v3 bat dau, se spawn quai sau " .. SPAWN_DELAY .. " giay...")
				isMatchActive = true
				task.delay(SPAWN_DELAY, spawnMonsters)
			end
		end
		print("[MonsterLoaderPVP] Da hook vao StartMatch")
	end
	
	-- Lang nghe khi EndMatch duoc goi
	local originalEndMatch = _G.EndMatch
	if originalEndMatch then
		_G.EndMatch = function(matchId, reason)
			if isMatchActive then
				print("[MonsterLoaderPVP] Tran dau ket thuc, xoa quai vat...")
				isMatchActive = false
				clearMonsters()
			end
			originalEndMatch(matchId, reason)
		end
		print("[MonsterLoaderPVP] Da hook vao EndMatch")
	end
end

-- ========== KHOI DONG ==========
-- Cho he thong match san sang
task.wait(1)
hookMatchSystem()

-- ========== EXPORT FUNCTIONS ==========
_G.SpawnPVPMonsters = spawnMonsters
_G.ClearPVPMonsters = clearMonsters

print("[MonsterLoaderPVP] San sang! Se spawn quai khi tran 3v3 bat dau.")