-- MonsterManager - Quai vat tan cong ca player va bot (uu tien player)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("[MonsterManager] Khoi dong...")

local CONFIG = {
	DETECTION_RANGE = 100,
	CHASE_RANGE = 80,
	ATTACK_RANGE = 5,
	ATTACK_DAMAGE = 3,  -- Giam tu 5 xuong 3
	ATTACK_COOLDOWN = 2.0,
	MAX_HEALTH = 150,
	WALK_SPEED = 16,
	HP_REGEN = 3,
	PATROL_RANGE = 30,
	RETREAT_HEALTH = 0.25,
	RESPAWN_TIME = 8,
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

local function findTarget(monsterData)
	local root = monsterData.character.PrimaryPart or monsterData.character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local pos = root.Position

	local players = {}
	local bots = {}

	for _, p in Players:GetPlayers() do
		if p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				local d = (hrp.Position - pos).Magnitude
				if d < CONFIG.DETECTION_RANGE then
					table.insert(players, {type = "player", instance = p, position = hrp.Position, distance = d})
				end
			end
		end
	end

	-- SỬA: Sử dụng _G.BotManager để lấy TẤT CẢ bot từ tất cả managers
	local BotManager = _G.BotManager
	if BotManager and BotManager.GetActiveBots then
		local activeBots = BotManager.GetActiveBots()
		for bot, data in pairs(activeBots) do
			if data.state ~= "dead" then
				local hrp = bot:FindFirstChild("HumanoidRootPart")
				if hrp then
					local d = (hrp.Position - pos).Magnitude
					if d < CONFIG.DETECTION_RANGE then
						table.insert(bots, {type = "bot", instance = bot, position = hrp.Position, distance = d, team = data.team})
					end
				end
			end
		end
	else
		-- Fallback: Tìm bot trực tiếp trong workspace
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") and obj:GetAttribute("Team") then
				local hrp = obj:FindFirstChild("HumanoidRootPart")
				local h = obj:FindFirstChildOfClass("Humanoid")
				if hrp and h and h.Health > 0 then
					local d = (hrp.Position - pos).Magnitude
					if d < CONFIG.DETECTION_RANGE then
						table.insert(bots, {type = "bot", instance = obj, position = hrp.Position, distance = d, team = obj:GetAttribute("Team")})
					end
				end
			end
		end
	end

	table.sort(players, function(a, b) return a.distance < b.distance end)
	if #players > 0 and players[1].distance <= CONFIG.CHASE_RANGE then
		return players[1]
	end

	table.sort(bots, function(a, b) return a.distance < b.distance end)
	if #bots > 0 then
		return bots[1]
	end

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

local function moveTo(monsterData, pos)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if h and hrp then
		h:MoveTo(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
	end
end

local function regenerateHP(monsterData, deltaTime)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		h.Health = math.min(h.Health + CONFIG.HP_REGEN * deltaTime, h.MaxHealth)
	end
end

local function shouldRetreat(monsterData)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	return h and h.Health / h.MaxHealth < CONFIG.RETREAT_HEALTH
end

local function updateAI(monsterData)
	if monsterData.state == "dead" then return end

	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp or h.Health <= 0 then
		monsterData.state = "dead"
		return
	end

	if shouldRetreat(monsterData) then
		monsterData.state = "retreating"
		if monsterData.spawnPos then
			moveTo(monsterData, monsterData.spawnPos)
		end
		return
	end

	local target = findTarget(monsterData)
	if target then
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
		monsterData.state = "patrolling"
		if not monsterData.patrolTarget or tick() - monsterData.lastPatrol > 6 then
			monsterData.patrolTarget = monsterData.spawnPos + Vector3.new(math.random(-CONFIG.PATROL_RANGE, CONFIG.PATROL_RANGE), 0, math.random(-CONFIG.PATROL_RANGE, CONFIG.PATROL_RANGE))
			monsterData.lastPatrol = tick()
		end
		moveTo(monsterData, monsterData.patrolTarget)
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
	}

	activeMonsters[character] = monsterData

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			monsterData.state = "dead"
			task.delay(CONFIG.RESPAWN_TIME, function()
				if character and character.Parent then character.Parent = nil end
				activeMonsters[character] = nil
				spawnMonster(spawnPos)
			end)
		end)
	end

	print(string.format("[MonsterManager] Spawned: %s", name))
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
print("[MonsterManager] San sang!")

return MonsterManager