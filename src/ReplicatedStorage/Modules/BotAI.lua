-- Bot AI Module - Điều khiển bot AI (Tách riêng theo chế độ chơi)
local BotAI = {}

-- ========== CẤU HÌNH THEO CHẾ ĐỘ ==========
local MODE_CONFIG = {
	["1v1"] = {
		ATTACK_RANGE = 8,
		DETECTION_RANGE = 60,
		ATTACK_DAMAGE = 15,
		ATTACK_COOLDOWN = 1.2,
		PATROL_RANGE = 25,
		CHASE_RANGE = 50,
		BASE_DEFENSE_RANGE = 35,
		RETREAT_HEALTH = 0.30,
		RECOVERY_HEALTH = 0.55,
		HP_REGEN = 2,
		AGGRESSIVENESS = 0.8,
		BASE_PRIORITY = 0.6,
	},
	["2v2"] = {
		ATTACK_RANGE = 10,
		DETECTION_RANGE = 70,
		ATTACK_DAMAGE = 12,
		ATTACK_COOLDOWN = 1.0,
		PATROL_RANGE = 30,
		CHASE_RANGE = 55,
		BASE_DEFENSE_RANGE = 40,
		RETREAT_HEALTH = 0.25,
		RECOVERY_HEALTH = 0.50,
		HP_REGEN = 1.5,
		AGGRESSIVENESS = 0.6,
		BASE_PRIORITY = 0.7,
		TEAM_COORDINATION = true,
	},
	["3v3"] = {
		ATTACK_RANGE = 12,
		DETECTION_RANGE = 80,
		ATTACK_DAMAGE = 10,
		ATTACK_COOLDOWN = 0.8,
		PATROL_RANGE = 35,
		CHASE_RANGE = 60,
		BASE_DEFENSE_RANGE = 45,
		RETREAT_HEALTH = 0.20,
		RECOVERY_HEALTH = 0.45,
		HP_REGEN = 1,
		AGGRESSIVENESS = 0.5,
		BASE_PRIORITY = 0.8,
		TEAM_COORDINATION = true,
		GROUP_ATTACK = true,
	},
}

-- Cấu hình mặc định
local DEFAULT_CONFIG = {
	ATTACK_RANGE = 10,
	DETECTION_RANGE = 60,
	ATTACK_DAMAGE = 12,
	ATTACK_COOLDOWN = 1.0,
	PATROL_RANGE = 30,
	CHASE_RANGE = 50,
	BASE_DEFENSE_RANGE = 40,
	RETREAT_HEALTH = 0.25,
	RECOVERY_HEALTH = 0.50,
	HP_REGEN = 1.5,
	AGGRESSIVENESS = 0.6,
	BASE_PRIORITY = 0.7,
}

-- ========== HÀM TIỆN ÍCH ==========

-- Lấy cấu hình theo chế độ
function BotAI.GetConfig(mode)
	return MODE_CONFIG[mode] or DEFAULT_CONFIG
end

-- Tìm base địch gần nhất
function BotAI.FindNearestEnemyBase(bot, team)
	local nearestBase = nil
	local nearestDistance = math.huge
	local nearestBaseHumanoid = nil
	
	local botHrp = bot:FindFirstChild("HumanoidRootPart")
	if not botHrp then return nil, nil, math.huge end
	
	-- Tìm trong Workspace.Maps
	local maps = game.Workspace:FindFirstChild("Maps")
	if not maps then return nil, nil, math.huge end
	
	-- Xác định team địch cần tìm
	local enemyTeam = (team == "Team1") and "Team2" or "Team1"
	local enemyBaseName = enemyTeam .. "Base"
	
	-- Tìm tất cả map và base
	for _, map in ipairs(maps:GetChildren()) do
		for _, base in ipairs(map:GetChildren()) do
			if string.find(base.Name, enemyBaseName) then
				-- Tìm BaseHumanoid trong base
				local baseHumanoid = base:FindFirstChild("BaseHumanoid")
				local tower = base:FindFirstChild("Tower")
				
				if baseHumanoid and baseHumanoid.Health > 0 then
					local targetPart = tower or base:FindFirstChildWhichIsA("BasePart")
					if targetPart then
						local distance = (targetPart.Position - botHrp.Position).Magnitude
						if distance < nearestDistance then
							nearestDistance = distance
							nearestBase = base
							nearestBaseHumanoid = baseHumanoid
						end
					end
				end
			end
		end
	end
	
	return nearestBase, nearestBaseHumanoid, nearestDistance
end

