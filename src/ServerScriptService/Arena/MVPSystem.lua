-- MVP System - Tính toán và hiển thị MVP dựa trên Kills và Base Damage
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- ========== CẤU HÌNH ==========
local CONFIG = {
	KILL_WEIGHT = 100,      -- Điểm cho mỗi kill
	BASE_DAMAGE_WEIGHT = 1, -- Điểm cho mỗi 1 base damage
	MVP_BONUS = 50,         -- Bonus điểm cho MVP
}

-- ========== BIẾN LƯU TRỮ ==========
local playerStats = {} -- {playerName = {kills=0, baseDamage=0, team="Team1"}}
local currentMatch = nil

-- ========== REMOTE EVENTS ==========
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name)
	local event = remoteEvents:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remoteEvents
	end
	return event
end

local MVPAnnouncement = getOrCreateRemoteEvent("MVPAnnouncement")

-- ========== HÀM HELPER ==========

-- Khởi tạo stats cho player
local function initPlayerStats(playerName, teamName)
	if not playerName or playerName == "" then
		warn("[MVP] initPlayerStats: playerName is nil or empty!")
		return
	end
	
	if not playerStats[playerName] then
		playerStats[playerName] = {
			kills = 0,
			baseDamage = 0,
			team = teamName or "Unknown",
			isBot = playerName:find("%[BOT%]") ~= nil
		}
	else
	end
end

-- Tính điểm MVP
local function calculateMVPScore(stats)
	return (stats.kills * CONFIG.KILL_WEIGHT) + (stats.baseDamage * CONFIG.BASE_DAMAGE_WEIGHT)
end

-- Tìm MVP của match
local function findMVP()
	local mvp = nil
	local mvpScore = 0
	
	for playerName, stats in pairs(playerStats) do
		local score = calculateMVPScore(stats)
		if score > mvpScore then
			mvpScore = score
			mvp = {
				name = playerName,
				kills = stats.kills,
				baseDamage = stats.baseDamage,
				team = stats.team,
				isBot = stats.isBot,
				score = score
			}
		end
	end
	
	return mvp
end

-- Tìm MVP của mỗi team
local function findTeamMVPs()
	local team1MVP = nil
	local team2MVP = nil
	local team1Score = -1  -- Sửa: Bắt đầu từ -1
	local team2Score = -1  -- Sửa: Bắt đầu từ -1
	
	for playerName, stats in pairs(playerStats) do
		local score = calculateMVPScore(stats)
		
		if stats.team == "Team1" then
			if score >= team1Score then  -- Sửa: Dùng >= thay vì >
				team1Score = score
				team1MVP = {
					name = playerName,
					kills = stats.kills,
					baseDamage = stats.baseDamage,
					team = stats.team,
					isBot = stats.isBot,
					score = score
				}
			end
		elseif stats.team == "Team2" then
			if score >= team2Score then  -- Sửa: Dùng >= thay vì >
				team2Score = score
				team2MVP = {
					name = playerName,
					kills = stats.kills,
					baseDamage = stats.baseDamage,
					team = stats.team,
					isBot = stats.isBot,
					score = score
				}
			end
		end
	end
	
	return team1MVP, team2MVP
end

-- ========== HÀM PUBLIC API ==========

-- Bắt đầu match mới
local function startMatch(matchData)
	currentMatch = matchData
	playerStats = {}
	
	
	-- Khởi tạo stats cho tất cả players trong match
	if matchData.team1 then
		for i, playerData in ipairs(matchData.team1) do
			if type(playerData) == "table" then
				
				-- Lấy name từ nhiều nguồn - SỬA: Bỏ điều kiện name ~= "Unknown"
				local name = playerData.name or playerData.Name or playerData.playerName
				if name and name ~= "" then
					initPlayerStats(name, "Team1")
				else
					-- Tạo tên mặc định nếu không có tên
					local defaultName = "Team1_Player" .. i
					initPlayerStats(defaultName, "Team1")
					warn("[MVP]   ⚠ Using default name for Team1 player " .. i .. ": " .. defaultName)
				end
			elseif type(playerData) == "string" then
				initPlayerStats(playerData, "Team1")
			else
				warn("[MVP]   ✗ INVALID playerData type for Team1 player " .. i .. ": " .. type(playerData))
			end
		end
	else
		warn("[MVP] Team1 is NIL!")
	end
	
	if matchData.team2 then
		for i, playerData in ipairs(matchData.team2) do
			if type(playerData) == "table" then
				
				-- Lấy name từ nhiều nguồn - SỬA: Bỏ điều kiện name ~= "Unknown"
				local name = playerData.name or playerData.Name or playerData.playerName
				if name and name ~= "" then
					initPlayerStats(name, "Team2")
				else
					-- Tạo tên mặc định nếu không có tên
					local defaultName = "Team2_Player" .. i
					initPlayerStats(defaultName, "Team2")
					warn("[MVP]   ⚠ Using default name for Team2 player " .. i .. ": " .. defaultName)
				end
			elseif type(playerData) == "string" then
				initPlayerStats(playerData, "Team2")
			else
				warn("[MVP]   ✗ INVALID playerData type for Team2 player " .. i .. ": " .. type(playerData))
			end
		end
	else
		warn("[MVP] Team2 is NIL!")
	end
	
	-- In tổng kết
	for name, stats in pairs(playerStats) do
	end
	
