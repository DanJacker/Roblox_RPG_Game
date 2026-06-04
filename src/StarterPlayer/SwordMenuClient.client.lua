-- Sword Menu Client - Xử lý menu chọn chế độ chơi + Spawn nhà khi vào trận
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Đợi PlayerGui sẵn sàng
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui", 10)

if not PlayerGui then
    warn("[SwordMenuClient] PlayerGui không tìm thấy sau 10 giây!")
    return
end

print("[SwordMenuClient] Loaded. PlayerGui ready for", player.Name)


-- RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
    warn("[SwordMenuClient] RemoteEvents không tìm thấy!")
    return
end

print("[SwordMenuClient] RemoteEvents found in ReplicatedStorage")

local JoinQueue = remoteEvents:WaitForChild("JoinQueue", 5)
local LeaveQueue = remoteEvents:WaitForChild("LeaveQueue", 5)
local MatchFound = remoteEvents:WaitForChild("MatchFound", 5)
local QueueStatus = remoteEvents:WaitForChild("QueueStatus", 5)
local MatchStart = remoteEvents:WaitForChild("MatchStart", 5)
local MatchEnded = remoteEvents:WaitForChild("MatchEnded", 5)

if not JoinQueue or not LeaveQueue or not MatchFound or not QueueStatus or not MatchStart or not MatchEnded then
    warn("[SwordMenuClient] Một hoặc nhiều RemoteEvent không tìm thấy!")
    return
end


-- Đợi GUI load
local swordMenuGui = PlayerGui:WaitForChild("SwordMenuGui", 10)
if not swordMenuGui then
    warn("[SwordMenuClient] SwordMenuGui không tìm thấy!")
    return
end

local swordButton = swordMenuGui:WaitForChild("SwordButton", 5)
local menuFrame = swordMenuGui:WaitForChild("MenuFrame", 5)

if not swordButton or not menuFrame then
    warn("[SwordMenuClient] SwordButton hoặc MenuFrame không tìm thấy!")
    return
end


-- Lấy các button trong menu
local button1v1 = menuFrame:WaitForChild("Button1v1")
local button2v2 = menuFrame:WaitForChild("Button2v2")
local button3v3 = menuFrame:WaitForChild("Button3v3")

-- Trạng thái menu và queue
local isMenuOpen = false
local currentQueue = nil
local queueJoinTime = nil
local queueTimeout = 60
local attempts = 1
local isTimerRunning = false
local isInMatch = false -- Track if player is in a match

-- UI Queue Status
local queueStatusFrame = swordMenuGui:WaitForChild("QueueStatusFrame")
local modeLabel = queueStatusFrame:WaitForChild("ModeLabel")
local timerLabel = queueStatusFrame:WaitForChild("TimerLabel")
local playersLabel = queueStatusFrame:WaitForChild("PlayersCountLabel")
local playersListLabel = queueStatusFrame:WaitForChild("PlayersListLabel")
local cancelButton = queueStatusFrame:WaitForChild("CancelButton")

-- Hàm ẩn/hiện SwordMenu GUI
local function hideSwordMenu()
	isInMatch = true
	swordButton.Visible = false
	menuFrame.Visible = false
	queueStatusFrame.Visible = false
	isMenuOpen = false
end

local function showSwordMenu()
	isInMatch = false
	swordButton.Visible = true
end

-- Hàm toggle menu
local function toggleMenu()
	-- Không cho phép mở menu khi đang trong trận
	if isInMatch then
		return
	end
	
	isMenuOpen = not isMenuOpen
	menuFrame.Visible = isMenuOpen
	
	if isMenuOpen then
		swordButton.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
	else
		swordButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	end
end

-- Hàm cập nhật timer
local function updateTimer()
	if queueJoinTime then
		local currentTime = time()
		local timeElapsed = currentTime - queueJoinTime
		local seconds = math.floor(timeElapsed)
		local remaining = math.max(0, queueTimeout - seconds)
		
		timerLabel.Text = string.format("⏱️ %ds / %ds", seconds, queueTimeout)
		
		-- Đổi màu theo thời gian còn lại
		if remaining <= 10 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		elseif remaining <= 30 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		else
			timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
		
		if attempts > 1 then
			modeLabel.Text = "🎮 " .. (currentQueue or "Unknown") .. " (Lần " .. attempts .. ")"
		end
	end
end

-- Xử lý click vào nút kiếm
swordButton.MouseButton1Click:Connect(function()
    toggleMenu()
end)


-- Phím tắt để test: Nhấn J để join 1v1 queue
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.J then
		print("[SwordMenuClient] Hotkey J pressed - firing JoinQueue 1v1")
        -- Join 1v1 queue
        currentQueue = "1v1"
        JoinQueue:FireServer("1v1")
        menuFrame.Visible = false
        isMenuOpen = false
    elseif input.KeyCode == Enum.KeyCode.K then
		print("[SwordMenuClient] Hotkey K pressed - firing JoinQueue 2v2")
        -- Join 2v2 queue
        currentQueue = "2v2"
        JoinQueue:FireServer("2v2")
        menuFrame.Visible = false
        isMenuOpen = false
    elseif input.KeyCode == Enum.KeyCode.L then
		print("[SwordMenuClient] Hotkey L pressed - firing JoinQueue 3v3")
        -- Join 3v3 queue
        currentQueue = "3v3"
        JoinQueue:FireServer("3v3")
        menuFrame.Visible = false
        isMenuOpen = false
    end
end)

-- Xử lý chọn chế độ chơi
button1v1.MouseButton1Click:Connect(function()
    print("[SwordMenuClient] Button1v1 clicked - firing JoinQueue 1v1")
	currentQueue = "1v1"
	JoinQueue:FireServer("1v1")
	toggleMenu()
end)

