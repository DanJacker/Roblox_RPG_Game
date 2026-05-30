-- BotManager - Quản lý bot AI (ROUTER - Điều phối theo chế độ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")


-- ĐẶT BIẾN TOÀN CỤC NGAY LẬP TỨC
local BotManager = {}
_G.BotManager = BotManager

local arenaFolder = ServerScriptService:FindFirstChild("Arena")

-- Đơn giản hóa: chỉ require module nếu có, không đợi
local function safeRequire(moduleName)
	local modScript = arenaFolder and arenaFolder:FindFirstChild(moduleName)
	if modScript and modScript:IsA("ModuleScript") then
		local ok, result = pcall(require, modScript)
		if ok then
			return result
		else
			warn("[BotManager] Lỗi require " .. moduleName .. ": " .. tostring(result))
		end
	else
	end
	return nil
end


-- Load modules (không đợi)
local ModeManagers = {
	["1v1"] = safeRequire("BotManager1v1"),
	["2v2"] = safeRequire("BotManager2v2"),
	["3v3"] = safeRequire("BotManager3v3"),
}


-- Export các module ra _G
for mode, mgr in pairs(ModeManagers) do
	if mgr then
		_G["BotManager" .. mode] = mgr
	end
end

-- ========== RETRY LOAD MODULES IF NEEDED ==========
-- Đảm bảo BotManager3v3 được load (fix cho 3v3 mode)
task.spawn(function()
	local maxRetries = 5
	local retryDelay = 1
	
	for mode, moduleName in pairs({["1v1"] = "BotManager1v1", ["2v2"] = "BotManager2v2", ["3v3"] = "BotManager3v3"}) do
		if not ModeManagers[mode] then
			for i = 1, maxRetries do
				task.wait(retryDelay)
				local modScript = arenaFolder and arenaFolder:FindFirstChild(moduleName)
				if modScript and modScript:IsA("ModuleScript") then
					local ok, result = pcall(require, modScript)
					if ok then
						ModeManagers[mode] = result
						_G["BotManager" .. mode] = result
						break
					else
						warn("[BotManager] Retry " .. i .. " failed for " .. moduleName .. ": " .. tostring(result))
					end
				end
			end
		end
	end
	
	-- Print final status
end)

-- ========== C?U H?NH M?C ??NH (FALLBACK) ==========
local CONFIG = {
	DETECTION_RANGE = 80,
	ATTACK_RANGE = 6,
	BASE_ATTACK_RANGE = 10,
	ATTACK_COOLDOWN = 1.2,
	ATTACK_DAMAGE = 20,
	BASE_ATTACK_DAMAGE = 25,
	RETREAT_HEALTH = 0.25,
	RECOVERY_HEALTH = 0.50,
	NORMAL_HP_REGEN = 1,
	RETREAT_HP_REGEN_MULTIPLIER = 1.5,
	PATROL_RANGE = 30,
	CHASE_RANGE = 50,
	BASE_DEFENSE_RANGE = 40,
	-- B?t ?? t? spawn/x?a bot test khi Studio ch?y (t?n t?i nguy?n / l?m b?n log)
	DEBUG_TEST_SPAWN = false,
	-- Refresh danh s?ch base trong workspace (gi?y) ? tr?nh qu?t workspace m?i bot m?i frame
	BASE_MODEL_CACHE_TTL = 1.0,
}

local activeBots = {}
local botCounter = 0

local function getMapModelByMode(mode)
	if type(mode) == "string" then
		mode = string.lower((mode):gsub("%s+", ""))
	end
	local mapsFolder = workspace:FindFirstChild("Maps")
	if not mapsFolder then
		return nil
	end
	local mapName = (mode == "1v1" and "Map1v1") or (mode == "2v2" and "Map2v2") or (mode == "3v3" and "Map3v3") or nil
	if not mapName then
		return nil
	end
	local mapModel = mapsFolder:FindFirstChild(mapName)
	return (mapModel and mapModel:IsA("Model")) and mapModel or nil
end

local function getBotsFolderForMode(mode)
	local mapModel = getMapModelByMode(mode)
	local parent = mapModel or workspace
	local folderName = "Bots"
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end
	return folder
end

local function moveBotCharacterToFolder(botData, folder)
	if not botData or not folder then return end
	local character = botData.character
	if character and character.Parent ~= folder then
		character.Parent = folder
	end
end

-- Cache model base theo team ??ch (gi?m workspace:GetChildren m?i bot m?i frame)
local baseModelsByEnemyTeam = { Team1 = {}, Team2 = {} }
local baseModelsCacheTime = -math.huge -- lan dau luon refresh (tranh tick() nho < TTL bo qua)

local function refreshBaseModelsCache(now)
	if now - baseModelsCacheTime < CONFIG.BASE_MODEL_CACHE_TTL then
		return
	end
	baseModelsCacheTime = now
	local t1, t2 = {}, {}
	-- Tìm trong toàn bộ workspace (bao gồm Maps folder)
	for _, obj in workspace:GetDescendants() do
		if obj:IsA("Model") then
			local n = obj.Name
			if string.find(n, "Team1Base", 1, true) then
				table.insert(t1, obj)
			end
			if string.find(n, "Team2Base", 1, true) then
				table.insert(t2, obj)
			end
		end
	end
	baseModelsByEnemyTeam.Team1 = t1
	baseModelsByEnemyTeam.Team2 = t2
end

-- Tìm base của team trong Maps folder
local function findTeamBase(teamName)
	-- Tìm trong Maps folder trước
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

local function distSq(a, b)
	local d = a - b
	return d.X * d.X + d.Y * d.Y + d.Z * d.Z
end

-- C?u h?nh respawn
local BOT_RESPAWN_TIME = 5 -- Th?i gian respawn bot (gi?y)
local botDeathCounts = {} -- Theo d?i s? l?n ch?t c?a m?i bot

local function ensureBotRefs(botData)
	local char = botData.character
	if not char or not char.Parent then
		return nil, nil
	end
	local h = botData.humanoid
	local hrp = botData.hrp
	if not h or not h.Parent then
		h = char:FindFirstChildOfClass("Humanoid")
		botData.humanoid = h
	end
	if not hrp or not hrp.Parent then
		hrp = char:FindFirstChild("HumanoidRootPart")
		botData.hrp = hrp
	end
	return h, hrp
end

-- T?o bot character t? Rig model
local function createBotCharacter(botName, teamName)
	-- T?m Rig template trong workspace
	local rigTemplate = workspace:FindFirstChild("Rig")
	if not rigTemplate then
		warn("[BotManager] Kh?ng t?m th?y Rig template!")
		return nil
	end

	-- Clone Rig model
	local character = rigTemplate:Clone()
	character.Name = botName

	-- X?a Animate script (bot kh?ng c?n animation client-side)
	local animate = character:FindFirstChild("Animate")
	if animate then animate:Destroy() end

	-- Set team color
	local teamColor3 = teamName == "Team1" and Color3.fromRGB(0, 100, 255) or Color3.fromRGB(255, 50, 50)

	-- ?p d?ng m?u cho t?t c? body parts
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Color = teamColor3
			part.Anchored = false
		end
	end

	-- Set BodyColors n?u c?
	local bodyColors = character:FindFirstChild("Body Colors")
	if bodyColors then
		bodyColors.HeadColor3 = teamColor3
		bodyColors.LeftArmColor3 = teamColor3
		bodyColors.RightArmColor3 = teamColor3
		bodyColors.LeftLegColor3 = teamColor3
		bodyColors.RightLegColor3 = teamColor3
		bodyColors.TorsoColor3 = teamColor3
	end

	-- Set Humanoid properties
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = 16
	end

	return character
end

-- T?m enemy g?n nh?t
local function findNearestEnemy(botData)
	local _, hrp = ensureBotRefs(botData)
	if not hrp then
		return nil
	end
	local pos = hrp.Position
	local maxSq = CONFIG.DETECTION_RANGE * CONFIG.DETECTION_RANGE
	local nearest, nearestDistSq = nil, maxSq

	for _, p in Players:GetPlayers() do
		local playerTeam = p.Team and p.Team.Name
		if playerTeam and playerTeam ~= botData.team and p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local phrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and phrp then
				local dSq = distSq(phrp.Position, pos)
				if dSq < nearestDistSq then
					nearestDistSq = dSq
					nearest = {
						type = "player",
						instance = p,
						position = phrp.Position,
						distance = math.sqrt(dSq),
					}
				end
			end
		end
	end

	for bot, data in pairs(activeBots) do
		if data.team ~= botData.team and data.state ~= "dead" then
			local bhrp = data.hrp
			if not bhrp or not bhrp.Parent then
				bhrp = bot:FindFirstChild("HumanoidRootPart")
				data.hrp = bhrp
			end
			if bhrp then
				local dSq = distSq(bhrp.Position, pos)
				if dSq < nearestDistSq then
					nearestDistSq = dSq
					nearest = {
						type = "bot",
						instance = bot,
						position = bhrp.Position,
						distance = math.sqrt(dSq),
						team = data.team,
					}
				end
			end
		end
	end

	return nearest
end

-- T?m enemy dang ti?p c?n base (d?ng khi b?o v? base)
local function findEnemyNearBase(botData)
	local myBase = workspace:FindFirstChild(botData.team .. "Base")
	if not myBase then
		return nil
	end

	local basePos = myBase:GetPivot().Position
	local maxSq = CONFIG.BASE_DEFENSE_RANGE * CONFIG.BASE_DEFENSE_RANGE
	local nearest, nearestDistSq = nil, maxSq

	for _, p in Players:GetPlayers() do
		local playerTeam = p.Team and p.Team.Name
		if playerTeam and playerTeam ~= botData.team and p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			local phrp = p.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and phrp then
				local dSq = distSq(phrp.Position, basePos)
				if dSq < nearestDistSq then
					nearestDistSq = dSq
					nearest = {
						type = "player",
						instance = p,
						position = phrp.Position,
						distance = math.sqrt(dSq),
					}
				end
			end
		end
	end

	for bot, data in pairs(activeBots) do
		if data.team ~= botData.team and data.state ~= "dead" then
			local bhrp = data.hrp
			if not bhrp or not bhrp.Parent then
				bhrp = bot:FindFirstChild("HumanoidRootPart")
				data.hrp = bhrp
			end
			if bhrp then
				local dSq = distSq(bhrp.Position, basePos)
				if dSq < nearestDistSq then
					nearestDistSq = dSq
					nearest = {
						type = "bot",
						instance = bot,
						position = bhrp.Position,
						distance = math.sqrt(dSq),
						team = data.team,
					}
				end
			end
		end
	end

	return nearest
end

-- T?m enemy base g?n nh?t (UU TI?N BASE C?A PLAYER)
local function findEnemyBase(botData)
	local _, hrp = ensureBotRefs(botData)
	if not hrp then
		return nil
	end
	local botPos = hrp.Position

	local now = tick()
	refreshBaseModelsCache(now)

	local enemyTeam = botData.team == "Team1" and "Team2" or "Team1"
	local models = baseModelsByEnemyTeam[enemyTeam]
	if not models or #models == 0 then
		return nil
	end

	local bestPlayer, dSqPlayer = nil, math.huge
	local bestUnowned, dSqUnowned = nil, math.huge
	local bestBot, dSqBotOwned = nil, math.huge

	for _, obj in models do
		local tower = obj:FindFirstChild("Tower")
		local pos
		if tower and tower:IsA("BasePart") then
			pos = tower.Position
		else
			pos = obj:GetPivot().Position
		end

		local owner = _G.GetBaseOwnerForModel and _G.GetBaseOwnerForModel(obj)
			or (_G.BaseOwner and _G.BaseOwner[obj.Name])
		local dSq = distSq(pos, botPos)
		local info = {
			type = "base",
			instance = obj,
			position = pos,
			targetPart = tower,
			distance = math.sqrt(dSq),
			owner = owner,
		}

		if owner and not owner.isBot then
			if dSq < dSqPlayer then
				dSqPlayer = dSq
				bestPlayer = info
			end
		elseif owner and owner.isBot then
			if dSq < dSqBotOwned then
				dSqBotOwned = dSq
				bestBot = info
			end
		else
			if dSq < dSqUnowned then
				dSqUnowned = dSq
				bestUnowned = info
			end
		end
	end

	return bestPlayer or bestUnowned or bestBot
end

-- Ki?m tra n?n r?t lui
local function shouldRetreat(botData)
	local h = select(1, ensureBotRefs(botData))
	if not h then
		return false
	end
	return h.Health / h.MaxHealth < CONFIG.RETREAT_HEALTH
end

-- Ki?m tra n?n quay l?i ??nh (HP >= 50%)
local function shouldReturnToFight(botData)
	local h = select(1, ensureBotRefs(botData))
	if not h then
		return false
	end
	return h.Health / h.MaxHealth >= CONFIG.RECOVERY_HEALTH
end

-- H?i ph?c HP cho bot
local function regenerateHP(botData, deltaTime)
	local h = select(1, ensureBotRefs(botData))
	if not h or h.Health <= 0 then
		return
	end

	local regenRate = CONFIG.NORMAL_HP_REGEN

	-- N?u dang r?t lui ho?c b?o v? base, h?i ph?c nhanh hon 1.5 l?n
	if botData.state == "retreating" or botData.state == "defending_base" then
		regenRate = CONFIG.NORMAL_HP_REGEN * CONFIG.RETREAT_HP_REGEN_MULTIPLIER
	end

	local newHealth = math.min(h.Health + regenRate * deltaTime, h.MaxHealth)
	h.Health = newHealth
end

-- T?n c?ng
local function attack(botData, target)
	local now = tick()
	if now - botData.lastAttack < CONFIG.ATTACK_COOLDOWN then
		return
	end
	botData.lastAttack = now

	local _, hrp = ensureBotRefs(botData)
	-- Hi?u ?ng t?n c?ng (xoay v? ph?a target)
	if hrp and target.position then
		hrp.CFrame = CFrame.new(hrp.Position, target.position)

		for _, part in pairs(botData.character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				local originalColor = part.Color
				part.Color = Color3.new(1, 1, 1) -- Flash tr?ng
				task.delay(0.1, function()
					if part and part.Parent then
						part.Color = originalColor
					end
				end)
			end
		end
	end

	if target.type == "player" then
		local h = target.instance.Character and target.instance.Character:FindFirstChild("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)

			-- Ki?m tra n?u player ch?t -> ghi nh?n kill
			if h.Health <= 0 then
				-- Ghi nh?n kill cho team c?a bot
				if _G.MatchEndConditions then
					_G.MatchEndConditions.RecordKill(
						{name = botData.name, team = botData.team}, -- Bot killer
						target.instance -- Player victim
					)
				end
				-- Ghi nh?n kill cho MVPSystem
				if _G.MVPSystem then
					_G.MVPSystem.RecordKill(botData.name, target.instance.Name)
				end
			end
		end
	elseif target.type == "bot" then
		local h = target.instance:FindFirstChild("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(CONFIG.ATTACK_DAMAGE)

			-- Ki?m tra n?u bot ch?t -> ghi nh?n kill
			if h.Health <= 0 then
				-- T?m t?n bot victim
				local victimName = target.instance.Name
				-- Ghi nh?n kill cho team c?a bot attacker
				local victimTeam = target.team
				if not victimTeam and activeBots[target.instance] then
					victimTeam = activeBots[target.instance].team
				end
				if _G.MatchEndConditions then
					_G.MatchEndConditions.RecordKill(
						{ name = botData.name, team = botData.team },
						{ name = victimName, team = victimTeam }
					)
				end
				-- Ghi nh?n kill cho MVPSystem
				if _G.MVPSystem then
					_G.MVPSystem.RecordKill(botData.name, victimName)
				end
			end
		end
	elseif target.type == "base" then
		-- G?y damage cho base s? d?ng BaseDamageSystem public API
		local base = target.instance
		local teamName = base.Name == "Team1Base" and "Team1" or "Team2"

		-- S? d?ng h?m public t? BaseDamageSystem
		if _G.BotAttackBase then
			local success, msg = _G.BotAttackBase(base, teamName, botData.name, botData.team, CONFIG.BASE_ATTACK_DAMAGE)
			if not success then
			end
		else
		end
	end
end

-- Di chuy?n
local function moveTo(botData, pos)
	local h = select(1, ensureBotRefs(botData))
	if h then
		h:MoveTo(pos)
	end
end

-- Forward declaration
local spawnBot

-- AI Update
local function updateAI(botData)
	if botData.state == "dead" then
		return
	end

	local h, hrp = ensureBotRefs(botData)
	if not h or not hrp or h.Health <= 0 then
		botData.state = "dead"
		return
	end

	local attackRangeSq = CONFIG.ATTACK_RANGE * CONFIG.ATTACK_RANGE
	local chaseRangeSq = CONFIG.CHASE_RANGE * CONFIG.CHASE_RANGE
	local baseAttackRangeSq = CONFIG.BASE_ATTACK_RANGE * CONFIG.BASE_ATTACK_RANGE

	-- Kiểm tra nếu bot rơi xuống void (dưới -50 studs)
	if hrp.Position.Y < -50 then
		botData.state = "dead"
		-- Respawn bot
		task.delay(2, function()
			local teamBase = workspace:FindFirstChild(botData.team .. "Base")
			if teamBase and spawnBot then
				local basePos = teamBase:GetPivot().Position
				spawnBot(botData.team, basePos + Vector3.new(0, 5, 0))
			end
		end)
		return
	end

	-- R?t lui n?u HP th?p - B?O V? BASE
	if shouldRetreat(botData) then
		botData.state = "retreating"
		botData.wasRetreating = true -- ??nh d?u d? t?ng r?t lui

		local myBase = workspace:FindFirstChild(botData.team .. "Base")
		if myBase then
			local basePos = myBase:GetPivot().Position

			-- T?m enemy dang ti?p c?n base
			local enemyNearBase = findEnemyNearBase(botData)

			if enemyNearBase then
				-- C? ENEMY G?N BASE: T?n c?ng b?o v? base!
				botData.state = "defending_base"

				if enemyNearBase.distance * enemyNearBase.distance < attackRangeSq then
					-- Trong t?m t?n c?ng, d?nh ngay
					attack(botData, enemyNearBase)
				else
					-- Di chuy?n d?n enemy d? t?n c?ng
					moveTo(botData, enemyNearBase.position)
				end
			else
				-- KH?NG C? ENEMY: Di chuy?n v? base d? h?i ph?c
				moveTo(botData, basePos)
			end
		end
		-- H?i ph?c HP khi r?t lui (s? du?c x? l? trong regenerateHP)
		return
	end

	-- N?u dang b?o v? base v? d? h?i d? 50% HP, quay l?i t?n c?ng
	if botData.wasRetreating and shouldReturnToFight(botData) then
		botData.wasRetreating = false
		botData.state = "chasing"
		-- Ti?p t?c t?m enemy v? t?n c?ng (kh?ng return, d? code b?n du?i x? l?)
	end

	-- T?m enemy g?n nh?t
	local enemy = findNearestEnemy(botData)
	local base = findEnemyBase(botData)

	-- UU TI?N T?N C?NG BASE C?A PLAYER
	-- N?u c? base c?a player d?ch v? trong range, uu ti?n d?nh base
	local shouldAttackBase = false
	if base and base.owner and not base.owner.isBot then
		-- ??y l? base c?a player, uu ti?n cao nh?t
		shouldAttackBase = true
	end

	if shouldAttackBase and base.distance * base.distance < baseAttackRangeSq then
		-- T?n c?ng base c?a player
		botData.state = "attacking_base"
		attack(botData, base)
	elseif shouldAttackBase and base.distance * base.distance < chaseRangeSq then
		botData.state = "moving_to_player_base"
		local toBase = base.position - hrp.Position
		local direction = toBase.Magnitude > 1e-4 and toBase.Unit or Vector3.new(0, 0, 1)
		local targetPos = base.position - direction * 2
		moveTo(botData, targetPos)
	elseif enemy and enemy.distance * enemy.distance < attackRangeSq then
		-- T?n c?ng player/bot d?ch n?u trong range
		botData.state = "attacking"
		attack(botData, enemy)
	elseif enemy and enemy.distance * enemy.distance < chaseRangeSq then
		-- ?u?i theo enemy n?u trong range
		botData.state = "chasing"
		moveTo(botData, enemy.position)
	elseif base then
		-- N?u kh?ng c? enemy, di chuy?n d?n base d?ch
		local toBase = base.position - hrp.Position
		local distToBaseSq = distSq(base.position, hrp.Position)
		botData.state = "moving_to_base"

		local direction = toBase.Magnitude > 1e-4 and toBase.Unit or Vector3.new(0, 0, 1)
		local targetPos = base.position - direction * 2
		moveTo(botData, targetPos)

		if distToBaseSq < baseAttackRangeSq then
			attack(botData, base)
		end
	else
		-- ========== DI CHUY?N ??N BASE ??CH ==========
		-- Khi kh?ng c? target, bot s? di chuy?n v? ph?a base ??ch
		botData.state = "moving_to_enemy_base"
		
		-- T?m base ??ch ?? di chuy?n ??n
		local enemyTeam = botData.team == "Team1" and "Team2" or "Team1"
		local enemyBase = nil
		
		-- T?m base ??ch trong Maps folder
		local mapsFolder = workspace:FindFirstChild("Maps")
		if mapsFolder then
			for _, mapFolder in pairs(mapsFolder:GetChildren()) do
				for _, obj in pairs(mapFolder:GetDescendants()) do
					if obj:IsA("Model") and string.find(obj.Name, enemyTeam .. "Base", 1, true) then
						enemyBase = obj
						break
					end
				end
				if enemyBase then break end
			end
		end
		
		-- Fallback: t?m trong workspace root
		if not enemyBase then
			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Model") and string.find(obj.Name, enemyTeam .. "Base", 1, true) then
					enemyBase = obj
					break
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
				botData.lastPatrol = tick()
			end
			if botData.patrolTarget then
				moveTo(botData, botData.patrolTarget)
			end
		end
	end
end

-- Spawn bot
local function spawnBot(teamName, spawnPos)
	botCounter = botCounter + 1
	local name = string.format("[BOT] Shadow%d", botCounter)

	-- T?m arena baseplate
	local arenaBaseplate = workspace:FindFirstChild("Arenas")
	if arenaBaseplate then
		local arena1v1 = arenaBaseplate:FindFirstChild("Arena1v1")
		if arena1v1 then
			arenaBaseplate = arena1v1:FindFirstChild("Baseplate")
		end
	end

	-- Spawn tr?n baseplate n?u t?m th?y, ngu?c l?i spawn ? v? tr? m?c d?nh
	local finalPos = spawnPos
	if arenaBaseplate then
		-- Spawn tr?n baseplate (Y=0.5 l? m?t tr?n c?a baseplate)
		finalPos = Vector3.new(spawnPos.X, 10, spawnPos.Z) -- 10 studs tr?n m?t d?t d? an to?n hon
	else
		-- Fallback: spawn ? d? cao 20
		finalPos = Vector3.new(spawnPos.X, 20, spawnPos.Z)
	end

	local character = createBotCharacter(name, teamName)
	if not character then
		warn("[BotManager] createBotCharacter failed, bo qua spawn")
		return nil
	end

	character.Parent = workspace

	character:SetAttribute("Team", teamName)

	-- Anchor t?m th?i d? tr?nh roi
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	character:SetPrimaryPartCFrame(CFrame.new(finalPos))

	-- Unanchor sau 0.2 gi?y d? d?m b?o ?n d?nh
	task.delay(0.2, function()
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Anchored = false
			end
		end
		-- HumanoidRootPart lu?n unanchored
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local spawnHrp = character:FindFirstChild("HumanoidRootPart")

	local botData = {
		name = name,
		team = teamName,
		character = character,
		humanoid = humanoid,
		hrp = spawnHrp,
		state = "idle",
		lastAttack = 0,
		patrolTarget = nil,
		lastPatrol = 0,
		wasRetreating = false,
		lastUpdateTime = tick(),
	}

	activeBots[character] = botData

	if not humanoid then
		warn("[BotManager] Bot khong co Humanoid")
		return botData
	end

	humanoid.Died:Connect(function()
		botData.state = "dead"

		-- Tang s? l?n ch?t
		botDeathCounts[name] = (botDeathCounts[name] or 0) + 1
		local deathCount = botDeathCounts[name]

		-- T?nh th?i gian respawn (tang d?n)
		local respawnTime = BOT_RESPAWN_TIME + (deathCount - 1) * 2
		respawnTime = math.min(respawnTime, 15) -- T?i da 15 gi?y


		-- X? l? respawn
		task.delay(respawnTime, function()
			-- X?a character cu
			if character and character.Parent then
				character:Destroy()
			end
			activeBots[character] = nil

			-- Respawn bot m?i
			local teamBase = workspace:FindFirstChild(teamName .. "Base")
			if teamBase then
				local basePos = teamBase:GetPivot().Position
				spawnBot(teamName, basePos + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)))
			end
		end)
	end)

	return botData
end

-- Public API - ROUTER (?i?u ph?i theo ch? d?)
-- BotManager đã được khai báo ở đầu script, không cần khai báo lại

local function normalizeMode(mode)
	if type(mode) ~= "string" then
		return "1v1"
	end
	mode = string.lower((mode):gsub("%s+", ""))
	if mode == "1v1" or mode == "2v2" or mode == "3v3" then
		return mode
	end
	return "1v1"
end

-- Uu tien Module da require; fallback _G neu module tu set
local function getManagerByMode(mode)
	mode = normalizeMode(mode)
	local manager = ModeManagers[mode] or (mode == "1v1" and _G.BotManager1v1)
		or (mode == "2v2" and _G.BotManager2v2)
		or (mode == "3v3" and _G.BotManager3v3)
		or nil
	
	if manager then
	else
		warn(string.format("[BotManager] getManagerByMode(%s): NO MANAGER FOUND!", mode))
	end
	
	return manager
end

-- Spawn bot theo ch? d?
function BotManager.SpawnBotForTeam(teamName, pos, mode)
	mode = normalizeMode(mode)
	
	local manager = getManagerByMode(mode)
	local botsFolder = getBotsFolderForMode(mode)

	if manager then
		local botData = manager.SpawnBotForTeam(teamName, pos)
		moveBotCharacterToFolder(botData, botsFolder)
		return botData
	else
		warn(string.format("[BotManager] ✗ KHÔNG TÌM THẤY BotManager%s! Using fallback spawn.", mode))
		-- Fallback: s? d?ng spawn m?c d?nh
		local botData = spawnBot(teamName, pos or Vector3.new(0, 10, 0))
		moveBotCharacterToFolder(botData, botsFolder)
		return botData
	end
end

-- L?y t?t c? bot t? t?t c? managers
function BotManager.GetActiveBots()
	-- H?p nh?t t? t?t c? managers
	local allBots = {}

	-- T? manager m?c d?nh
	for bot, data in pairs(activeBots) do
		allBots[bot] = data
	end

	local function mergeFromManager(mgr)
		if mgr and mgr.GetActiveBots then
			for bot, data in pairs(mgr.GetActiveBots()) do
				allBots[bot] = data
			end
		end
	end

	for _, mgr in pairs(ModeManagers) do
		mergeFromManager(mgr)
	end
	mergeFromManager(_G.BotManager1v1)
	mergeFromManager(_G.BotManager2v2)
	mergeFromManager(_G.BotManager3v3)

	return allBots
end

function BotManager.GetBotCount()
	local c = 0
	for _ in pairs(BotManager.GetActiveBots()) do c = c + 1 end
	return c
end

-- ??m bot theo team
function BotManager.GetBotCountByTeam(teamName)
	local c = 0
	for bot, data in pairs(BotManager.GetActiveBots()) do
		if data.team == teamName and data.state ~= "dead" then
			c = c + 1
		end
	end
	return c
end

-- X?a t?t c? bot t? t?t c? managers
function BotManager.ClearAllBots()
	local count = 0

	-- X?a t? manager m?c d?nh
	for bot, data in pairs(activeBots) do
		if bot and bot.Parent then
			bot:Destroy()
			count = count + 1
		end
	end
	activeBots = {}
	botCounter = 0

	local clearedManagers = {}
	local function clearManager(mgr)
		if not mgr or clearedManagers[mgr] or not mgr.ClearAllBots then
			return 0
		end
		clearedManagers[mgr] = true
		return mgr.ClearAllBots()
	end
	for _, mgr in pairs(ModeManagers) do
		count = count + clearManager(mgr)
	end
	count = count + clearManager(_G.BotManager1v1)
	count = count + clearManager(_G.BotManager2v2)
	count = count + clearManager(_G.BotManager3v3)

	return count
end

-- Spawn bot cho match theo ch? d?
function BotManager.SpawnBotsForMatch(teamName, count, basePositions, mode)
	mode = normalizeMode(mode)
	local manager = getManagerByMode(mode)
	local botsFolder = getBotsFolderForMode(mode)

	if manager then
		local spawned = {}
		for i = 1, count do
			local basePos = basePositions[i]
			if basePos then
				local spawnPos = basePos + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
				local botData = manager.SpawnBotForTeam(teamName, spawnPos)
				moveBotCharacterToFolder(botData, botsFolder)
				if botData then
					table.insert(spawned, botData)
				end
			end
		end
		return spawned
	else
		-- Fallback
		local spawned = {}
		for i = 1, count do
			local basePos = basePositions[i]
			if basePos then
				local spawnPos = basePos + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
				local botData = spawnBot(teamName, spawnPos)
				moveBotCharacterToFolder(botData, botsFolder)
				if botData then
					table.insert(spawned, botData)
				end
			end
		end
		return spawned
	end
end

-- AI Loop
RunService.Heartbeat:Connect(function(deltaTime)
	for _, data in pairs(activeBots) do
		if data.state ~= "dead" then
			-- H?i ph?c HP li?n t?c (nhanh hon khi r?t lui)
			regenerateHP(data, deltaTime)
			updateAI(data)
		end
	end
end)


if CONFIG.DEBUG_TEST_SPAWN then
	task.delay(1, function()
		local testBot = BotManager.SpawnBotForTeam("Team1", Vector3.new(0, 20, 0))
		if testBot then
			task.delay(2, function()
				local ch = testBot.character
				if ch and ch.Parent then
					activeBots[ch] = nil
					ch:Destroy()
				end
			end)
		else
			warn("[BotManager] Test spawn FAILED!")
		end
	end)
end

-- Scripts don't return values - only ModuleScripts do qwas 
