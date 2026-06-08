-- PatrolMonsterSystem - Quai patrol vung co dinh, uu tien danh player hon bot (model giong Rig)
-- ServerScriptService/Arena/PatrolMonsterSystem (Script hoac ModuleScript + require)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	-- Bot dùng `Rig`, quái dùng riêng `RigTemplate`
	TEMPLATE_NAMES = { "RigTemplate" },
	MONSTER_FOLDER_NAME = "PatrolMonsters",
	DEFAULT_ZONE_RADIUS = 45,
	DEFAULT_PATROL_RADIUS = 22,
	DETECTION_BUFFER = 2,
	ATTACK_RANGE = 8,
	ATTACK_DAMAGE = 3,  -- Giam tu 18 xuong 3
	ATTACK_COOLDOWN = 1.1,
	WALK_SPEED = 14,
	MAX_HEALTH = 120,
	PATROL_REPICK_MIN = 2,
	PATROL_REPICK_MAX = 5,
	CHASE_LEASH = 1.1,  -- Monster quay ve zone center neu xa qua zoneRadius * 1.1
	HP_REGEN_IDLE = 2,
	HP_REGEN_COMBAT = 0,
	HP_REGEN_RETURNING = 20,  -- Hoi mau nhanh khi dang quay ve zone center
	MONSTER_TINT = Color3.fromRGB(120, 80, 160),
}

local function getMapContainerFromPosition(pos)
	local mapsFolder = Workspace:FindFirstChild("Maps")
	if not mapsFolder or not pos then
		return Workspace
	end

	local best, bestDist = nil, math.huge
	for _, mapModel in ipairs(mapsFolder:GetChildren()) do
		if mapModel:IsA("Model") then
			local pivotPos = mapModel:GetPivot().Position
			local dx = pivotPos.X - pos.X
			local dz = pivotPos.Z - pos.Z
			local d = dx * dx + dz * dz
			if d < bestDist then
				bestDist = d
				best = mapModel
			end
		end
	end

	return best or Workspace
end

