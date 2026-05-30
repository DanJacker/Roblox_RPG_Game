-- BotAttackBaseHandler - Xu ly khi bot tan cong base
-- ServerScriptService.Arena.BotAttackBaseHandler


-- ========== FUNCTION: BOT ATTACK BASE ==========
-- Function nay duoc goi khi bot tan cong base
local function botAttackBase(baseModel, defendingTeam, attackerName, attackerTeam, damage)
	if not baseModel then return end
	
	-- Tim BaseHumanoid trong base
	local baseHumanoid = baseModel:FindFirstChild("BaseHumanoid")
	if not baseHumanoid then
		-- Fallback: Tim Humanoid
		baseHumanoid = baseModel:FindFirstChildOfClass("Humanoid")
	end
	
	if not baseHumanoid then
		warn("[BotAttackBaseHandler] Khong tim thay BaseHumanoid trong " .. baseModel.Name)
		return
	end
	
	-- Giam HP base
	local oldHealth = baseHumanoid.Health
	baseHumanoid.Health = math.max(0, baseHumanoid.Health - damage)
	
	print(string.format("[BotAttackBaseHandler] %s (%s) danh %s: %.0f damage (HP: %.0f -> %.0f)", 
		attackerName, attackerTeam, baseModel.Name, damage, oldHealth, baseHumanoid.Health))
	
	-- Kiem tra neu base bi huy
	if baseHumanoid.Health <= 0 then
		
		-- Thong bao cho MatchEndConditions
		if _G.MatchEndConditions and _G.MatchEndConditions.RecordBaseDestroyed then
			_G.MatchEndConditions.RecordBaseDestroyed(defendingTeam, attackerTeam)
		end
	end
end

-- ========== EXPORT ==========
_G.BotAttackBase = botAttackBase

