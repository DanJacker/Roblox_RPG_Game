-- Combat System - PvP và Respawn
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cấu hình combat
local CONFIG = {
	BASE_RESPAWN_TIME = 10,     -- Thời gian respawn cơ bản (giây)
	RESPAWN_INCREMENT = 3,      -- Tăng thêm mỗi lần chết (giây)
	MAX_RESPAWN_TIME = 30,      -- Thời gian respawn tối đa (giây)
	BASE_DAMAGE = 10,           -- Sát thương cơ bản
	ATTACK_COOLDOWN = 0.5,      -- Thời gian chờ giữa các đòn tấn công (giây)
	ATTACK_RANGE = 5,           -- Phạm vi tấn công (studs)
}

-- Lưu trữ số lần chết của mỗi người chơi
local deathCount = {}

-- Tạo RemoteEvent để thông báo cho client
local combatEvent = Instance.new("RemoteEvent")
combatEvent.Name = "CombatEvent"
combatEvent.Parent = ReplicatedStorage

-- Tạo RemoteFunction để client gọi tấn công
local combatFunction = Instance.new("RemoteFunction")
combatFunction.Name = "CombatFunction"
combatFunction.Parent = ReplicatedStorage

-- Tính thời gian respawn dựa trên số lần chết
local function getRespawnTime(player)
	local deaths = deathCount[player.UserId] or 0
	local respawnTime = CONFIG.BASE_RESPAWN_TIME + (deaths * CONFIG.RESPAWN_INCREMENT)
	return math.min(respawnTime, CONFIG.MAX_RESPAWN_TIME)
end

-- Xử lý khi người chơi chết
local function onPlayerDeath(player, killer)
	-- Tính thời gian respawn TRƯỚC khi tăng số lần chết
	local respawnTime = getRespawnTime(player)
	
	-- Sau đó mới tăng số lần chết cho lần chết tiếp theo
	deathCount[player.UserId] = (deathCount[player.UserId] or 0) + 1
	
	print(player.Name .. " died! Respawn in " .. respawnTime .. "s")
	print("Death count: " .. deathCount[player.UserId])
	
	-- Ghi nhận kill cho MatchEndConditions
	if killer and killer ~= player then
		if _G.MatchEndConditions then
			_G.MatchEndConditions.RecordKill(killer, player)
		end
	end
	
	-- Thông báo cho người chơi về thời gian respawn
	combatEvent:FireClient(player, {
		event = "PlayerDied",
		respawnTime = respawnTime,
		deathCount = deathCount[player.UserId],
		killer = killer and killer.Name or "Unknown"
	})
	
	-- Thông báo cho tất cả người chơi khác
	combatEvent:FireAllClients({
		event = "PlayerKilled",
		victim = player.Name,
		killer = killer and killer.Name or "Unknown"
	})
	
	-- Đợi thời gian respawn
	task.wait(respawnTime)
	
	-- Respawn người chơi
	if player and player.Parent then
		-- Kiểm tra nếu character đã bị destroy
		if not player.Character or player.Character.Parent == nil then
			player:LoadCharacter()
			print(player.Name .. " has respawned!")
			
			combatEvent:FireClient(player, {
				event = "PlayerRespawned"
			})
		end
	end
end

-- Xử lý tấn công từ client
combatFunction.OnServerInvoke = function(player, targetPlayerName)
	-- Kiểm tra người chơi có character không
	if not player.Character then
		return {success = false, message = "No character"}
	end
	
	-- Tìm người chơi mục tiêu
	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer or not targetPlayer.Character then
		return {success = false, message = "Invalid target"}
	end
	
	-- Kiểm tra khoảng cách
	local playerPos = player.Character:GetPivot().Position
	local targetPos = targetPlayer.Character:GetPivot().Position
	local distance = (playerPos - targetPos).Magnitude
	
	if distance > CONFIG.ATTACK_RANGE then
		return {success = false, message = "Out of range"}
	end
	
	-- Tìm Humanoid của mục tiêu
	local targetHumanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
if not targetHumanoid then
		return {success = false, message = "No humanoid"}
	end
	
	-- Gây sát thương
	targetHumanoid:TakeDamage(CONFIG.BASE_DAMAGE)
	
	-- Ghi nhận attacker để tracking kills
	if _G.SetLastAttacker then
		_G.SetLastAttacker(targetPlayer, player)
	end
	
	-- Thông báo cho cả hai người chơi
	combatEvent:FireClient(player, {
		event = "AttackHit",
		target = targetPlayerName,
		damage = CONFIG.BASE_DAMAGE
	})
	
	combatEvent:FireClient(targetPlayer, {
		event = "Damaged",
		attacker = player.Name,
		damage = CONFIG.BASE_DAMAGE,
		health = targetHumanoid.Health
	})
	
	return {success = true, damage = CONFIG.BASE_DAMAGE}
end

-- Export onPlayerDeath để KillTracker có thể gọi
_G.OnPlayerDeath = onPlayerDeath

-- Xử lý khi người chơi tham gia
Players.PlayerAdded:Connect(function(player)
	deathCount[player.UserId] = 0
	print("Combat system initialized for " .. player.Name)
end)

-- Xử lý khi người chơi rời game
Players.PlayerRemoving:Connect(function(player)
	deathCount[player.UserId] = nil
end)

-- Khởi tạo cho người chơi hiện tại
for _, player in ipairs(Players:GetPlayers()) do
	deathCount[player.UserId] = 0
end

print("=== Combat System đã khởi động ===")
print("- Base respawn time: " .. CONFIG.BASE_RESPAWN_TIME .. "s")
print("- Respawn increment: +" .. CONFIG.RESPAWN_INCREMENT .. "s per death")
print("- Max respawn time: " .. CONFIG.MAX_RESPAWN_TIME .. "s")