-- MatchEndHandler - Xử lý kết thúc match và gọi UI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- Đợi MVPSystem sẵn sàng
local maxWait = 10
local waited = 0
while not (_G.MVPSystem and _G.MVPSystem.EndMatch) and waited < maxWait do
	task.wait(0.5)
	waited = waited + 0.5
end

if _G.MVPSystem and _G.MVPSystem.EndMatch then
else
	warn("[MatchEndHandler] ⚠️ MVPSystem KHÔNG sẵn sàng sau " .. maxWait .. "s!")
end

-- ========== REMOTE EVENTS ==========
-- Tạo hoặc lấy RemoteEvents folder
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

-- Tạo hoặc lấy VictoryAnnouncement
local VictoryAnnouncement = remoteEvents:FindFirstChild("VictoryAnnouncement")
if not VictoryAnnouncement then
	VictoryAnnouncement = Instance.new("RemoteEvent")
	VictoryAnnouncement.Name = "VictoryAnnouncement"
	VictoryAnnouncement.Parent = remoteEvents
end

-- Tạo hoặc lấy MVPAnnouncement
local MVPAnnouncement = remoteEvents:FindFirstChild("MVPAnnouncement")
if not MVPAnnouncement then
	MVPAnnouncement = Instance.new("RemoteEvent")
	MVPAnnouncement.Name = "MVPAnnouncement"
	MVPAnnouncement.Parent = remoteEvents
end

-- ========== BIẾN LƯU TRỮ ==========
local currentMatch = nil
local playerTeams = {} -- {player = teamName}

-- ========== PUBLIC API ==========

-- Bắt đầu match
local function startMatch(matchData)
	currentMatch = matchData
	
	-- Lưu team của player
	if matchData.team1 then
		for _, playerData in ipairs(matchData.team1) do
			local player = type(playerData) == "userdata" and playerData or Players:FindFirstChild(playerData.name or playerData.Name)
			if player then
				playerTeams[player] = "Team1"
			end
		end
	end
	
	if matchData.team2 then
		for _, playerData in ipairs(matchData.team2) do
			local player = type(playerData) == "userdata" and playerData or Players:FindFirstChild(playerData.name or playerData.Name)
			if player then
				playerTeams[player] = "Team2"
			end
		end
	end
end

-- Kết thúc match
local function endMatch(winnerTeam, reason)
	
	-- Gọi Victory/Lost UI cho tất cả players
	for _, player in ipairs(Players:GetPlayers()) do
		-- Lấy team trực tiếp từ player.Team
		local playerTeam = player.Team and player.Team.Name
		
		-- Fallback: Tìm trong playerTeams nếu không có team
		if not playerTeam then
			playerTeam = playerTeams[player]
		end
		
		
		if playerTeam == winnerTeam then
			-- Player thắng
			VictoryAnnouncement:FireClient(player, {
				winnerTeam = winnerTeam,
				playerTeam = playerTeam,
				reason = reason,
				isWinner = true
			})
		else
			-- Player thua
			VictoryAnnouncement:FireClient(player, {
				winnerTeam = winnerTeam,
				playerTeam = playerTeam,
				reason = reason,
				isWinner = false
			})
		end
	end
	
	-- Đợi 1 giây để client sẵn sàng nhận MVP event
	task.delay(1, function()
		
		-- Gọi MVPSystem.EndMatch để tính MVP thực tế
		if _G.MVPSystem and _G.MVPSystem.EndMatch then
			_G.MVPSystem.EndMatch(winnerTeam)
		else
		warn("[MatchEndHandler] MVPSystem.EndMatch not available! Using fallback data")
		
		-- Fallback: Tạo test MVP data
		local mvpData = {
			winnerTeam = winnerTeam,
			winnerMVP = {
				name = "TestPlayer1",
				kills = 5,
				baseDamage = 250,
				team = winnerTeam,
				score = 750
			},
			loserMVP = {
				name = "TestPlayer2",
				kills = 3,
				baseDamage = 150,
				team = winnerTeam == "Team1" and "Team2" or "Team1",
				score = 450
			}
		}
		
		for _, player in ipairs(Players:GetPlayers()) do
			MVPAnnouncement:FireClient(player, mvpData)
		end
		end
	end)
	
	-- Sau 13 giây, cleanup (để player có thời gian xem MVP)
	task.delay(13, function()
		currentMatch = nil
		playerTeams = {}
	end)
end

-- ========== EXPORT ==========
_G.MatchEndHandler = {
	StartMatch = startMatch,
	EndMatch = endMatch
}

