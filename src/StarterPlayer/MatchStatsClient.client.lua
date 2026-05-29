-- Match Stats Client - Hiển thị thống kê trận đấu
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Đợi GUI được tạo
local screenGui = playerGui:WaitForChild("MatchStatsGui", 5)
if not screenGui then
	warn("[MatchStatsClient] Không tìm thấy MatchStatsGui")
	return
end

local mainFrame = screenGui:FindFirstChild("MainFrame")
if not mainFrame then return end

local timerLabel = mainFrame:FindFirstChild("TimerLabel")
local team1Frame = mainFrame:FindFirstChild("TeamsContainer"):FindFirstChild("Team1Frame")
local team2Frame = mainFrame:FindFirstChild("TeamsContainer"):FindFirstChild("Team2Frame")

-- Ẩn GUI ban đầu
mainFrame.Visible = false

-- ========== REMOTE EVENTS ==========
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then return end

local MatchStatsUpdate = remoteEvents:FindFirstChild("MatchStatsUpdate")
local MatchEnded = remoteEvents:FindFirstChild("MatchEnded")
local MatchStart = remoteEvents:FindFirstChild("MatchStart")
local MatchTimer = remoteEvents:FindFirstChild("MatchTimer")

-- ========== BIẾN THEO DÕI ==========
local currentTeam1Kills = 0
local currentTeam2Kills = 0

-- ========== HÀM FORMAT THỜI GIAN ==========
local function formatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

-- ========== HÀM CẬP NHẬT GUI ==========
local function updateStats(stats)
	if not stats then return end
	
	-- Cập nhật kills
	if team1Frame then
		local killsLabel = team1Frame:FindFirstChild("KillsLabel")
		if killsLabel then
			currentTeam1Kills = stats.teamKills and stats.teamKills.Team1 or 0
			killsLabel.Text = string.format("🗡️ Team 1: %d kills", currentTeam1Kills)
		end
	end
	
	if team2Frame then
		local killsLabel = team2Frame:FindFirstChild("KillsLabel")
		if killsLabel then
			currentTeam2Kills = stats.teamKills and stats.teamKills.Team2 or 0
			killsLabel.Text = string.format("🗡️ Team 2: %d kills", currentTeam2Kills)
		end
	end
end

-- Cập nhật timer
local function updateTimer(data)
	if not timerLabel then return end
	if not data or not data.remaining then return end
	
	local remaining = data.remaining
	timerLabel.Text = "⏱️ " .. formatTime(remaining)
	
	-- Đổi màu khi còn ít thời gian
	if remaining <= 60 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Đỏ khi < 1 phút
	elseif remaining <= 180 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Vàng khi < 3 phút
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Trắng bình thường
	end
end

-- ========== EVENT HANDLERS ==========

-- Khi nhận cập nhật thống kê
if MatchStatsUpdate then
	MatchStatsUpdate.OnClientEvent:Connect(function(stats)
		updateStats(stats)
	end)
end

-- Khi nhận cập nhật timer
if MatchTimer then
	MatchTimer.OnClientEvent:Connect(function(data)
		if data.action == "update" then
			updateTimer(data)
		end
	end)
end

-- Khi trận đấu bắt đầu
if MatchStart then
	MatchStart.OnClientEvent:Connect(function(matchData)
		print("[MatchStatsClient] Trận đấu bắt đầu!")
		mainFrame.Visible = true
		
		-- Reset thống kê
		currentTeam1Kills = 0
		currentTeam2Kills = 0
		updateStats({
			teamKills = {Team1 = 0, Team2 = 0},
			teamBaseDamage = {Team1 = 0, Team2 = 0}
		})
		
		-- Reset timer
		if timerLabel then
			timerLabel.Text = "⏱️ 10:00"
			timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		
		-- Animation hiện GUI
		mainFrame.Position = UDim2.new(0.5, -200, 0, -100)
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			Position = UDim2.new(0.5, -200, 0, 10)
		})
		tween:Play()
	end)
end

-- Khi trận đấu kết thúc
if MatchEnded then
	MatchEnded.OnClientEvent:Connect(function(resultData)
		print("[MatchStatsClient] Trận đấu kết thúc!")
		
		-- Hiển thị kết quả cuối cùng
		if resultData.stats then
			updateStats(resultData.stats)
		end
		
		-- Hiển thị thời gian kết thúc
		if timerLabel then
			timerLabel.Text = "⏱️ 00:00"
			timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		end
		
		-- Ẩn GUI sau 5 giây
		task.delay(5, function()
			local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
				Position = UDim2.new(0.5, -200, 0, -100)
			})
			tween:Play()
			tween.Completed:Connect(function()
				mainFrame.Visible = false
			end)
		end)
	end)
end

print("[MatchStatsClient] Đã khởi động thành công!")
