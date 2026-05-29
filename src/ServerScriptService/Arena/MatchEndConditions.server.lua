-- Match End Conditions - Kết thúc trận đấu dựa trên metric
-- Metric: Sát thương lên Nhà chính, Số hạ gục (kills)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[MatchEndConditions] Đang khởi động...")

-- ========== CẤU HÌNH ==========
-- Load config từ module
local success, MatchEndConfig = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MatchEndConfig"))
end)

local CONFIG = success and MatchEndConfig or {
	-- Fallback config nếu không load được module
	KILLS_TO_WIN = 10,
	BASE_DAMAGE_TO_WIN = 1000,
	MAX_MATCH_DURATION = 300,
	END_MATCH_DELAY = 3,
}

-- ========== BIẾN LƯU TRỮ ==========
-- Thống kê trận đấu hiện tại
local matchStats = {
	isActive = false,
	matchId = nil,
	startTime = 0,
	
	-- Kills theo team
	teamKills = {
		Team1 = 0,
		Team2 = 0
	},
	
	-- Sát thương lên base theo team (tổng damage đã gây)
	teamBaseDamage = {
		Team1 = 0,  -- Sát thương Team1 gây lên base Team2
		Team2 = 0   -- Sát thương Team2 gây lên base Team1
	},
	
	-- Chi tiết kills của từng player
	playerKills = {},
	playerDeaths = {},
}

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

local MatchStatsUpdate = getOrCreateRemoteEvent("MatchStatsUpdate")
local MatchEnded = getOrCreateRemoteEvent("MatchEnded")

-- ========== HÀM HELPER ==========

-- Gửi cập nhật thống kê cho tất cả players
local function broadcastStats()
	local stats = {
		teamKills = matchStats.teamKills,
		teamBaseDamage = matchStats.teamBaseDamage,
		elapsedTime = tick() - matchStats.startTime
	}
	
	for _, player in ipairs(Players:GetPlayers()) do
		MatchStatsUpdate:FireClient(player, stats)
	end
end

-- Kiểm tra điều kiện thắng
local function checkWinCondition()
	if not matchStats.isActive then return end
	
	-- Kiểm tra kills
	if CONFIG.KILLS_TO_WIN > 0 then
		if matchStats.teamKills.Team1 >= CONFIG.KILLS_TO_WIN then
			return "Team1", "kills"
		elseif matchStats.teamKills.Team2 >= CONFIG.KILLS_TO_WIN then
			return "Team2", "kills"
		end
	end
	
	-- Kiểm tra sát thương base
	if CONFIG.BASE_DAMAGE_TO_WIN > 0 then
		if matchStats.teamBaseDamage.Team1 >= CONFIG.BASE_DAMAGE_TO_WIN then
			return "Team1", "base_damage"
		elseif matchStats.teamBaseDamage.Team2 >= CONFIG.BASE_DAMAGE_TO_WIN then
			return "Team2", "base_damage"
		end
	end
	
	-- Kiểm tra thời gian
	local elapsed = tick() - matchStats.startTime
	if elapsed >= CONFIG.MAX_MATCH_DURATION then
		-- Team có nhiều kills hơn thắng
		if matchStats.teamKills.Team1 > matchStats.teamKills.Team2 then
			return "Team1", "time"
		elseif matchStats.teamKills.Team2 > matchStats.teamKills.Team1 then
			return "Team2", "time"
		else
			-- Hòa - kiểm tra sát thương base
			if matchStats.teamBaseDamage.Team1 > matchStats.teamBaseDamage.Team2 then
				return "Team1", "time_tiebreak"
			elseif matchStats.teamBaseDamage.Team2 > matchStats.teamBaseDamage.Team1 then
				return "Team2", "time_tiebreak"
			else
				return nil, "draw"  -- Hòa thực sự
			end
		end
	end
	
	return nil, nil
end

