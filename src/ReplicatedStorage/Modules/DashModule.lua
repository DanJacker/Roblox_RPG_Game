local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- ========== CONFIG (Blox Fruits style smooth dash) ==========
local DASH_SPEED = 130        -- Dash speed (studs/sec)
local DASH_DURATION = 0.15     -- Burst phase duration (very short burst)
local DASH_DECEL = 0.12       -- Smooth deceleration time after burst
local COOLDOWN = 1.5          -- Cooldown between dashes
local INVINCIBLE_TIME = 0.3   -- Brief invincibility during dash
local FOV_BOOST = 6            -- FOV increase during dash for speed feel

local Effects = ReplicatedStorage:FindFirstChild("Effects")
local Animations = ReplicatedStorage:FindFirstChild("Animations", 10)

local DashModule = {}
local isDashing = false
local lastDashTime = 0
-- Default: whether dash can phase through world geometry (true = can pass through)
DashModule.allowPhase = false

function DashModule.SetAllowPhase(enabled)
	DashModule.allowPhase = not not enabled
end


-- ========== TRAIL EFFECT (cyan speed trail) ==========
local function CreateDashTrail(rootPart)
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 1, -1.5)
	att0.Parent = rootPart

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 1, 1.5)
	att1.Parent = rootPart

	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.35
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	trail.Color = ColorSequence.new(
		Color3.fromRGB(0, 180, 255),
		Color3.fromRGB(0, 255, 200)
	)
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 0)
	})
	trail.Parent = rootPart

	return trail, att0, att1
end

local function CleanupDashTrail(trail, att0, att1)
	if trail then trail.Enabled = false end
	task.delay(0.5, function()
		if trail and trail.Parent then trail:Destroy() end
		if att0 and att0.Parent then att0:Destroy() end
		if att1 and att1.Parent then att1:Destroy() end
	end)
end

-- ========== PARTICLE VFX ==========
local function CreateDashVFX(rootPart)
	local vfxTemplate = Effects and Effects:FindFirstChild("DashVFX")
	if not vfxTemplate then return nil end

	local vfx = vfxTemplate:Clone()
	vfx.Name = "DashEffect"
	vfx.Parent = rootPart
	vfx.Anchored = true
	vfx.CanCollide = false
	vfx.Massless = true
	vfx.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)

	for _, child in pairs(vfx:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = true
			child:Emit(50)
		end
	end

	return vfx
end

local function CleanupDashVFX(vfx)
	if not vfx then return end
	for _, child in pairs(vfx:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		end
	end
	task.delay(0.15, function()
		if vfx and vfx.Parent then vfx:Destroy() end
	end)
end

-- ========== ANIMATION ==========
local function PlayDashAnimation(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if not Animations then return end

	local animation = Animations:FindFirstChild("Front")
	if not animation or not animation:IsA("Animation") then return end

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
end

-- ========== FOV EFFECT ==========
local function ApplyFOVBoost(camera)
	local originalFOV = camera.FieldOfView
	local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {FieldOfView = originalFOV + FOV_BOOST})
	tween:Play()
	return originalFOV
end

local function RestoreFOV(camera, targetFOV)
	if not camera or not camera.Parent then return end
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {FieldOfView = targetFOV})
	tween:Play()
end

-- ========== MAIN DASH (Blox Fruits style) ==========
function DashModule.Execute(direction: string, phase)
	direction = direction or "Forward"

	-- Cooldown check
	if isDashing then return false end
	if tick() - lastDashTime < COOLDOWN then return false end

	local player = Players.LocalPlayer
	if not player then return false end

	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Can't dash while seated, climbing, or swimming
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Seated
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Swimming then
		return false
	end

	isDashing = true
	lastDashTime = tick()

	-- ===== CALCULATE DASH DIRECTION (camera-relative) =====
	local camera = workspace.CurrentCamera
	local camCF = camera.CFrame

	local dashDir
	if direction == "Forward" then
		dashDir = camCF.LookVector
	elseif direction == "Backward" then
		dashDir = -camCF.LookVector
	elseif direction == "Left" then
		dashDir = -camCF.RightVector
	elseif direction == "Right" then
		dashDir = camCF.RightVector
	else
		dashDir = camCF.LookVector
	end

	-- Flatten to horizontal plane
	dashDir = Vector3.new(dashDir.X, 0, dashDir.Z)
	if dashDir.Magnitude > 0.001 then
		dashDir = dashDir.Unit
	else
		dashDir = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
	end

	-- ===== PLAY ANIMATION =====
	PlayDashAnimation(character)

	-- ===== CREATE TRAIL =====
	local trail, att0, att1 = CreateDashTrail(rootPart)

	-- ===== CREATE PARTICLE VFX =====
	local dashVFX = CreateDashVFX(rootPart)

	-- ===== FOV BOOST (speed feel) =====
	local originalFOV = ApplyFOVBoost(camera)

	-- ===== OPTIONAL: DISABLE COLLISION (prevent fling / allow phasing) =====
	local canPhase = (phase ~= nil) and phase or DashModule.allowPhase
	local originalCollisions = nil
	if canPhase then
		originalCollisions = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				originalCollisions[part] = part.CanCollide
				part.CanCollide = false
			end
		end
	end

	-- ===== BRIEF INVINCIBILITY =====
	local forceField = Instance.new("ForceField")
	forceField.Name = "DashProtection"
	forceField.Visible = false
	forceField.Parent = character
	task.delay(INVINCIBLE_TIME, function()
		if forceField and forceField.Parent then
			forceField:Destroy()
		end
	end)

	-- ===== APPLY VELOCITY DIRECTLY (client-friendly) =====
	-- Using AssemblyLinearVelocity is more reliable for client-local
	-- dash movement than creating Actuators which may not take effect
	-- depending on network ownership and engine settings.
	local originalVelocity = rootPart.AssemblyLinearVelocity

	-- Burst phase: set horizontal velocity while preserving Y
	rootPart.AssemblyLinearVelocity = Vector3.new(dashDir.X * DASH_SPEED, originalVelocity.Y, dashDir.Z * DASH_SPEED)
	task.wait(DASH_DURATION)

	-- Deceleration phase: smoothly reduce horizontal speed
	local decelStart = tick()
	while true do
		local elapsed = tick() - decelStart
		local progress = math.clamp(elapsed / DASH_DECEL, 0, 1)

		local speed = DASH_SPEED * (1 - progress * progress)

		if rootPart and rootPart.Parent then
			local currentY = rootPart.AssemblyLinearVelocity.Y
			rootPart.AssemblyLinearVelocity = Vector3.new(dashDir.X * speed, currentY, dashDir.Z * speed)
		end

		if progress >= 1 then break end
		task.wait()
	end

	-- Leave vertical velocity as-is; no actuator cleanup required

	-- Restore collision (only if we disabled them earlier)
	if originalCollisions then
		for part, original in pairs(originalCollisions) do
			if part and part.Parent then
				part.CanCollide = original
			end
		end
	end

	-- Restore FOV smoothly
	RestoreFOV(camera, originalFOV)

	-- Cleanup VFX
	CleanupDashVFX(dashVFX)
	CleanupDashTrail(trail, att0, att1)

	-- NO PlatformStand, NO Physics state, NO GettingUp state
	-- The humanoid never lost control — it resumes walking instantly!

	isDashing = false
	return true
end

function DashModule.IsDashing()
	return isDashing
end

function DashModule.GetCooldownRemaining()
	if isDashing then return COOLDOWN end
	return math.max(0, COOLDOWN - (tick() - lastDashTime))
end

return DashModule