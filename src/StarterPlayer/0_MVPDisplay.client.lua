-- MVP Display Client - Hiển thị MVP UI khi kết thúc trận
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

print("[MVP Display] Đang khởi động...")

-- Đợi player sẵn sàng
local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

-- Đợi PlayerGui sẵn sàng
local PlayerGui = player:WaitForChild("PlayerGui", 10)
if not PlayerGui then
	warn("[MVP Display] KHÔNG TÌM THẤY PlayerGui!")
	return
end

print("[MVP Display] PlayerGui đã sẵn sàng!")

-- ========== TẠO UI ==========
print("[MVP Display] Bắt đầu tạo UI...")

-- Tạo ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MVPDisplayGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
screenGui.Parent = PlayerGui
print("[MVP Display] ✓ ScreenGui đã tạo!")

-- ========== CONTAINER CHÍNH ==========
local container = Instance.new("Frame")
container.Name = "MVPContainer"
container.Size = UDim2.new(0, 500, 0, 280)
container.Position = UDim2.new(0.5, -250, 0.5, -140)
container.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
container.BorderSizePixel = 0
container.Visible = false
container.ZIndex = 100
container.ClipsDescendants = false
container.Parent = screenGui
print("[MVP Display] ✓ Container đã tạo!")

-- Viền vàng
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(200, 160, 0)
stroke.Thickness = 4
stroke.Parent = container

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 15)
containerCorner.Parent = container

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🏆 KẾT QUẢ TRANH ĐẤU 🏆"
titleLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.TextSize = 24
titleLabel.Font = Enum.Font.GothamBold
titleLabel.ZIndex = 100
titleLabel.Parent = container
print("[MVP Display] ✓ Title đã tạo!")

-- ========== BÊN TRÁI - TEAM THẮNG ==========
local winnerBg = Instance.new("Frame")
winnerBg.Name = "WinnerBg"
winnerBg.Size = UDim2.new(0.5, -10, 0, 180)
winnerBg.Position = UDim2.new(0, 10, 0, 55)
winnerBg.BackgroundColor3 = Color3.fromRGB(0, 80, 0)
winnerBg.BorderSizePixel = 0
winnerBg.ZIndex = 1
winnerBg.Parent = container

local winnerCorner = Instance.new("UICorner")
winnerCorner.CornerRadius = UDim.new(0, 10)
winnerCorner.Parent = winnerBg

local winnerTitle = Instance.new("TextLabel")
winnerTitle.Name = "WinnerTitle"
winnerTitle.Size = UDim2.new(0.5, -10, 0, 30)
winnerTitle.Position = UDim2.new(0, 10, 0, 60)
winnerTitle.BackgroundTransparency = 1
winnerTitle.Text = "👑 TEAM THẮNG"
winnerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
winnerTitle.TextSize = 18
winnerTitle.Font = Enum.Font.GothamBold
winnerTitle.ZIndex = 100
winnerTitle.TextStrokeTransparency = 0
winnerTitle.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
winnerTitle.Parent = container

local winnerName = Instance.new("TextLabel")
winnerName.Name = "WinnerName"
winnerName.Size = UDim2.new(0.5, -10, 0, 35)
winnerName.Position = UDim2.new(0, 10, 0, 95)
winnerName.BackgroundTransparency = 1
winnerName.Text = "Waiting..."
winnerName.TextColor3 = Color3.fromRGB(255, 255, 255)
winnerName.TextSize = 22
winnerName.Font = Enum.Font.GothamBold
winnerName.ZIndex = 100
winnerName.TextStrokeTransparency = 0
winnerName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
winnerName.Parent = container

