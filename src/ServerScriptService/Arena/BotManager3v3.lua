-- BotManager3v3 - Bot AI cho che do 3v3 voi he thong 3 lane (Left, Mid, Right)
-- ServerScriptService.Arena.BotManager3v3 (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("[BotManager3v3] Khoi dong...")

local CONFIG = {
	DETECTION_RANGE = 120,
	ATTACK_RANGE = 12,
	BASE_ATTACK_RANGE = 25,
	ATTACK_COOLDOWN = 0.78,
	ATTACK_DAMAGE = 12,
	BASE_ATTACK_DAMAGE = 25,
	RETREAT_HEALTH = 0.15,
	RECOVERY_HEALTH = 0.45,
	HP_REGEN = 5,
	BOT_MAX_HEALTH = 150,
	PATROL_RANGE = 35,
	CHASE_RANGE = 80,
	PLAYER_CHASE_RANGE = 100,
	MELEE_THREAT_RANGE = 10,
	BASE_DEFENSE_RANGE = 45,
	RESPAWN_TIME = 5,
	TEAM_COORDINATION = false,
	GROUP_ATTACK = false,
	MOVE_REFRESH = 0.25,
	STUCK_SECONDS = 0.8,
	WALK_SPEED = 24,
	CHASE_SPEED_MULT = 1.3,
	BASE_CACHE_TTL = 1.25,
	AGGRESSIVE_PLAYER_CHASE = false,  -- TAT: bot ngung duoi player khi qua xa
	MAX_CHASE_DISTANCE = 150,        -- Khoang cach toi da tu vi tri spawn, vuot qua thi quay ve lane

	-- ========== LANE SYSTEM CONFIG ==========
	LANE_OFFSET = 80,           -- Khoang cach le trai/phai so voi duong giua (studs)
	WAYPOINT_REACH_DIST = 8,    -- Khoang cach de coi nhu den waypoint
}

-- ========== MAP BOUNDARIES ==========
local MAP_BOUNDS = {
	["Map1v1"] = {
		center = Vector3.new(49.9, 0, -1032.7),
		size = Vector3.new(1074, 100, 666),
		minX = 49.9 - 537,
		maxX = 49.9 + 537,
		minZ = -1032.7 - 333,
		maxZ = -1032.7 + 333,
	},
	["Map2v2"] = {
		center = Vector3.new(49.9, 0, -2087.7),
		size = Vector3.new(1074, 100, 666),
		minX = 49.9 - 537,
		maxX = 49.9 + 537,
		minZ = -2087.7 - 333,
		maxZ = -2087.7 + 333,
	},
	["Map3v3"] = {
		center = Vector3.new(-150.5, 0, -7539.9),
		size = Vector3.new(669, 100, 668),
		minX = -485.0,
		maxX = 184.0,
		minZ = -7874.1,
		maxZ = -7205.7,
	},
}

local function getMapFromPosition(pos)
	for mapName, bounds in pairs(MAP_BOUNDS) do
		if pos.X >= bounds.minX and pos.X <= bounds.maxX and
		   pos.Z >= bounds.minZ and pos.Z <= bounds.maxZ then
			return mapName
		end
	end
	local nearestMap = nil
	local nearestDist = math.huge
	for mapName, bounds in pairs(MAP_BOUNDS) do
		local dist = (Vector3.new(bounds.center.X, 0, bounds.center.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestMap = mapName
		end
	end
	return nearestMap
end

local function isPositionInMap(pos, mapName)
	local bounds = MAP_BOUNDS[mapName]
	if not bounds then return false end
	return pos.X >= bounds.minX and pos.X <= bounds.maxX and
	       pos.Z >= bounds.minZ and pos.Z <= bounds.maxZ
end

local function clampToMap(pos, mapName)
	local bounds = MAP_BOUNDS[mapName]
	if not bounds then return pos end
	return Vector3.new(
		math.clamp(pos.X, bounds.minX + 10, bounds.maxX - 10),
		pos.Y,
		math.clamp(pos.Z, bounds.minZ + 10, bounds.maxZ - 10)
	)
end

-- ========== FIND BASE IN MAP ==========
local function findTeamBaseInMap(teamName, mapName)
	local mapsFolder = workspace:FindFirstChild("Maps")
	if mapsFolder then
		local mapFolder = mapsFolder:FindFirstChild(mapName or "")
		if mapFolder then
			for _, obj in ipairs(mapFolder:GetChildren()) do
				if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
					return obj
				end
			end
		end
		for _, mf in pairs(mapsFolder:GetChildren()) do
			for _, obj in pairs(mf:GetDescendants()) do
				if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
					return obj
				end
			end
		end
	end
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
			return obj
		end
	end
	return nil
end

-- ========== LANE SYSTEM ==========
local LANE_NAMES = {"Left", "Mid", "Right"}
local laneAssignmentCounter = {Team1 = 0, Team2 = 0}

-- ========== GENERATE LANE WAYPOINTS ==========
local function generateLaneWaypoints(myBase, enemyBase, laneName, mapName)
	local myPos = myBase:GetPivot().Position
	local enemyPos = enemyBase:GetPivot().Position

	local enemyTower = enemyBase:FindFirstChild("Tower")
	if enemyTower and enemyTower:IsA("BasePart") then
		enemyPos = enemyTower.Position
	end
	local myTower = myBase:FindFirstChild("Tower")
	if myTower and myTower:IsA("BasePart") then
		myPos = myTower.Position
	end

	local dir = (enemyPos - myPos)
	dir = Vector3.new(dir.X, 0, dir.Z)
	local dist = dir.Magnitude
	if dist < 1 then
		dir = Vector3.new(0, 0, -1)
		dist = 1
	end
	dir = dir.Unit

	local perp = Vector3.new(-dir.Z, 0, dir.X)

	local waypoints = {}

	if laneName == "Mid" then
		local wp1 = myPos + dir * (dist * 0.3)
		local wp2 = myPos + dir * (dist * 0.6)
		table.insert(waypoints, Vector3.new(wp1.X, 3, wp1.Z))
		table.insert(waypoints, Vector3.new(wp2.X, 3, wp2.Z))
	elseif laneName == "Left" then
		local offset = perp * CONFIG.LANE_OFFSET
		local wp1 = myPos + dir * (dist * 0.2) + offset * 0.5
		local wp2 = myPos + dir * (dist * 0.5) + offset
		local wp3 = myPos + dir * (dist * 0.8) + offset * 0.5
		table.insert(waypoints, Vector3.new(wp1.X, 3, wp1.Z))
		table.insert(waypoints, Vector3.new(wp2.X, 3, wp2.Z))
		table.insert(waypoints, Vector3.new(wp3.X, 3, wp3.Z))
	elseif laneName == "Right" then
		local offset = perp * (-CONFIG.LANE_OFFSET)
		local wp1 = myPos + dir * (dist * 0.2) + offset * 0.5
		local wp2 = myPos + dir * (dist * 0.5) + offset
		local wp3 = myPos + dir * (dist * 0.8) + offset * 0.5
		table.insert(waypoints, Vector3.new(wp1.X, 3, wp1.Z))
		table.insert(waypoints, Vector3.new(wp2.X, 3, wp2.Z))
		table.insert(waypoints, Vector3.new(wp3.X, 3, wp3.Z))
	end

	if mapName then
		for i, wp in ipairs(waypoints) do
			waypoints[i] = clampToMap(wp, mapName)
		end
	end

	return waypoints
end

local activeBots = {}
local botCounter = 0
local botDeathCounts = {}

local function createBotCharacter(botName, teamName)
	local rigTemplate = workspace:FindFirstChild("Rig")
	if not rigTemplate then
		warn("[BotManager3v3] Khong tim thay workspace.Rig")
		return nil
	end

	local character = rigTemplate:Clone()
	character.Name = botName

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		character.PrimaryPart = hrp
	end

	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local teamColor3 = teamName == "Team1" and Color3.fromRGB(0, 100, 255) or Color3.fromRGB(255, 50, 50)

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Color = teamColor3
			part.Anchored = false
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = CONFIG.WALK_SPEED
		humanoid.AutoRotate = true
	end

	local head = character:FindFirstChild("Head")
	if head then
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "BotNameDisplay"
		billboardGui.Adornee = head
		billboardGui.Size = UDim2.new(4, 0, 1.2, 0)
		billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
		billboardGui.AlwaysOnTop = true
		billboardGui.Parent = character

		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "NameLabel"
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = botName
		textLabel.TextColor3 = teamColor3
		textLabel.TextStrokeTransparency = 0
		textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		textLabel.TextSize = 14
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Parent = billboardGui
	end

	return character
end

local baseModelCache = { t = -1e9, Team1 = {}, Team2 = {} }

local function refreshBaseModelCache()
	local now = tick()
	if now - baseModelCache.t < CONFIG.BASE_CACHE_TTL then
		return
	end
	baseModelCache.t = now
	baseModelCache.Team1 = {}
	baseModelCache.Team2 = {}

	local mapsFolder = workspace:FindFirstChild("Maps")
	if mapsFolder then
		for _, mapFolder in pairs(mapsFolder:GetChildren()) do
			for _, inst in pairs(mapFolder:GetDescendants()) do
				if inst:IsA("Model") then
					if string.find(inst.Name, "Team1Base", 1, true) then
						table.insert(baseModelCache.Team1, inst)
					end
					if string.find(inst.Name, "Team2Base", 1, true) then
						table.insert(baseModelCache.Team2, inst)
					end
				end
			end
		end
	end

	for _, inst in workspace:GetChildren() do
		if inst:IsA("Model") then
			if string.find(inst.Name, "Team1Base", 1, true) then
				table.insert(baseModelCache.Team1, inst)
			end
			if string.find(inst.Name, "Team2Base", 1, true) then
				table.insert(baseModelCache.Team2, inst)
			end
		end
	end
end

local function findNearestEnemy(botData)
	local root = botData.character.PrimaryPart or botData.character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local pos = root.Position
	local nearest, nearestDist = nil, CONFIG.DETECTION_RANGE

	for _, p in Players:GetPlayers() do
		local playerTeam = p.Team and p.Team.Name
		if playerTeam and playerTeam ~= botData.team and p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				local d = (hrp.Position - pos).Magnitude
				if d < CONFIG.PLAYER_CHASE_RANGE then
					if d < nearestDist then
						nearest, nearestDist = { type = "player", instance = p, position = hrp.Position, distance = d }, d
					end
				end
			end
		end
	end

	for bot, data in pairs(activeBots) do
		if data.team ~= botData.team and data.state ~= "dead" then
			local hrp = bot:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (hrp.Position - pos).Magnitude
				if d < nearestDist then
					nearest, nearestDist = { type = "bot", instance = bot, position = hrp.Position, distance = d, team = data.team }, d
				end
			end
		end
	end

	return nearest
end

local function findEnemyBase(botData)
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local currentMap = getMapFromPosition(hrp.Position)
	if not currentMap then
		return nil
	end

	local enemyTeam = botData.team == "Team1" and "Team2" or "Team1"
	refreshBaseModelCache()
	local list = baseModelCache[enemyTeam]
	if not list or #list == 0 then
		return nil
	end

	local best, bestDist = nil, math.huge
	for _, obj in ipairs(list) do
		if obj.Parent then
			local tower = obj:FindFirstChild("Tower")
			local pos = (tower and tower:IsA("BasePart")) and tower.Position or obj:GetPivot().Position

			if isPositionInMap(pos, currentMap) then
				local d = (pos - hrp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = {
						type = "base",
						instance = obj,
						position = pos,
						targetPart = tower,
						distance = d,
						mapName = currentMap,
					}
				end
			end
		end
	end

	return best
end

local function regenerateHP(botData, deltaTime)
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then
		return
	end

	local regenRate = CONFIG.HP_REGEN
	if botData.state == "retreating" then
		regenRate = CONFIG.HP_REGEN * 1.5
	end

	h.Health = math.min(h.Health + regenRate * deltaTime, h.MaxHealth)
end

local function attack(botData, target)
	local now = tick()
	if now - botData.lastAttack < CONFIG.ATTACK_COOLDOWN then
		return
	end
	botData.lastAttack = now

	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if hrp and target.position then
		hrp.CFrame = CFrame.new(hrp.Position, target.position)
	end

	if target.type == "player" then
		local h = target.instance.Character and target.instance.Character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)
			if h.Health <= 0 then
				if _G.MatchEndConditions then
					_G.MatchEndConditions.RecordKill({ name = botData.name, team = botData.team }, target.instance)
				end
				if _G.MVPSystem and _G.MVPSystem.RecordKill then
					_G.MVPSystem.RecordKill(botData.name, target.instance.Name)
				end
			end
		end
	elseif target.type == "bot" then
		local h = target.instance:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)
			if h.Health <= 0 then
				local victimTeam = target.team
				if not victimTeam and activeBots[target.instance] then
					victimTeam = activeBots[target.instance].team
				end
				if _G.MatchEndConditions then
					_G.MatchEndConditions.RecordKill(
						{ name = botData.name, team = botData.team },
						{ name = target.instance.Name, team = victimTeam }
					)
				end
				if _G.MVPSystem and _G.MVPSystem.RecordKill then
					_G.MVPSystem.RecordKill(botData.name, target.instance.Name)
				end
			end
		end
	elseif target.type == "base" then
		local tname = target.instance.Name
		local defTeam = string.find(tname, "Team1", 1, true) and "Team1" or "Team2"
		botAttackBase(target.instance, defTeam, botData.name, botData.team, CONFIG.BASE_ATTACK_DAMAGE)
	end
end

-- ========== SMART MOVE WITH STUCK DETECTION ==========
local function smartMoveTo(botData, worldPos)
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp then
		return
	end

	local currentMap = getMapFromPosition(hrp.Position)
	local pos = Vector3.new(worldPos.X, hrp.Position.Y, worldPos.Z)
	if currentMap then
		pos = clampToMap(pos, currentMap)
	end

	-- Stuck detection
	local now = tick()
	botData._lastSamplePos = botData._lastSamplePos or hrp.Position
	botData._stuckSince = botData._stuckSince or now

	if (hrp.Position - botData._lastSamplePos).Magnitude < 0.2 then
		if now - botData._stuckSince > CONFIG.STUCK_SECONDS then
			if h.FloorMaterial ~= Enum.Material.Air then
				h:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			local jitter = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			local newPos = hrp.Position + jitter
			if currentMap then
				newPos = clampToMap(newPos, currentMap)
			end
			h:MoveTo(newPos)
			botData._stuckSince = now
			botData.lastMoveTime = 0
		end
	else
		botData._lastSamplePos = hrp.Position
		botData._stuckSince = now
	end

	botData.lastMoveGoal = botData.lastMoveGoal or pos
	botData.lastMoveTime = botData.lastMoveTime or 0
	if (pos - botData.lastMoveGoal).Magnitude > 3 or (now - botData.lastMoveTime) >= CONFIG.MOVE_REFRESH then
		botData.lastMoveGoal = pos
		botData.lastMoveTime = now
		h:MoveTo(pos)
	end
end

-- ========== UPDATE AI WITH LANE SYSTEM ==========
local function updateAI(botData)
	if botData.state == "dead" then
		return
	end

	local h = botData.character:FindFirstChildOfClass("Humanoid")
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")

	if not h then
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end
	if not hrp then
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end
	if h.Health <= 0 then
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end

	-- Void check
	if hrp.Position.Y < -50 then
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end

	-- ========== KIEM TRA: Bot di qua xa tu spawn -> ngung duoi, quay ve lane ==========
	local spawnPos = botData.spawnPos or (botData.waypoints and botData.waypoints[1])
	if spawnPos then
		local distFromSpawn = (hrp.Position - spawnPos).Magnitude
		if distFromSpawn > CONFIG.MAX_CHASE_DISTANCE then
			botData.state = "following_lane"
			botData.currentTarget = nil
			h.WalkSpeed = CONFIG.WALK_SPEED
			if base then
				smartMoveTo(botData, base.position)
			end
			return
		end
	end

	-- ========== RUT LUI KHI HP THAP ==========
	local healthRatio = h.Health / h.MaxHealth
	if healthRatio < CONFIG.RETREAT_HEALTH then
		botData.wasRetreating = true
		botData.state = "retreating"
		botData.currentTarget = nil
		local myBase = findTeamBaseInMap(botData.team, botData._currentMap)
		if myBase then
			smartMoveTo(botData, myBase:GetPivot().Position)
		end
		return
	end

	-- ========== QUAY LAI TAN CONG KHI HP HOI PHUC ==========
	if botData.wasRetreating and healthRatio >= CONFIG.RECOVERY_HEALTH then
		botData.wasRetreating = false
		botData.state = "following_lane"
		botData.currentWaypointIndex = 1
		print(string.format("[BotManager3v3] %s (Lane %s) hoi HP, quay lai tan cong!", botData.name, botData.lane))
	end

	-- ========== TIM MUC TIEU ==========
	local enemy = findNearestEnemy(botData)
	local base = findEnemyBase(botData)

	-- ========== UU TIEN TRUY DUOI PLAYER ==========
	if enemy and enemy.type == "player" and enemy.distance <= CONFIG.PLAYER_CHASE_RANGE then
		h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
		botData.currentTarget = enemy.instance.Character

		if enemy.distance <= CONFIG.ATTACK_RANGE then
			botData.state = "attacking_player"
			attack(botData, enemy)
		else
			botData.state = "chasing_player"
			smartMoveTo(botData, enemy.position)
		end
		return
	end

	-- ========== TAN CONG ENEMY GAN ==========
	if enemy and enemy.distance <= CONFIG.ATTACK_RANGE then
		botData.state = "defending_while_pushing"
		attack(botData, enemy)
		if base then
			smartMoveTo(botData, base.position)
		end
		return
	end

	-- ========== CHASE ENEMY GAN ==========
	if enemy and enemy.distance <= CONFIG.CHASE_RANGE then
		botData.state = "chasing_player"
		smartMoveTo(botData, enemy.position)
		return
	end

	-- ========== DI THEO LANE WAYPOINTS DEN BASE DICH ==========
	if base then
		botData.currentTarget = nil
		h.WalkSpeed = CONFIG.WALK_SPEED

		-- Tan cong base khi den gan
		if base.distance <= CONFIG.BASE_ATTACK_RANGE then
			botData.state = "attacking_base"
			attack(botData, base)
			return
		end

		-- Di theo lane waypoints
		botData.state = "following_lane"
		local waypoints = botData.waypoints
		if waypoints and #waypoints > 0 and botData.currentWaypointIndex <= #waypoints then
			local targetWP = waypoints[botData.currentWaypointIndex]
			local distToWP = (hrp.Position - targetWP).Magnitude
			if distToWP < CONFIG.WAYPOINT_REACH_DIST then
				botData.currentWaypointIndex = botData.currentWaypointIndex + 1
				if botData.currentWaypointIndex <= #waypoints then
					smartMoveTo(botData, waypoints[botData.currentWaypointIndex])
				else
					smartMoveTo(botData, base.position)
				end
			else
				smartMoveTo(botData, targetWP)
			end
		else
			-- Khong co waypoints hoac da di het, di thang den base
			smartMoveTo(botData, base.position)
		end
		return
	end

	-- ========== KHONG TIM THAY BASE: PATROL ==========
	botData.state = "patrolling"
	botData.currentTarget = nil
	local currentMap = botData._currentMap or getMapFromPosition(hrp.Position)
	if not botData.patrolTarget or tick() - botData.lastPatrol > 3 then
		botData.patrolTarget = hrp.Position + Vector3.new(
			math.random(-CONFIG.PATROL_RANGE, CONFIG.PATROL_RANGE),
			0,
			math.random(-CONFIG.PATROL_RANGE, CONFIG.PATROL_RANGE)
		)
		if currentMap then
			botData.patrolTarget = clampToMap(botData.patrolTarget, currentMap)
		end
		botData.lastPatrol = tick()
	end
	if botData.patrolTarget then
		smartMoveTo(botData, botData.patrolTarget)
	end
end

-- ========== SPAWN BOT ==========
local function spawnBot(teamName, spawnPos, laneName)
	botCounter = botCounter + 1

	-- Xac dinh map
	local currentMap = getMapFromPosition(spawnPos)

	-- Assign lane vong tron neu khong chi dinh
	if not laneName then
		laneAssignmentCounter[teamName] = laneAssignmentCounter[teamName] + 1
		local laneIndex = ((laneAssignmentCounter[teamName] - 1) % #LANE_NAMES) + 1
		laneName = LANE_NAMES[laneIndex]
	end

	local name = string.format("[BOT-3v3] %s%d", laneName, botCounter)

	-- Tim base de tao waypoints
	local enemyTeam = teamName == "Team1" and "Team2" or "Team1"
	local myBase = findTeamBaseInMap(teamName, currentMap)
	local enemyBase = findTeamBaseInMap(enemyTeam, currentMap)

	local waypoints = {}
	if myBase and enemyBase then
		waypoints = generateLaneWaypoints(myBase, enemyBase, laneName, currentMap)
	end

	local character = createBotCharacter(name, teamName)
	if not character then
		return nil
	end

	character.Parent = workspace
	character:SetAttribute("Team", teamName)

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	character:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 10, 0)))

	task.delay(0.2, function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
	end)

	local botData = {
		name = name,
		team = teamName,
		character = character,
		state = "following_lane",
		lastAttack = 0,
		patrolTarget = nil,
		lastPatrol = 0,
		mode = "3v3",
		currentTarget = nil,

		-- Lane system
		lane = laneName,
		waypoints = waypoints,
		currentWaypointIndex = 1,
		wasRetreating = false,
		_currentMap = currentMap,

		-- Smart move
		lastMoveGoal = nil,
		lastMoveTime = 0,
		_lastSamplePos = nil,
		_stuckSince = tick(),
	}

	activeBots[character] = botData

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[BotManager3v3] Character khong co Humanoid")
		return botData
	end

	humanoid.Died:Connect(function()
		botData.state = "dead"
		botData.currentTarget = nil
		botDeathCounts[name] = (botDeathCounts[name] or 0) + 1
		local respawnTime = math.min(CONFIG.RESPAWN_TIME + (botDeathCounts[name] - 1) * 2, 15)

		print(string.format("[BotManager3v3] %s (Lane %s) da chet!", name, laneName))

		task.delay(respawnTime, function()
			if character and character.Parent then
				character.Parent = nil
			end
			activeBots[character] = nil

			-- Respawn bot cung lane
			local teamBase = findTeamBaseInMap(teamName, currentMap)
			if teamBase then
				local respawnPos = teamBase:GetPivot().Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
				spawnBot(teamName, respawnPos, laneName)
				print(string.format("[BotManager3v3] %s (Lane %s) da respawn!", name, laneName))
			end
		end)
	end)

	-- Init MVP stats
	if _G.MVPSystem and _G.MVPSystem.InitPlayerStats then
		_G.MVPSystem.InitPlayerStats(name, teamName)
	end

	print(string.format("[BotManager3v3] Spawned: %s (Team: %s, Lane: %s)", name, teamName, laneName))
	return botData
