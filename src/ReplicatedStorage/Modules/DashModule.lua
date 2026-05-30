local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DASH_SPEED = 80
local DASH_DURATION = 0.3
local COOLDOWN = 0.5

-- ========== CONFIG CHO AN TOÀN DASH ==========
local DISABLE_COLLISIONS = true -- Tắt collision khi dash để không bị văng
local USE_FORCEFIELD = true -- Thêm ForceField để bảo vệ khỏi fling

local Animations = ReplicatedStorage:WaitForChild("Animations")
local Effects = ReplicatedStorage:FindFirstChild("Effects")

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
		warn("[DashModule] Animation not found: " .. direction)
		return false
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
	
	-- Use pcall to ensure isDashing is always reset
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
		bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
		bodyVelocity.Velocity = dashDirection * DASH_SPEED
		bodyVelocity.Parent = rootPart
		
		-- Dash for duration
		task.wait(DASH_DURATION)
		
		-- Clean up
		bodyVelocity:Destroy()
	end)
	
	-- ========== KHÔI PHỤC COLLISION ==========
	if DISABLE_COLLISIONS then
		for part, originalValue in pairs(originalCollisions) do
			if part and part.Parent then
				part.CanCollide = originalValue
			end
		end
	end
	
	-- ========== XÓA FORCEFIELD ==========
	if forceField then
		forceField:Destroy()
	end
	
	-- Xóa VFX
	CleanupDashVFX(dashVFX)
	
	if not success then
		warn("[DashModule] Error during dash: " .. tostring(err))
	end
	
	-- Cooldown - always reset isDashing
	task.wait(COOLDOWN)
	isDashing = false
	
	return success
end

return DashModule
