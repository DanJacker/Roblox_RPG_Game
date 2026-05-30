-- BossClientHandler - Xử lý thông báo và hiển thị Elite Boss
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== GUI CREATION ==========

-- Tạo ScreenGui cho Boss announcements
local bossGui = Instance.new("ScreenGui")
bossGui.Name = "BossAnnouncementGui"
bossGui.ResetOnSpawn = false
bossGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bossGui.IgnoreGuiInset = true
bossGui.Parent = playerGui

-- Frame chính cho thông báo (ẩn mặc định)
local announcementFrame = Instance.new("Frame")
announcementFrame.Name = "AnnouncementFrame"
announcementFrame.Size = UDim2.new(0.6, 0, 0.12, 0)
announcementFrame.Position = UDim2.new(0.2, 0, 0.15, 0)
announcementFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
announcementFrame.BackgroundTransparency = 1 -- Ẩn mặc định
announcementFrame.BorderSizePixel = 0
announcementFrame.Visible = false -- Ẩn mặc định
announcementFrame.Parent = bossGui

-- Viền vàng gradient
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 215, 0)
stroke.Thickness = 4
stroke.Parent = announcementFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 15)
corner.Parent = announcementFrame

-- Gradient background
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 40, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 30, 0))
})
gradient.Parent = announcementFrame

-- Text thông báo chính
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, 0, 0.65, 0)
titleText.Position = UDim2.new(0, 0, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "👑 ELITE BOSS ĐÃ XUẤT HIỆN! 👑"
titleText.TextColor3 = Color3.fromRGB(255, 215, 0)
titleText.TextSize = 32
titleText.Font = Enum.Font.GothamBold
titleText.TextStrokeTransparency = 0
titleText.TextStrokeColor3 = Color3.fromRGB(100, 50, 0)
titleText.Parent = announcementFrame

-- Text phụ
local subtitleText = Instance.new("TextLabel")
subtitleText.Name = "SubtitleText"
subtitleText.Size = UDim2.new(1, 0, 0.35, 0)
subtitleText.Position = UDim2.new(0, 0, 0.65, 0)
subtitleText.BackgroundTransparency = 1
subtitleText.Text = "Hãy tiêu diệt để nhận phần thưởng đặc biệt!"
subtitleText.TextColor3 = Color3.new(1, 1, 1)
subtitleText.TextSize = 18
subtitleText.Font = Enum.Font.Gotham
subtitleText.Parent = announcementFrame

-- Boss Health Bar (hiển thị khi boss active)
local bossHealthFrame = Instance.new("Frame")
bossHealthFrame.Name = "BossHealthFrame"
bossHealthFrame.Size = UDim2.new(0.5, 0, 0.04, 0)
bossHealthFrame.Position = UDim2.new(0.25, 0, 0.03, 0)
bossHealthFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
bossHealthFrame.BackgroundTransparency = 1 -- Ẩn mặc định
bossHealthFrame.BorderSizePixel = 0
bossHealthFrame.Visible = false -- Ẩn mặc định
bossHealthFrame.Parent = bossGui

local healthCorner = Instance.new("UICorner")
healthCorner.CornerRadius = UDim.new(0, 5)
healthCorner.Parent = bossHealthFrame

local healthStroke = Instance.new("UIStroke")
healthStroke.Color = Color3.fromRGB(255, 50, 50)
healthStroke.Thickness = 2
healthStroke.Parent = bossHealthFrame

local healthFill = Instance.new("Frame")
healthFill.Name = "HealthFill"
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
healthFill.BorderSizePixel = 0
healthFill.Parent = bossHealthFrame

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 5)
fillCorner.Parent = healthFill

local bossNameLabel = Instance.new("TextLabel")
bossNameLabel.Name = "BossNameLabel"
bossNameLabel.Size = UDim2.new(1, 0, 1, 0)
bossNameLabel.BackgroundTransparency = 1
bossNameLabel.Text = "👑 ELITE BOSS"
bossNameLabel.TextColor3 = Color3.new(1, 1, 1)
bossNameLabel.TextSize = 16
bossNameLabel.Font = Enum.Font.GothamBold
bossNameLabel.Parent = bossHealthFrame

