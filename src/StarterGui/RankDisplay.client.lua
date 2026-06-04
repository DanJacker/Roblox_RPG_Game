-- RankDisplay - Hiển thị rank của player
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Modules
local RankingSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RankingSystem"))

-- RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local MatchResult = remoteEvents:WaitForChild("MatchResult")

-- Tạo ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RankDisplayGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

-- ========== RANK DISPLAY (GÓC PHẢI TRÊN) ==========
local rankFrame = Instance.new("Frame")
rankFrame.Name = "RankFrame"
rankFrame.Size = UDim2.new(0, 200, 0, 80)
rankFrame.Position = UDim2.new(1, -220, 0, 20)
rankFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
rankFrame.BorderSizePixel = 0
rankFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = rankFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 100, 120)
stroke.Thickness = 2
stroke.Parent = rankFrame

-- Rank icon (vòng tròn màu)
local rankIcon = Instance.new("Frame")
rankIcon.Name = "RankIcon"
rankIcon.Size = UDim2.new(0, 50, 0, 50)
rankIcon.Position = UDim2.new(0, 10, 0.5, -25)
rankIcon.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
rankIcon.Parent = rankFrame

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = rankIcon

-- Rank name
local rankName = Instance.new("TextLabel")
rankName.Name = "RankName"
rankName.Size = UDim2.new(1, -70, 0, 30)
rankName.Position = UDim2.new(0, 65, 0, 10)
rankName.BackgroundTransparency = 1
rankName.Text = "Sắt 3"
rankName.TextColor3 = Color3.new(1, 1, 1)
rankName.TextSize = 20
rankName.Font = Enum.Font.GothamBold
rankName.TextXAlignment = Enum.TextXAlignment.Left
rankName.Parent = rankFrame

-- Points bar background
local pointsBarBg = Instance.new("Frame")
pointsBarBg.Name = "PointsBarBg"
pointsBarBg.Size = UDim2.new(1, -75, 0, 20)
pointsBarBg.Position = UDim2.new(0, 65, 0, 45)
pointsBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
pointsBarBg.Parent = rankFrame

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 5)
barCorner.Parent = pointsBarBg

-- Points bar fill
local pointsBarFill = Instance.new("Frame")
pointsBarFill.Name = "PointsBarFill"
pointsBarFill.Size = UDim2.new(0.5, 0, 1, 0)
pointsBarFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
pointsBarFill.Parent = pointsBarBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 5)
fillCorner.Parent = pointsBarFill

-- Points text
local pointsText = Instance.new("TextLabel")
pointsText.Name = "PointsText"
pointsText.Size = UDim2.new(1, 0, 1, 0)
pointsText.BackgroundTransparency = 1
pointsText.Text = "50/100"
pointsText.TextColor3 = Color3.new(1, 1, 1)
pointsText.TextSize = 14
pointsText.Font = Enum.Font.GothamBold
pointsText.Parent = pointsBarBg

-- ========== RANK UP/DOWN POPUP ==========
local popupFrame = Instance.new("Frame")
popupFrame.Name = "RankPopup"
popupFrame.Size = UDim2.new(0, 300, 0, 150)
popupFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
popupFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
popupFrame.BorderSizePixel = 0
popupFrame.Visible = false
popupFrame.ZIndex = 100
popupFrame.Parent = screenGui

local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, 15)
popupCorner.Parent = popupFrame

local popupStroke = Instance.new("UIStroke")
popupStroke.Color = Color3.fromRGB(255, 215, 0)
popupStroke.Thickness = 3
popupStroke.Parent = popupFrame

local popupTitle = Instance.new("TextLabel")
popupTitle.Name = "Title"
popupTitle.Size = UDim2.new(1, 0, 0, 40)
popupTitle.Position = UDim2.new(0, 0, 0, 10)
popupTitle.BackgroundTransparency = 1
popupTitle.Text = "RANK UP!"
popupTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
popupTitle.TextSize = 28
popupTitle.Font = Enum.Font.GothamBold
popupTitle.Parent = popupFrame

local popupOldRank = Instance.new("TextLabel")
popupOldRank.Name = "OldRank"
popupOldRank.Size = UDim2.new(0.5, 0, 0, 30)
popupOldRank.Position = UDim2.new(0, 0, 0, 55)
popupOldRank.BackgroundTransparency = 1
popupOldRank.Text = "Sắt 3"
popupOldRank.TextColor3 = Color3.fromRGB(150, 150, 150)
popupOldRank.TextSize = 20
popupOldRank.Font = Enum.Font.Gotham
popupOldRank.Parent = popupFrame

local popupArrow = Instance.new("TextLabel")
popupArrow.Name = "Arrow"
popupArrow.Size = UDim2.new(0, 40, 0, 30)
popupArrow.Position = UDim2.new(0.5, -20, 0, 55)
popupArrow.BackgroundTransparency = 1
popupArrow.Text = "→"
popupArrow.TextColor3 = Color3.new(1, 1, 1)
popupArrow.TextSize = 24
popupArrow.Parent = popupFrame

