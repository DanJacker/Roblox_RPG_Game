-- BaseSetupManager - Qu?n l? base cho match (d? lo?i b? duplicate)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- ??i c?c module c?n thi?t
task.wait(2)

-- C?u h?nh
local CONFIG = {
	BASE_SPACING = 50, -- Kho?ng c?ch gi?a c?c base (studs) - tang l?n
	BASE_SIZE = 8, -- K?ch thu?c base
}

-- Team colors
local TEAM_COLORS = {
	Team1 = Color3.fromRGB(0, 100, 255), -- Xanh duong
	Team2 = Color3.fromRGB(255, 50, 50)   -- ??
}

-- Luu tr? th?ng tin base c?a match hi?n t?i
local currentMatchBases = {
	Team1 = {},
	Team2 = {}
}

-- Flag d? ngan ch?n duplicate setup
local isSettingUp = false
local lastSetupTime = 0
local currentMatchId = nil -- Track current match ID

-- ??m s? bot c?a m?i team
local function countBotsByTeam(teamName)
	local count = 0
	-- Duy?t descendants v? bot c? th? ?? ???c ??a v?o folder theo map (Workspace.Maps/MapXvY/Bots)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:GetAttribute("Team") == teamName then
			-- L?c theo t?n ?? tr?nh ??m base/tower v? t?nh c? attribute Team
			if string.find(obj.Name, "[BOT", 1, true) then
				local humanoid = obj:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health > 0 then
					count = count + 1
				end
			end
		end
	end
	return count
end

-- ??m s? player c?a m?i team
local function countPlayersByTeam(teamName)
	local count = 0
	for _, player in pairs(Players:GetPlayers()) do
		if player.Team and player.Team.Name == teamName then
			count = count + 1
		end
	end
	return count
end

-- X?a t?m cache base (duplicate); kh?ng reset currentMatchId ? tr?nh m?t tr?ng th?i khi g?i gi?a setupBasesForMatch
local function clearDuplicateBases()
	currentMatchBases = {Team1 = {}, Team2 = {}}
	print("[BaseSetup] ClearDuplicateBases - reset cache bases")
	return 0
end

local function findArenaBase(baseName)
	local direct = Workspace:FindFirstChild(baseName)
	if direct then
		return direct
	end
	return Workspace:FindFirstChild(baseName, true)
end

-- Duplicate base theo s? lu?ng (?? V? HI?U H?A)
local function duplicateBasesForTeam(teamName, count)
	-- Kh?ng c?n s? d?ng duplicate bases
	-- Ch? tr? v? base g?c
	local templateName = teamName .. "Base"
	local template = findArenaBase(templateName)

	if template then
		return {template}
	end

	return {}
end

