-- BotLoader3v3 - Tu dong spawn bot co kha nang tan cong base trong map 3v3
-- Bot se di chuyen va pha base nhu map 1v1
-- Dat trong: ServerScriptService.Arena.BotLoader3v3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[BotLoader3v3] Khoi dong...")

-- ========== REQUIRE MODULE ==========
local BotManager3v3 = require(script.Parent:WaitForChild("BotManager3v3"))
print("[BotLoader3v3] BotManager3v3 da duoc load!")

-- ========== CONFIG ==========
local BOTS_PER_TEAM = 3 -- So bot moi team (3v3)
local SPAWN_DELAY = 2 -- Giay sau khi tran bat dau
local isMatchActive = false
local currentMode = nil

-- ========== VI TRI SPAWN BOT THEO TEAM ==========
-- Team1Base: -385.47, 12.09, -7302.43
-- Team2Base: 112.68, 11.70, -7811.01
-- Bot spawn gan base cua team minh

local TEAM1_SPAWN_POSITIONS = {
	Vector3.new(-400, 10, -7280),   -- Gan Team1 base
	Vector3.new(-420, 10, -7320),   -- Gan Team1 base 2
	Vector3.new(-360, 10, -7340),   -- Gan Team1 base 3
}

local TEAM2_SPAWN_POSITIONS = {
	Vector3.new(130, 10, -7790),    -- Gan Team2 base
	Vector3.new(100, 10, -7830),    -- Gan Team2 base 2
	Vector3.new(150, 10, -7780),    -- Gan Team2 base 3
}

-- ========== FUNCTIONS ==========
local function spawnBots()
	-- Xoa bot cu neu co
	BotManager3v3.ClearAllBots()
	
	-- Spawn bot cho Team1
	for i = 1, BOTS_PER_TEAM do
		local pos = TEAM1_SPAWN_POSITIONS[i] or TEAM1_SPAWN_POSITIONS[1]
		task.wait(0.3)
		BotManager3v3.SpawnBotForTeam("Team1", pos)
		print(string.format("[BotLoader3v3] Spawned Team1 Bot %d at %s", i, tostring(pos)))
	end
	
	-- Spawn bot cho Team2
	for i = 1, BOTS_PER_TEAM do
		local pos = TEAM2_SPAWN_POSITIONS[i] or TEAM2_SPAWN_POSITIONS[1]
		task.wait(0.3)
		BotManager3v3.SpawnBotForTeam("Team2", pos)
		print(string.format("[BotLoader3v3] Spawned Team2 Bot %d at %s", i, tostring(pos)))
	end

	print(string.format("[BotLoader3v3] Da spawn %d bot cho moi team!", BOTS_PER_TEAM))
end

local function clearBots()
	BotManager3v3.ClearAllBots()
	print("[BotLoader3v3] Da xoa tat ca bot")
end

-- ========== LANG NGHE MATCH START/END ==========
local function hookMatchSystem()
	-- Lang nghe khi StartMatch duoc goi
	local originalStartMatch = _G.StartMatch
	if originalStartMatch then
		_G.StartMatch = function(matchId, matchData)
			originalStartMatch(matchId, matchData)
			
			if matchData and matchData.mode == "3v3" then
				print("[BotLoader3v3] Tran 3v3 bat dau, se spawn bot sau " .. SPAWN_DELAY .. " giay...")
				isMatchActive = true
				currentMode = "3v3"
				task.delay(SPAWN_DELAY, spawnBots)
			end
		end
		print("[BotLoader3v3] Da hook vao StartMatch")
	end
	
	-- Lang nghe khi EndMatch duoc goi
	local originalEndMatch = _G.EndMatch
	if originalEndMatch then
		_G.EndMatch = function(matchId, reason)
			if isMatchActive then
				print("[BotLoader3v3] Tran dau ket thuc, xoa bot...")
				isMatchActive = false
				currentMode = nil
				clearBots()
			end
			originalEndMatch(matchId, reason)
		end
		print("[BotLoader3v3] Da hook vao EndMatch")
	end
end

-- Cho he thong match san sang
task.wait(1)
hookMatchSystem()

-- ========== EXPORT FUNCTIONS ==========
_G.Spawn3v3Bots = spawnBots
_G.Clear3v3Bots = clearBots

print("[BotLoader3v3] San sang! Se spawn bot co kha nang pha base khi tran 3v3 bat dau.")

-- ========== TEST MODE: DA TAT ==========
-- TEST MODE da duoc tat de khong spawn bot cho map 1v1