-- Tìm mục tiêu gần nhất (player, bot, hoặc base)
function BotAI.FindNearestTarget(bot, team, config)
	local nearestTarget = nil
	local nearestDistance = config.DETECTION_RANGE
	local nearestType = nil
	
	local botHrp = bot:FindFirstChild("HumanoidRootPart")
	if not botHrp then return nil, 0, nil end
	
	local Players = game:GetService("Players")
	
	-- Tìm player địch
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			
			local isEnemy = false
			if (team == "Team1" and player.Team and player.Team.Name == "Team2") or
			   (team == "Team2" and player.Team and player.Team.Name == "Team1") then
				isEnemy = true
			end
			
			if isEnemy and humanoid and humanoid.Health > 0 and hrp then
				local distance = (hrp.Position - botHrp.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestTarget = player.Character
					nearestType = "player"
				end
			end
		end
	end
	
	-- Tìm bot địch
	local activeBots = _G.GetActiveBots and _G.GetActiveBots()
	if activeBots then
		for enemyBot, botData in pairs(activeBots) do
			if botData.team ~= team and botData.state ~= "dead" then
				local hrp = enemyBot:FindFirstChild("HumanoidRootPart")
				local humanoid = enemyBot:FindFirstChildOfClass("Humanoid")
				if hrp and humanoid and humanoid.Health > 0 then
					local distance = (hrp.Position - botHrp.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestTarget = enemyBot
						nearestType = "bot"
					end
				end
			end
		end
	end
	
	return nearestTarget, nearestDistance, nearestType
end

-- Di chuyển đến mục tiêu
function BotAI.MoveToTarget(bot, target)
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local targetHrp = target:FindFirstChild("HumanoidRootPart")
	
	if humanoid and targetHrp then
		humanoid:MoveTo(targetHrp.Position)
	end
end

-- Di chuyển đến base
function BotAI.MoveToBase(bot, base)
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local tower = base:FindFirstChild("Tower")
	local targetPart = tower or base:FindFirstChildWhichIsA("BasePart")
	
	if humanoid and targetPart then
		humanoid:MoveTo(targetPart.Position)
	end
end

-- Tấn công base
function BotAI.AttackBase(bot, baseHumanoid, config)
	if baseHumanoid and baseHumanoid.Health > 0 then
		baseHumanoid:TakeDamage(config.ATTACK_DAMAGE)
		return true
	end
	return false
end

-- Tấn công mục tiêu
function BotAI.AttackTarget(bot, target, config)
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local botHrp = bot:FindFirstChild("HumanoidRootPart")
	local targetHrp = target:FindFirstChild("HumanoidRootPart")
	
	if humanoid and targetHumanoid and botHrp and targetHrp then
		local distance = (targetHrp.Position - botHrp.Position).Magnitude
		if distance <= config.ATTACK_RANGE then
			targetHumanoid:TakeDamage(config.ATTACK_DAMAGE)
			return true
		end
	end
	return false
end

-- ========== AI THEO CHẾ ĐỘ ==========

-- AI cho 1v1: Tập trung vào combat 1vs1, đánh quyết liệt
function BotAI.Start1v1(bot, team)
	local config = BotAI.GetConfig("1v1")
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local lastAttackTime = 0
	
	task.spawn(function()
		while bot and bot.Parent and humanoid and humanoid.Health > 0 do
			-- Ưu tiên tìm enemy trước
			local target, distance, targetType = BotAI.FindNearestTarget(bot, team, config)
			
			if target then
				-- Có enemy -> tấn công enemy
				BotAI.MoveToTarget(bot, target)
				
				if distance <= config.ATTACK_RANGE then
					if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
						BotAI.AttackTarget(bot, target, config)
						lastAttackTime = tick()
					end
				end
			else
				-- Không có enemy -> tìm base địch để tấn công
				local enemyBase, baseHumanoid, baseDistance = BotAI.FindNearestEnemyBase(bot, team)
				
				if enemyBase and baseHumanoid then
					BotAI.MoveToBase(bot, enemyBase)
					
					if baseDistance <= config.ATTACK_RANGE then
						if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
							BotAI.AttackBase(bot, baseHumanoid, config)
							lastAttackTime = tick()
						end
					end
				else
					-- Không có base -> patrol
					local botHrp = bot:FindFirstChild("HumanoidRootPart")
					if botHrp then
						local randomOffset = Vector3.new(
							(math.random() - 0.5) * config.PATROL_RANGE,
							0,
							(math.random() - 0.5) * config.PATROL_RANGE
						)
						humanoid:MoveTo(botHrp.Position + randomOffset)
					end
				end
			end
			
			task.wait(0.5)
		end
	end)
end

-- AI cho 2v2: Có hỗ trợ đồng đội
function BotAI.Start2v2(bot, team)
	local config = BotAI.GetConfig("2v2")
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local lastAttackTime = 0
	
	task.spawn(function()
		while bot and bot.Parent and humanoid and humanoid.Health > 0 do
			-- Ưu tiên tìm enemy trước
			local target, distance, targetType = BotAI.FindNearestTarget(bot, team, config)
			
			if target then
				-- Có enemy -> tấn công enemy
				BotAI.MoveToTarget(bot, target)
				
				if distance <= config.ATTACK_RANGE then
					if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
						BotAI.AttackTarget(bot, target, config)
						lastAttackTime = tick()
					end
				end
			else
				-- Không có enemy -> tìm base địch để tấn công
				local enemyBase, baseHumanoid, baseDistance = BotAI.FindNearestEnemyBase(bot, team)
				
				if enemyBase and baseHumanoid then
					BotAI.MoveToBase(bot, enemyBase)
					
					if baseDistance <= config.ATTACK_RANGE then
						if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
							BotAI.AttackBase(bot, baseHumanoid, config)
							lastAttackTime = tick()
						end
					end
				else
					-- Không có base -> patrol
					local botHrp = bot:FindFirstChild("HumanoidRootPart")
					if botHrp then
						local randomOffset = Vector3.new(
							(math.random() - 0.5) * config.PATROL_RANGE,
							0,
							(math.random() - 0.5) * config.PATROL_RANGE
						)
						humanoid:MoveTo(botHrp.Position + randomOffset)
					end
				end
			end
			
			task.wait(0.5)
		end
	end)
end

-- AI cho 3v3: Tấn công theo nhóm
function BotAI.Start3v3(bot, team)
	local config = BotAI.GetConfig("3v3")
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local lastAttackTime = 0
	
	task.spawn(function()
		while bot and bot.Parent and humanoid and humanoid.Health > 0 do
			-- Ưu tiên tìm enemy trước
			local target, distance, targetType = BotAI.FindNearestTarget(bot, team, config)
			
			if target then
				-- Có enemy -> tấn công enemy
				BotAI.MoveToTarget(bot, target)
				
				if distance <= config.ATTACK_RANGE then
					if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
						BotAI.AttackTarget(bot, target, config)
						lastAttackTime = tick()
					end
				end
			else
				-- Không có enemy -> tìm base địch để tấn công
				local enemyBase, baseHumanoid, baseDistance = BotAI.FindNearestEnemyBase(bot, team)
				
				if enemyBase and baseHumanoid then
					BotAI.MoveToBase(bot, enemyBase)
					
					if baseDistance <= config.ATTACK_RANGE then
						if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
							BotAI.AttackBase(bot, baseHumanoid, config)
							lastAttackTime = tick()
						end
					end
				else
					-- Không có base -> patrol
					local botHrp = bot:FindFirstChild("HumanoidRootPart")
					if botHrp then
						local randomOffset = Vector3.new(
							(math.random() - 0.5) * config.PATROL_RANGE,
							0,
							(math.random() - 0.5) * config.PATROL_RANGE
						)
						humanoid:MoveTo(botHrp.Position + randomOffset)
					end
				end
			end
			
			task.wait(0.5)
		end
	end)
end

-- Main AI entry point - tự động chọn chế độ
function BotAI.Start(bot, team, mode)
	mode = mode or "1v1"
	
	if mode == "1v1" then
		return BotAI.Start1v1(bot, team)
	elseif mode == "2v2" then
		return BotAI.Start2v2(bot, team)
	elseif mode == "3v3" then
		return BotAI.Start3v3(bot, team)
	else
		-- Fallback to default
		local config = BotAI.GetConfig(mode)
		local humanoid = bot:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		local lastAttackTime = 0
		
		task.spawn(function()
			while bot and bot.Parent and humanoid and humanoid.Health > 0 do
				-- Ưu tiên tìm enemy trước
				local target, distance, targetType = BotAI.FindNearestTarget(bot, team, config)
				
				if target then
					-- Có enemy -> tấn công enemy
					BotAI.MoveToTarget(bot, target)
					
					if distance <= config.ATTACK_RANGE then
						if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
							BotAI.AttackTarget(bot, target, config)
							lastAttackTime = tick()
						end
					end
				else
					-- Không có enemy -> tìm base địch để tấn công
					local enemyBase, baseHumanoid, baseDistance = BotAI.FindNearestEnemyBase(bot, team)
					
					if enemyBase and baseHumanoid then
						BotAI.MoveToBase(bot, enemyBase)
						
						if baseDistance <= config.ATTACK_RANGE then
							if tick() - lastAttackTime >= config.ATTACK_COOLDOWN then
								BotAI.AttackBase(bot, baseHumanoid, config)
								lastAttackTime = tick()
							end
						end
					else
						-- Không có base -> patrol
						local botHrp = bot:FindFirstChild("HumanoidRootPart")
						if botHrp then
							local randomOffset = Vector3.new(
								(math.random() - 0.5) * config.PATROL_RANGE,
								0,
								(math.random() - 0.5) * config.PATROL_RANGE
							)
							humanoid:MoveTo(botHrp.Position + randomOffset)
						end
					end
				end
				
				task.wait(0.5)
			end
		end)
	end
end

return BotAI