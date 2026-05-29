-- Base Danger Effects Client - Hiệu ứng sấm sét và nhuộm đỏ khi base còn 15-25% máu
-- Thiết kế an toàn cho người bị động kinh (seizure-safe)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Cấu hình hiệu ứng (an toàn cho seizure)
local LIGHTNING_INTERVAL = 3.0 -- Khoảng cách giữa các tia sét (giây) - chậm để an toàn
local LIGHTNING_DURATION = 0.3 -- Thời gian hiển thị tia sét
local RED_TINT_INTENSITY = 0.25 -- Độ mạnh của màu đỏ (0-1)
local AMBIENT_RED = Color3.fromRGB(180, 100, 100) -- Màu ambient đỏ nhẹ
local NORMAL_AMBIENT = Color3.fromRGB(170, 170, 170) -- Màu ambient bình thường

-- Trạng thái
local isDangerActive = false
local dangerTeam = nil
local lightningLoop = nil
local colorCorrection = nil
local bloomEffect = nil

-- Tạo ColorCorrectionEffect nếu chưa có
local function setupPostProcessing()
	-- Tìm hoặc tạo ColorCorrection
	colorCorrection = Lighting:FindFirstChild("DangerColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "DangerColorCorrection"
		colorCorrection.Parent = Lighting
	end
	
	-- Tìm hoặc tạo Bloom
	bloomEffect = Lighting:FindFirstChild("DangerBloom")
	if not bloomEffect then
		bloomEffect = Instance.new("BloomEffect")
		bloomEffect.Name = "DangerBloom"
		bloomEffect.Parent = Lighting
	end
	
	-- Reset về trạng thái bình thường
	colorCorrection.TintColor = Color3.new(1, 1, 1)
	colorCorrection.Saturation = 0
	bloomEffect.Intensity = 0
end

-- Tạo hiệu ứng sấm sét (visual only, an toàn)
local function createLightningEffect()
	if not isDangerActive then return end
	
	-- Tạo tia sét ngẫu nhiên trên màn hình
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	-- Tạo Part cho tia sét (sẽ được render trên client)
	local lightning = Instance.new("Part")
	lightning.Name = "LightningBolt"
	lightning.Anchored = true
	lightning.CanCollide = false
	lightning.Transparency = 0.3
	lightning.Material = Enum.Material.Neon
	lightning.Color = Color3.fromRGB(200, 200, 255)
	lightning.Size = Vector3.new(0.5, 50, 0.5)
	
	-- Vị trí ngẫu nhiên quanh base
	local basePosition
	
	-- Hàm tìm base trong Maps folder
	local function findTeamBase(teamName)
		local mapsFolder = workspace:FindFirstChild("Maps")
		if mapsFolder then
			for _, mapFolder in pairs(mapsFolder:GetChildren()) do
				for _, obj in pairs(mapFolder:GetDescendants()) do
					if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
						return obj
					end
				end
			end
		end
		-- Fallback: tìm trong workspace root
		for _, obj in pairs(workspace:GetChildren()) do
			if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
				return obj
			end
		end
		return nil
	end
	
	if dangerTeam == "Team1" then
		local team1Base = findTeamBase("Team1")
		basePosition = team1Base and team1Base:GetPivot().Position or Vector3.new(-129, 7, 1)
	else
		local team2Base = findTeamBase("Team2")
		basePosition = team2Base and team2Base:GetPivot().Position or Vector3.new(281, 7, -14)
	end
	
	-- Offset ngẫu nhiên
	local offset = Vector3.new(
		math.random(-30, 30),
		math.random(20, 50),
		math.random(-30, 30)
	)
	lightning.Position = basePosition + offset
	lightning.Parent = workspace
	
	-- Hiệu ứng flash nhẹ (an toàn - không nhấp nháy nhanh)
	local flashIntensity = 0.15
	local tweenInfo = TweenInfo.new(
		LIGHTNING_DURATION / 2,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	-- Flash sáng
	local flashTween = TweenService:Create(colorCorrection, tweenInfo, {
		Brightness = flashIntensity,
		TintColor = Color3.fromRGB(255, 240, 240)
	})
	flashTween:Play()
	
	-- Xóa tia sét sau một thời gian
	task.delay(LIGHTNING_DURATION, function()
		if lightning and lightning.Parent then
			lightning.Parent = nil
		end
		
		-- Trở về màu đỏ nhẹ
		if isDangerActive and colorCorrection then
			local returnTween = TweenService:Create(colorCorrection, tweenInfo, {
				Brightness = 0,
				TintColor = Color3.fromRGB(255, 230, 230)
			})
			returnTween:Play()
		end
	end)
end

-- Bật hiệu ứng nguy hiểm
local function startDangerEffects(teamName, healthPercent)
	if isDangerActive then return end
	
	isDangerActive = true
	dangerTeam = teamName
	
	print("[DangerEffects] Bật hiệu ứng nguy hiểm cho " .. teamName .. " (" .. math.floor(healthPercent * 100) .. "% HP)")
	
	-- Thiết lập post-processing
	setupPostProcessing()
	
	-- Tween màu đỏ nhẹ (gradual - an toàn)
	local tweenInfo = TweenInfo.new(
		2.0, -- 2 giây để chuyển đổi (chậm, an toàn)
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	-- Áp dụng màu đỏ nhẹ
	local colorTween = TweenService:Create(colorCorrection, tweenInfo, {
		TintColor = Color3.fromRGB(255, 230, 230),
		Saturation = -0.1
	})
	colorTween:Play()
	
	-- Áp dụng bloom nhẹ
	local bloomTween = TweenService:Create(bloomEffect, tweenInfo, {
		Intensity = 0.3,
		Size = 24,
		Threshold = 2
	})
	bloomTween:Play()
	
	-- Thay đổi ambient màu đỏ nhẹ
	local ambientTween = TweenService:Create(Lighting, tweenInfo, {
		Ambient = AMBIENT_RED,
		OutdoorAmbient = AMBIENT_RED
	})
	ambientTween:Play()
	
	-- Bắt đầu loop tạo sấm sét (chậm để an toàn)
	lightningLoop = task.spawn(function()
		while isDangerActive do
			createLightningEffect()
			task.wait(LIGHTNING_INTERVAL)
		end
	end)
end

-- Tắt hiệu ứng nguy hiểm
local function stopDangerEffects()
	if not isDangerActive then return end
	
	isDangerActive = false
	dangerTeam = nil
	
	print("[DangerEffects] Tắt hiệu ứng nguy hiểm")
	
	-- Hủy loop sấm sét
	if lightningLoop then
		task.cancel(lightningLoop)
		lightningLoop = nil
	end
	
	-- Xóa các tia sét còn lại
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "LightningBolt" then
			obj.Parent = nil
		end
	end
	
	-- Trở về trạng thái bình thường (gradual)
	local tweenInfo = TweenInfo.new(
		2.0,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	if colorCorrection then
		local colorTween = TweenService:Create(colorCorrection, tweenInfo, {
			TintColor = Color3.new(1, 1, 1),
			Saturation = 0,
			Brightness = 0
		})
		colorTween:Play()
	end
	
	if bloomEffect then
		local bloomTween = TweenService:Create(bloomEffect, tweenInfo, {
			Intensity = 0
		})
		bloomTween:Play()
	end
	
	-- Trở về ambient bình thường
	local ambientTween = TweenService:Create(Lighting, tweenInfo, {
		Ambient = NORMAL_AMBIENT,
		OutdoorAmbient = NORMAL_AMBIENT
	})
	ambientTween:Play()
end

-- Lắng nghe event từ server
local function setupEventListener()
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then return end
	
	local dangerEvent = remoteEvents:FindFirstChild("BaseDangerEffect")
	if not dangerEvent then return end
	
	dangerEvent.OnClientEvent:Connect(function(teamName, healthPercent)
		print("[DangerEffects] Nhận event từ server: " .. teamName .. " - " .. math.floor(healthPercent * 100) .. "%")
		startDangerEffects(teamName, healthPercent)
	end)
	
	print("[DangerEffects] Đã thiết lập event listener")
end

-- Khởi tạo
local function init()
	setupPostProcessing()
	setupEventListener()
	print("[DangerEffects] Client script đã khởi động!")
end

init()