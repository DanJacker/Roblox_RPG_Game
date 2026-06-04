-- Victory/Lost Client - Hiển thị UI chiến thắng/thua cuộc
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")


-- Đợi player sẵn sàng
local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

local PlayerGui = player:WaitForChild("PlayerGui", 10)
if not PlayerGui then
	warn("[VictoryLostClient] KHÔNG TÌM THẤY PlayerGui!")
	return
end


-- Đợi _G.MVPDisplay sẵn sàng (quan trọng!) - Đợi lâu hơn
local mvpWaitTime = 0
local maxWaitTime = 15 -- Tăng thời gian đợi lên 15 giây

while not (_G.MVPDisplay and _G.MVPDisplay.showMVP) and mvpWaitTime < maxWaitTime do
	task.wait(0.5)
	mvpWaitTime = mvpWaitTime + 0.5
end

if _G.MVPDisplay and _G.MVPDisplay.showMVP then
else
	warn("[VictoryLostClient] ⚠️ _G.MVPDisplay KHÔNG sẵn sàng sau " .. maxWaitTime .. "s!")
	warn("[VictoryLostClient] _G.MVPDisplay: " .. tostring(_G.MVPDisplay))
end

-- ========== LẤY GUI ==========
local victoryGui = PlayerGui:WaitForChild("VictoryGui", 5)
local lostGui = PlayerGui:WaitForChild("LostGui", 5)

if not victoryGui or not lostGui then
	warn("[VictoryLostClient] KHÔNG TÌM THẤY GUI!")
	return
end

local victoryFrame = victoryGui:FindFirstChild("MainFrame")
local lostFrame = lostGui:FindFirstChild("MainFrame")

-- Lấy nút đóng
local victoryCloseButton = victoryFrame and victoryFrame:FindFirstChild("CloseButton")
local lostCloseButton = lostFrame and lostFrame:FindFirstChild("CloseButton")

-- Biến theo dõi timer
local victoryTimer = nil
local lostTimer = nil

-- Ẩn GUI ban đầu
if victoryFrame then victoryFrame.Visible = false end
if lostFrame then lostFrame.Visible = false end

-- Hàm hiển thị MVP GUI với data đầy đủ
local function showMVPGui()
	
	-- Đợi _G.MVPDisplay sẵn sàng - tăng thời gian đợi
	local maxWait = 15
	local waited = 0
	while not (_G.MVPDisplay and _G.MVPDisplay.showMVP) and waited < maxWait do
		task.wait(0.5)
		waited = waited + 0.5
	end
	
	
	if not _G.MVPDisplay then
		warn("[VictoryLostClient] ⚠️ _G.MVPDisplay is NIL! Cannot show MVP UI")
		return
	end
	
	if not _G.MVPDisplay.showMVP then
		warn("[VictoryLostClient] ⚠️ _G.MVPDisplay.showMVP is NIL!")
		return
	end
	
	-- Lấy stored data
	local storedData = _G.MVPDisplay.getStoredData and _G.MVPDisplay.getStoredData()
	
	if storedData then
	else
		-- Thử đợi thêm nếu data chưa có
		local dataWait = 0
		while not (_G.MVPDisplay.getStoredData and _G.MVPDisplay.getStoredData()) and dataWait < 10 do
			task.wait(0.5)
			dataWait = dataWait + 0.5
		end
		storedData = _G.MVPDisplay.getStoredData and _G.MVPDisplay.getStoredData()
	end
	
	-- Gọi hàm showMVP từ MVPDisplay script
	_G.MVPDisplay.showMVP()
	
	-- Kiểm tra container visible
	task.wait(0.5)
	if _G.MVPDisplay.container then
	else
		warn("[VictoryLostClient] Container is NIL!")
	end
end

