-- Respawn Client - Hiển thị bộ đếm thời gian hồi sinh
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Lấy GUI
local respawnGui = PlayerGui:WaitForChild("RespawnGui")
local mainFrame = respawnGui:WaitForChild("MainFrame")
local countdownLabel = mainFrame:WaitForChild("CountdownLabel")
local deathCountLabel = mainFrame:WaitForChild("DeathCountLabel")

-- Lấy RespawnEvent
local respawnEvent = ReplicatedStorage:WaitForChild("RespawnEvent")

-- Biến theo dõi
local isCountingDown = false
local currentCountdown = 0

-- Hàm cập nhật countdown
local function startCountdown(respawnTime, deathCount)
	if isCountingDown then return end
	
	isCountingDown = true
	currentCountdown = respawnTime
	mainFrame.Visible = true
	deathCountLabel.Text = "Lần chết: " .. tostring(deathCount)
	
	-- Countdown loop
	task.spawn(function()
		while currentCountdown > 0 and isCountingDown do
			countdownLabel.Text = "Hồi sinh sau: " .. tostring(currentCountdown) .. "s"
			
			-- Đổi màu theo thời gian còn lại
			if currentCountdown <= 3 then
				countdownLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Đỏ
			elseif currentCountdown <= 6 then
				countdownLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Cam
			else
				countdownLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Xanh lá
			end
			
			task.wait(1)
			currentCountdown = currentCountdown - 1
		end
		
		-- Ẩn GUI khi xong
		mainFrame.Visible = false
		isCountingDown = false
	end)
end

-- Lắng nghe sự kiện chết
respawnEvent.OnClientEvent:Connect(function(data)
	if data.event == "PlayerDied" then
		startCountdown(data.respawnTime, data.deathCount)
	elseif data.event == "PlayerRespawned" then
		isCountingDown = false
		mainFrame.Visible = false
	end
end)

