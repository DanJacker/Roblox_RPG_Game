-- BossManager - Quản lý Elite Boss Event
-- Elite Boss xuất hiện ngẫu nhiên ở nửa sau trận đấu

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

print("[BossManager] ========== KHỞI ĐỘNG ==========")

-- ========== CONFIG ==========
local CONFIG = {
	SPAWN_CHANCE = 0.02, -- 2% cơ hội xuất hiện
	MIN_MATCH_TIME = 0.5, -- Xuất hiện từ 50% thời gian trận
	SCALE = 4, -- Phóng to 4 lần
	HEALTH = 2000, -- Máu cực cao
	WALK_SPEED = 6, -- 1/3 tốc độ người chơi (16/3 ≈ 5.3)
	ATTACK_DAMAGE = 3, -- Giam tu 150 xuong 3
	ATTACK_COOLDOWN = 3.0, -- Tấn công siêu chậm
	ATTACK_RANGE = 15, -- Tầm đánh xa hơn
	CHASE_RANGE = 100, -- Tầm đuổi theo xa
}

-- ========== STATE ==========
local activeBoss = nil
local currentMatchId = nil
local bossSpawned = false
local matchStartTime = 0

-- ========== REMOTE EVENTS ==========
local bossEvent = Instance.new("RemoteEvent")
bossEvent.Name = "BossEvent"
bossEvent.Parent = ReplicatedStorage

-- ========== HELPER FUNCTIONS ==========

