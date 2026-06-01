-- BotManager3v3 - Bot AI cho che do 3v3
-- ServerScriptService.Arena.BotManager3v3 (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


local CONFIG = {
	DETECTION_RANGE = 120,       -- Tang pham vi phat hien
	ATTACK_RANGE = 12,
	BASE_ATTACK_RANGE = 25,
	ATTACK_COOLDOWN = 0.78,
	ATTACK_DAMAGE = 12,          -- Tang sat thuong len player
	BASE_ATTACK_DAMAGE = 25,
	RETREAT_HEALTH = 0.15,      -- Giam nguong rut lui
	RECOVERY_HEALTH = 0.45,
	HP_REGEN = 5,                -- TANG TOC DO HOI PHUC LEN 5 HP/giay
	BOT_MAX_HEALTH = 150,        -- TANG HP BOT LEN 150
	PATROL_RANGE = 35,
	CHASE_RANGE = 80,           -- Tang pham vi truy duoi
	PLAYER_CHASE_RANGE = 100,   -- Pham vi truy duoi player dac biet
	MELEE_THREAT_RANGE = 10,
	BASE_DEFENSE_RANGE = 45,
	RESPAWN_TIME = 5,
	TEAM_COORDINATION = false,
	GROUP_ATTACK = false,
	MOVE_REFRESH = 0.25,
	STUCK_SECONDS = 0.8,
	WALK_SPEED = 24,            -- Tang toc do
	CHASE_SPEED_MULT = 1.3,     -- Tang toc do khi truy duoi player
	BASE_CACHE_TTL = 1.25,
	AGGRESSIVE_PLAYER_CHASE = true, -- Kich hoat truy duoi player hung manh
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
		center = Vector3.new(-1166.5, 0, -1030),
		size = Vector3.new(1074, 100, 700),
		minX = -1703.5,
		maxX = -629.5,
		minZ = -1380,
		maxZ = -680,
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
local botAttackBase

local function createBotCharacter(botName, teamName)
	local rigTemplate = workspace:FindFirstChild("Rig")
	if not rigTemplate then
		warn("[BotManager3v3] Khong tim thay workspace.Rig")
		return nil
	end

	local character = rigTemplate:Clone()
	character.Name = botName
	
	-- Đảm bảo PrimaryPart được set
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

local baseModelCache = { t = -1e9, Team1 = {}, Team2 = {} }

local function refreshBaseModelCache()
	local now = tick()
	if now - baseModelCache.t < CONFIG.BASE_CACHE_TTL then
		return
	end
	baseModelCache.t = now
	baseModelCache.Team1 = {}
	baseModelCache.Team2 = {}
	
	-- Tìm trong Maps folder trước
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
	
	-- Fallback: tìm trong workspace root
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

	-- UU TIEN CAO: Tim player truoc
	for _, p in Players:GetPlayers() do
		local playerTeam = p.Team and p.Team.Name
		if playerTeam and playerTeam ~= botData.team and p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and hrp then
				local d = (hrp.Position - pos).Magnitude
				-- Tang pham vi phat hien player
				if d < CONFIG.PLAYER_CHASE_RANGE then
					if d < nearestDist then
						nearest, nearestDist = { type = "player", instance = p, position = hrp.Position, distance = d }, d
					end
				end
			end
		end
	end

	-- Sau do tim bot
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

local function findAllyNeedingHelp(botData)
	local root = botData.character.PrimaryPart or botData.character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local pos = root.Position
	local nearest, nearestDist = nil, CONFIG.CHASE_RANGE

	for bot, data in pairs(activeBots) do
		if data.team == botData.team and data.state ~= "dead" and bot ~= botData.character then
			local h = bot:FindFirstChildOfClass("Humanoid")
			local hrp = bot:FindFirstChild("HumanoidRootPart")
			if h and hrp and h.Health / h.MaxHealth < 0.5 then
				local d = (hrp.Position - pos).Magnitude
				if d < nearestDist then
					nearest, nearestDist = { type = "ally", instance = bot, position = hrp.Position, distance = d }, d
				end
			end
		end
	end

	return nearest
end

-- data.currentTarget la Model (character cua player hoac bot)
local function findEnemyTargetedByAllies(botData)
	local root = botData.character.PrimaryPart or botData.character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end
	local pos = root.Position
	local target, targetDist = nil, CONFIG.DETECTION_RANGE

	for bot, data in pairs(activeBots) do
		if data.team == botData.team and data.state ~= "dead" and bot ~= botData.character then
			local ct = data.currentTarget
			if typeof(ct) == "Instance" and ct:IsA("Model") then
				local hrp = ct:FindFirstChild("HumanoidRootPart")
				if hrp then
					local d = (hrp.Position - pos).Magnitude
					if d < targetDist then
						target = ct
						targetDist = d
					end
				end
			end
		end
	end

	return target, targetDist
end

local function attackTargetFromModel(botData, targetModel, distance)
	local hrp = targetModel:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local plr = Players:GetPlayerFromCharacter(targetModel)
	if plr then
		return {
			type = "player",
			instance = plr,
			position = hrp.Position,
			distance = distance,
		}
	end
	local data = activeBots[targetModel]
	return {
		type = "bot",
		instance = targetModel,
		position = hrp.Position,
		distance = distance,
		team = data and data.team,
	}
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
	
	if best then
	else
	end
	
	return best
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
			if h.Health <= 0 and _G.MatchEndConditions then
				_G.MatchEndConditions.RecordKill({ name = botData.name, team = botData.team }, target.instance)
			end
		end
	elseif target.type == "bot" then
		local h = target.instance:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)
			if h.Health <= 0 and _G.MatchEndConditions then
				local victimTeam = target.team
				if not victimTeam and activeBots[target.instance] then
					victimTeam = activeBots[target.instance].team
				end
				_G.MatchEndConditions.RecordKill(
					{ name = botData.name, team = botData.team },
					{ name = target.instance.Name, team = victimTeam }
				)
			end
		end
	elseif target.type == "base" then
		local tname = target.instance.Name
		local defTeam = string.find(tname, "Team1", 1, true) and "Team1" or "Team2"
		-- Goi truc tiep function botAttackBase
		botAttackBase(target.instance, defTeam, botData.name, botData.team, CONFIG.BASE_ATTACK_DAMAGE)
	end
end

local function approachPointToward(baseInfo, hrp)
	-- Di chuyen thang den base, khong can approach point
	return baseInfo.position
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
	
	-- Debug: Log move command mỗi 1 giây
	local now = tick()
	if not botData._lastMoveLog or now - botData._lastMoveLog > 1 then
		botData._lastMoveLog = now
		print(string.format("[BotManager3v3] %s MoveTo (%.1f, %.1f, %.1f) from (%.1f, %.1f, %.1f)", 
			botData.name, pos.X, pos.Y, pos.Z, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
	end
	
	-- Gọi MoveTo trực tiếp
	h:MoveTo(pos)
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
	
	-- Debug: Log nếu không tìm thấy Humanoid hoặc HumanoidRootPart
	if not h then
		warn("[BotManager3v3] " .. botData.name .. " không có Humanoid!")
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end
	if not hrp then
		warn("[BotManager3v3] " .. botData.name .. " không có HumanoidRootPart!")
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end
	if h.Health <= 0 then
		botData.state = "dead"
		botData.currentTarget = nil
		return
	end

	-- Debug: Log bot state mỗi 2 giây
	if not botData.lastDebugLog or tick() - botData.lastDebugLog > 2 then
		botData.lastDebugLog = tick()
		print(string.format("[BotManager3v3] %s | State: %s | HP: %d | Pos: %.1f, %.1f, %.1f", 
			botData.name, botData.state, h.Health, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
	end

	-- ========== RÚT LUI KHI HP THẤP ==========
	if shouldRetreat(botData) then
		botData.state = "retreating"
		botData.currentTarget = nil
		local myBase = workspace:FindFirstChild(botData.team .. "Base", true)
		if myBase then
			moveTo(botData, myBase:GetPivot().Position)
		end
		return
	end

	-- ========== TÌM MỤC TIÊU ==========
	local enemy = findNearestEnemy(botData)
	local base = findEnemyBase(botData)

	-- ========== ƯU TIÊN TRUY DUOI PLAYER ==========
	-- Neu co player gan, uu tien truy duoi player truoc
	if enemy and enemy.type == "player" and enemy.distance <= CONFIG.PLAYER_CHASE_RANGE then
		-- Tang toc do khi truy duoi player
		h.WalkSpeed = CONFIG.WALK_SPEED * CONFIG.CHASE_SPEED_MULT
		
		botData.currentTarget = enemy.instance.Character
		
		-- Tan cong neu gan enough
		if enemy.distance <= CONFIG.ATTACK_RANGE then
			botData.state = "attacking_player"
			attack(botData, enemy)
			
			-- Log tan cong player
			if not botData.lastAttackLog or tick() - botData.lastAttackLog > 2 then
				botData.lastAttackLog = tick()
				print(string.format("[BotManager3v3] %s dang TAN CONG player %s (dist=%.1f)", 
					botData.name, enemy.instance.Name, enemy.distance))
			end
		else
			-- Truy duoi player
			botData.state = "chasing_player"
			moveTo(botData, enemy.position)
			
			-- Log truy duoi player
			if not botData.lastChaseLog or tick() - botData.lastChaseLog > 2 then
				botData.lastChaseLog = tick()
				print(string.format("[BotManager3v3] %s dang TRUY DUOI player %s (dist=%.1f)", 
					botData.name, enemy.instance.Name, enemy.distance))
			end
		end
		return
	end

	-- ========== ƯU TIÊN TUYỆT ĐỐI: ĐI ĐẾN BASE ĐỊCH ==========
	-- Bot sẽ đi đến base địch khi khong co player gan
	if base then
		botData.currentTarget = nil
		
		-- Reset toc do khi di chuyen den base
		h.WalkSpeed = CONFIG.WALK_SPEED
		
		-- Chỉ đánh player nếu player ĐANG ĐÁNH MÌNH (trong ATTACK_RANGE)
		if enemy and enemy.distance <= CONFIG.ATTACK_RANGE then
			botData.state = "defending_while_pushing"
			attack(botData, enemy)
			-- Vẫn tiếp tục di chuyển đến base
			moveTo(botData, approachPointToward(base, hrp))
			return
		end
		
		-- Nếu đến gần base, tấn công base
		if base.distance <= CONFIG.BASE_ATTACK_RANGE then
			botData.state = "attacking_base"
			attack(botData, base)
		else
			botData.state = "pushing_base"
			moveTo(botData, approachPointToward(base, hrp))
		end
		return
	end

	-- ========== KHÔNG TÌM THẤY BASE: TÌM BASE ĐỊCH ==========
	-- Khi không tìm thấy base, bot sẽ tìm base địch để di chuyển đến
	botData.state = "moving_to_enemy_base"
	botData.currentTarget = nil
	
	-- Tìm base địch để di chuyển đến
	local enemyTeam = botData.team == "Team1" and "Team2" or "Team1"
	local currentMap = botData._currentMap or getMapFromPosition(hrp.Position)
	local enemyBase = nil
	
	-- Tìm base địch trong map hiện tại
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
		-- Di chuyển đến base địch
		local tower = enemyBase:FindFirstChild("Tower")
		local targetPos = tower and tower.Position or enemyBase:GetPivot().Position
		
		-- Di chuyển thẳng đến base địch
		moveTo(botData, targetPos)
	else
		-- Fallback: patrol ngẫu nhiên để tìm base địch
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

local function spawnBot(teamName, spawnPos)
	botCounter = botCounter + 1
	local name = string.format("[BOT-3v3] Shadow%d", botCounter)

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
		mode = "3v3",
		currentTarget = nil,
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

	return botData
end

-- ========== BOT ATTACK BASE FUNCTION ==========
-- Function nay duoc goi khi bot tan cong base
botAttackBase = function(baseModel, defendingTeam, attackerName, attackerTeam, damage)
	if not baseModel then return end
	
	-- Tim BaseHumanoid trong base
	local baseHumanoid = baseModel:FindFirstChild("BaseHumanoid")
	if not baseHumanoid then
		-- Fallback: Tim Humanoid
		baseHumanoid = baseModel:FindFirstChildOfClass("Humanoid")
	end
	
	if not baseHumanoid then
		warn("[BotManager3v3] Khong tim thay BaseHumanoid trong " .. baseModel.Name)
		return
	end
	
	-- Giam HP base
	local oldHealth = baseHumanoid.Health
	baseHumanoid.Health = math.max(0, baseHumanoid.Health - damage)
	
	print(string.format("[BotManager3v3] %s (%s) danh %s: %.0f damage (HP: %.0f -> %.0f)", 
		attackerName, attackerTeam, baseModel.Name, damage, oldHealth, baseHumanoid.Health))
	
	-- Kiem tra neu base bi huy
	if baseHumanoid.Health <= 0 then
		
		-- Thong bao cho MatchEndConditions
		if _G.MatchEndConditions and _G.MatchEndConditions.RecordBaseDestroyed then
			_G.MatchEndConditions.RecordBaseDestroyed(defendingTeam, attackerTeam)
		end
	end
end

-- Export function
_G.BotAttackBase = botAttackBase

local BotManager3v3 = {}

function BotManager3v3.SpawnBotForTeam(teamName, pos)
	return spawnBot(teamName, pos or Vector3.new(0, 10, 0))
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

_G.BotManager3v3 = BotManager3v3

return BotManager3v3
