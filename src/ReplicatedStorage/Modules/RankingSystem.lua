-- RankingSystem - Hệ thống xếp hạng
local RankingSystem = {}

-- Cấu hình rank
local RANKS = {
	{ name = "Sắt", color = Color3.fromRGB(150, 150, 150), tiers = 3 },		-- Iron
	{ name = "Đồng", color = Color3.fromRGB(205, 127, 50), tiers = 3 },		-- Bronze
	{ name = "Bạc", color = Color3.fromRGB(192, 192, 192), tiers = 3 },	-- Silver
	{ name = "Vàng", color = Color3.fromRGB(255, 215, 0), tiers = 3 },		-- Gold
	{ name = "Bạch Kim", color = Color3.fromRGB(0, 255, 255), tiers = 3 },	-- Platinum
	{ name = "Kim Cương", color = Color3.fromRGB(0, 191, 255), tiers = 3 },	-- Diamond
	{ name = "Cao Thủ", color = Color3.fromRGB(148, 0, 211), tiers = 3 },	-- Master
	{ name = "Thách Đấu", color = Color3.fromRGB(255, 0, 0), tiers = 1 },	-- Challenger (chỉ 1 tier)
}

-- Điểm cần để lên mốc (100 điểm mỗi mốc)
local POINTS_PER_TIER = 100

-- Điểm thưởng/phạt theo chế độ
local POINTS_BY_MODE = {
	["1v1"] = {
		WIN = 50,
		LOSE = -50,
		DRAW = 25
	},
	["2v2"] = {
		WIN = 100,
		LOSE = -100,
		DRAW = 50
	},
	["3v3"] = {
		WIN = 150,
		LOSE = -150,
		DRAW = 75
	}
}

-- Default (fallback)
local POINTS = {
	WIN = 50,
	LOSE = -50,
	DRAW = 25
}

-- Lấy thông tin rank từ điểm số
function RankingSystem.GetRankFromPoints(points)
	points = math.max(0, points or 0)
	
	-- Tính tổng điểm cần cho mỗi rank
	local accumulatedPoints = 0
	
	for rankIndex, rankData in ipairs(RANKS) do
		local tiers = rankData.tiers
		local rankTotalPoints = tiers * POINTS_PER_TIER
		
		-- Kiểm tra nếu points nằm trong rank này
		if points < accumulatedPoints + rankTotalPoints then
			-- Player ở rank này
			local pointsInRank = points - accumulatedPoints
			
			-- Tính tier: tier cao nhất = 1, tier thấp nhất = tiers
			-- Ví dụ: Sắt có 300 điểm (0-299)
			-- 0-99 = Sắt 3, 100-199 = Sắt 2, 200-299 = Sắt 1
			local tierNumber = tiers - math.floor(pointsInRank / POINTS_PER_TIER)
			local pointsInCurrentTier = pointsInRank % POINTS_PER_TIER
			
			return {
				rankIndex = rankIndex,
				rankName = rankData.name,
				tier = tierNumber,
				color = rankData.color,
				points = pointsInCurrentTier,
				maxPoints = POINTS_PER_TIER,
				totalPoints = points,
				displayName = rankData.name .. " " .. tierNumber,
				isMaxRank = rankIndex == #RANKS and tierNumber == 1
			}
		end
		
		accumulatedPoints = accumulatedPoints + rankTotalPoints
	end
	
	-- Đã đạt rank cao nhất (Thách Đấu)
	local lastRank = RANKS[#RANKS]
	local lastRankTotalPoints = lastRank.tiers * POINTS_PER_TIER
	local pointsAboveMax = points - accumulatedPoints
	
	return {
		rankIndex = #RANKS,
		rankName = lastRank.name,
		tier = 1,
		color = lastRank.color,
		points = math.min(pointsAboveMax, POINTS_PER_TIER - 1),
		maxPoints = POINTS_PER_TIER,
		totalPoints = points,
		displayName = lastRank.name .. " 1",
		isMaxRank = true
	}
end

-- Tính điểm mới sau trận đấu
function RankingSystem.CalculateNewPoints(currentPoints, result, mode)
	local pointsConfig = POINTS_BY_MODE[mode] or POINTS
	local pointsChange = 0
	
	if result == "win" then
		pointsChange = pointsConfig.WIN
	elseif result == "lose" then
		pointsChange = pointsConfig.LOSE
	elseif result == "draw" then
		pointsChange = pointsConfig.DRAW
	end
	
	local newPoints = math.max(0, currentPoints + pointsChange)
	
	return newPoints, pointsChange
end

-- Lấy rank trước và sau khi thay đổi điểm
function RankingSystem.GetRankChange(oldPoints, newPoints)
	local oldRank = RankingSystem.GetRankFromPoints(oldPoints)
	local newRank = RankingSystem.GetRankFromPoints(newPoints)
	
	local rankChanged = oldRank.rankName ~= newRank.rankName or oldRank.tier ~= newRank.tier
	local rankUp = newRank.rankIndex > oldRank.rankIndex or 
	             (newRank.rankIndex == oldRank.rankIndex and newRank.tier < oldRank.tier)
	local rankDown = newRank.rankIndex < oldRank.rankIndex or 
	                (newRank.rankIndex == oldRank.rankIndex and newRank.tier > oldRank.tier)
	
	return {
		oldRank = oldRank,
		newRank = newRank,
		rankChanged = rankChanged,
		rankUp = rankUp,
		rankDown = rankDown
	}
end

-- Lấy danh sách tất cả ranks (cho UI)
function RankingSystem.GetAllRanks()
	return RANKS
end

-- Lấy điểm cần cho mỗi tier
function RankingSystem.GetPointsPerTier()
	return POINTS_PER_TIER
end

-- Lấy điểm thưởng/phạt
function RankingSystem.GetPointsConfig()
	return POINTS
end

-- Tính tổng điểm cần để đạt rank cụ thể
function RankingSystem.GetPointsForRank(rankIndex, tier)
	local totalPoints = 0
	
	for i = 1, rankIndex - 1 do
		totalPoints = totalPoints + RANKS[i].tiers * POINTS_PER_TIER
	end
	
	if tier then
		local tiersInRank = RANKS[rankIndex].tiers
		totalPoints = totalPoints + (tiersInRank - tier) * POINTS_PER_TIER
	end
	
	return totalPoints
end

return RankingSystem