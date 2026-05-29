-- Kill Tracker - Theo dõi kills khi player chết
local Players = game:GetService("Players")

print("[KillTracker] Đang khởi động...")

-- Lưu trữ người tấn công cuối cùng của mỗi player
local lastAttacker = {}

-- ========== HÀM HELPER ==========

-- Xác định killer dựa trên lastAttacker
local function getKiller(victim)
	local attackerName = lastAttacker[victim.UserId]
	if attackerName then
		return Players:FindFirstChild(attackerName)
	end
	return nil
end

-- ========== XỬ LÝ KHI PLAYER CHẾT ==========

local function onPlayerDeath(player)
	-- Đợi một chút để đảm bảo character đã chết
	task.wait(0.1)
	
	-- Tìm killer
	local killer = getKiller(player)
	
	-- Gọi onPlayerDeath từ CombatSystem nếu có
	if _G.OnPlayerDeath then
		_G.OnPlayerDeath(player, killer)
	end
	
	-- Ghi nhận kill cho MVPSystem
	if killer and _G.MVPSystem then
		_G.MVPSystem.RecordKill(killer.Name, player.Name)
	end
	
	-- KHÔNG gọi RecordKill ở đây nữa - CombatSystem đã gọi trong onPlayerDeath
	-- Tránh duplicate kill count
	
	-- Xóa lastAttacker
	lastAttacker[player.UserId] = nil
	
	print(string.format("[KillTracker] %s died | Killer: %s",
		player.Name, killer and killer.Name or "None"))
end

-- ========== THEO DÕI SÁT THƯƠNG ==========

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	
	-- Theo dõi khi character chết
	humanoid.Died:Connect(function()
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			onPlayerDeath(player)
		end
	end)
	
	-- Theo dõi sát thương để xác định attacker
	humanoid.HealthChanged:Connect(function(newHealth)
		-- Nếu health giảm, có thể là do bị tấn công
		-- Chúng ta sẽ dựa vào CombatSystem để ghi nhận attacker
	end)
end

-- ========== KHỞI TẠO ==========

-- Xử lý cho players hiện tại
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setupCharacter(player.Character)
	end
	
	player.CharacterAdded:Connect(setupCharacter)
end

-- Xử lý cho players mới tham gia
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupCharacter)
end)

-- ========== EXPORT TO _G ==========

_G.SetLastAttacker = function(victimPlayer, attackerPlayer)
	lastAttacker[victimPlayer.UserId] = attackerPlayer.Name
end

print("[KillTracker] Đã khởi động thành công!")

return nil