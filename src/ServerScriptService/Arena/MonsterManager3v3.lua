-- MonsterManager3v3 - Quai vat cho che do 3v3
-- Tan cong ca player va bot (uu tien player)
-- ServerScriptService.Arena.MonsterManager3v3

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


local CONFIG = {
	DETECTION_RANGE = 150,      -- Tang pham vi phat hien
	CHASE_RANGE = 120,           -- Tang pham vi truy duoi
	ATTACK_RANGE = 14,
	ATTACK_DAMAGE = 3,          -- Giam sat thuong xuong 3
	ATTACK_COOLDOWN = 1.5,      -- Giam cooldown
	MAX_HEALTH = 250,
	WALK_SPEED = 22,            -- Tang toc do
	CHASE_SPEED_MULT = 1.4,     -- Tang toc do khi truy duoi player
	HP_REGEN = 5,
	PATROL_RANGE = 40,
	RETREAT_HEALTH = 0.20,     -- Giam nguong rut lui
	RESPAWN_TIME = 12,
	MAX_MONSTERS = 12,
	AGGRESSIVE_CHASE = true,    -- Kich hoat che do truy duoi hung manh
	-- Safe zone config - players in their base are protected from monsters
	SAFE_ZONE_RADIUS = 100,     -- Radius around each team base where players are safe
	TEAM1_BASE_CENTER = Vector3.new(-385, 12, -7302),  -- Team1Base position
	TEAM2_BASE_CENTER = Vector3.new(113, 12, -7811),   -- Team2Base position
}

local activeMonsters = {}
local monsterCounter = 0

local function createMonsterCharacter(monsterName)
	local rigTemplate = workspace:FindFirstChild("RigTemplate") or workspace:FindFirstChild("Rig")
	if not rigTemplate then
		warn("[MonsterManager3v3] Khong tim thay RigTemplate hoac Rig!")
		return nil
	end

	local character = rigTemplate:Clone()
	character.Name = monsterName

	local animate = character:FindFirstChild("Animate")
	if animate then animate:Destroy() end

	-- Mau do dam hon cho 3v3 monster (manh hon)
	local monsterColor = Color3.fromRGB(150, 30, 30)

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

-- Check if a player is in their team's safe zone (base area)
local function isInSafeZone(player, position)
	local teamName = player.Team and player.Team.Name
	if not teamName then return false end
	
	if teamName == "Team1" then
		-- Check if player is near Team1 base
		local distanceToBase = (position - CONFIG.TEAM1_BASE_CENTER).Magnitude
		return distanceToBase <= CONFIG.SAFE_ZONE_RADIUS
	elseif teamName == "Team2" then
		-- Check if player is near Team2 base
		local distanceToBase = (position - CONFIG.TEAM2_BASE_CENTER).Magnitude
		return distanceToBase <= CONFIG.SAFE_ZONE_RADIUS
	end
	
	return false
end

local function findTarget(monsterData)
	local root = monsterData.character.PrimaryPart or monsterData.character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local pos = root.Position

	local players = {}
	local bots = {}

	-- Tim players trong pham vi - UU TIEN CAO
	for _, p in Players:GetPlayers() do
		if p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				-- Skip players in safe zone (their team's base)
				if isInSafeZone(p, hrp.Position) then
					continue
				end
				
				local d = (hrp.Position - pos).Magnitude
				-- Tang pham vi phat hien player
				if d < CONFIG.DETECTION_RANGE * 1.2 then
					table.insert(players, {type = "player", instance = p, position = hrp.Position, distance = d})
				end
			end
		end
	end

	-- Tim bots tu BotManager3v3
	if _G.BotManager3v3 then
		local activeBots = _G.BotManager3v3.GetActiveBots()
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
	end

	-- UU TIEN TUYET DOI: Player gan nhat
	table.sort(players, function(a, b) return a.distance < b.distance end)
	if #players > 0 then
		-- Luon truy duoi player neu trong pham vi phat hien
		local closestPlayer = players[1]
		if closestPlayer.distance <= CONFIG.CHASE_RANGE then
			return closestPlayer
		end
		-- Neu player xa hon, van truy duoi neu trong DETECTION_RANGE
		if CONFIG.AGGRESSIVE_CHASE and closestPlayer.distance <= CONFIG.DETECTION_RANGE then
			return closestPlayer
		end
	end

	-- Sau do den bot
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

	-- Retreat khi HP thap
	if shouldRetreat(monsterData) then
		monsterData.state = "retreating"
		-- Reset toc do khi rut lui
		h.WalkSpeed = CONFIG.WALK_SPEED
		if monsterData.spawnPos then
			moveTo(monsterData, monsterData.spawnPos)
		end
		return
	end

	local target = findTarget(monsterData)
	if target then
		-- Tang toc do khi truy duoi player
		if target.type == "player" then
			h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
		else
			h.WalkSpeed = CONFIG.WALK_SPEED
		end
		
		if target.distance <= CONFIG.ATTACK_RANGE then
			monsterData.state = "attacking"
			attack(monsterData, target)
		elseif target.distance <= CONFIG.CHASE_RANGE or (CONFIG.AGGRESSIVE_CHASE and target.type == "player") then
			-- Truy duoi neu trong CHASE_RANGE hoac AGGRESSIVE_CHASE voi player
			monsterData.state = "chasing"
			moveTo(monsterData, target.position)
			
			-- Log truy duoi player
			if target.type == "player" and (not monsterData.lastChaseLog or tick() - monsterData.lastChaseLog > 2) then
				monsterData.lastChaseLog = tick()
				print(string.format("[MonsterManager3v3] %s TRUY DUOI player %s (dist=%.1f)", 
					monsterData.name, target.instance.Name, target.distance))
			end
		else
			monsterData.state = "idle"
			h.WalkSpeed = CONFIG.WALK_SPEED
		end
	else
		-- Reset toc do khi khong co muc tieu
		h.WalkSpeed = CONFIG.WALK_SPEED
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
	local name = string.format("[MONSTER-3v3] Beast%d", monsterCounter)

	local character = createMonsterCharacter(name)
	if not character then return nil end

	character.Parent = workspace
	character:SetAttribute("IsMonster", true)
	character:SetAttribute("Mode", "3v3")

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

	return monsterData
end

local MonsterManager3v3 = {}

function MonsterManager3v3.SpawnMonster(pos)
	return spawnMonster(pos or Vector3.new(0, 10, 0))
end

function MonsterManager3v3.GetMonsterCount()
	local c = 0
	for _ in pairs(activeMonsters) do c = c + 1 end
	return c
end

function MonsterManager3v3.ClearAllMonsters()
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

_G.MonsterManager3v3 = MonsterManager3v3

return MonsterManager3v3