-- Kết thúc trận đấu
local function endMatch(winner, reason)
	if not matchStats.isActive then return end
	
	print(string.format("[MatchEndConditions] Kết thúc trận đấu! Winner: %s, Reason: %s", winner or "Draw", reason))
	
	matchStats.isActive = false
	
	-- Chuẩn bị dữ liệu kết quả
	local resultData = {
		winner = winner,
		reason = reason,
		matchId = matchStats.matchId,
		stats = {
			teamKills = matchStats.teamKills,
			teamBaseDamage = matchStats.teamBaseDamage,
			playerKills = matchStats.playerKills,
			playerDeaths = matchStats.playerDeaths,
			duration = tick() - matchStats.startTime
		}
	}
	
	-- Thông báo cho tất cả players
	for _, player in ipairs(Players:GetPlayers()) do
		MatchEnded:FireClient(player, resultData)
	end
	
	-- KHÔNG gọi MVPSystem ở đây nữa
	-- MatchManager sẽ gọi MVPSystem sau khi Victory/Lost UI hiển thị xong
	print("[MatchEndConditions] Bỏ qua MVPSystem.EndMatch - sẽ được gọi bởi MatchManager sau Victory/Lost UI")
	
	-- Gọi EndMatch từ MatchManager ngay lập tức
	-- MatchManager sẽ xử lý việc hiển thị Victory/Lost UI trước (10s), rồi MVP UI
	if _G.EndMatch then
		_G.EndMatch(matchStats.matchId, winner and (winner .. "_wins_" .. reason) or "draw")
	end
end

-- ========== HÀM PUBLIC API ==========

-- Bắt đầu trận đấu mới
local function startMatch(matchId)
	matchStats = {
		isActive = true,
		matchId = matchId,
		startTime = tick(),
		teamKills = {Team1 = 0, Team2 = 0},
		teamBaseDamage = {Team1 = 0, Team2 = 0},
		playerKills = {},
		playerDeaths = {},
	}
	
	print("[MatchEndConditions] Bắt đầu trận đấu: " .. matchId)
	broadcastStats()
end

-- Ghi nhận kill (hỗ trợ cả player và bot)
local function recordKill(killerPlayer, victimPlayer)
	if not matchStats.isActive then return end
	
	-- Lấy team của killer (player hoặc bot)
	local killerTeam = nil
	local killerName = "Unknown"
	local victimName = "Unknown"
	
	-- Xử lý killer
	if type(killerPlayer) == "userdata" then
		-- Là Player object
		killerTeam = killerPlayer.Team and killerPlayer.Team.Name
		killerName = killerPlayer.Name
	elseif type(killerPlayer) == "table" then
		-- Là bot data
		killerTeam = killerPlayer.team
		killerName = killerPlayer.name or "[BOT]"
	elseif type(killerPlayer) == "string" then
		-- Là tên (có thể là bot)
		killerName = killerPlayer
		
		-- Tìm team từ BotManager
		local BotManager = _G.BotManager
		if BotManager then
			for bot, data in pairs(BotManager.GetActiveBots()) do
				if data.name == killerPlayer or bot.Name == killerPlayer then
					killerTeam = data.team
					print("[MatchEndConditions] Tìm thấy bot " .. killerPlayer .. " trong team " .. tostring(killerTeam))
					break
				end
			end
		end
		
		-- Nếu vẫn không tìm thấy, thử parse từ tên bot
		if not killerTeam and killerPlayer:find("%[BOT%]") then
			-- Bot name format: [BOT] Shadow1
			-- Cần tìm trong activeBots
			if BotManager then
				for bot, data in pairs(BotManager.GetActiveBots()) do
					if bot.Name == killerPlayer then
						killerTeam = data.team
						break
					end
				end
			end
		end
	end
	
	-- Xử lý victim
	if type(victimPlayer) == "userdata" then
		victimName = victimPlayer.Name
	elseif type(victimPlayer) == "table" then
		victimName = victimPlayer.name or "[BOT]"
	elseif type(victimPlayer) == "string" then
		victimName = victimPlayer
	end
	
	if not killerTeam then 
		print("[MatchEndConditions] Không tìm thấy team cho killer: " .. killerName)
		return 
	end
	
	-- Tăng kills cho team
	matchStats.teamKills[killerTeam] = matchStats.teamKills[killerTeam] + 1
	
	-- Tăng kills cho player (nếu là player)
	if type(killerPlayer) == "userdata" and killerPlayer.UserId then
		matchStats.playerKills[killerPlayer.UserId] = (matchStats.playerKills[killerPlayer.UserId] or 0) + 1
	end
	
	-- Tăng deaths cho victim (nếu là player)
	if type(victimPlayer) == "userdata" and victimPlayer.UserId then
		matchStats.playerDeaths[victimPlayer.UserId] = (matchStats.playerDeaths[victimPlayer.UserId] or 0) + 1
	end
	
	print(string.format("[MatchEndConditions] %s (%s) killed %s | Team kills: %d-%d",
		killerName, killerTeam, victimName,
		matchStats.teamKills.Team1, matchStats.teamKills.Team2))
	
	-- Gửi KillEvent cho UI
	local KillEvent = ReplicatedStorage:FindFirstChild("KillEvent")
	if KillEvent then
		KillEvent:FireAllClients(matchStats.teamKills.Team1, matchStats.teamKills.Team2)
	end
	
	broadcastStats()
	
	-- Kiểm tra điều kiện thắng
	local winner, reason = checkWinCondition()
	if winner then
		endMatch(winner, reason)
	end
