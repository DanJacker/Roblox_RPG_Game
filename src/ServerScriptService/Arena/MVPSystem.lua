-- MVP System - Tính toán và hiển thị MVP dựa trên Kills và Base Damage
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[MVP] ========== KHỞI TẠO MVP SYSTEM ==========")
print("[MVP] Đang khởi động...")

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
			isBot = playerName:find("%[BOT%]") ~= nil or playerName:find("%[MONSTER%]") ~= nil
		}
		print(string.format("[MVP] Initialized stats for: %s (team: %s, isBot: %s)", playerName, teamName or "Unknown", tostring(playerStats[playerName].isBot)))
	else
		print(string.format("[MVP] Stats already exists for: %s", playerName))
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
	print("[MVP] ========== START MATCH ==========")
	currentMatch = matchData
	playerStats = {}
	
	print("[MVP] StartMatch called with matchData:")
	print("[MVP]   mode: " .. tostring(matchData.mode))
	print("[MVP]   team1: " .. tostring(matchData.team1 and #matchData.team1 or 0) .. " players")
	print("[MVP]   team2: " .. tostring(matchData.team2 and #matchData.team2 or 0) .. " players")
	
	-- Khởi tạo stats cho tất cả players trong match
	if matchData.team1 then
		print("[MVP] Processing Team1...")
		for i, playerData in ipairs(matchData.team1) do
			print("[MVP] DEBUG team1[" .. i .. "]: " .. tostring(playerData))
			print("[MVP]   type: " .. type(playerData))
			if type(playerData) == "table" then
				print("[MVP]   name: " .. tostring(playerData.name))
				print("[MVP]   Name: " .. tostring(playerData.Name))
				print("[MVP]   playerId: " .. tostring(playerData.playerId))
				print("[MVP]   isBot: " .. tostring(playerData.isBot))
				
				-- Lấy name từ nhiều nguồn - SỬA: Bỏ điều kiện name ~= "Unknown"
				local name = playerData.name or playerData.Name or playerData.playerName
				if name and name ~= "" then
					initPlayerStats(name, "Team1")
					print("[MVP]   ✓ Team1 player initialized: " .. name)
				else
					-- Tạo tên mặc định nếu không có tên
					local defaultName = "Team1_Player" .. i
					initPlayerStats(defaultName, "Team1")
					warn("[MVP]   ⚠ Using default name for Team1 player " .. i .. ": " .. defaultName)
				end
			elseif type(playerData) == "string" then
				initPlayerStats(playerData, "Team1")
				print("[MVP]   ✓ Team1 player (string) initialized: " .. playerData)
			else
				warn("[MVP]   ✗ INVALID playerData type for Team1 player " .. i .. ": " .. type(playerData))
			end
		end
	else
		warn("[MVP] Team1 is NIL!")
	end
	
	if matchData.team2 then
		print("[MVP] Processing Team2...")
		for i, playerData in ipairs(matchData.team2) do
			print("[MVP] DEBUG team2[" .. i .. "]: " .. tostring(playerData))
			print("[MVP]   type: " .. type(playerData))
			if type(playerData) == "table" then
				print("[MVP]   name: " .. tostring(playerData.name))
				print("[MVP]   Name: " .. tostring(playerData.Name))
				print("[MVP]   playerId: " .. tostring(playerData.playerId))
				print("[MVP]   isBot: " .. tostring(playerData.isBot))
				
				-- Lấy name từ nhiều nguồn - SỬA: Bỏ điều kiện name ~= "Unknown"
				local name = playerData.name or playerData.Name or playerData.playerName
				if name and name ~= "" then
					initPlayerStats(name, "Team2")
					print("[MVP]   ✓ Team2 player initialized: " .. name)
				else
					-- Tạo tên mặc định nếu không có tên
					local defaultName = "Team2_Player" .. i
					initPlayerStats(defaultName, "Team2")
					warn("[MVP]   ⚠ Using default name for Team2 player " .. i .. ": " .. defaultName)
				end
			elseif type(playerData) == "string" then
				initPlayerStats(playerData, "Team2")
				print("[MVP]   ✓ Team2 player (string) initialized: " .. playerData)
			else
				warn("[MVP]   ✗ INVALID playerData type for Team2 player " .. i .. ": " .. type(playerData))
			end
		end
	else
		warn("[MVP] Team2 is NIL!")
	end
	
	-- In tổng kết
	print("[MVP] ========== INITIALIZATION SUMMARY ==========")
	print("[MVP] Total players in playerStats: " .. tostring(next(playerStats) and "not empty" or "EMPTY"))
	for name, stats in pairs(playerStats) do
		print(string.format("[MVP]   %s: team=%s, isBot=%s", name, tostring(stats.team), tostring(stats.isBot)))
	end
	print("[MVP] ===========================================")
	
	print("[MVP] Bắt đầu match: " .. (matchData.matchId or matchData.mode or "unknown"))
end

-- Ghi nhận kill
local function recordKill(killerName, victimName)
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
					print("[MVP] Found bot team: " .. killerName .. " -> " .. tostring(killerTeam))
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
								print("[MVP] Found bot team (mode-specific): " .. killerName .. " -> " .. tostring(killerTeam))
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
				print("[MVP] Found team from player object: " .. killerName .. " -> " .. killerTeam)
			end
		end
		
		if killerTeam then
			initPlayerStats(killerName, killerTeam)
			print("[MVP] Initialized stats for: " .. killerName .. " (team: " .. killerTeam .. ")")
		else
			warn("[MVP] Không tìm thấy team cho killer: " .. killerName .. " - SKIPPING")
			return
		end
	end
	
	playerStats[killerName].kills = playerStats[killerName].kills + 1
	print(string.format("[MVP] %s killed %s | Kills: %d", killerName, victimName, playerStats[killerName].kills))
end

-- Ghi nhận base damage
local function recordBaseDamage(attackerName, damage)
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
					print("[MVP] Found bot team: " .. attackerName .. " -> " .. tostring(attackerTeam))
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
								print("[MVP] Found bot team (mode-specific): " .. attackerName .. " -> " .. tostring(attackerTeam))
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
				print("[MVP] Found team from player object: " .. attackerName .. " -> " .. attackerTeam)
			end
		end
		
		if attackerTeam then
			initPlayerStats(attackerName, attackerTeam)
			print("[MVP] Initialized stats for: " .. attackerName .. " (team: " .. attackerTeam .. ")")
		else
			warn("[MVP] Không tìm thấy team cho attacker: " .. attackerName .. " - SKIPPING")
			return
		end
	end
	
	playerStats[attackerName].baseDamage = playerStats[attackerName].baseDamage + damage
	print(string.format("[MVP] %s gây %d damage | Total: %d", attackerName, damage, playerStats[attackerName].baseDamage))
end

-- Kết thúc match và tính MVP
local function endMatch(winnerTeam)
	print("[MVP] ========== END MATCH ==========")
	print("[MVP] winnerTeam: " .. tostring(winnerTeam))
	print("[MVP] playerStats count: " .. tostring(next(playerStats) and "not empty" or "EMPTY"))
	
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
		print("[MVP] Created dummy data for testing")
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
	
	print("[MVP] winnerMVP: " .. (winnerMVP and winnerMVP.name or "nil"))
	print("[MVP] loserMVP: " .. (loserMVP and loserMVP.name or "nil"))
	
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
	print("[MVP] Players online: " .. playerCount)
	
	if playerCount == 0 then
		warn("[MVP] ⚠️ No players online! MVP UI will not be displayed.")
	else
		for _, player in ipairs(Players:GetPlayers()) do
			print("[MVP] Firing MVPAnnouncement to: " .. player.Name)
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
		print("[MVP] Đã gửi MVPAnnouncement cho " .. playerCount .. " players")
	end
	
	print("[MVP] ========== END END MATCH ==========")
	return mvp
end

-- Lấy stats hiện tại
local function getStats()
	return playerStats
end

-- ========== TEST FUNCTION ==========
local function testMVP()
	print("[MVP TEST] ========== BẮT ĐẦU TEST MVP ==========")
	
	-- Tạo test data
	playerStats = {
		["TestPlayer1"] = {kills = 5, baseDamage = 250, team = "Team1", isBot = false},
		["TestPlayer2"] = {kills = 3, baseDamage = 150, team = "Team2", isBot = false},
		["[BOT] Shadow1"] = {kills = 2, baseDamage = 100, team = "Team1", isBot = true},
	}
	
	print("[MVP TEST] playerStats created:")
	for name, stats in pairs(playerStats) do
		print(string.format("  %s: kills=%d, baseDamage=%d, team=%s", name, stats.kills, stats.baseDamage, stats.team))
	end
	
	local winnerTeam = "Team1"
	local mvp = findMVP()
	local team1MVP, team2MVP = findTeamMVPs()
	
	print("[MVP TEST] MVP found: " .. (mvp and mvp.name or "nil"))
	print("[MVP TEST] Team1 MVP: " .. (team1MVP and team1MVP.name or "nil"))
	print("[MVP TEST] Team2 MVP: " .. (team2MVP and team2MVP.name or "nil"))
	
	local winnerMVP = team1MVP
	local loserMVP = team2MVP
	
	print("[MVP TEST] Firing MVPAnnouncement to all players...")
	print("[MVP TEST] Winner: " .. (winnerMVP and winnerMVP.name or "N/A"))
	print("[MVP TEST] Loser: " .. (loserMVP and loserMVP.name or "N/A"))
	
	local playerCount = #Players:GetPlayers()
	print("[MVP TEST] Players online: " .. playerCount)
	
	for _, player in ipairs(Players:GetPlayers()) do
		print("[MVP TEST] Firing to: " .. player.Name)
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
	
	print("[MVP TEST] ========== KẾT THÚC TEST MVP ==========")
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

print("[MVP] Đã khởi động thành công!")
print("[MVP] Để test MVP display, chạy: _G.MVPSystem.TestMVP()")

return MVPSystem