local winnerKills = Instance.new("TextLabel")
winnerKills.Name = "WinnerKills"
winnerKills.Size = UDim2.new(0.5, -10, 0, 25)
winnerKills.Position = UDim2.new(0, 10, 0, 135)
winnerKills.BackgroundTransparency = 1
winnerKills.Text = "🗡️ Kills: 0"
winnerKills.TextColor3 = Color3.fromRGB(255, 255, 255)
winnerKills.TextSize = 16
winnerKills.Font = Enum.Font.Gotham
winnerKills.ZIndex = 100
winnerKills.TextStrokeTransparency = 0
winnerKills.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
winnerKills.Parent = container

local winnerDamage = Instance.new("TextLabel")
winnerDamage.Name = "WinnerDamage"
winnerDamage.Size = UDim2.new(0.5, -10, 0, 25)
winnerDamage.Position = UDim2.new(0, 10, 0, 165)
winnerDamage.BackgroundTransparency = 1
winnerDamage.Text = "🏠 Damage: 0"
winnerDamage.TextColor3 = Color3.fromRGB(255, 255, 255)
winnerDamage.TextSize = 16
winnerDamage.Font = Enum.Font.Gotham
winnerDamage.ZIndex = 100
winnerDamage.TextStrokeTransparency = 0
winnerDamage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
winnerDamage.Parent = container

local winnerScore = Instance.new("TextLabel")
winnerScore.Name = "WinnerScore"
winnerScore.Size = UDim2.new(0.5, -10, 0, 30)
winnerScore.Position = UDim2.new(0, 10, 0, 195)
winnerScore.BackgroundTransparency = 1
winnerScore.Text = "⭐ Tổng: 0"
winnerScore.TextColor3 = Color3.fromRGB(255, 215, 0)
winnerScore.TextSize = 18
winnerScore.Font = Enum.Font.GothamBold
winnerScore.ZIndex = 100
winnerScore.TextStrokeTransparency = 0
winnerScore.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
winnerScore.Parent = container
print("[MVP Display] ✓ Winner side đã tạo!")

-- ========== BÊN PHẢI - TEAM THUA ==========
local loserBg = Instance.new("Frame")
loserBg.Name = "LoserBg"
loserBg.Size = UDim2.new(0.5, -10, 0, 180)
loserBg.Position = UDim2.new(0.5, 0, 0, 55)
loserBg.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
loserBg.BorderSizePixel = 0
loserBg.ZIndex = 1
loserBg.Parent = container

local loserCorner = Instance.new("UICorner")
loserCorner.CornerRadius = UDim.new(0, 10)
loserCorner.Parent = loserBg

local loserTitle = Instance.new("TextLabel")
loserTitle.Name = "LoserTitle"
loserTitle.Size = UDim2.new(0.5, -10, 0, 30)
loserTitle.Position = UDim2.new(0.5, 0, 0, 60)
loserTitle.BackgroundTransparency = 1
loserTitle.Text = "💀 TEAM THUA"
loserTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
loserTitle.TextSize = 18
loserTitle.Font = Enum.Font.GothamBold
loserTitle.ZIndex = 100
loserTitle.TextStrokeTransparency = 0
loserTitle.TextStrokeColor3 = Color3.fromRGB(100, 0, 0)
loserTitle.Parent = container

local loserName = Instance.new("TextLabel")
loserName.Name = "LoserName"
loserName.Size = UDim2.new(0.5, -10, 0, 35)
loserName.Position = UDim2.new(0.5, 0, 0, 95)
loserName.BackgroundTransparency = 1
loserName.Text = "Waiting..."
loserName.TextColor3 = Color3.fromRGB(255, 255, 255)
loserName.TextSize = 22
loserName.Font = Enum.Font.GothamBold
loserName.ZIndex = 100
loserName.TextStrokeTransparency = 0
loserName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
loserName.Parent = container

local loserKills = Instance.new("TextLabel")
loserKills.Name = "LoserKills"
loserKills.Size = UDim2.new(0.5, -10, 0, 25)
loserKills.Position = UDim2.new(0.5, 0, 0, 135)
loserKills.BackgroundTransparency = 1
loserKills.Text = "🗡️ Kills: 0"
loserKills.TextColor3 = Color3.fromRGB(255, 255, 255)
loserKills.TextSize = 16
loserKills.Font = Enum.Font.Gotham
loserKills.ZIndex = 100
loserKills.TextStrokeTransparency = 0
loserKills.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
loserKills.Parent = container