end

-- Kiem tra xem ten co phai la monster khong
local function isMonsterName(name)
	if not name then return false end
	return name:find("%[MONSTER%]") ~= nil or name:find("%[Monster%]") ~= nil
end

-- Ghi nhận kill
local function recordKill(killerName, victimName)
	-- Monster kill KHONG duoc tinh vao MVP (ca khi lam killer lan victim)
	if isMonsterName(killerName) then
		return
	end
	if isMonsterName(victimName) then
		return
	end
	
	if not playerStats[killerName] then
		-- Tìm team của killer
		local killerTeam = nil
		
		-- Kiểm tra nếu là bot (hỗ trợ nhiều format: [BOT], [BOT-1v1], [BOT-2v2], etc.)
		local BotManager = _G.BotManager or _G.BotManager1v1 or _G.BotManager2v2 or _G.BotManager3v3
		if BotManager and (killerName:find("%[BOT") or killerName:find("BOT")) then
			-- Thử tìm trong GetActiveBots
			local activeBots = BotManager.GetActiveBots and BotManager.GetActiveBots() or {}
			for bot, data in pairs(activeBots) do
				local botName = bot.Name or data.name
				if botName == killerName or data.name == killerName then
					killerTeam = data.team
					break
				end
			end
			
			-- Nếu không tìm thấy, thử tìm trong các BotManager riêng biệt
			if not killerTeam then
				for _, mgr in ipairs({_G.BotManager1v1, _G.BotManager2v2, _G.BotManager3v3}) do
					if mgr and mgr.GetActiveBots then
						for bot, data in pairs(mgr.GetActiveBots()) do
							local botName = bot.Name or data.name
							if botName == killerName or data.name == killerName then
								killerTeam = data.team
								break
							end
						end
					end
					if killerTeam then break end
				end
			end
		end
		
		-- Nếu không phải bot, tìm team từ player object
		if not killerTeam then
			local player = Players:FindFirstChild(killerName)
			if player and player.Team then
				killerTeam = player.Team.Name
			end
		end
		
		if killerTeam then
			initPlayerStats(killerName, killerTeam)
		else
			warn("[MVP] Không tìm thấy team cho killer: " .. killerName .. " - SKIPPING")
			return
		end
	end
	
	playerStats[killerName].kills = playerStats[killerName].kills + 1
end

-- Ghi nhận base damage
local function recordBaseDamage(attackerName, damage)
	-- Monster KHONG duoc tinh vao MVP
	if isMonsterName(attackerName) then
		return
	end
	
	if not playerStats[attackerName] then
		-- Tìm team của attacker
		local attackerTeam = nil
		
		-- Kiểm tra nếu là bot (hỗ trợ nhiều format: [BOT], [BOT-1v1], [BOT-2v2], etc.)
		local BotManager = _G.BotManager or _G.BotManager1v1 or _G.BotManager2v2 or _G.BotManager3v3
		if BotManager and (attackerName:find("%[BOT") or attackerName:find("BOT")) then
			-- Thử tìm trong GetActiveBots
			local activeBots = BotManager.GetActiveBots and BotManager.GetActiveBots() or {}
			for bot, data in pairs(activeBots) do
				local botName = bot.Name or data.name
				if botName == attackerName or data.name == attackerName then
					attackerTeam = data.team
					break
				end
			end
			
			-- Nếu không tìm thấy, thử tìm trong các BotManager riêng biệt
			if not attackerTeam then
				for _, mgr in ipairs({_G.BotManager1v1, _G.BotManager2v2, _G.BotManager3v3}) do
					if mgr and mgr.GetActiveBots then
						for bot, data in pairs(mgr.GetActiveBots()) do
							local botName = bot.Name or data.name
							if botName == attackerName or data.name == attackerName then
								attackerTeam = data.team
								break
							end
						end
					end
					if attackerTeam then break end
				end
			end
		end
		
		-- Nếu không phải bot, tìm team từ player object
		if not attackerTeam then
			local player = Players:FindFirstChild(attackerName)
			if player and player.Team then
				attackerTeam = player.Team.Name
			end
		end
		
		if attackerTeam then
			initPlayerStats(attackerName, attackerTeam)
		else
			warn("[MVP] Không tìm thấy team cho attacker: " .. attackerName .. " - SKIPPING")
			return
		end
	end
	
	playerStats[attackerName].baseDamage = playerStats[attackerName].baseDamage + damage
end