end

-- Ghi nhận sát thương lên base
local function recordBaseDamage(attackerTeam, damage)
	if not matchStats.isActive then return end
	
	-- Sát thương mà team tấn công gây lên base đối phương
	matchStats.teamBaseDamage[attackerTeam] = matchStats.teamBaseDamage[attackerTeam] + damage
	
	print(string.format("[MatchEndConditions] %s gây %d damage lên base đối phương | Total: %d-%d",
		attackerTeam, damage,
		matchStats.teamBaseDamage.Team1, matchStats.teamBaseDamage.Team2))
	
	broadcastStats()
	
	-- Kiểm tra điều kiện thắng
	local winner, reason = checkWinCondition()
	if winner then
		endMatch(winner, reason)
	end
end

-- Lấy thống kê hiện tại
local function getStats()
	return {
		teamKills = matchStats.teamKills,
		teamBaseDamage = matchStats.teamBaseDamage,
		playerKills = matchStats.playerKills,
		playerDeaths = matchStats.playerDeaths,
		elapsedTime = matchStats.isActive and (tick() - matchStats.startTime) or 0
	}
end

-- ========== EXPORT TO _G ==========
local MatchEndConditions = {}

MatchEndConditions.StartMatch = startMatch
MatchEndConditions.RecordKill = recordKill
MatchEndConditions.RecordBaseDamage = recordBaseDamage
MatchEndConditions.GetStats = getStats
MatchEndConditions.CheckWinCondition = checkWinCondition
MatchEndConditions.EndMatch = endMatch

_G.MatchEndConditions = MatchEndConditions

-- ========== TÍCH HỢP VỚI HỆ THỐNG HIỆN TẠI ==========

-- Hook vào CombatSystem để theo dõi kills
local function hookCombatSystem()
	-- Lắng nghe event PlayerKilled từ CombatSystem
	local combatEvent = ReplicatedStorage:FindFirstChild("CombatEvent")
	if combatEvent then
		combatEvent.OnServerEvent:Connect(function(player, data)
			if data.event == "PlayerKilled" then
				-- Tìm killer và victim
				local killerName = data.killer
				local victimName = data.victim
				
				local killer = Players:FindFirstChild(killerName)
				local victim = Players:FindFirstChild(victimName)
				
				if killer and victim then
					recordKill(killer, victim)
				end
			end
		end)
		print("[MatchEndConditions] Đã hook vào CombatEvent")
	end
end

-- Hook vào BaseDamageSystem để theo dõi sát thương base
local function hookBaseDamageSystem()
	-- Lắng nghe khi base bị đánh
	-- BaseDamageSystem sẽ gọi RecordBaseDamage khi có sát thương
	print("[MatchEndConditions] Sẵn sàng nhận base damage từ BaseDamageSystem")
end

-- ========== KHỞI TẠO ==========
hookCombatSystem()
hookBaseDamageSystem()

print("[MatchEndConditions] Đã khởi động thành công!")
print(string.format("[MatchEndConditions] Cấu hình: Kills để thắng = %d, Base damage để thắng = %d",
	CONFIG.KILLS_TO_WIN, CONFIG.BASE_DAMAGE_TO_WIN))

return MatchEndConditions