local loserDamage = Instance.new("TextLabel")
loserDamage.Name = "LoserDamage"
loserDamage.Size = UDim2.new(0.5, -10, 0, 25)
loserDamage.Position = UDim2.new(0.5, 0, 0, 165)
loserDamage.BackgroundTransparency = 1
loserDamage.Text = "🏠 Damage: 0"
loserDamage.TextColor3 = Color3.fromRGB(255, 255, 255)
loserDamage.TextSize = 16
loserDamage.Font = Enum.Font.Gotham
loserDamage.ZIndex = 100
loserDamage.TextStrokeTransparency = 0
loserDamage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
loserDamage.Parent = container

local loserScore = Instance.new("TextLabel")
loserScore.Name = "LoserScore"
loserScore.Size = UDim2.new(0.5, -10, 0, 30)
loserScore.Position = UDim2.new(0.5, 0, 0, 195)
loserScore.BackgroundTransparency = 1
loserScore.Text = "⭐ Tổng: 0"
loserScore.TextColor3 = Color3.fromRGB(255, 200, 100)
loserScore.TextSize = 18
loserScore.Font = Enum.Font.GothamBold
loserScore.ZIndex = 100
loserScore.TextStrokeTransparency = 0
loserScore.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
loserScore.Parent = container
print("[MVP Display] ✓ Loser side đã tạo!")

-- ========== NÚT ĐÓNG ==========
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 120, 0, 35)
closeButton.Position = UDim2.new(0.5, -60, 1, -45)
closeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
closeButton.Text = "ĐÓNG"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.GothamBold
closeButton.ZIndex = 150
closeButton.Active = true
closeButton.Parent = container

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	print("[MVP Display] Nút Đóng được nhấn!")
	container.Visible = false
end)
print("[MVP Display] ✓ Close button đã tạo!")

-- ========== BIẾN LƯU DATA ==========
local storedMVPData = nil

-- ========== HÀM HIỂN THỊ ==========
local function showMVP(data)
	print("[MVP Display] ========== SHOW MVP CALLED ==========")
	print("[MVP Display] Input data: " .. tostring(data))
	print("[MVP Display] storedMVPData: " .. tostring(storedMVPData))
	
	-- Nếu không có data truyền vào, dùng data đã lưu
	if not data then
		print("[MVP Display] No input data, using storedMVPData")
		data = storedMVPData
	end
	
	if not data then
		warn("[MVP Display] ⚠️ KHÔNG CÓ DATA! Cannot show MVP GUI")
		return
	end
	
	print("[MVP Display] Using data: winnerTeam=" .. tostring(data.winnerTeam))
	print("[MVP Display] winnerMVP: " .. tostring(data.winnerMVP and data.winnerMVP.name or "nil"))
	print("[MVP Display] loserMVP: " .. tostring(data.loserMVP and data.loserMVP.name or "nil"))
	
	local winnerTeam = data.winnerTeam
	local winnerMVP = data.winnerMVP
	local loserMVP = data.loserMVP
	
	-- ========== HIỂN THỊ BÊN THẮNG ==========
	if winnerMVP then
		local winnerIcon = winnerMVP.isBot and "🤖 " or "👤 "
		winnerName.Text = winnerIcon .. (winnerMVP.name or "Unknown")
		winnerKills.Text = "🗡️ Kills: " .. tostring(winnerMVP.kills or 0)
		winnerDamage.Text = "🏠 Damage: " .. tostring(winnerMVP.baseDamage or 0)
		winnerScore.Text = "⭐ Tổng: " .. tostring(winnerMVP.score or 0)
		
		if winnerTeam == "Team1" then
			winnerBg.BackgroundColor3 = Color3.fromRGB(0, 60, 150)
		else
			winnerBg.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		end
	else
		winnerName.Text = "No Data"
	end
	
	-- ========== HIỂN THỊ BÊN THUA ==========
	if loserMVP then
		local loserIcon = loserMVP.isBot and "🤖 " or "👤 "
		loserName.Text = loserIcon .. (loserMVP.name or "Unknown")
		loserKills.Text = "🗡️ Kills: " .. tostring(loserMVP.kills or 0)
		loserDamage.Text = "🏠 Damage: " .. tostring(loserMVP.baseDamage or 0)
		loserScore.Text = "⭐ Tổng: " .. tostring(loserMVP.score or 0)
		
		if winnerTeam == "Team1" then
			loserBg.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		else
			loserBg.BackgroundColor3 = Color3.fromRGB(0, 60, 150)
		end
	else
		loserName.Text = "No Data"
	end
	
	-- Chạy animation hiển thị
	print("[MVP Display] Setting container visible and playing animation...")
	container.Visible = true
	container.Size = UDim2.new(0, 0, 0, 0)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	local tween = TweenService:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 500, 0, 280),
		Position = UDim2.new(0.5, -250, 0.5, -140)
	})
	tween:Play()
	tween.Completed:Connect(function()
		print("[MVP Display] ✓ Animation completed!")
	end)
	
	print("[MVP Display] ✓ MVP UI đã hiển thị! Container.Visible = " .. tostring(container.Visible))