-- Thi?t l?p base cho match
local function setupBasesForMatch(matchId, matchData)
	-- Ki?m tra n?u d? setup cho match n?y r?i
	if currentMatchId == matchId then
		print("[BaseSetup] Match " .. matchId .. " d? du?c setup, b? qua...")
		return currentMatchBases
	end

	-- Ngan ch?n duplicate setup (ch? cho ph?p 1 setup m?i 10 gi?y)
	if isSettingUp or (tick() - lastSetupTime) < 10 then
		print("[BaseSetup] ?ang setup ho?c v?a setup xong, b? qua...")
		return currentMatchBases
	end

	isSettingUp = true
	currentMatchId = matchId
	print("[BaseSetup] B?t d?u thi?t l?p base cho match " .. matchId)

	-- Reset cache base; khong goi ClearAllBots ? Matchmaking co the da spawn bot truoc StartMatch
	clearDuplicateBases()

	-- L?y mode c?a match (1v1, 2v2, 3v3)
	local mode = matchData.mode or "1v1"
	local playersPerTeam = tonumber(string.sub(mode, 1, 1)) or 1

	-- ??m s? player m?i team
	local team1Players = countPlayersByTeam("Team1")
	local team2Players = countPlayersByTeam("Team2")
	local team1BotsAlive = countBotsByTeam("Team1")
	local team2BotsAlive = countBotsByTeam("Team2")

	-- Tru bot da co trong workspace (vd Matchmaking) de khong xoa roi spawn lai / double spawn
	local team1BotsNeeded = math.max(0, playersPerTeam - team1Players - team1BotsAlive)
	local team2BotsNeeded = math.max(0, playersPerTeam - team2Players - team2BotsAlive)

	-- T?ng s? base = s? player + s? bot m?i team
	local team1Total = playersPerTeam
	local team2Total = playersPerTeam

	print(string.format("[BaseSetup] Mode: %s - M?i team %d ngu?i", mode, playersPerTeam))
	print(string.format("[BaseSetup] Team1: %d players, %d bot san co, can them %d (muc tieu %d)", team1Players, team1BotsAlive, team1BotsNeeded, team1Total))
	print(string.format("[BaseSetup] Team2: %d players, %d bot san co, can them %d (muc tieu %d)", team2Players, team2BotsAlive, team2BotsNeeded, team2Total))

	local team1Base = findArenaBase("Team1Base")
	local team2Base = findArenaBase("Team2Base")
	if not team1Base then
		warn("[BaseSetup] Khong tim thay Team1Base trong Workspace (ke ca nested)")
	end
	if not team2Base then
		warn("[BaseSetup] Khong tim thay Team2Base trong Workspace (ke ca nested)")
	end

	if team1Base then
		currentMatchBases.Team1 = {team1Base}
	end
	if team2Base then
		currentMatchBases.Team2 = {team2Base}
	end

	-- L?y v? tr? c?c base d? spawn bot
	local team1BasePositions = {}
	local team2BasePositions = {}

	for _, base in ipairs(currentMatchBases.Team1) do
		table.insert(team1BasePositions, base:GetPivot().Position)
	end
	for _, base in ipairs(currentMatchBases.Team2) do
		table.insert(team2BasePositions, base:GetPivot().Position)
	end

	-- ========== KIỂM TRA ĐỦ PLAYER THẬT ==========
	-- Nếu đã đủ player thật cho cả 2 team, KHÔNG spawn bot
	local totalRealPlayers = team1Players + team2Players
	local totalNeeded = playersPerTeam * 2 -- 2 team
	
	-- QUAN TRỌNG: Chỉ spawn bot khi có ít nhất 1 player thật
	if totalRealPlayers == 0 then
		print("[BaseSetup] KHÔNG CÓ PLAYER NÀO - KHÔNG spawn bot!")
		team1BotsNeeded = 0
		team2BotsNeeded = 0
	elseif totalRealPlayers >= totalNeeded then
		print(string.format("[BaseSetup] Đã có %d player thật (cần %d), KHÔNG spawn bot!", totalRealPlayers, totalNeeded))
		team1BotsNeeded = 0
		team2BotsNeeded = 0
	else
		-- SỬA: Chỉ spawn bot cho team KHÔNG có player
		-- Nếu Team1 có player, chỉ spawn bot cho Team2 (và ngược lại)
		if team1Players > 0 and team2Players == 0 then
			team1BotsNeeded = 0
			team2BotsNeeded = playersPerTeam - team2BotsAlive
			print(string.format("[BaseSetup] Team1 có %d player -> Chỉ spawn %d bot cho Team2", team1Players, team2BotsNeeded))
		elseif team2Players > 0 and team1Players == 0 then
			team2BotsNeeded = 0
			team1BotsNeeded = playersPerTeam - team1BotsAlive
			print(string.format("[BaseSetup] Team2 có %d player -> Chỉ spawn %d bot cho Team1", team2Players, team1BotsNeeded))
		else
			print(string.format("[BaseSetup] Cần spawn bot: Team1=%d, Team2=%d", team1BotsNeeded, team2BotsNeeded))
		end
	end
	-- ==============================================

	-- ========== TẮT BOT SPAWN Ở ĐÂY ==========
	-- Bot spawning đã được xử lý bởi MatchmakingService
	-- Không spawn bot ở đây để tránh duplicate
	print("[BaseSetup] Bot spawning được xử lý bởi MatchmakingService")
	print(string.format("[BaseSetup] Team1 cần %d bot, Team2 cần %d bot (sẽ được spawn bởi MatchmakingService)", team1BotsNeeded, team2BotsNeeded))
	-- ===========================================

	-- Reset flag
	isSettingUp = false
	print("[BaseSetup] Hoàn thành setup base")

	lastSetupTime = tick()
	print(string.format("[BaseSetup] ?? t?o %d bases cho Team1, %d bases cho Team2", #currentMatchBases.Team1, #currentMatchBases.Team2))

	return currentMatchBases
end

-- API to?n c?c
_G.SetupBasesForMatch = setupBasesForMatch
_G.ClearDuplicateBases = clearDuplicateBases
_G.GetMatchBases = function() return currentMatchBases end

-- Hook v?o MatchManager d? t? d?ng setup base khi match b?t d?u
local originalStartMatch = _G.StartMatch
if originalStartMatch then
	_G.StartMatch = function(matchId, matchData)
		-- G?i h?m g?c tru?c
		originalStartMatch(matchId, matchData)

		-- Setup base sau khi match d? b?t d?u
		task.delay(1, function()
			setupBasesForMatch(matchId, matchData)
		end)
	end
	print("[BaseSetup] ?? hook v?o MatchManager.StartMatch")
end

print("[BaseSetup] Base Setup Manager d? du?c t?i!")
print("[BaseSetup] S? d?ng: _G.SetupBasesForMatch(matchId, matchData)")