-- Kết thúc match và tính MVP
local function endMatch(winnerTeam)
	
	-- Debug: In tất cả playerStats
	for name, stats in pairs(playerStats) do
		print(string.format("[MVP]   %s: kills=%d, baseDamage=%d, team=%s",
			name, stats.kills, stats.baseDamage, tostring(stats.team)))
	end
	
	-- KIỂM TRA NẾU playerStats RỖNG - TẠO DUMMY DATA
	if not next(playerStats) then
		warn("[MVP] ⚠️ playerStats is EMPTY! Creating dummy data for testing...")
		-- Tạo dummy data để test UI
		playerStats = {
			["[BOT] Shadow1"] = {kills = 3, baseDamage = 100, team = winnerTeam or "Team1", isBot = true},
			["[BOT] Shadow2"] = {kills = 2, baseDamage = 50, team = winnerTeam == "Team1" and "Team2" or "Team1", isBot = true},
		}
	end
	
	local mvp = findMVP()
	local team1MVP, team2MVP = findTeamMVPs()
	
	-- Xác định MVP của team thắng và team thua
	local winnerMVP = nil
	local loserMVP = nil
	
	if winnerTeam == "Team1" then
		winnerMVP = team1MVP
		loserMVP = team2MVP
	elseif winnerTeam == "Team2" then
		winnerMVP = team2MVP
		loserMVP = team1MVP
	end
	
	
	-- KIỂM TRA NẾU KHÔNG CÓ MVP - TẠO DUMMY
	if not winnerMVP then
		warn("[MVP] ⚠️ No winnerMVP found! Creating dummy...")
		winnerMVP = {
			name = "[BOT] Winner",
			kills = 0,
			baseDamage = 0,
			team = winnerTeam or "Team1",
			isBot = true,
			score = 0
		}
	end
	
	if not loserMVP then
		warn("[MVP] ⚠️ No loserMVP found! Creating dummy...")
		loserMVP = {
			name = "[BOT] Loser",
			kills = 0,
			baseDamage = 0,
			team = winnerTeam == "Team1" and "Team2" or "Team1",
			isBot = true,
			score = 0
		}
	end
	
	-- Tạo dummy mvp nếu nil
	if not mvp then
		warn("[MVP] ⚠️ No mvp found! Creating dummy...")
		mvp = winnerMVP or {
			name = "[BOT] MVP",
			kills = 0,
			baseDamage = 0,
			team = winnerTeam or "Team1",
			isBot = true,
			score = 0
		}
	end
	
	print(string.format("[MVP] 🏆 MVP: %s (%s) | Kills: %d, Base Damage: %d, Score: %d",
		mvp.name, mvp.team, mvp.kills, mvp.baseDamage, mvp.score))
	
	-- Gửi MVP announcement cho tất cả players với format mới
	local playerCount = #Players:GetPlayers()
	
	if playerCount == 0 then
		warn("[MVP] ⚠️ No players online! MVP UI will not be displayed.")
	else
		for _, player in ipairs(Players:GetPlayers()) do
			MVPAnnouncement:FireClient(player, {
				winnerTeam = winnerTeam,
				winnerMVP = winnerMVP,
				loserMVP = loserMVP,
				mvp = mvp,
				team1MVP = team1MVP,
				team2MVP = team2MVP,
				allStats = playerStats
			})
		end
	end
	
	return mvp
end

-- Lấy stats hiện tại
local function getStats()
	return playerStats
end

-- ========== TEST FUNCTION ==========
local function testMVP()
	
	-- Tạo test data
	playerStats = {
		["TestPlayer1"] = {kills = 5, baseDamage = 250, team = "Team1", isBot = false},
		["TestPlayer2"] = {kills = 3, baseDamage = 150, team = "Team2", isBot = false},
		["[BOT] Shadow1"] = {kills = 2, baseDamage = 100, team = "Team1", isBot = true},
	}
	
	for name, stats in pairs(playerStats) do
	end
	
	local winnerTeam = "Team1"
	local mvp = findMVP()
	local team1MVP, team2MVP = findTeamMVPs()
	
	
	local winnerMVP = team1MVP
	local loserMVP = team2MVP
	
	
	local playerCount = #Players:GetPlayers()
	
	for _, player in ipairs(Players:GetPlayers()) do
		MVPAnnouncement:FireClient(player, {
			winnerTeam = winnerTeam,
			winnerMVP = winnerMVP,
			loserMVP = loserMVP,
			mvp = mvp,
			team1MVP = team1MVP,
			team2MVP = team2MVP,
			allStats = playerStats
		})
	end
	
	return "MVP test fired to " .. playerCount .. " players!"
end

-- ========== EXPORT TO _G ==========
local MVPSystem = {}

MVPSystem.StartMatch = startMatch
MVPSystem.RecordKill = recordKill
MVPSystem.RecordBaseDamage = recordBaseDamage
MVPSystem.EndMatch = endMatch
MVPSystem.GetStats = getStats
MVPSystem.FindMVP = findMVP
MVPSystem.TestMVP = testMVP
MVPSystem.InitPlayerStats = initPlayerStats -- Thêm hàm public để khởi tạo stats cho bot

_G.MVPSystem = MVPSystem


return MVPSystem
