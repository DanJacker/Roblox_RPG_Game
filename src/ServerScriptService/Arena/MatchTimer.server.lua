-- Match Timer - Đếm thời gian trận đấu
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tạo hoặc lấy RemoteEvents
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
    remoteEvents = Instance.new("Folder")
    remoteEvents.Name = "RemoteEvents"
    remoteEvents.Parent = ReplicatedStorage
end

-- Tạo MatchTimer nếu chưa có
local MatchTimer = remoteEvents:FindFirstChild("MatchTimer")
if not MatchTimer then
    MatchTimer = Instance.new("RemoteEvent")
    MatchTimer.Name = "MatchTimer"
    MatchTimer.Parent = remoteEvents
end

-- Tạo MatchEnded nếu chưa có
local MatchEnded = remoteEvents:FindFirstChild("MatchEnded")
if not MatchEnded then
    MatchEnded = Instance.new("RemoteEvent")
    MatchEnded.Name = "MatchEnded"
    MatchEnded.Parent = remoteEvents
end

-- Lưu trữ các timer đang chạy
local activeTimers = {}

-- Thời gian trận đấu (10 phút cho tất cả chế độ)
local MATCH_DURATION = 600 -- 10 phút

-- Hàm đếm số base còn lại của mỗi team
local function countBasesByTeam(teamName)
	local count = 0
	local totalHealth = 0
	
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base") then
			-- Kiểm tra base còn sống
			local humanoid = obj:FindFirstChild("BaseHumanoid")
			if humanoid and humanoid.Health > 0 then
				count = count + 1
				totalHealth = totalHealth + humanoid.Health
			end
		end
	end
	
	return count, totalHealth
end

-- Hàm tính winner khi hết thời gian
local function calculateWinnerByScore()
	local team1Bases, team1Health = countBasesByTeam("Team1")
	local team2Bases, team2Health = countBasesByTeam("Team2")
	
	-- Lấy số kills từ GameManager
	local team1Kills = _G.Team1Kills or 0
	local team2Kills = _G.Team2Kills or 0
	
	print(string.format("[MatchTimer] Điểm số - Team1: %d bases, %d HP, %d kills | Team2: %d bases, %d HP, %d kills",
		team1Bases, team1Health, team1Kills, team2Bases, team2Health, team2Kills))
	
	-- 1. So sánh số base
	if team1Bases > team2Bases then
		return "Team1", "MORE_BASES"
	elseif team2Bases > team1Bases then
		return "Team2", "MORE_BASES"
	end
	
	-- 2. Số base bằng nhau, so sánh tổng HP
	if team1Health > team2Health then
		return "Team1", "MORE_HP"
	elseif team2Health > team1Health then
		return "Team2", "MORE_HP"
	end
	
	-- 3. HP bằng nhau, so sánh số kills
	if team1Kills > team2Kills then
		return "Team1", "MORE_KILLS"
	elseif team2Kills > team1Kills then
		return "Team2", "MORE_KILLS"
	end
	
	-- 4. Hoàn toàn bằng nhau - hòa
	return "DRAW", "EQUAL"
end

-- Hàm bắt đầu đếm thời gian
local function startMatchTimer(matchId, matchData)
	if activeTimers[matchId] then return end
	
	-- Reset kill count
	_G.Team1Kills = 0
	_G.Team2Kills = 0
	
	
	activeTimers[matchId] = {
		startTime = tick(),
		duration = MATCH_DURATION,
		players = matchData.players,
		mode = matchData.mode
	}
	
	-- Bắt đầu loop cập nhật timer
	task.spawn(function()
		while activeTimers[matchId] do
			local timerData = activeTimers[matchId]
			local elapsed = tick() - timerData.startTime
			local remaining = math.max(0, timerData.duration - elapsed)
			
			-- Kiểm tra spawn Elite Boss (nửa sau trận)
			local BossManager = _G.BossManager
			if BossManager and not BossManager.IsBossSpawned() then
				BossManager.CheckSpawn(elapsed, timerData.duration)
			end
			
			-- Cập nhật cho tất cả players
			for _, playerId in ipairs(timerData.players) do
				local player = Players:GetPlayerByUserId(playerId)
				if player then
					MatchTimer:FireClient(player, {
						action = "update",
						matchId = matchId,
						elapsed = elapsed,
						remaining = remaining,
						duration = timerData.duration
					})
				end
			end
			
			-- Kiểm tra hết thời gian
			if remaining <= 0 then
				
				-- Tính winner theo điểm số
				local winner, reason = calculateWinnerByScore()
				
				
				-- Thông báo kết quả
				for _, playerId in ipairs(timerData.players) do
					local player = Players:GetPlayerByUserId(playerId)
					if player then
						MatchEnded:FireClient(player, {
							reason = "timeout",
							matchId = matchId,
							winner = winner,
							winReason = reason
						})
						
						-- Gửi win event
						local winEvent = ReplicatedStorage:FindFirstChild("WinEvent")
						if winEvent and winner ~= "DRAW" then
							winEvent:FireClient(player, winner, _G.Team1Kills or 0, _G.Team2Kills or 0)
						end
					end
				end
				
				-- Kết thúc match
				if _G.EndMatch then
					_G.EndMatch(matchId, winner .. "_WINS_BY_" .. reason)
				end
				
				activeTimers[matchId] = nil
				break
			end
			
			task.wait(1)
		end
	end)
end

-- Hàm dừng đếm thời gian
local function stopMatchTimer(matchId)
	if activeTimers[matchId] then
		activeTimers[matchId] = nil
	end
end

-- Export functions
_G.StartMatchTimer = startMatchTimer
_G.StopMatchTimer = stopMatchTimer

