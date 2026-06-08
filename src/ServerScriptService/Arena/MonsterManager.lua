-- MonsterManager - Quai vat chi tan cong khi bi danh (aggro on hit)
-- LEASH: Monster chi duoi player gan spawn, xa qua -> quay ve hoi mau

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONFIG = {
	DETECTION_RANGE = 100,
	CHASE_RANGE = 80,
	ATTACK_RANGE = 5,
	ATTACK_DAMAGE = 3,
	ATTACK_COOLDOWN = 2.0,
	MAX_HEALTH = 150,
	WALK_SPEED = 16,
	CHASE_SPEED_MULT = 1.3,
	HP_REGEN_IDLE = 3,
	HP_REGEN_COMBAT = 0,
	HP_REGEN_RETURNING = 25,
	PATROL_RANGE = 30,
	RETREAT_HEALTH = 0.25,
	RESPAWN_TIME = 8,
	MAX_CHASE_FROM_SPAWN = 60,
	MAX_MONSTERS = 3,
}

local activeMonsters = {}
local monsterCounter = 0

local function createMonsterCharacter(monsterName)
	local rigTemplate = workspace:FindFirstChild("RigTemplate")
	if not rigTemplate then
		warn("[MonsterManager] Khong tim thay RigTemplate!")
		return nil
	end

	local character = rigTemplate:Clone()
	character.Name = monsterName

	local animate = character:FindFirstChild("Animate")
	if animate then animate:Destroy() end

	local monsterColor = Color3.fromRGB(50, 0, 80)

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Color = monsterColor
			part.Material = Enum.Material.Slate
			part.Anchored = false
		end
	end

	local bodyColors = character:FindFirstChild("Body Colors")
	if bodyColors then
		bodyColors.HeadColor3 = monsterColor
		bodyColors.LeftArmColor3 = monsterColor
		bodyColors.RightArmColor3 = monsterColor
		bodyColors.LeftLegColor3 = monsterColor
		bodyColors.RightLegColor3 = monsterColor
		bodyColors.TorsoColor3 = monsterColor
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = CONFIG.MAX_HEALTH
		humanoid.Health = CONFIG.MAX_HEALTH
		humanoid.WalkSpeed = CONFIG.WALK_SPEED
	end

	return character
end

local moveTo

local function returnToSpawn(monsterData)
	monsterData.state = "returning"
	monsterData.hasAggro = false
	monsterData.aggroTarget = nil
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	if h then
		h.WalkSpeed = CONFIG.WALK_SPEED
	end
	moveTo(monsterData, monsterData.spawnPos)
end

local function findTarget(monsterData)
	-- AGGRO-ON-HIT: Chi tim muc tieu khi da bi danh
	if not monsterData.hasAggro then
		return nil
	end

	local root = monsterData.character.PrimaryPart or monsterData.character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local pos = root.Position

	-- Kiem tra aggro target (player da danh minh)
	if monsterData.aggroTarget and monsterData.aggroTarget.Parent then
		local targetChar = monsterData.aggroTarget.Character
		if targetChar then
			local h = targetChar:FindFirstChildOfClass("Humanoid")
			local hrp = targetChar:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				local d = (hrp.Position - pos).Magnitude
				-- KIEM TRA LEASH: Player phai nam trong MAX_CHASE_FROM_SPAWN tu spawn
				local distFromSpawn = (hrp.Position - monsterData.spawnPos).Magnitude
				if d <= CONFIG.DETECTION_RANGE and distFromSpawn <= CONFIG.MAX_CHASE_FROM_SPAWN then
					return {type = "player", instance = monsterData.aggroTarget, position = hrp.Position, distance = d}
				end
			end
		end
	end
	-- Aggro target mat hoac xa qua -> mat aggro, quay ve spawn
	monsterData.hasAggro = false
	monsterData.aggroTarget = nil
	return nil
end

local function attack(monsterData, target)
	local now = tick()
	if now - monsterData.lastAttack < CONFIG.ATTACK_COOLDOWN then return end
	monsterData.lastAttack = now

	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if hrp and target.position then
		hrp.CFrame = CFrame.new(hrp.Position, target.position)
	end

	if target.type == "player" then
		local h = target.instance.Character and target.instance.Character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)
		end
	elseif target.type == "bot" then
		local h = target.instance:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)
		end
	end
end