-- Tạo model boss từ RigTemplate
local function createBossModel(position)
	local template = Workspace:FindFirstChild("RigTemplate")
	if not template then
		warn("[BossManager] Không tìm thấy RigTemplate")
		return nil
	end
	
	-- Clone template
	local boss = template:Clone()
	boss.Name = "EliteBoss"
	
	-- Phóng to 4 lần
	boss:ScaleTo(CONFIG.SCALE)
	
	-- Cấu hình Humanoid
	local humanoid = boss:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = CONFIG.HEALTH
		humanoid.Health = CONFIG.HEALTH
		humanoid.WalkSpeed = CONFIG.WALK_SPEED
	end
	
	-- Đặt vị trí
	boss:SetAttribute("IsEliteBoss", true)
	boss:SetAttribute("BossHealth", CONFIG.HEALTH)
	boss:PivotTo(CFrame.new(position))
	
	-- Màu đặc biệt (đỏ rực)
	for _, part in ipairs(boss:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Color = Color3.fromRGB(255, 50, 50)
			part.Material = Enum.Material.Neon
		end
	end
	
	-- Tạo BillboardGui hiển thị tên và máu
	local head = boss:FindFirstChild("Head")
	if head then
		-- Name Label
		local nameLabel = Instance.new("BillboardGui")
		nameLabel.Name = "BossNameLabel"
		nameLabel.Size = UDim2.new(0, 300, 0, 50)
		nameLabel.StudsOffset = Vector3.new(0, 8 * CONFIG.SCALE, 0)
		nameLabel.Adornee = head
		nameLabel.AlwaysOnTop = true
		nameLabel.Parent = head
		
		local nameText = Instance.new("TextLabel")
		nameText.Size = UDim2.new(1, 0, 1, 0)
		nameText.BackgroundTransparency = 1
		nameText.Text = "👑 ELITE BOSS 👑"
		nameText.TextColor3 = Color3.fromRGB(255, 215, 0)
		nameText.TextSize = 28
		nameText.Font = Enum.Font.GothamBold
		nameText.TextStrokeTransparency = 0
		nameText.Parent = nameLabel
		
		-- Health Bar
		local healthBar = Instance.new("BillboardGui")
		healthBar.Name = "BossHealthBar"
		healthBar.Size = UDim2.new(0, 400, 0, 30)
		healthBar.StudsOffset = Vector3.new(0, 5 * CONFIG.SCALE, 0)
		healthBar.Adornee = head
		healthBar.AlwaysOnTop = true
		healthBar.Parent = head
		
		local bgFrame = Instance.new("Frame")
		bgFrame.Size = UDim2.new(1, 0, 1, 0)
		bgFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
		bgFrame.BorderSizePixel = 2
		bgFrame.BorderColor3 = Color3.new(0, 0, 0)
		bgFrame.Parent = healthBar
		
		local healthFill = Instance.new("Frame")
		healthFill.Name = "HealthFill"
		healthFill.Size = UDim2.new(1, 0, 1, 0)
		healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		healthFill.BorderSizePixel = 0
		healthFill.Parent = bgFrame
		
		local healthText = Instance.new("TextLabel")
		healthText.Size = UDim2.new(1, 0, 1, 0)
		healthText.BackgroundTransparency = 1
		healthText.Text = CONFIG.HEALTH .. "/" .. CONFIG.HEALTH
		healthText.TextColor3 = Color3.new(1, 1, 1)
		healthText.TextSize = 18
		healthText.Font = Enum.Font.GothamBold
		healthText.Parent = bgFrame
	end
	
	return boss
end

-- Cập nhật thanh máu boss
local function updateBossHealthBar(boss, currentHealth)
	local head = boss:FindFirstChild("Head")
	if not head then return end
	
	local healthBar = head:FindFirstChild("BossHealthBar")
	if not healthBar then return end
	
	local bgFrame = healthBar:FindFirstChild("Frame")
	if not bgFrame then return end
	
	local healthFill = bgFrame:FindFirstChild("HealthFill")
	local healthText = bgFrame:FindFirstChild("TextLabel")
	
	local healthPercent = currentHealth / CONFIG.HEALTH
	
	if healthFill then
		healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
		-- Màu thay đổi theo máu
		if healthPercent > 0.5 then
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		elseif healthPercent > 0.25 then
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
		else
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		end
	end
	
	if healthText then
		healthText.Text = math.floor(currentHealth) .. "/" .. CONFIG.HEALTH
	end
end

-- AI Logic cho boss
local function setupBossAI(boss)
	local humanoid = boss:FindFirstChildOfClass("Humanoid")
	local hrp = boss:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not hrp then return end
	
	local lastAttackTime = 0
	local target = nil
	
	-- Tìm target gần nhất
	local function findNearestTarget()
		local nearestDistance = CONFIG.CHASE_RANGE
		local nearestTarget = nil
		
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local targetHRP = character.HumanoidRootPart
				local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
				
				if targetHumanoid and targetHumanoid.Health > 0 then
					local distance = (hrp.Position - targetHRP.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestTarget = character
					end
				end
			end
		end
		
		-- Cũng kiểm tra bots
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:GetAttribute("IsBot") and descendant:FindFirstChild("HumanoidRootPart") then
				local botHRP = descendant.HumanoidRootPart
				local botHumanoid = descendant:FindFirstChildOfClass("Humanoid")
				
				if botHumanoid and botHumanoid.Health > 0 then
					local distance = (hrp.Position - botHRP.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestTarget = descendant
					end
				end
			end
		end
		
		return nearestTarget
	end
	
	-- Tấn công target
	local function attackTarget(targetCharacter)
		local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
		local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		
		if not targetHRP or not targetHumanoid then return end
		
		local distance = (hrp.Position - targetHRP.Position).Magnitude
		
		if distance <= CONFIG.ATTACK_RANGE then
			-- Gây damage
			targetHumanoid:TakeDamage(CONFIG.ATTACK_DAMAGE)
			
			-- Hiệu ứng đánh
			local attackEffect = Instance.new("Part")
			attackEffect.Name = "BossAttackEffect"
			attackEffect.Size = Vector3.new(2, 2, 2)
			attackEffect.Color = Color3.fromRGB(255, 100, 0)
			attackEffect.Material = Enum.Material.Neon
			attackEffect.Shape = Enum.PartType.Ball
			attackEffect.Anchored = true
			attackEffect.CanCollide = false
			attackEffect.Position = targetHRP.Position
			attackEffect.Parent = Workspace
			
			game:GetService("Debris"):AddItem(attackEffect, 0.3)
			
			print("[BossManager] Boss tấn công " .. targetCharacter.Name .. " gây " .. CONFIG.ATTACK_DAMAGE .. " damage")
		end
	end
	
	-- Main AI loop
	task.spawn(function()
		while boss.Parent and humanoid.Health > 0 do
			target = findNearestTarget()
			
			if target then
				local targetHRP = target:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					local distance = (hrp.Position - targetHRP.Position).Magnitude
					
					-- Di chuyển đến target
					if distance > CONFIG.ATTACK_RANGE then
						humanoid:MoveTo(targetHRP.Position)
					else
						-- Trong tầm đánh, tấn công
						local currentTime = tick()
						if currentTime - lastAttackTime >= CONFIG.ATTACK_COOLDOWN then
							attackTarget(target)
							lastAttackTime = currentTime
						end
					end
				end
			end
			
			task.wait(0.5)
		end
	end)
end

-- ========== MAIN FUNCTIONS ==========

-- Kiểm tra và spawn boss
local function checkAndSpawnBoss(matchTime, matchDuration)
	if bossSpawned then return end
	
	-- Kiểm tra thời gian (nửa sau trận)
	local timeProgress = matchTime / matchDuration
	if timeProgress < CONFIG.MIN_MATCH_TIME then return end
	
	-- Random spawn chance
	if math.random() <= CONFIG.SPAWN_CHANCE then
		print("[BossManager] Elite Boss đang xuất hiện!")
		
		-- Tìm vị trí spawn (giữa map)
		local spawnPos = Vector3.new(13, 15, -1040) -- Vị trí trung tâm
		
		-- Tạo boss
		local boss = createBossModel(spawnPos)
		if boss then
			boss.Parent = Workspace
			activeBoss = boss
			bossSpawned = true
			
			-- Setup AI
			setupBossAI(boss)
			
			-- Thông báo toàn trận
			bossEvent:FireAllClients({
				event = "BossSpawned",
				position = spawnPos,
				health = CONFIG.HEALTH
			})
			
			-- Lắng nghe thay đổi máu
			local humanoid = boss:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.HealthChanged:Connect(function(newHealth)
					updateBossHealthBar(boss, newHealth)
					boss:SetAttribute("BossHealth", newHealth)
					
					-- Gửi update cho clients
					bossEvent:FireAllClients({
						event = "BossHealthUpdate",
						health = newHealth,
						maxHealth = CONFIG.HEALTH
					})
				end)
				
				-- Xử lý khi boss chết
				humanoid.Died:Connect(function()
					print("[BossManager] Elite Boss đã bị tiêu diệt!")
					
					bossEvent:FireAllClients({
						event = "BossDefeated",
						position = boss:GetPivot().Position
					})
					
					-- Xóa boss sau 2 giây
					task.wait(2)
					if boss.Parent then
						boss:Destroy()
					end
					activeBoss = nil
				end)
			end
			
			print("[BossManager] Elite Boss đã spawn tại: " .. tostring(spawnPos))
		end
	end
end

-- Cleanup khi match kết thúc
local function cleanup()
	if activeBoss and activeBoss.Parent then
		activeBoss:Destroy()
	end
	activeBoss = nil
	bossSpawned = false
	currentMatchId = nil
	print("[BossManager] Đã cleanup")
end

-- ========== PUBLIC API ==========
local BossManager = {}

function BossManager.CheckSpawn(matchTime, matchDuration)
	checkAndSpawnBoss(matchTime, matchDuration)
end

function BossManager.GetActiveBoss()
	return activeBoss
end

function BossManager.IsBossSpawned()
	return bossSpawned
end

function BossManager.Cleanup()
	cleanup()
end

-- Export
_G.BossManager = BossManager

print("[BossManager] ========== KHỞI ĐỘNG THÀNH CÔNG ==========")
print("[BossManager] Cấu hình:")
print("  - Tỉ lệ xuất hiện: " .. (CONFIG.SPAWN_CHANCE * 100) .. "%")
print("  - Thời gian xuất hiện: Từ " .. (CONFIG.MIN_MATCH_TIME * 100) .. "% trận")
print("  - Kích thước: " .. CONFIG.SCALE .. "x")
print("  - Máu: " .. CONFIG.HEALTH)
print("  - Tốc độ: " .. CONFIG.WALK_SPEED .. " (1/3 người chơi)")
print("  - Damage: " .. CONFIG.ATTACK_DAMAGE)
print("  - Tốc độ đánh: " .. CONFIG.ATTACK_COOLDOWN .. "s")