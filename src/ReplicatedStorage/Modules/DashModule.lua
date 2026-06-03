local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DASH_SPEED = 80
local DASH_DURATION = 0.3
local COOLDOWN = 0.5

-- ========== CONFIG CHO AN TOÀN DASH ==========
local DISABLE_COLLISIONS = true -- Tắt collision khi dash để không bị văng
local USE_FORCEFIELD = true -- Thêm ForceField để bảo vệ khỏi fling
local Animations = ReplicatedStorage:WaitForChild("Animations", 10)
local Effects = ReplicatedStorage:FindFirstChild("Effects")

-- Fallback: Tự tạo Animations nếu chưa có
if not Animations then
	Animations = Instance.new("Folder")
	Animations.Name = "Animations"
	Animations.Parent = ReplicatedStorage

	local ok, AnimationIdAsset = pcall(function()
		return require(ReplicatedStorage.Modules.AnimationIdAsset)
	end)

	if ok and AnimationIdAsset then
		for name, id in pairs(AnimationIdAsset) do
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = id
			anim.Parent = Animations
		end
		-- Thêm Back animation (fallback từ Front)
		if not AnimationIdAsset.Back then
			local backAnim = Instance.new("Animation")
			backAnim.Name = "Back"
			backAnim.AnimationId = AnimationIdAsset.Front or ""
			backAnim.Parent = Animations
		end
	end
end

local DashModule = {}
local isDashing = false

-- Tạo VFX cho dash
local function CreateDashVFX(character, direction)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	-- Tìm template VFX
	local vfxTemplate = Effects and Effects:FindFirstChild("DashVFX")
	if not vfxTemplate then
		warn("[DashModule] DashVFX template not found!")
		return nil
	end
	
	-- Clone VFX và gắn vào HumanoidRootPart
	local vfx = vfxTemplate:Clone()
	vfx.Name = "DashEffect"
	vfx.Parent = rootPart
	vfx.Anchored = true
	vfx.CanCollide = false
	vfx.Massless = true
	
	-- Đặt VFX ngay tại vị trí thân nhân vật (HumanoidRootPart)
	-- Xoay 90 độ sang trái để particle bắn ngang
	vfx.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
	
	-- Kích hoạt tất cả ParticleEmitter
	for _, child in pairs(vfx:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = true
			child:Emit(50) -- Phát 50 particle ngay lập tức
		end
	end
	
	return vfx
end

-- Xóa VFX sau khi dash xong
local function CleanupDashVFX(vfx)
	if vfx then
		-- Tắt tất cả ParticleEmitter
		for _, child in pairs(vfx:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		-- Xóa sau một chút để particle hiện ra hết
		task.delay(0.1, function()
			if vfx then
				vfx:Destroy()
			end
		end)
	end
end

local function PlayAnimation(character: Model, direction: string)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then 
		warn("[DashModule] No Humanoid found")
		return false
	end
	
	-- Get or create Animator
	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	-- Find the animation
	local animation = Animations:FindFirstChild(direction)
	if not animation then
		-- Fallback: Nếu không tìm thấy animation (ví dụ 'Back'), dùng 'Front'
		animation = Animations:FindFirstChild("Front")
		if not animation then
			warn("[DashModule] Animation not found: " .. direction .. " (and Front fallback)")
			return false
		end
	end

	if not animation:IsA("Animation") then
		warn("[DashModule] Object is not an Animation: " .. direction)
		return false
	end
	
	
	-- Load and play animation with high priority
	local animationTrack = animator:LoadAnimation(animation)
	animationTrack.Priority = Enum.AnimationPriority.Action
	animationTrack:Play()
	
	
	return true
end

function DashModule.Execute(direction: string)
	direction = direction or "Front"

	if isDashing then
		return false
	end

	local player = Players.LocalPlayer
	if not player then
		return false
	end
	
	local character = player.Character
	if not character then
		return false
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return false
	end
	
	isDashing = true
	
	-- Tạo VFX
	local dashVFX = CreateDashVFX(character, direction)
	
	-- ========== LƯU TRẠNG THÁI COLLISION GỐC ==========
	local originalCollisions = {}
	if DISABLE_COLLISIONS then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				originalCollisions[part] = part.CanCollide
				part.CanCollide = false
			end
		end
	end
	
	-- ========== THÊM FORCEFIELD ĐỂ BẢO VỆ ==========
	local forceField = nil
	if USE_FORCEFIELD then
		forceField = Instance.new("ForceField")
		forceField.Name = "DashProtection"
		forceField.Visible = false
		forceField.Parent = character
	end
	
	-- Giữ character ổn định trong khi dash
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- ========== PHÁT HIỆN VA CHẠM ĐỂ DỪNG DASH ==========
	local dashCancelled = false

	local touchConn
	touchConn = rootPart.Touched:Connect(function(hit)
		if dashCancelled then return end
		if not hit or not hit.Parent then return end
		
		-- Bỏ qua các part thuộc character của mình
		if hit:IsDescendantOf(character) then return end
		
		-- Bỏ qua Tool
		if hit.Parent and hit.Parent:IsA("Tool") then return end
		
		-- Bỏ qua các part thuộc character người khác (không dừng khi chạm người)
		local hitHumanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hitHumanoid then return end
		
		-- Chạm vật thể thế giới (tường, đá, sàn...) → dừng dash
		dashCancelled = true
	end)

	-- Use pcall to ensure cleanup always runs
	local success, err = pcall(function()
		-- Play animation
		PlayAnimation(character, direction)
		
		-- Calculate dash direction (Front or Back only)
		local lookVector = rootPart.CFrame.LookVector
		local dashDirection = lookVector -- Default forward
		
		if direction == "Front" then
			dashDirection = lookVector
		elseif direction == "Back" then
			dashDirection = -lookVector
		end
		
		-- Create BodyVelocity
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = Vector3.new(dashDirection.X * DASH_SPEED, 0, dashDirection.Z * DASH_SPEED)
		bodyVelocity.Parent = rootPart
		
		-- Dash cho đến khi hết thời gian HOẶC chạm vật thể
		local startTime = tick()
		while task.wait() do
			if dashCancelled then break end
			if tick() - startTime >= DASH_DURATION then break end
		end
		
		-- Clean up
		bodyVelocity:Destroy()
	end)
	
	-- Ngắt kết nối Touched event
	if touchConn then
		touchConn:Disconnect()
	end

	-- ========== KHÔI PHỤC TRẠNG THÁI ==========
	-- Khôi phục PlatformStand
	humanoid.PlatformStand = false
	
	-- Khôi phục collision
	if DISABLE_COLLISIONS then
		for part, originalCanCollide in pairs(originalCollisions) do
			if part and part.Parent then
				part.CanCollide = originalCanCollide
			end
		end
	end
	
	-- ========== XÓA FORCEFIELD ==========
	if forceField then
		forceField:Destroy()
	end
	
	-- Xóa VFX
	CleanupDashVFX(dashVFX)
	
	-- Dừng velocity dư thừa sau dash
	if rootPart and rootPart.Parent then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	
	-- Chuyển HumanoidState về GettingUp để character đứng dậy và di chuyển lại
	if humanoid and humanoid.Parent then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	if not success then
		warn("[DashModule] Error during dash: " .. tostring(err))
	end
	
	-- Cooldown - always reset isDashing
	task.wait(COOLDOWN)
	isDashing = false
	
	return success
end

return DashModule