moveTo = function(monsterData, pos)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if h and hrp then
		h:MoveTo(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
	end
end

local function regenerateHP(monsterData, deltaTime)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end

	if monsterData.hasAggro then
		h.Health = math.min(h.Health + CONFIG.HP_REGEN_COMBAT * deltaTime, h.MaxHealth)
	elseif monsterData.state == "returning" then
		h.Health = math.min(h.Health + CONFIG.HP_REGEN_RETURNING * deltaTime, h.MaxHealth)
	else
		h.Health = math.min(h.Health + CONFIG.HP_REGEN_IDLE * deltaTime, h.MaxHealth)
	end
end

local function updateAI(monsterData)
	if monsterData.state == "dead" then return end

	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp or h.Health <= 0 then
		monsterData.state = "dead"
		return
	end

	-- DANG QUAY VE SPAWN
	if monsterData.state == "returning" then
		if monsterData.hasAggro and monsterData.aggroTarget then
			monsterData.state = "chasing"
			h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
		else
			local distToSpawn = (hrp.Position - monsterData.spawnPos).Magnitude
			if distToSpawn <= 8 then
				monsterData.state = "idle"
				monsterData.hasAggro = false
				monsterData.aggroTarget = nil
			else
				moveTo(monsterData, monsterData.spawnPos)
				return
			end
		end
	end

	-- LEASH: Monster xa spawn qua -> mat aggro, quay ve hoi mau
	local distFromSpawn = (hrp.Position - monsterData.spawnPos).Magnitude
	if distFromSpawn > CONFIG.MAX_CHASE_FROM_SPAWN then
		returnToSpawn(monsterData)
		return
	end

	-- KHONG CO AGGRO -> DUNG YEN TAI SPAWN
	if not monsterData.hasAggro then
		if distFromSpawn > 15 then
			returnToSpawn(monsterData)
			return
		end
		monsterData.state = "idle"
		return
	end

	-- CO AGGRO -> TIM MUC TIEU
	local target = findTarget(monsterData)
	if target then
		h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
		if target.distance <= CONFIG.ATTACK_RANGE then
			monsterData.state = "attacking"
			attack(monsterData, target)
		elseif target.distance <= CONFIG.CHASE_RANGE then
			monsterData.state = "chasing"
			moveTo(monsterData, target.position)
		else
			monsterData.state = "idle"
		end
	else
		-- KHONG TIM THAY MUC TIEU -> QUAY VE SPAWN HOI MAU
		returnToSpawn(monsterData)
	end
end

local function spawnMonster(spawnPos)
	if #activeMonsters >= CONFIG.MAX_MONSTERS then return nil end

	monsterCounter = monsterCounter + 1
	local name = string.format("[MONSTER] Beast%d", monsterCounter)

	local character = createMonsterCharacter(name)
	if not character then return nil end

	character.Parent = workspace
	character:SetAttribute("IsMonster", true)

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = true end
	end

	character:SetPrimaryPartCFrame(CFrame.new(spawnPos + Vector3.new(0, 5, 0)))

	task.delay(0.2, function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = false end
		end
	end)

	local monsterData = {
		name = name,
		character = character,
		state = "idle",
		lastAttack = 0,
		spawnPos = spawnPos,
		patrolTarget = nil,
		lastPatrol = 0,
		hasAggro = false,
		aggroTarget = nil,
	}

	activeMonsters[character] = monsterData

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			monsterData.state = "dead"
			monsterData.hasAggro = false
			monsterData.aggroTarget = nil
			task.delay(CONFIG.RESPAWN_TIME, function()
				if character and character.Parent then character.Parent = nil end
				activeMonsters[character] = nil
				spawnMonster(spawnPos)
			end)
		end)

		-- AGGRO-ON-HIT: Monster bi danh -> bat dau truy duoi
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < humanoid.MaxHealth and monsterData.state ~= "dead" then
				monsterData.hasAggro = true

				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local closestPlayer = nil
					local closestDist = math.huge
					for _, p in Players:GetPlayers() do
						if p.Character then
							local pH = p.Character:FindFirstChildOfClass("Humanoid")
							local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
							if pH and pH.Health > 0 and pHrp then
								local d = (pHrp.Position - hrp.Position).Magnitude
								-- Chi aggro player trong pham vi spawn
								local pDistFromSpawn = (pHrp.Position - spawnPos).Magnitude
								if d < closestDist and d <= CONFIG.DETECTION_RANGE and pDistFromSpawn <= CONFIG.MAX_CHASE_FROM_SPAWN then
									closestDist = d
									closestPlayer = p
								end
							end
						end
					end
					if closestPlayer then
						monsterData.aggroTarget = closestPlayer
					end
				end
			end
		end)
	end

	return monsterData
end

local MonsterManager = {}

function MonsterManager.SpawnMonster(pos)
	return spawnMonster(pos or Vector3.new(0, 10, 0))
end

function MonsterManager.GetMonsterCount()
	local c = 0
	for _ in pairs(activeMonsters) do c = c + 1 end
	return c
end

function MonsterManager.ClearAllMonsters()
	for monster in pairs(activeMonsters) do
		if monster and monster.Parent then monster.Parent = nil end
	end
	activeMonsters = {}
	monsterCounter = 0
end

RunService.Heartbeat:Connect(function(deltaTime)
	for _, data in pairs(activeMonsters) do
		if data.state ~= "dead" then
			regenerateHP(data, deltaTime)
			updateAI(data)
		end
	end
end)

_G.MonsterManager = MonsterManager

return MonsterManager