end

-- Hàm lưu data (không hiển thị)
local function storeMVPData(data)
	print("[MVP Display] ========== LƯU MVP DATA ==========")
	storedMVPData = data
	print("[MVP Display] ✓ Data đã được lưu, chờ gọi showMVP()")
end

-- ========== KẾT NỐI VỚI SERVER ==========
local function getOrCreateMVPAnnouncementEvent()
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = ReplicatedStorage
	end
	
	local mvpAnnouncement = remoteEvents:FindFirstChild("MVPAnnouncement")
	if not mvpAnnouncement then
		mvpAnnouncement = Instance.new("RemoteEvent")
		mvpAnnouncement.Name = "MVPAnnouncement"
		mvpAnnouncement.Parent = remoteEvents
	end
	
	return mvpAnnouncement
end

local MVPAnnouncement = getOrCreateMVPAnnouncementEvent()
print("[MVP Display] ✓ MVPAnnouncement RemoteEvent đã kết nối!")

-- Lắng nghe event từ server - CHỈ LƯU DATA, KHÔNG HIỂN THỊ NGAY
MVPAnnouncement.OnClientEvent:Connect(function(data)
	print("[MVP Display] ========== NHẬN MVP DATA TỪ SERVER ==========")
	print("[MVP Display] winnerTeam: " .. tostring(data.winnerTeam))
	print("[MVP Display] winnerMVP: " .. tostring(data.winnerMVP and data.winnerMVP.name or "nil"))
	print("[MVP Display] loserMVP: " .. tostring(data.loserMVP and data.loserMVP.name or "nil"))
	print("[MVP Display] Full data: " .. tostring(data))
	storeMVPData(data)
	print("[MVP Display] ✓ Data đã được lưu vào storedMVPData")
	print("[MVP Display] storedMVPData is now: " .. tostring(storedMVPData))
end)

print("[MVP Display] ✓ Đang lắng nghe MVPAnnouncement event...")

-- ========== EXPORT ĐỂ TEST ==========
_G.MVPDisplay = {
	showMVP = showMVP,
	storeMVPData = storeMVPData,
	container = container,
	getStoredData = function() return storedMVPData end
}

print("[MVP Display] ========== ĐÃ KHỞI TẠO THÀNH CÔNG! ==========")
print("[MVP Display] Sử dụng _G.MVPDisplay.showMVP(data) để test")
