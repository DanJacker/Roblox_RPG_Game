-- Win Condition Checker - Kiểm tra điều kiện thắng thua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[WinConditionChecker] Đang khởi động...")

-- Lưu trữ thông tin match hiện tại
local currentMatch = nil

-- Tạo RemoteEvent để thông báo kết quả
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local MatchEnded = remoteEvents:FindFirstChild("MatchEnded")
if not MatchEnded then
	MatchEnded = Instance.new("RemoteEvent")
	MatchEnded.Name = "MatchEnded"
	MatchEnded.Parent = remoteEvents
end

-- Kiểm tra team nào còn base
local function checkTeamBases(teamName)
	local IndividualBaseManager = _G.IndividualBaseManager
	if not IndividualBaseManager then
		return true -- Nếu không có IndividualBaseManager, giả sử team còn base
	end
	
	-- Lấy tất cả base data
	local allBases = {}
	for playerName, baseData in pairs(IndividualBaseManager.GetPlayerBaseData or {}) do
		if baseData.team == teamName and baseData.alive then
			return true -- Team còn ít nhất 1 base
		end
	end
	
	return false -- Team không còn base nào
end

-- Kiểm tra điều kiện thắng
local function checkWinCondition()
	if not currentMatch then return end
	
	local team1HasBases = checkTeamBases("Team1")
	local team2HasBases = checkTeamBases("Team2")
	
	-- Nếu Team1 hết base
	if not team1HasBases then
		print("[WinConditionChecker] Team2 thắng! Team1 đã mất hết base.")
		
		-- Thông báo cho tất cả players
		for _, player in ipairs(Players:GetPlayers()) do
			MatchEnded:FireClient(player, {
				reason = "base_destroyed",
				winner = "Team2",
				loser = "Team1",
				matchId = currentMatch.matchId
			})
		end
		
		-- Dừng timer
		if _G.StopMatchTimer then
			_G.StopMatchTimer(currentMatch.matchId)
		end
		
		currentMatch = nil
		return
	end
	
	-- Nếu Team2 hết base
	if not team2HasBases then
		print("[WinConditionChecker] Team1 thắng! Team2 đã mất hết base.")
		
		-- Thông báo cho tất cả players
		for _, player in ipairs(Players:GetPlayers()) do
			MatchEnded:FireClient(player, {
				reason = "base_destroyed",
				winner = "Team1",
				loser = "Team2",
				matchId = currentMatch.matchId
			})
		end
		
		-- Dừng timer
		if _G.StopMatchTimer then
			_G.StopMatchTimer(currentMatch.matchId)
		end
		
		currentMatch = nil
		return
	end
end

-- Lắng nghe khi base bị phá hủy
local function setupBaseDestructionListener()
	-- Lắng nghe khi có object bị xóa
	workspace.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("Model") and descendant.Name:find("_Base$") then
			-- Đợi một chút để IndividualBaseManager cập nhật
			task.wait(0.1)
			checkWinCondition()
		end
	end)
end

-- Khởi tạo match
local function initializeMatch(matchData)
	currentMatch = matchData
	print("[WinConditionChecker] Đã khởi tạo match: " .. matchData.matchId)
end

-- Public API
local WinConditionChecker = {}

function WinConditionChecker.InitializeMatch(matchData)
	initializeMatch(matchData)
end

function WinConditionChecker.CheckWinCondition()
	checkWinCondition()
end

-- Export to _G
_G.WinConditionChecker = WinConditionChecker

-- Khởi tạo
setupBaseDestructionListener()

print("[WinConditionChecker] Đã khởi động thành công!")

return WinConditionChecker