local popupNewRank = Instance.new("TextLabel")
popupNewRank.Name = "NewRank"
popupNewRank.Size = UDim2.new(0.5, 0, 0, 30)
popupNewRank.Position = UDim2.new(0.5, 0, 0, 55)
popupNewRank.BackgroundTransparency = 1
popupNewRank.Text = "Sắt 2"
popupNewRank.TextColor3 = Color3.fromRGB(100, 200, 100)
popupNewRank.TextSize = 20
popupNewRank.Font = Enum.Font.GothamBold
popupNewRank.TextXAlignment = Enum.TextXAlignment.Left
popupNewRank.Parent = popupFrame

local popupPoints = Instance.new("TextLabel")
popupPoints.Name = "Points"
popupPoints.Size = UDim2.new(1, 0, 0, 30)
popupPoints.Position = UDim2.new(0, 0, 0, 100)
popupPoints.BackgroundTransparency = 1
popupPoints.Text = "+30 điểm"
popupPoints.TextColor3 = Color3.fromRGB(100, 255, 100)
popupPoints.TextSize = 18
popupPoints.Font = Enum.Font.Gotham
popupPoints.Parent = popupFrame

-- Hàm cập nhật hiển thị rank
local function updateRankDisplay(rankInfo)
	rankIcon.BackgroundColor3 = rankInfo.color
	rankName.Text = rankInfo.displayName
	rankName.TextColor3 = rankInfo.color
	
	-- Cập nhật progress bar
	local progress = rankInfo.points / rankInfo.maxPoints
	pointsBarFill.Size = UDim2.new(progress, 0, 1, 0)
	pointsBarFill.BackgroundColor3 = rankInfo.color
	pointsText.Text = rankInfo.points .. "/" .. rankInfo.maxPoints
end

-- Hàm hiển thị popup rank up/down
local function showRankPopup(rankingData)
	if not rankingData then return end
	
	local oldRank = rankingData.oldRank
	local newRank = rankingData.newRank
	
	-- Cập nhật nội dung popup
	if rankingData.rankUp then
		popupTitle.Text = "RANK UP!"
		popupTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
		popupStroke.Color = Color3.fromRGB(255, 215, 0)
		popupNewRank.TextColor3 = Color3.fromRGB(100, 255, 100)
		popupPoints.Text = "+" .. math.abs(rankingData.pointsChange) .. " điểm"
		popupPoints.TextColor3 = Color3.fromRGB(100, 255, 100)
	elseif rankingData.rankDown then
		popupTitle.Text = "RANK DOWN"
		popupTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
		popupStroke.Color = Color3.fromRGB(255, 100, 100)
		popupNewRank.TextColor3 = Color3.fromRGB(255, 100, 100)
		popupPoints.Text = rankingData.pointsChange .. " điểm"
		popupPoints.TextColor3 = Color3.fromRGB(255, 100, 100)
	else
		-- Không thay đổi rank, chỉ hiển thị điểm
		popupTitle.Text = "KẾT QUẢ"
		popupTitle.TextColor3 = Color3.new(1, 1, 1)
		popupStroke.Color = Color3.fromRGB(100, 100, 120)
		popupNewRank.TextColor3 = newRank.color
		
		if rankingData.pointsChange >= 0 then
			popupPoints.Text = "+" .. rankingData.pointsChange .. " điểm"
			popupPoints.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			popupPoints.Text = rankingData.pointsChange .. " điểm"
			popupPoints.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end
	
	popupOldRank.Text = oldRank.displayName
	popupOldRank.TextColor3 = oldRank.color
	popupNewRank.Text = newRank.displayName
	
	-- Hiển thị popup
	popupFrame.Visible = true
	popupFrame.Size = UDim2.new(0, 0, 0, 0)
	popupFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	-- Animation
	local tweenIn = TweenService:Create(popupFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 300, 0, 150),
		Position = UDim2.new(0.5, -150, 0.5, -75)
	})
	tweenIn:Play()
	
	-- Tự động ẩn sau 3 giây
	task.delay(3, function()
		local tweenOut = TweenService:Create(popupFrame, TweenInfo.new(0.3), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0)
		})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			popupFrame.Visible = false
		end)
	end)
	
	-- Cập nhật rank display
	updateRankDisplay(newRank)
end

-- Lắng nghe kết quả trận đấu
MatchResult.OnClientEvent:Connect(function(data)
	if data.ranking then
		showRankPopup(data.ranking)
	end
end)

-- Lắng nghe cập nhật rank từ server
local RankUpdate = remoteEvents:WaitForChild("RankUpdate")
RankUpdate.OnClientEvent:Connect(function(rankInfo)
	updateRankDisplay(rankInfo)
	rankFrame.Visible = true
end)

-- Hiện rank display ở lobby (mặc định)
rankFrame.Visible = true

-- Yêu cầu rank info từ server khi player join
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- Đợi PlayerData sẵn sàng và yêu cầu rank info
task.spawn(function()
    task.wait(2) -- Đợi server khởi động
    local RequestRankUpdate = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("RequestRankUpdate")
    if RequestRankUpdate then
        RequestRankUpdate:FireServer()
    end
end)

-- Hiện rank display khi vào trận (lắng nghe MatchTimer)
local MatchTimer = remoteEvents:WaitForChild("MatchTimer")
MatchTimer.OnClientEvent:Connect(function(data)
	if data.action == "start" then
		rankFrame.Visible = true
	elseif data.action == "stop" or data.action == "end" then
		rankFrame.Visible = false
	end
end)