end

-- ========== BOT ATTACK BASE FUNCTION ==========
local function botAttackBase(baseModel, defendingTeam, attackerName, attackerTeam, damage)
	if not baseModel then return end

	local baseHumanoid = baseModel:FindFirstChild("BaseHumanoid")
	if not baseHumanoid then
		baseHumanoid = baseModel:FindFirstChildOfClass("Humanoid")
	end

	if not baseHumanoid then
		warn("[BotManager3v3] Khong tim thay BaseHumanoid trong " .. baseModel.Name)
		return
	end

	local oldHealth = baseHumanoid.Health
	baseHumanoid.Health = math.max(0, baseHumanoid.Health - damage)

	print(string.format("[BotManager3v3] %s (%s) danh %s: %.0f damage (HP: %.0f -> %.0f)",
		attackerName, attackerTeam, baseModel.Name, damage, oldHealth, baseHumanoid.Health))

	if baseHumanoid.Health <= 0 then
		print(string.format("[BotManager3v3] %s da bi HUY BOI %s (%s)!", baseModel.Name, attackerName, attackerTeam))

		if _G.MatchEndConditions and _G.MatchEndConditions.RecordBaseDestroyed then
			_G.MatchEndConditions.RecordBaseDestroyed(defendingTeam, attackerTeam)
		end
	end
