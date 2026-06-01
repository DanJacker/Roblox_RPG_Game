--[[
	Combat Client - Script tấn công mới
	- Nhấn M1 (chuột trái) để tấn công
	- Tự động tìm mục tiêu trong phạm vi
	- Gửi damage đến server qua CombatRemote
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ========== CẤU HÌNH ==========
local CONFIG = {
	COOLDOWN = 1,			-- Thời gian chờ giữa các đòn tấn công (giây)
	ATTACK_RANGE = 15,		-- Phạm vi tấn công (studs)
	DAMAGE = 10,			-- Sát thương mỗi đòn
	ANIMATION_DURATION = 0.5,	-- Thời gian animation (giây)
}
-- =============================

-- Biến theo dõi
local lastAttackTime = 0
local attackTrack = nil
local isAttacking = false

-- Lấy CombatRemote và Animation
local combatRemote = ReplicatedStorage:WaitForChild("CombatRemote")
local animationsFolder = ReplicatedStorage:WaitForChild("Animations", 10)

-- Fallback: Tạo Animations folder nếu chưa có
if not animationsFolder then
	animationsFolder = Instance.new("Folder")
	animationsFolder.Name = "Animations"
	animationsFolder.Parent = ReplicatedStorage
	
	local ok, AnimationIdAsset = pcall(function()
		return require(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("AnimationIdAsset"))
	end)
	
	if ok and AnimationIdAsset then
		for name, id in pairs(AnimationIdAsset) do
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = id
			anim.Parent = animationsFolder
		end
	end
end

local basicAttackAnim = animationsFolder:WaitForChild("Basicattack", 5)
local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")


-- ========== HÀM CHÍNH ==========

-- Tạo VFX cho attack
local function createAttackVFX(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	local vfxTemplate = effectsFolder and effectsFolder:FindFirstChild("AttackVFX")
	if not vfxTemplate then return nil end
	
	local vfx = vfxTemplate:Clone()
	vfx.Name = "AttackEffect"
	vfx.Parent = rootPart
	vfx.Anchored = true
	vfx.CanCollide = false
	vfx.Massless = true
	
	-- Đặt VFX trước thân nhân vật 5 studs
	vfx.CFrame = rootPart.CFrame * CFrame.new(0, 0, -5)
	
	-- Phát particle
	for _, child in pairs(vfx:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(30)
		end
	end
	
	-- Xóa sau khi hoàn thành
	task.delay(0.6, function()
		if vfx then vfx:Destroy() end
	end)
	
	return vfx
end

-- Tạo VFX khi đánh trúng
local function createImpactVFX(target)
	if not target then return nil end
	
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return nil end
	
	local vfxTemplate = effectsFolder and effectsFolder:FindFirstChild("ImpactVFX")
	if not vfxTemplate then return nil end
	
	local vfx = vfxTemplate:Clone()
	vfx.Name = "ImpactEffect"
	vfx.Parent = targetRoot
	vfx.CFrame = targetRoot.CFrame
	vfx.Anchored = true
	vfx.CanCollide = false
	vfx.Massless = true
	
	-- Phát particle
	for _, child in pairs(vfx:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(60)
		end
	end
	
	-- Xóa sau khi hoàn thành
	task.delay(0.5, function()
		if vfx then vfx:Destroy() end
	end)
	
	return vfx
end

-- Phát animation tấn công
local function playAttackAnimation()
	local character = player.Character
	if not character then 
		warn("[CombatClient] No character")
		return false 
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then 
		warn("[CombatClient] No Humanoid")
		return false 
	end
	
	-- Lấy Animator từ Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	
	
	-- Dừng animation cũ nếu có
	if attackTrack then
		attackTrack:Stop()
	end
	
	-- Load và phát animation
	local success, result = pcall(function()
		attackTrack = animator:LoadAnimation(basicAttackAnim)
		attackTrack.Priority = Enum.AnimationPriority.Action
		attackTrack.Looped = false
		attackTrack:Play()
	end)
	
	if not success then
		warn("[CombatClient] Animation lỗi: " .. tostring(result))
		return false
	end
	
	

	
	return true
end

-- Tìm mục tiêu gần nhất trong phạm vi
local function findNearestTarget()
	local character = player.Character
	if not character then return nil end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	local nearestTarget = nil
	local nearestDistance = CONFIG.ATTACK_RANGE
	
	-- Tìm trong tất cả objects có Humanoid
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= character then
			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			local objRoot = obj:FindFirstChild("HumanoidRootPart")
			
			if humanoid and humanoid.Health > 0 and objRoot then
				local distance = (rootPart.Position - objRoot.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestTarget = obj
				end
			end
		end
	end
	
	-- Tìm trong các player khác
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local otherChar = otherPlayer.Character
			local humanoid = otherChar:FindFirstChildOfClass("Humanoid")
			local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
			
			if humanoid and humanoid.Health > 0 and otherRoot then
				local distance = (rootPart.Position - otherRoot.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestTarget = otherPlayer
				end
			end
		end
	end
	
	if nearestTarget then
	end
	
	return nearestTarget
end

-- Gây sát thương (gửi đến server)
local function dealDamage(target)
	if not target then return false end
	
	local success, err = pcall(function()
		combatRemote:FireServer(target, CONFIG.DAMAGE)
	end)
	
	if success then
		lastAttackTime = tick()
		return true
	else
		warn("[CombatClient] Lỗi gửi damage: " .. tostring(err))
		return false
	end
end

-- Xử lý tấn công khi nhấn M1
local function onAttack()
	-- Kiểm tra cooldown
	local timeSinceLastAttack = tick() - lastAttackTime
	if timeSinceLastAttack < CONFIG.COOLDOWN then
		return
	end
	
	-- Phát animation
	playAttackAnimation()
	
	-- Tạo VFX attack
	local character = player.Character
	if character then
		createAttackVFX(character)
	end
	
	-- Tìm mục tiêu và gây damage
	local target = findNearestTarget()
	if target then
		dealDamage(target)
		-- Tạo VFX impact khi đánh trúng
		createImpactVFX(target)
	else
	end
end

-- ========== INPUT HANDLER ==========

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Chỉ xử lý M1 (chuột trái)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	
	-- Log để debug
	
	-- Thực hiện tấn công
	onAttack()
end)

-- ========== KHỞI TẠO ==========

