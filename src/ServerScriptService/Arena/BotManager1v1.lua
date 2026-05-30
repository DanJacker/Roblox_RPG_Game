-- BotManager1v1 - Bot AI cho che do 1v1
-- Dat ModuleScript nay trong: ServerScriptService.Arena.BotManager1v1
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CONFIG = {
	DETECTION_RANGE = 85,
	ATTACK_RANGE = 8,
	BASE_ATTACK_RANGE = 12,
	ATTACK_COOLDOWN = 1.05,
	ATTACK_DAMAGE = 15,
	BASE_ATTACK_DAMAGE = 25,
	RETREAT_HEALTH = 0.30,
	RECOVERY_HEALTH = 0.55,
	HP_REGEN = 2,
	PATROL_RANGE = 25,
	CHASE_RANGE = 52,
	MELEE_THREAT_RANGE = 14,
	BASE_DEFENSE_RANGE = 35,
	BASE_PROTECTION_RANGE = 50, -- Pham vi bao ve base
	RESPAWN_TIME = 5,
	MOVE_REFRESH = 0.42,
	STUCK_SECONDS = 1.35,
	WALK_SPEED = 18,
	BASE_CACHE_TTL = 1.25,
	-- ========== THÊM CONFIG CHO NHẢY ==========
	JUMP_FORCE = 50, -- Độ cao nhảy
	OBSTACLE_CHECK_DISTANCE = 5, -- Khoảng cách kiểm tra chướng ngại vật
	JUMP_COOLDOWN = 0.5, -- Thời gian chờ giữa các lần nhảy
	MAX_JUMP_HEIGHT = 15, -- Độ cao tối đa có thể nhảy qua
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
		center = Vector3.new(-1166.5, 0, -1361.4),
		size = Vector3.new(1074, 100, 332),
		minX = -1166.5 - 537,
		maxX = -1166.5 + 537,
		minZ = -1361.4 - 166,
		maxZ = -1361.4 + 166,
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
-- Tìm base của team trong Maps folder
local function findTeamBase(teamName)
    local mapsFolder = workspace:FindFirstChild("Maps")
    if mapsFolder then
        for _, mapFolder in pairs(mapsFolder:GetChildren()) do
            for _, obj in pairs(mapFolder:GetDescendants()) do
                if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
                    return obj
                end
            end
        end
    end
    -- Fallback: tìm trong workspace root
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
            return obj
        end
    end
    return nil
end
local activeBots = {}
local botCounter = 0
local botDeathCounts = {}
local function createBotCharacter(botName, teamName)
	local rigTemplate = workspace:FindFirstChild("Rig")
	if not rigTemplate then
		warn("[BotManager1v1] Khong tim thay workspace.Rig — dat Rig (model) vao Workspace hoac ServerStorage va clone khi spawn.")
		return nil
	end
	local character = rigTemplate:Clone()
	character.Name = botName
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
	local bodyColors = character:FindFirstChild("Body Colors")
	if bodyColors then
		bodyColors.HeadColor3 = teamColor3
		bodyColors.LeftArmColor3 = teamColor3
		bodyColors.RightArmColor3 = teamColor3
		bodyColors.LeftLegColor3 = teamColor3
		bodyColors.RightLegColor3 = teamColor3
		bodyColors.TorsoColor3 = teamColor3
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = CONFIG.WALK_SPEED
		humanoid.AutoRotate = true
	end

	-- ========== THÊM HIỂN THỊ TÊN TRÊN ĐẦU ==========
	local head = character:FindFirstChild("Head")
	if head then
		-- Tạo BillboardGui với kích thước theo studs (tự động scale theo khoảng cách)
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "BotNameDisplay"
		billboardGui.Adornee = head
		billboardGui.Size = UDim2.new(4, 0, 1.2, 0) -- 4 studs rộng, 1.2 studs cao
		billboardGui.StudsOffset = Vector3.new(0, 2.5, 0) -- 2.5 studs trên đầu
		billboardGui.AlwaysOnTop = true
		billboardGui.Parent = character

		-- Tạo TextLabel với font size cố định
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "NameLabel"
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = botName
		textLabel.TextColor3 = teamColor3
		textLabel.TextStrokeTransparency = 0
		textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		textLabel.TextSize = 14 -- Font size cố định, không scale
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Parent = billboardGui
	end
	-- ================================================

	return character
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
				if d < nearestDist then
					nearest, nearestDist = {
						type = "player", instance = p, position = hrp.Position, distance = d }, d
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
local baseModelCache = { t = -1e9, Team1 = {}, Team2 = {} }
local function refreshBaseModelCache()
	local now = tick()
	if now - baseModelCache.t < CONFIG.BASE_CACHE_TTL then
		return
	end
	baseModelCache.t = now
	baseModelCache.Team1 = {}
	baseModelCache.Team2 = {}
	for _, inst in workspace:GetDescendants() do
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
local function findEnemyBase(botData)
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	
	-- Xác định map hiện tại của bot
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
			
			-- CHỈ tìm base trong cùng map với bot
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
-- TIM PLAYER TIEP CAN BASE CUA BOT (DE BAO VE)
local function findPlayerNearMyBase(botData)
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	-- Tim base cua bot
	refreshBaseModelCache()
	local myTeam = botData.team
	local myBaseList = baseModelCache[myTeam]
	if not myBaseList or #myBaseList == 0 then
		return nil
	end
	-- Lay vi tri base
	local myBasePos = nil
	for _, obj in ipairs(myBaseList) do
		if obj.Parent then
			local tower = obj:FindFirstChild("Tower")
			myBasePos = (tower and tower:IsA("BasePart")) and tower.Position or obj:GetPivot().Position
			break
		end
	end
	if not myBasePos then
		return nil
	end
	-- Tim player doi thu gan base cua minh
	local nearest, nearestDist = nil, CONFIG.BASE_PROTECTION_RANGE
	for _, p in Players:GetPlayers() do
		local playerTeam = p.Team and p.Team.Name
		if playerTeam and playerTeam ~= botData.team and p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local playerHrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and playerHrp then
				-- Khoang cach tu player den base cua bot
				local distToMyBase = (playerHrp.Position - myBasePos).Magnitude
				if distToMyBase < CONFIG.BASE_PROTECTION_RANGE then
					-- Player dang tiep can base!
					local distToBot = (playerHrp.Position - hrp.Position).Magnitude
					if distToBot < nearestDist then
					nearest, nearestDist = {
						type = "player",
							instance = p,
							position = playerHrp.Position,
							distance = distToBot,
							distToBase = distToMyBase,
						}, distToBot
					end
				end
			end
		end
	end
	return nearest
end
-- LAY VI TRI BASE CUA BOT
local function getMyBasePosition(botData)
	refreshBaseModelCache()
	local myTeam = botData.team
	local myBaseList = baseModelCache[myTeam]
	if not myBaseList or #myBaseList == 0 then
		return nil
	end
	for _, obj in ipairs(myBaseList) do
		if obj.Parent then
			local tower = obj:FindFirstChild("Tower")
			return (tower and tower:IsA("BasePart")) and tower.Position or obj:GetPivot().Position
		end
	end
	return nil
end
local function shouldRetreat(botData)
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	if not h then
		return false
	end
	return h.Health / h.MaxHealth < CONFIG.RETREAT_HEALTH
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
				-- Ghi nhận kill cho MatchEndConditions
				if _G.MatchEndConditions then
					_G.MatchEndConditions.RecordKill({ name = botData.name, team = botData.team }, target.instance)
				end
				-- Ghi nhận kill cho MVP System
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
				-- Ghi nhận kill cho MatchEndConditions
				if _G.MatchEndConditions then
					_G.MatchEndConditions.RecordKill(
						{ name = botData.name, team = botData.team },
						{ name = target.instance.Name, team = victimTeam }
					)
				end
				-- Ghi nhận kill cho MVP System
				if _G.MVPSystem and _G.MVPSystem.RecordKill then
					_G.MVPSystem.RecordKill(botData.name, target.instance.Name)
				end
			end
		end
	elseif target.type == "base" and _G.BotAttackBase then
		local tname = target.instance.Name
		local defTeam = string.find(tname, "Team1", 1, true) and "Team1" or "Team2"
		_G.BotAttackBase(target.instance, defTeam, botData.name, botData.team, CONFIG.BASE_ATTACK_DAMAGE)
	end
end
local function approachPointToward(baseInfo, hrp)
	local to = baseInfo.position - hrp.Position
	local flat = Vector3.new(to.X, 0, to.Z)
	local mag = flat.Magnitude
	local dir = mag > 1e-3 and flat.Unit or hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	return baseInfo.position - dir.Unit * math.min(6, math.max(3, mag * 0.15))
end
-- ========== HÀM KIỂM TRA CHƯỚNG NGẠI VẬT ==========
local function checkObstacleInFront(botData)
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp then
		return false, nil
	end
	
	-- Hướng di chuyển hiện tại
	local moveDir = h.MoveDirection or Vector3.new(0, 0, 0)
	if moveDir.Magnitude < 0.1 then
		-- Nếu không có hướng di chuyển, sử dụng hướng nhìn
		moveDir = hrp.CFrame.LookVector
	end
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
	
	-- Raycast kiểm tra chướng ngại vật ở phía trước
	local rayOrigin = hrp.Position + Vector3.new(0, 1, 0)
	local rayDirection = moveDir * CONFIG.OBSTACLE_CHECK_DISTANCE
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {botData.character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if result then
		-- Kiểm tra xem chướng ngại vật có thể nhảy qua không
		local hitPart = result.Instance
		local hitPos = result.Position
		
		-- Kiểm tra chiều cao chướng ngại vật
		local obstacleHeight = hitPos.Y - hrp.Position.Y
		
		-- Nếu chướng ngại vật không quá cao và là BasePart
		if hitPart and obstacleHeight < CONFIG.MAX_JUMP_HEIGHT then
			return true, hitPart
		end
	end
	
	-- Kiểm tra phía trên xem có thể nhảy qua không
	local rayUp = workspace:Raycast(rayOrigin, Vector3.new(0, CONFIG.MAX_JUMP_HEIGHT, 0), raycastParams)
	if rayUp then
		return false, nil -- Có vật cản phía trên, không thể nhảy
	end
	
	return false, nil
end

-- ========== HÀM NHẢY QUA CHƯỚNG NGẠI VẬT ==========
local function tryJump(botData)
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	if not h then
		return false
	end
	
	-- Kiểm tra cooldown nhảy
	local now = tick()
	botData._lastJumpTime = botData._lastJumpTime or 0
	if now - botData._lastJumpTime < CONFIG.JUMP_COOLDOWN then
		return false
	end
	
	-- Kiểm tra xem bot có đang ở trên mặt đất không
	if h.FloorMaterial == Enum.Material.Air then
		return false -- Đang ở trên không, không nhảy
	end
	
	-- Thực hiện nhảy
	h:ChangeState(Enum.HumanoidStateType.Jumping)
	botData._lastJumpTime = now
	
	return true
end

local function smartMoveTo(botData, worldPos)
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp then
		return
	end
	
	-- Xác định map hiện tại của bot
	local currentMap = getMapFromPosition(hrp.Position)
	
	-- Giới hạn vị trí mục tiêu trong map
	local pos = Vector3.new(worldPos.X, hrp.Position.Y, worldPos.Z)
	if currentMap then
		pos = clampToMap(pos, currentMap)
	end
	
	local now = tick()
	botData._lastSamplePos = botData._lastSamplePos or hrp.Position
	botData._stuckSince = botData._stuckSince or now
	botData._currentMap = currentMap
	
	-- ========== KIỂM TRA CHƯỚNG NGẠI VẬT VÀ NHẢY ==========
	local hasObstacle, obstaclePart = checkObstacleInFront(botData)
	if hasObstacle then
		tryJump(botData)
	end
	
	if (hrp.Position - botData._lastSamplePos).Magnitude < 0.2 then
		if now - botData._stuckSince > CONFIG.STUCK_SECONDS then
			-- ========== KHI BỊ STUCK, NHẢY ĐỂ THOÁT ==========
			tryJump(botData)
			
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
local function moveTo(botData, pos)
	smartMoveTo(botData, pos)
end
local function updateAI(botData)
	if botData.state == "dead" then
		return
	end
	local h = botData.character:FindFirstChildOfClass("Humanoid")
	local hrp = botData.character:FindFirstChild("HumanoidRootPart")
	if not h or not hrp or h.Health <= 0 then
		botData.state = "dead"
		return
	end

	-- ========== RÚT LUI KHI HP THẤP ==========
	if shouldRetreat(botData) then
		botData.state = "retreating"
		local myBasePos = getMyBasePosition(botData)
		if myBasePos then
			moveTo(botData, myBasePos)
		end
		return
	end

	-- ========== TÌM MỤC TIÊU ==========
	local enemy = findNearestEnemy(botData)
	local base = findEnemyBase(botData)

	-- ========== ƯU TIÊN 1: ĐÁNH BASE ĐỊCH ==========
	if base then
		botData.state = "pushing_base"
		if base.distance <= CONFIG.BASE_ATTACK_RANGE then
			botData.state = "attacking_base"
			attack(botData, base)
		else
			moveTo(botData, approachPointToward(base, hrp))
		end
		return
	end

	-- ========== ƯU TIÊN 2: BẢO VỆ BASE KHI PLAYER TIẾP CẬN ==========
	local playerNearMyBase = findPlayerNearMyBase(botData)
	if playerNearMyBase then
		if playerNearMyBase.distance <= CONFIG.ATTACK_RANGE then
			botData.state = "defending_base"
			attack(botData, playerNearMyBase)
		else
			botData.state = "chasing_defender"
			moveTo(botData, playerNearMyBase.position)
		end
		return
	end

	-- ========== ƯU TIÊN 3: CHỈ ĐÁNH PLAYER KHI KHÔNG CÓ BASE ==========
	local meleeThreat = enemy and enemy.distance <= CONFIG.MELEE_THREAT_RANGE
	if meleeThreat then
		if enemy.distance <= CONFIG.ATTACK_RANGE then
			botData.state = "attacking"
			attack(botData, enemy)
		else
			botData.state = "chasing_threat"
			moveTo(botData, enemy.position)
		end
		return
	end

	-- ========== ƯU TIÊN 4: TẤN CÔNG ENEMY GẦN ==========
	if enemy and enemy.distance <= CONFIG.ATTACK_RANGE then
		botData.state = "attacking"
		attack(botData, enemy)
	elseif enemy and enemy.distance < CONFIG.CHASE_RANGE then
		botData.state = "chasing"
		moveTo(botData, enemy.position)
	else
		-- ========== DI CHUY?N ??N BASE ??CH ==========
		-- Khi kh?ng c? target, bot s? di chuy?n v? ph?a base ??ch
		botData.state = "moving_to_enemy_base"
		
		-- T?m base ??ch ?? di chuy?n ??n
		local enemyTeam = botData.team == "Team1" and "Team2" or "Team1"
		local currentMap = botData._currentMap or getMapFromPosition(hrp.Position)
		local enemyBase = nil
		
		-- T?m base ??ch trong map hi?n t?i
		local mapsFolder = workspace:FindFirstChild("Maps")
		if mapsFolder and currentMap then
			local mapFolder = mapsFolder:FindFirstChild(currentMap)
			if mapFolder then
				for _, obj in ipairs(mapFolder:GetChildren()) do
					if obj:IsA("Model") and string.find(obj.Name, enemyTeam) and string.find(obj.Name, "Base") then
						enemyBase = obj
						break
					end
				end
			end
		end
		
		if enemyBase then
			-- Di chuy?n ??n base ??ch
			local tower = enemyBase:FindFirstChild("Tower")
			local targetPos = tower and tower.Position or enemyBase:GetPivot().Position
			
			-- Di chuy?n ??n g?n base ??ch
			local toBase = targetPos - hrp.Position
			local direction = toBase.Magnitude > 1e-4 and toBase.Unit or Vector3.new(0, 0, -1)
			local approachPos = targetPos - direction * 5
			
			if currentMap then
				approachPos = clampToMap(approachPos, currentMap)
			end
			
			moveTo(botData, approachPos)
		else
			-- Fallback: patrol ng?u nhi?n ?? t?m base ??ch
			botData.state = "patrolling"
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
				moveTo(botData, botData.patrolTarget)
			end
		end
	end
end
local function spawnBot(teamName, spawnPos)
	botCounter = botCounter + 1
	local name = string.format("[BOT-1v1] Shadow%d", botCounter)
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
	character:SetPrimaryPartCFrame(CFrame.new(spawnPos + Vector3.new(0, 10, 0)))
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
		state = "idle",
		lastAttack = 0,
		patrolTarget = nil,
		lastPatrol = 0,
		mode = "1v1",
	}
	activeBots[character] = botData
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[BotManager1v1] Character khong co Humanoid")
		return botData
	end
	humanoid.Died:Connect(function()
		botData.state = "dead"
		botDeathCounts[name] = (botDeathCounts[name] or 0) + 1
		local respawnTime = math.min(CONFIG.RESPAWN_TIME + (botDeathCounts[name] - 1) * 2, 15)
		task.delay(respawnTime, function()
			if character and character.Parent then
				character:Destroy()
			end
			activeBots[character] = nil
			local teamBase = workspace:FindFirstChild(teamName .. "Base", true)
			if teamBase then
				spawnBot(teamName, teamBase:GetPivot().Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)))
			end
		end)
	end)
	-- Khởi tạo stats cho bot trong MVPSystem - Đợi nếu cần
	local maxWait = 5
	local waited = 0
	while not (_G.MVPSystem and _G.MVPSystem.InitPlayerStats) and waited < maxWait do
		task.wait(0.5)
		waited = waited + 0.5
	end
	
	if _G.MVPSystem and _G.MVPSystem.InitPlayerStats then
		_G.MVPSystem.InitPlayerStats(name, teamName)
	else
		warn("[BotManager1v1] MVPSystem không sẵn sàng sau " .. maxWait .. "s, không thể khởi tạo stats cho bot: " .. name)
	end
	
	return botData
end
local BotManager1v1 = {}
function BotManager1v1.SpawnBotForTeam(teamName, pos)
	return spawnBot(teamName, pos or Vector3.new(0, 10, 0))
end
function BotManager1v1.GetActiveBots()
	return activeBots
end
function BotManager1v1.GetBotCount()
	local c = 0
	for _ in pairs(activeBots) do
		c = c + 1
	end
	return c
end
function BotManager1v1.GetBotCountByTeam(teamName)
	local c = 0
	for _, data in pairs(activeBots) do
		if data.team == teamName and data.state ~= "dead" then
			c = c + 1
		end
	end
	return c
end
function BotManager1v1.ClearAllBots()
	local count = 0
	for bot in pairs(activeBots) do
		if bot and bot.Parent then
			bot:Destroy()
			count = count + 1
		end
	end
	activeBots = {}
	botCounter = 0
	botDeathCounts = {}
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
_G.BotManager1v1 = BotManager1v1
return BotManager1v1