-- Xử lý click nút đóng
if victoryCloseButton then
	victoryCloseButton.MouseButton1Click:Connect(function()
		-- Hủy timer tự động ẩn
		if victoryTimer then
			task.cancel(victoryTimer)
			victoryTimer = nil
		end
		if victoryFrame then
			victoryFrame.Visible = false
		end
		-- Hiển thị MVP GUI ngay lập tức
		task.wait(0.1) -- Small delay to ensure frame is hidden
		showMVPGui()
	end)
else
	warn("[VictoryLostClient] ✗ Victory CloseButton NOT FOUND!")
end

if lostCloseButton then
	lostCloseButton.MouseButton1Click:Connect(function()
		-- Hủy timer tự động ẩn
		if lostTimer then
			task.cancel(lostTimer)
			lostTimer = nil
		end
		if lostFrame then
			lostFrame.Visible = false
		end
		-- Hiển thị MVP GUI ngay lập tức
		task.wait(0.1) -- Small delay to ensure frame is hidden
		showMVPGui()
	end)
else
	warn("[VictoryLostClient] ✗ Lost CloseButton NOT FOUND!")
end


-- ========== REMOTE EVENTS ==========
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	warn("[VictoryLostClient] KHÔNG TÌM THẤY RemoteEvents!")
	return
end

-- Tạo hoặc lấy VictoryAnnouncement (SỬA: Đúng tên với server)
local victoryAnnouncement = remoteEvents:FindFirstChild("VictoryAnnouncement")
if not victoryAnnouncement then
	victoryAnnouncement = Instance.new("RemoteEvent")
	victoryAnnouncement.Name = "VictoryAnnouncement"
	victoryAnnouncement.Parent = remoteEvents
end


-- ========== HÀM HIỂN THỊ ==========
local function showVictory(teamName)
	
	if victoryFrame then
		-- Cập nhật team label
		local teamLabel = victoryFrame:FindFirstChild("TeamLabel")
		if teamLabel then
			teamLabel.Text = "Team: " .. tostring(teamName)
		end
		
		-- Hiển thị với animation
		victoryFrame.Visible = true
		victoryFrame.Size = UDim2.new(0, 0, 0, 0)
		victoryFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		
		local tween = TweenService:Create(victoryFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			Size = UDim2.new(0.5, 0, 0.4, 0),
			Position = UDim2.new(0.25, 0, 0.3, 0)
		})
		tween:Play()
		
		-- Tự động ẩn sau 10 giây
		victoryTimer = task.delay(10, function()
			local hideTween = TweenService:Create(victoryFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0)
			})
			hideTween:Play()
			hideTween.Completed:Connect(function()
				victoryFrame.Visible = false
			end)
		end)
	end
end

local function showLost(teamName)
	
	if lostFrame then
		-- Cập nhật team label
		local teamLabel = lostFrame:FindFirstChild("TeamLabel")
		if teamLabel then
			teamLabel.Text = "Team: " .. tostring(teamName)
		end
		
		-- Hiển thị với animation
		lostFrame.Visible = true
		lostFrame.Size = UDim2.new(0, 0, 0, 0)
		lostFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		
		local tween = TweenService:Create(lostFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			Size = UDim2.new(0.5, 0, 0.4, 0),
			Position = UDim2.new(0.25, 0, 0.3, 0)
		})
		tween:Play()
		
		-- Tự động ẩn sau 10 giây
		lostTimer = task.delay(10, function()
			local hideTween = TweenService:Create(lostFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0)
			})
			hideTween:Play()
			hideTween.Completed:Connect(function()
				lostFrame.Visible = false
			end)
		end)
	end
end

-- ========== LẮNG NGHE EVENT ==========
victoryAnnouncement.OnClientEvent:Connect(function(data)
	
	-- Tính isWinner từ winnerTeam và playerTeam
	local isWinner = data.winnerTeam == data.playerTeam
	
	if isWinner then
		showVictory(data.playerTeam)
	else
		showLost(data.playerTeam)
	end
end)

-- ========== EXPORT ĐỂ TEST ==========
_G.VictoryLostClient = {
	showVictory = showVictory,
	showLost = showLost
}