local function getMonstersFolderForContainer(container)
	local parent = container or Workspace
	local folder = parent:FindFirstChild(CONFIG.MONSTER_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = CONFIG.MONSTER_FOLDER_NAME
		folder.Parent = parent
	end
	return folder
end

local monsterCounter = 0
local active = {}

local function getRigTemplate()
	for _, n in ipairs(CONFIG.TEMPLATE_NAMES) do
		local w = Workspace:FindFirstChild(n)
		if w and w:IsA("Model") then
			return w
		end
	end
	local rs = game:GetService("ReplicatedStorage")
	for _, n in ipairs(CONFIG.TEMPLATE_NAMES) do
		local t = rs:FindFirstChild(n)
		if t and t:IsA("Model") then
			return t
		end
	end
	return nil
end

local function ensureLastAttacker(model)
	local v = model:FindFirstChild("LastAttacker")
	if not v then
		v = Instance.new("StringValue")
		v.Name = "LastAttacker"
		v.Parent = model
	end
	return v
end

local function recordAttacker(monsterModel, attackerCharacter)
	if not attackerCharacter or not monsterModel then
		return
	end
	local plr = Players:GetPlayerFromCharacter(attackerCharacter)
	local nameStr = plr and plr.Name or attackerCharacter.Name
	ensureLastAttacker(monsterModel).Value = nameStr
end

local function hookIncomingDamage(monsterModel, humanoid)
	humanoid.Touched:Connect(function(hit)
		local char = hit:FindFirstAncestorOfClass("Model")
		if not char or char == monsterModel then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		if char:GetAttribute("IsPatrolMonster") then
			return
		end
		recordAttacker(monsterModel, char)
	end)
end

local function createMonsterCharacter(displayName, zoneCenter, parentFolder)
	local template = getRigTemplate()
	if not template then
		warn("[PatrolMonster] Không tìm thấy `RigTemplate` (Workspace/ReplicatedStorage)")
		return nil
	end

	monsterCounter = monsterCounter + 1
	local char = template:Clone()
	char.Name = "[Monster] " .. displayName .. "_" .. tostring(monsterCounter)
	char:SetAttribute("IsPatrolMonster", true)
	char:SetAttribute("MonsterId", monsterCounter)

	local anim = char:FindFirstChild("Animate")
	if anim then
		anim:Destroy()
	end

	local tint = CONFIG.MONSTER_TINT
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") or p:IsA("MeshPart") then
			p.Color = Color3.new(
				math.clamp(p.Color.R * 0.4 + tint.R * 0.6, 0, 1),
				math.clamp(p.Color.G * 0.4 + tint.G * 0.6, 0, 1),
				math.clamp(p.Color.B * 0.4 + tint.B * 0.6, 0, 1)
			)
		end
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = CONFIG.MAX_HEALTH
		humanoid.Health = CONFIG.MAX_HEALTH
		humanoid.WalkSpeed = CONFIG.WALK_SPEED
		humanoid.AutoRotate = true
	end

	char.Parent = parentFolder or Workspace

	if char.PrimaryPart == nil then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			char.PrimaryPart = hrp
		end
	end

	if char.PrimaryPart then
		char:SetPrimaryPartCFrame(CFrame.new(zoneCenter + Vector3.new(0, 3, 0)))
	end

	if humanoid then
		hookIncomingDamage(char, humanoid)
	end

	-- Bo sung: cham vao model quai cung ghi LastAttacker (Combat thuong cham Part)
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") and part.CanTouch ~= false then
			part.Touched:Connect(function(hit)
				local attackerChar = hit:FindFirstAncestorOfClass("Model")
				if attackerChar and attackerChar ~= char and not attackerChar:GetAttribute("IsPatrolMonster") then
					local hum = attackerChar:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						recordAttacker(char, attackerChar)
					end
				end
			end)
		end
	end

	return char, humanoid
end

local function flatDist(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function randomPatrolPoint(data, fromPos)
	local center = data.zoneCenter
	local r = data.patrolRadius
	for _ = 1, 12 do
		local ang = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * r
		local pos = center + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		pos = Vector3.new(pos.X, fromPos.Y, pos.Z)
		if flatDist(pos, center) <= r + 0.01 then
			return pos
		end
	end
	return center
end

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function isHostileCharacter(char, myModel)
	if not char or char == myModel then
		return false
	end
	if char:GetAttribute("IsPatrolMonster") then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then
		return false
	end
	local plr = Players:GetPlayerFromCharacter(char)
	if plr then
		local t = plr.Team and plr.Team.Name
		return t == "Team1" or t == "Team2"
	end
	local teamAttr = char:GetAttribute("Team")
	return teamAttr == "Team1" or teamAttr == "Team2"
end

local botCandidatesCacheByContainer = {}
local botCandidatesCacheTimeByContainer = {}
local BOT_CACHE_TTL = 0.25

local function refreshBotCandidates(container)
	local now = tick()
	container = container or Workspace
	local lastTime = botCandidatesCacheTimeByContainer[container] or -math.huge
	local cached = botCandidatesCacheByContainer[container]
	if cached and now - lastTime < BOT_CACHE_TTL then
		return cached
	end
	botCandidatesCacheTimeByContainer[container] = now
	local list = {}
	
	-- SỬA: Sử dụng _G.BotManager để lấy TẤT CẢ bot từ tất cả managers
	local BotManager = _G.BotManager
	if BotManager and BotManager.GetActiveBots then
		for bot, data in pairs(BotManager.GetActiveBots()) do
			if data.state ~= "dead" and bot.Parent then
				table.insert(list, bot)
			end
		end
	else
		-- Fallback: Tìm bot trực tiếp trong container
		for _, inst in ipairs(container:GetDescendants()) do
			if inst:IsA("Model") and inst:GetAttribute("Team") then
				if not Players:GetPlayerFromCharacter(inst) and not inst:GetAttribute("IsPatrolMonster") then
					table.insert(list, inst)
				end
			end
		end
	end
	
	botCandidatesCacheByContainer[container] = list
	return list
end

local function findBestTarget(data, myPos)
	-- AGGRO-ON-HIT: Chi tan cong khi bi danh truoc
	if not data.hasAggro then
		return nil, nil
	end

	-- Kiem tra aggro target (player da danh minh)
	if data.aggroTarget then
		local plr = data.aggroTarget
		if plr and plr.Parent then
			local char = plr.Character
			if isHostileCharacter(char, data.model) then
				local hrp = getRoot(char)
				if hrp then
					local d = flatDist(myPos, hrp.Position)
					local maxRange = data.zoneRadius * CONFIG.CHASE_LEASH
					if d <= maxRange then
						return char, d
					end
				end
			end
		end
		-- Aggro target mat (chet/xa/ve base) -> mat aggro
		data.hasAggro = false
		data.aggroTarget = nil
	end

	return nil, nil
end

local function faceAndAttack(data, targetChar, dist)
	local monster = data.model
	local myHrp = getRoot(monster)
	local th = targetChar:FindFirstChildOfClass("Humanoid")
	local thrp = getRoot(targetChar)
	if not myHrp or not th or not thrp or th.Health <= 0 then
		return
	end

	myHrp.CFrame = CFrame.new(myHrp.Position, Vector3.new(thrp.Position.X, myHrp.Position.Y, thrp.Position.Z))

	local now = tick()
	if dist <= CONFIG.ATTACK_RANGE and now - data.lastAttack >= CONFIG.ATTACK_COOLDOWN then
		data.lastAttack = now
		th:TakeDamage(CONFIG.ATTACK_DAMAGE)
	end
end

local function updateMonster(data, dt)
	local monster = data.model
	if not monster.Parent then
		active[monster] = nil
		return
	end

	local hum = monster:FindFirstChildOfClass("Humanoid")
	local hrp = getRoot(monster)
	if not hum or not hrp or hum.Health <= 0 then
		return
	end

	local pos = hrp.Position

	-- LEASH: Monster xa zone qua -> quay ve zone center, hoi mau nhanh
	if flatDist(pos, data.zoneCenter) > data.zoneRadius * CONFIG.CHASE_LEASH then
		data.chaseTarget = nil
		data.hasAggro = false
		data.aggroTarget = nil
		data.isReturning = true
		hum:MoveTo(Vector3.new(data.zoneCenter.X, pos.Y, data.zoneCenter.Z))
		-- Hoi mau nhanh khi dang quay ve
		hum.Health = math.min(hum.Health + CONFIG.HP_REGEN_RETURNING * dt, hum.MaxHealth)
		return
	end

	-- Da ve gan zone center -> het trang thai returning
	if data.isReturning then
		if flatDist(pos, data.zoneCenter) <= 8 then
			data.isReturning = false
		end
	end

	-- Hoi mau theo trang thai
	if data.hasAggro then
		hum.Health = math.min(hum.Health + CONFIG.HP_REGEN_COMBAT * dt, hum.MaxHealth)
	elseif data.isReturning then
		hum.Health = math.min(hum.Health + CONFIG.HP_REGEN_RETURNING * dt, hum.MaxHealth)
	else
		hum.Health = math.min(hum.Health + CONFIG.HP_REGEN_IDLE * dt, hum.MaxHealth)
	end

	local target, tDist = findBestTarget(data, pos)

	if target and tDist then
		local thrp = getRoot(target)
		if thrp then
			if tDist <= CONFIG.ATTACK_RANGE + 0.5 then
				faceAndAttack(data, target, tDist)
			else
				hum:MoveTo(thrp.Position)
			end
		end
		return
	end

	if not data.nextPatrol or tick() > data.nextPatrol then
		data.nextPatrol = tick() + math.random(CONFIG.PATROL_REPICK_MIN, CONFIG.PATROL_REPICK_MAX)
		data.patrolGoal = randomPatrolPoint(data, pos)
	end
	if data.patrolGoal then
		hum:MoveTo(data.patrolGoal)
	end
end

local PatrolMonster = {}

function PatrolMonster.Spawn(opts)
	opts = opts or {}
	local center = opts.zoneCenter or opts.patrolCenter or Vector3.new(0, 5, 0)
	local zoneR = opts.zoneRadius or CONFIG.DEFAULT_ZONE_RADIUS
	local patrolR = math.min(opts.patrolRadius or CONFIG.DEFAULT_PATROL_RADIUS, zoneR)
	local name = opts.displayName or "Creep"

	local mapContainer = opts.mapContainer or getMapContainerFromPosition(center)
	local monstersFolder = getMonstersFolderForContainer(mapContainer)
	local char, hum = createMonsterCharacter(name, center, monstersFolder)
	if not char or not hum then
		return nil
	end

	active[char] = {
		model = char,
		mapContainer = mapContainer,
		monstersFolder = monstersFolder,
		zoneCenter = center,
		zoneRadius = zoneR,
		patrolRadius = patrolR,
		lastAttack = 0,
		chaseTarget = nil,
		nextPatrol = 0,
		patrolGoal = nil,
		hasAggro = false,
		aggroTarget = nil,
		isReturning = false,
	}

	hum.Died:Connect(function()
		active[char] = nil
	end)

	-- AGGRO-ON-HIT: Monster bi danh -> bat dau truy duoi player do
	hum.HealthChanged:Connect(function(newHealth)
		if newHealth < hum.MaxHealth then
			local mData = active[char]
			if not mData or mData.hasAggro then return end

			-- Tim player gan nhat lam aggro target
			local hrp = getRoot(char)
			if hrp then
				local closestPlayer = nil
				local closestDist = math.huge
				for _, p in Players:GetPlayers() do
					if p.Character then
						local pH = p.Character:FindFirstChildOfClass("Humanoid")
						local pHrp = getRoot(p.Character)
						if pH and pH.Health > 0 and pHrp then
							local d = flatDist(hrp.Position, pHrp.Position)
							if d < closestDist and d <= zoneR * CONFIG.CHASE_LEASH then
								closestDist = d
								closestPlayer = p
							end
						end
					end
				end
				if closestPlayer then
					mData.hasAggro = true
					mData.aggroTarget = closestPlayer
				end
			end
		end
	end)

	return char
end

function PatrolMonster.ClearAll()
	for m in pairs(active) do
		if m and m.Parent then
			m:Destroy()
		end
	end
	table.clear(active)
end

function PatrolMonster.GetActive()
	return active
end

RunService.Heartbeat:Connect(function(dt)
	for _, data in active do
		updateMonster(data, dt)
	end
end)

_G.PatrolMonster = PatrolMonster


return PatrolMonster
