-- MonsterManager3v3 - Quai vat cho che do 3v3
-- LOGIC CHINH:
-- 1. Monster danh den chet (khong bo chay khi HP thap)
-- 2. Player di ra khoi pham vi tan cong -> monster dung tan cong, quay ve spawn hoi mau
-- 3. Monster chi tan cong khi bi kich (aggro on hit)
-- ServerScriptService.Arena.MonsterManager3v3

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("[MonsterManager3v3] Khoi dong...")

local CONFIG = {
	-- ========== PHAM VI TAN CONG ==========
	-- Day la "lanh tho" cua quai - ban kinh tu vi tri spawn
	-- Player di ra khoi pham vi nay -> monster NGUNG tan cong, quay ve spawn hoi mau
	ATTACK_TERRITORY = 200,     -- Ban kinh lanh tho tu spawn (studs)

	-- Khoang cach toi da tu monster den player de giu aggro
	-- Neu player xa qua (vuot khoang nay) -> mat aggro, quay ve spawn
	LEASH_LOSE_RANGE = 150,    -- Khoang cach monster-player toi da de giu aggro

	ATTACK_RANGE = 14,         -- Pham vi danh gan
	ATTACK_DAMAGE = 15,
	ATTACK_COOLDOWN = 1.5,
	MAX_HEALTH = 250,
	WALK_SPEED = 22,
	CHASE_SPEED_MULT = 1.4,   -- Tang toc do khi truy duoi

	-- ========== HOI MAU ==========
	HP_REGEN_COMBAT = 0,       -- KHONG hoi mau khi dang combat
	HP_REGEN_IDLE = 5,        -- Hoi mau khi idle (dung yen tai spawn)
	HP_REGEN_RETURNING = 15,  -- Hoi mau nhanh khi dang quay ve spawn

	-- ========== RESPAWN ==========
	RESPAWN_TIME = 10,
	MAX_MONSTERS = 12,

	-- ========== SAFE ZONE (khu vung an toan cua team) ==========
	SAFE_ZONE_RADIUS = 100,
	TEAM1_BASE_CENTER = Vector3.new(-385, 12, -7302),
	TEAM2_BASE_CENTER = Vector3.new(113, 12, -7811),
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
		local distanceToBase = (position - CONFIG.TEAM1_BASE_CENTER).Magnitude
		return distanceToBase <= CONFIG.SAFE_ZONE_RADIUS
	elseif teamName == "Team2" then
		local distanceToBase = (position - CONFIG.TEAM2_BASE_CENTER).Magnitude
		return distanceToBase <= CONFIG.SAFE_ZONE_RADIUS
	end

	return false
end

-- ========== KIEM TRA PLAYER CO NAM TRONG PHAM VI TAN CONG CUA QUAI KHONG ==========
-- Player phai nam trong ATTACK_TERRITORY (tu spawn) VA khong xa monster qua LEASH_LOSE_RANGE
local function isTargetInTerritory(monsterData, targetPosition)
	local distFromSpawn = (targetPosition - monsterData.spawnPos).Magnitude
	return distFromSpawn <= CONFIG.ATTACK_TERRITORY
end

local function isTargetInRange(monsterPosition, targetPosition)
	local distFromMonster = (targetPosition - monsterPosition).Magnitude
	return distFromMonster <= CONFIG.LEASH_LOSE_RANGE
end

local moveTo

-- ========== QUAY VE SPAWN VA HOI MAU ==========
-- Monster mat aggro -> quay ve spawn, hoi mau nhanh
local function returnToSpawn(monsterData)
	monsterData.state = "returning"
	monsterData.hasAggro = false
	monsterData.aggroTarget = nil
	monsterData.lastKnownTargetPos = nil
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	if h then
		h.WalkSpeed = CONFIG.WALK_SPEED
	end
	moveTo(monsterData, monsterData.spawnPos)
end

-- ========== TIM MUC TIEU ==========
-- Chi tim khi da co aggro (bi danh)
-- Kiem tra 2 dieu kien de giu aggro:
--   1. Player con trong ATTACK_TERRITORY (tu spawn)
--   2. Player khong xa monster qua LEASH_LOSE_RANGE
local function findTarget(monsterData)
	-- CHUA BI DANH -> KHONG TIM MUC TIEU
	if not monsterData.hasAggro then
		return nil
	end

	local root = monsterData.character.PrimaryPart or monsterData.character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local monsterPos = root.Position

	-- ========== KIEM TRA AGGRO TARGET (player da danh minh) ==========
	if monsterData.aggroTarget and monsterData.aggroTarget.Parent then
		local targetChar = monsterData.aggroTarget.Character
		if targetChar then
			local h = targetChar:FindFirstChildOfClass("Humanoid")
			local hrp = targetChar:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				-- Kiem tra: player khong o safe zone
				if not isInSafeZone(monsterData.aggroTarget, hrp.Position) then
					-- KIEM TRA 2 DIEU KIEN DE GIU AGGRO:
					-- 1. Player con trong ATTACK_TERRITORY (tu spawn)
					local inTerritory = isTargetInTerritory(monsterData, hrp.Position)
					-- 2. Player khong xa monster qua LEASH_LOSE_RANGE
					local inRange = isTargetInRange(monsterPos, hrp.Position)

					if inTerritory and inRange then
						monsterData.lastKnownTargetPos = hrp.Position
						local d = (hrp.Position - monsterPos).Magnitude
						return {type = "player", instance = monsterData.aggroTarget, position = hrp.Position, distance = d}
					end
				end
			end
		end
		-- Player da chet / ve base / ra khoi pham vi tan cong -> MAT AGGRO
		monsterData.aggroTarget = nil
		monsterData.lastKnownTargetPos = nil
	end

	-- ========== TIM PLAYER KHAC GAN NHAT (neu van con aggro) ==========
	local players = {}
	local bots = {}

	for _, p in Players:GetPlayers() do
		if p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				if isInSafeZone(p, hrp.Position) then continue end
				-- Kiem tra player nam trong territory VA trong range
				if isTargetInTerritory(monsterData, hrp.Position) and isTargetInRange(monsterPos, hrp.Position) then
					local d = (hrp.Position - monsterPos).Magnitude
					table.insert(players, {type = "player", instance = p, position = hrp.Position, distance = d})
				end
			end
		end
	end

	if _G.BotManager3v3 then
		local activeBots = _G.BotManager3v3.GetActiveBots()
		for bot, data in pairs(activeBots) do
			if data.state ~= "dead" then
				local hrp = bot:FindFirstChild("HumanoidRootPart")
				if hrp then
					if isTargetInTerritory(monsterData, hrp.Position) and isTargetInRange(monsterPos, hrp.Position) then
						local d = (hrp.Position - monsterPos).Magnitude
						table.insert(bots, {type = "bot", instance = bot, position = hrp.Position, distance = d, team = data.team})
					end
				end
			end
		end
	end

	-- Uu tien player gan nhat
	table.sort(players, function(a, b) return a.distance < b.distance end)
	if #players > 0 then
		return players[1]
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

moveTo = function(monsterData, pos)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if h and hrp then
		h:MoveTo(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
	end
end

-- ========== HOI MAU ==========
-- Combat: 0 (khong hoi) | Returning: 15 (nhanh) | Idle: 5 (binh thuong)
local function regenerateHP(monsterData, deltaTime)
	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end

	if monsterData.hasAggro then
		-- Dang combat -> KHONG hoi mau
		h.Health = math.min(h.Health + CONFIG.HP_REGEN_COMBAT * deltaTime, h.MaxHealth)
	elseif monsterData.state == "returning" then
		-- Dang quay ve spawn -> hoi mau nhanh
		h.Health = math.min(h.Health + CONFIG.HP_REGEN_RETURNING * deltaTime, h.MaxHealth)
	else
		-- Idle tai spawn -> hoi mau binh thuong
		h.Health = math.min(h.Health + CONFIG.HP_REGEN_IDLE * deltaTime, h.MaxHealth)
	end
end

-- ========== UPDATE AI CHINH ==========
-- Logic:
-- 1. Monster danh den chet (khong retreat)
-- 2. Player ra khoi pham vi tan cong -> quay ve spawn hoi mau
local function updateAI(monsterData)
	if monsterData.state == "dead" then return end

	local h = monsterData.character:FindFirstChildOfClass("Humanoid")
	local hrp = monsterData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp or h.Health <= 0 then
		monsterData.state = "dead"
		return
	end

	-- ========== TRANG THAI DANG QUAY VE SPAWN ==========
	if monsterData.state == "returning" then
		-- Neu bi danh lai khi dang quay ve -> quay lai danh
		if monsterData.hasAggro and monsterData.aggroTarget then
			monsterData.state = "chasing"
			h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
			-- Tiep tuc xu ly aggro o duoi (khong return)
		else
			local distToSpawn = (hrp.Position - monsterData.spawnPos).Magnitude
			if distToSpawn <= 8 then
				-- Da ve den spawn -> idle, hoi mau binh thuong
				monsterData.state = "idle"
				monsterData.hasAggro = false
				monsterData.aggroTarget = nil
			else
				-- Van dang di ve spawn
				moveTo(monsterData, monsterData.spawnPos)
				return
			end
		end
	end

	-- ========== KHONG CO AGGRO -> DUNG YEN TAI SPAWN ==========
	if not monsterData.hasAggro then
		local distFromSpawn = (hrp.Position - monsterData.spawnPos).Magnitude
		if distFromSpawn > 15 then
			-- Di lac khoi spawn -> quay ve
			returnToSpawn(monsterData)
			return
		end
		-- Dung yen tai spawn, cho bi danh
		monsterData.state = "idle"
		return
	end

	-- ========== CO AGGRO -> TIM MUC TIEU ==========
	local target = findTarget(monsterData)

	if target then
		-- Co muc tieu hop le (trong pham vi tan cong)
		if target.type == "player" then
			h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
		else
			h.WalkSpeed = CONFIG.WALK_SPEED
		end

		if target.distance <= CONFIG.ATTACK_RANGE then
			-- Gan du -> DANH
			monsterData.state = "attacking"
			attack(monsterData, target)
		else
			-- Con xa -> TRUY DUOI
			monsterData.state = "chasing"
			moveTo(monsterData, target.position)
		end
	else
		-- KHONG TIM THAY MUC TIEU (player da ra khoi pham vi tan cong hoac chet)
		-- -> MAT AGGRO, QUAY VE SPAWN HOI MAU
		returnToSpawn(monsterData)
	end
end

local function spawnMonster(spawnPos, respawnTime)
	local count = 0
	for _ in pairs(activeMonsters) do count = count + 1 end
	if count >= CONFIG.MAX_MONSTERS then return nil end

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
		respawnTime = respawnTime or CONFIG.RESPAWN_TIME, -- Thoi gian hoi sinh rieng cho tung monster
		hasAggro = false,         -- Monster chi tan cong khi bi danh
		aggroTarget = nil,         -- Player da danh monster
		lastKnownTargetPos = nil,  -- Vi tri cuoi cung thay target
	}

	activeMonsters[character] = monsterData

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			monsterData.state = "dead"
			monsterData.hasAggro = false
			monsterData.aggroTarget = nil
			task.delay(monsterData.respawnTime, function()
				if character and character.Parent then character.Parent = nil end
				activeMonsters[character] = nil
				spawnMonster(spawnPos, monsterData.respawnTime)
			end)
		end)

		-- ========== AGGRO: Monster bi danh -> bat dau truy duoi ==========
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < humanoid.MaxHealth and monsterData.state ~= "dead" then
				-- Monster bi gay damage -> kich hoat aggro
				monsterData.hasAggro = true

				-- Tim player gan nhat lam aggro target (chi trong pham vi tan cong)
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local closestPlayer = nil
					local closestDist = math.huge
					for _, p in Players:GetPlayers() do
						if p.Character then
							local pH = p.Character:FindFirstChildOfClass("Humanoid")
							local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
							if pH and pH.Health > 0 and pHrp then
								-- Chi aggro player trong pham vi tan cong
								if isTargetInTerritory(monsterData, pHrp.Position) and isTargetInRange(hrp.Position, pHrp.Position) then
									local d = (pHrp.Position - hrp.Position).Magnitude
									if d < closestDist then
										closestDist = d
										closestPlayer = p
									end
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

	print(string.format("[MonsterManager3v3] Spawned: %s tai %s", name, tostring(spawnPos)))
	return monsterData
end

local MonsterManager3v3 = {}

function MonsterManager3v3.SpawnMonster(pos, respawnTime)
	return spawnMonster(pos or Vector3.new(0, 10, 0), respawnTime)
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
print("[MonsterManager3v3] San sang!")

return MonsterManager3v3