button2v2.MouseButton1Click:Connect(function()
    print("[SwordMenuClient] Button2v2 clicked - firing JoinQueue 2v2")
	currentQueue = "2v2"
	JoinQueue:FireServer("2v2")
	toggleMenu()
end)

button3v3.MouseButton1Click:Connect(function()
    print("[SwordMenuClient] Button3v3 clicked - firing JoinQueue 3v3")
	currentQueue = "3v3"
	JoinQueue:FireServer("3v3")
	toggleMenu()
end)

-- Xử lý nút hủy
cancelButton.MouseButton1Click:Connect(function()
	LeaveQueue:FireServer()
	queueStatusFrame.Visible = false
	currentQueue = nil
	queueJoinTime = nil
	isTimerRunning = false
end)

-- Lắng nghe cập nhật queue
QueueStatus.OnClientEvent:Connect(function(data)
	if data.action == "joinResult" then
		if data.success then
			-- Sử dụng thời gian local của client, không phải từ server
			queueJoinTime = time()
			queueTimeout = data.timeout or 60
			attempts = data.attempts or 1
			
			if not isTimerRunning then
				isTimerRunning = true
				task.spawn(function()
					while isTimerRunning and queueJoinTime do
						updateTimer()
						task.wait(0.1)
					end
				end)
			end
			
			queueStatusFrame.Visible = true
			modeLabel.Text = "🎮 " .. (currentQueue or "Unknown")
			
			-- SỬA: Sử dụng data từ server nếu có, nếu không thì dùng default
			if data.count and data.needed then
				playersLabel.Text = data.count .. "/" .. data.needed .. " players"
			else
				playersLabel.Text = "1/" .. (currentQueue == "1v1" and 2 or currentQueue == "2v2" and 4 or 6) .. " players"
			end
			
			-- SỬA: Hiển thị danh sách players từ server
			if data.players and #data.players > 0 then
				local playerListText = ""
				for i, playerName in ipairs(data.players) do
					if i == 1 then
						playerListText = "👤 " .. playerName
					else
						playerListText = playerListText .. "\n👤 " .. playerName
					end
				end
				playersListLabel.Text = playerListText
			else
				playersListLabel.Text = "👤 " .. Players.LocalPlayer.Name
			end
		else
			currentQueue = nil
		end
	elseif data.action == "leaveResult" then
		if data.success then
			currentQueue = nil
			queueJoinTime = nil
			queueStatusFrame.Visible = false
			isTimerRunning = false
		else
		end
	elseif data.action == "timeout" then
		queueStatusFrame.Visible = true
		timerLabel.Text = "⏱️ Hết thời gian!"
		timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		playersLabel.Text = data.message or "Vui lòng thử lại!"
		
		task.delay(2, function()
			queueStatusFrame.Visible = false
			currentQueue = nil
			queueJoinTime = nil
			isTimerRunning = false
		end)
	else
		
		-- Sử dụng thời gian local của client
		if not queueJoinTime then
			queueJoinTime = time()
		end
		queueTimeout = data.timeout or 60
		attempts = data.attempts or 1
		
		if not isTimerRunning then
			isTimerRunning = true
			task.spawn(function()
				while isTimerRunning and queueJoinTime do
					updateTimer()
					task.wait(0.1)
				end
			end)
		end
		
		playersLabel.Text = data.count .. "/" .. data.needed .. " players"
		
		-- Hiển thị danh sách người chơi
		if data.players and #data.players > 0 then
			local playerListText = ""
			for i, playerName in ipairs(data.players) do
				if i == 1 then
					playerListText = "👤 " .. playerName
				else
					playerListText = playerListText .. "\n👤 " .. playerName
				end
			end
			playersListLabel.Text = playerListText
		end
	end
end)

-- Lắng nghe khi tìm thấy trận
MatchFound.OnClientEvent:Connect(function(data)
    print("[SwordMenuClient] MatchFound received - mode:", data.mode, "matchId:", data.matchId)
	
	if data.hasBots then
		-- Đếm số bot trong players list
		local botCount = 0
		for _, playerName in ipairs(data.players) do
			if playerName:find("%[BOT%]") then
				botCount = botCount + 1
			end
		end
	end
	
	currentQueue = nil
	queueJoinTime = nil
	queueStatusFrame.Visible = false
	isTimerRunning = false
	
	-- ẨN SwordMenu GUI khi vào trận
	hideSwordMenu()
	
	-- Thông báo cho server spawn nhà
	MatchStart:FireServer({
		mode = data.mode,
		players = data.players,
		matchId = data.matchId,
		hasBots = data.hasBots or false
	})
	
end)

-- Lắng nghe khi trận đấu kết thúc
MatchEnded.OnClientEvent:Connect(function(data)
	
	-- Hiện lại SwordMenu GUI khi thoát trận
	task.delay(6, function()
		showSwordMenu()
	end)
end)

-- Theo dõi team change để ẩn/hiện GUI
player:GetPropertyChangedSignal("Team"):Connect(function()
	local team = player.Team
	if team then
		local teamName = team.Name
		
		if teamName == "Team1" or teamName == "Team2" then
			-- Player vào team trận đấu -> ẩn GUI
			if not isInMatch then
				hideSwordMenu()
			end
		elseif teamName == "Lobby" then
			-- Player về lobby -> hiện GUI
			if isInMatch then
				showSwordMenu()
			end
		end
	else
		-- Player không có team (có thể đang loading)
	end
end)

-- Kiểm tra team hiện tại khi script khởi động
local currentTeam = player.Team
if currentTeam then
	if currentTeam.Name == "Team1" or currentTeam.Name == "Team2" then
		hideSwordMenu()
	elseif currentTeam.Name == "Lobby" then
		showSwordMenu()
	end
else
	showSwordMenu()
end