end

-- Export function
_G.BotAttackBase = botAttackBase

local BotManager3v3 = {}

function BotManager3v3.SpawnBotForTeam(teamName, pos, laneName)
	return spawnBot(teamName, pos or Vector3.new(0, 10, 0), laneName)
end

-- ========== SPAWN 3 LANE BOTS ==========
function BotManager3v3.SpawnLaneBots(teamName, spawnPos)
	local currentMap = getMapFromPosition(spawnPos)
	local spawned = {}
	for _, laneName in ipairs(LANE_NAMES) do
		local offset
		if laneName == "Left" then
			offset = Vector3.new(math.random(-15, -5), 0, math.random(-5, 5))
		elseif laneName == "Mid" then
			offset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		else -- Right
			offset = Vector3.new(math.random(5, 15), 0, math.random(-5, 5))
		end
		local botData = spawnBot(teamName, spawnPos + offset, laneName)
		if botData then
			table.insert(spawned, botData)
		end
	end
	print(string.format("[BotManager3v3] Spawned %d lane bots cho %s (Left, Mid, Right)", #spawned, teamName))
	return spawned
end

function BotManager3v3.GetActiveBots()
	return activeBots
end

function BotManager3v3.GetBotCount()
	local c = 0
	for _ in pairs(activeBots) do
		c = c + 1
	end
	return c
end

function BotManager3v3.GetBotCountByTeam(teamName)
	local c = 0
	for _, data in pairs(activeBots) do
		if data.team == teamName and data.state ~= "dead" then
			c = c + 1
		end
	end
	return c
end

function BotManager3v3.ClearAllBots()
	local count = 0
	for bot in pairs(activeBots) do
		if bot and bot.Parent then
			bot.Parent = nil
			count = count + 1
		end
	end
	activeBots = {}
	botCounter = 0
	botDeathCounts = {}
	laneAssignmentCounter = {Team1 = 0, Team2 = 0}
	return count
end

RunService.Heartbeat:Connect(function(deltaTime)
	for _, data in pairs(activeBots) do
		if data.state ~= "dead" then
			regenerateHP(data, deltaTime)
			updateAI(data)
		end
	end
end)

_G.BotManager3v3 = BotManager3v3
print("[BotManager3v3] San sang - He thong 3 lane (Left, Mid, Right).")

return BotManager3v3