-- ========== MINIMAP BOSS MARKER ==========

-- Tạo minimap marker cho boss
local function createMinimapMarker(position)
	local minimapGui = playerGui:FindFirstChild("MinimapGui")
	if not minimapGui then return nil end
	
	local minimapFrame = minimapGui:FindFirstChild("MinimapFrame")
	if not minimapFrame then return nil end
	
	-- Tạo marker
	local marker = Instance.new("Frame")
	marker.Name = "BossMarker"
	marker.Size = UDim2.new(0, 20, 0, 20)
	marker.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	marker.BorderSizePixel = 0
	marker.Parent = minimapFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = marker
	
	-- Icon vương miện
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "👑"
	icon.TextSize = 14
	icon.Parent = marker
	
	return marker
end

-- ========== EVENT HANDLERS ==========

local bossEvent = ReplicatedStorage:FindFirstChild("BossEvent")
if not bossEvent then
	bossEvent = Instance.new("RemoteEvent")
	bossEvent.Name = "BossEvent"
	bossEvent.Parent = ReplicatedStorage
end

bossEvent.OnClientEvent:Connect(function(data)
	local event = data.event
	
	if event == "BossSpawned" then
		-- Hiển thị thông báo CHỈ khi boss xuất hiện
		
		-- Reset text
		titleText.Text = "👑 ELITE BOSS ĐÃ XUẤT HIỆN! 👑"
		subtitleText.Text = "Hãy tiêu diệt để nhận phần thưởng đặc biệt!"
		
		-- Hiện frame
		announcementFrame.Visible = true
		announcementFrame.BackgroundTransparency = 1
		
		-- Tween in (hiệu ứng xuất hiện)
		local tweenIn = TweenService:Create(announcementFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0
		})
		tweenIn:Play()
		
		-- Tự động ẩn sau 5 giây
		task.delay(5, function()
			local tweenOut = TweenService:Create(announcementFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1
			})
			tweenOut:Play()
			
			-- Ẩn hoàn toàn sau animation
			tweenOut.Completed:Connect(function()
				announcementFrame.Visible = false
			end)
		end)
		
		-- Hiển thị thanh máu boss
		bossHealthFrame.Visible = true
		bossHealthFrame.BackgroundTransparency = 0
		
		-- Tạo minimap marker
		local marker = createMinimapMarker(data.position)
		if marker then
			marker:SetAttribute("BossPosition", data.position)
		end
		
	elseif event == "BossHealthUpdate" then
		-- Cập nhật thanh máu
		local healthPercent = data.health / data.maxHealth
		healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
		
		-- Cập nhật màu theo máu
		if healthPercent > 0.5 then
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		elseif healthPercent > 0.25 then
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
		else
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		end
		
	elseif event == "BossDefeated" then
		-- Thông báo boss bị tiêu diệt
		
		titleText.Text = "🎉 ELITE BOSS ĐÃ BỊ TIÊU DIỆT! 🎉"
		subtitleText.Text = "Phần thưởng đã được phân phối!"
		
		-- Hiện frame
		announcementFrame.Visible = true
		announcementFrame.BackgroundTransparency = 1
		
		-- Hiển thị lại thông báo
		local tweenIn = TweenService:Create(announcementFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0
		})
		tweenIn:Play()
		
		-- Ẩn thanh máu
		task.delay(3, function()
			bossHealthFrame.Visible = false
			local tweenOut = TweenService:Create(announcementFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1
			})
			tweenOut:Play()
			
			-- Ẩn hoàn toàn sau animation
			tweenOut.Completed:Connect(function()
				announcementFrame.Visible = false
			end)
		end)
		
		-- Xóa minimap marker
		local minimapGui = playerGui:FindFirstChild("MinimapGui")
		if minimapGui then
			local minimapFrame = minimapGui:FindFirstChild("MinimapFrame")
			if minimapFrame then
				local marker = minimapFrame:FindFirstChild("BossMarker")
				if marker then
					marker:Destroy()
				end
			end
		end
	end
end)

