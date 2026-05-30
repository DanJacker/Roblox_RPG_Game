-- Matchmaking Service - Ghép trận LIÊN SERVER + Spawn nhà khi vào trận
-- 📍 LOCATION: ServerScriptService/Lobby/
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
-- ========== SHARED CONFIG ==========
local SharedConfig = require(ServerScriptService.Shared.SharedConfig)
-- ========== SECURITY: Wait for SecurityManager ==========
-- Đợi _G.Security sẵn sàng (được khởi tạo bởi GameServer trong Shared/)
local maxWait = 10
local startTime = tick()
while not _G.Security and (tick() - startTime) < maxWait do
	task.wait(0.1)
end
if not _G.Security then
	warn("[MatchmakingService] SecurityManager không khả dụng! Một số tính năng bảo mật sẽ bị vô hiệu hóa.")
else
end
-- Modules (vẫn ở ReplicatedStorage)
local RankingSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RankingSystem"))
local PlayerData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerData"))
-- RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local JoinQueue = remoteEvents:WaitForChild("JoinQueue")
local LeaveQueue = remoteEvents:WaitForChild("LeaveQueue")
local MatchFound = remoteEvents:WaitForChild("MatchFound")
local QueueStatus = remoteEvents:WaitForChild("QueueStatus")
-- Queue local (server hiện tại)
local localQueues = {
	["1v1"] = {},
	["2v2"] = {},
	["3v3"] = {}
}
-- Queue toàn cục (tất cả server)
local globalQueues = {
	["1v1"] = {},
	["2v2"] = {},
	["3v3"] = {}
}
-- Số lượng người chơi cần thiết cho từng chế độ
local playersNeeded = {
	["1v1"] = 2,
	["2v2"] = 4,
	["3v3"] = 6
}
-- Thời gian chờ tối đa (giây)
local QUEUE_TIMEOUT = 60
-- Thời gian chờ trước khi điền bot (giây)
local BOT_FILL_TIMEOUT = 3 -- Giảm xuống 3 giây để bot spawn nhanh hơn
-- ========== CẤU HÌNH RANK MATCHMAKING ==========
-- Rank index từ Kim Cương trở lên (index 6 = Kim Cương)
local NO_BOT_RANK_INDEX = 6 -- Kim Cương, Cao Thủ, Thách Đấu không có bot
-- Số tier chênh lệch cho phép (±3 tier = khoảng 1 rank)
-- Ví dụ: Sắt 3 có thể ghép với Sắt 1, Đồng 3, Đồng 2
local RANK_TIER_RANGE = 3
-- Hàm chuyển rank thành số thứ tự liên tiếp để so sánh
-- Sắt 3 = 1, Sắt 2 = 2, Sắt 1 = 3, Đồng 3 = 4, Đồng 2 = 5, ...
local function getRankValue(rankInfo)
	-- Mỗi rank có 3 tier (trừ Thách Đấu chỉ có 1)
	-- tier 3 là thấp nhất (số nhỏ), tier 1 là cao nhất (số lớn)
	local ranks = RankingSystem.GetAllRanks()
	local totalTiersBefore = 0
	
	-- Tính tổng số tier của các rank trước đó
	for i = 1, rankInfo.rankIndex - 1 do
		totalTiersBefore = totalTiersBefore + ranks[i].tiers
	end
	
	-- Tính vị trí tier trong rank
	-- Ví dụ: rank có 3 tier, tier 3 -> vị trí 1, tier 2 -> vị trí 2, tier 1 -> vị trí 3
	local rankTierCount = ranks[rankInfo.rankIndex].tiers
	local tierPosition = rankTierCount - rankInfo.tier + 1
	
	return totalTiersBefore + tierPosition
end
-- Hàm kiểm tra 2 player có thể ghép trận không (±1 tier)
local function canMatchByRank(rank1, rank2)
	local value1 = getRankValue(rank1)
	local value2 = getRankValue(rank2)
	local diff = math.abs(value1 - value2)
	
	-- Debug log
	-- print(string.format("[Matchmaking] canMatchByRank: %d vs %d = diff %d (allowed: %d)", value1, value2, diff, RANK_TIER_RANGE))
	
	-- Chênh lệch tối đa 1 tier
	return diff <= RANK_TIER_RANGE
end
-- Hàm kiểm tra rank có được điền bot không
local function canUseBots(rankInfo)
	-- Từ Kim Cương trở lên không có bot
	return rankInfo.rankIndex < NO_BOT_RANK_INDEX
end
-- Hàm lấy rank info của player
local function getPlayerRankInfo(player)
	local playerData = PlayerData.Get(player)
	if playerData then
		return RankingSystem.GetRankFromPoints(playerData.RankPoints or 0)
	end
	-- Default: Sắt 3
	return RankingSystem.GetRankFromPoints(0)
end
-- Lưu thời gian join queue của mỗi player
local playerJoinTime = {}
-- Lưu các queue đang chờ bot fill
local queuesWaitingForBots = {}
-- Lưu thông tin match data (bao gồm bot info) để spawn bot đúng cách
-- PHẢI ĐỊNH NGHĨA TRƯỚC KHI SỬ DỤNG
local matchDataCache = {}
-- Export matchDataCache để debug
_G.matchDataCache = matchDataCache
-- ========== DEBOUNCE: Tránh spawn bot 2 lần ==========
local botFillInProgress = {} -- Track đang fill bot cho mode nào
local BOT_FILL_COOLDOWN = 5 -- Giây - không fill lại trong 5 giây
-- ========== ĐỢI BOTMANAGER SẴN SÀNG ==========
local function waitForBotManager()
	local maxWait = 15 -- Tăng lên 15 giây
	local startTime = tick()
	while not _G.BotManager and (tick() - startTime) < maxWait do
		task.wait(0.5)
	end
	if _G.BotManager then
	else
		warn("[Matchmaking] BotManager KHÔNG KHẢ DỤNG sau " .. maxWait .. " giây!")
	end
	return _G.BotManager ~= nil
end
-- Gọi ngay khi script khởi động và ĐỢI HOÀN TẤT
local botManagerReady = waitForBotManager()
-- Job ID của server hiện tại
local currentJobId = game.JobId
-- Match ID counter
local matchIdCounter = 0
-- Lưu các nhà đang có trong trận
local activeHouses = {}
-- ========== HỆ THỐNG NHÀ PHÁ HỦY ==========
local DAMAGE_PER_HIT = 10
local EXPLOSION_DAMAGE = 30
local EXPLOSION_RADIUS = 15
local HIT_COOLDOWN = 0.5
local houseHealth = {}
local lastHitTime = {}
-- Hàm tạo mảnh vỡ
local function createDebris(originalPart, position)
    local debris = Instance.new("Part")
    debris.Name = "Debris"
    debris.Size = Vector3.new(
        math.random(1, 3),
        math.random(1, 3),
        math.random(1, 3)
    )
    debris.Position = position
    debris.Color = originalPart.Color
    debris.Material = originalPart.Material
    debris.Anchored = false
    debris.CanCollide = true
    debris.Parent = workspace
    
    debris.AssemblyLinearVelocity = Vector3.new(
        math.random(-20, 20),
        math.random(10, 30),
        math.random(-20, 20)
    )
    
    Debris:AddItem(debris, 5)
    return debris
end
-- Hàm gây damage cho players gần đó
local function damageNearbyPlayers(position, damage, radius)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            local humanoid = player.Character.Humanoid
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                local distance = (hrp.Position - position).Magnitude
                if distance <= radius then
                    local finalDamage = math.floor(damage * (1 - distance / radius))
                    if finalDamage > 0 then
                        humanoid:TakeDamage(finalDamage)
                    end
                end
            end
        end
    end
end
-- Hàm phá hủy nhà
local function destroyHouse(house)
    if not house or not house.Parent then return end
    
    
    local explosion = Instance.new("Explosion")
    explosion.BlastPressure = 0
    explosion.BlastRadius = EXPLOSION_RADIUS
    explosion.Position = house:GetPivot().Position
    explosion.Parent = workspace
    
    damageNearbyPlayers(house:GetPivot().Position, EXPLOSION_DAMAGE, EXPLOSION_RADIUS)
    
    for _, part in ipairs(house:GetChildren()) do
        if part:IsA("BasePart") then
            local numDebris = math.random(3, 5)
            for i = 1, numDebris do
                local offset = Vector3.new(
                    math.random(-2, 2),
                    math.random(0, 2),
                    math.random(-2, 2)
                )
                createDebris(part, part.Position + offset)
            end
        end
    end
    
    -- Xóa khỏi danh sách active
    for i, h in ipairs(activeHouses) do
        if h == house then
            table.remove(activeHouses, i)
            break
        end
    end
    
    house:Destroy()
end
-- Hàm xử lý khi nhà bị đánh
local function onHouseHit(house, hitPart)
    local character = hitPart.Parent
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    
    local now = tick()
    local lastHit = lastHitTime[player] or 0
    if now - lastHit < HIT_COOLDOWN then return end
    lastHitTime[player] = now
    
    houseHealth[house] = (houseHealth[house] or 100) - DAMAGE_PER_HIT
    
    -- Hiệu ứng rung
    for _, part in ipairs(house:GetChildren()) do
        if part:IsA("BasePart") then
            local originalPos = part.Position
            part.Position = originalPos + Vector3.new(
                math.random(-1, 1) * 0.1,
                0,
                math.random(-1, 1) * 0.1
            )
            task.wait(0.05)
            part.Position = originalPos
        end
    end
    
    if houseHealth[house] <= 0 then
        destroyHouse(house)
        houseHealth[house] = nil
    end
end
-- Hàm tạo nhà có thể phá hủy
local function createDestructibleHouse(position)
    local houseModel = Instance.new("Model")
    houseModel.Name = "DestructibleHouse_" .. tostring(tick())
    houseModel.Parent = workspace
    
    local function createPart(name, size, pos, color)
        local part = Instance.new("Part")
        part.Name = name
        part.Size = size
        part.Position = pos
        part.Color = color
        part.Material = Enum.Material.Wood
        part.Anchored = true
        part.CanCollide = true
        part.Parent = houseModel
        return part
    end
    
    local wallColor = Color3.fromRGB(139, 90, 43)
    local roofColor = Color3.fromRGB(120, 60, 30)
    local doorColor = Color3.fromRGB(80, 50, 20)
    
    createPart("Floor", Vector3.new(12, 1, 10), position + Vector3.new(0, 0.5, 0), Color3.fromRGB(100, 70, 40))
    createPart("WallFront", Vector3.new(12, 6, 1), position + Vector3.new(0, 4, 4.5), wallColor)
    createPart("WallBack", Vector3.new(12, 6, 1), position + Vector3.new(0, 4, -4.5), wallColor)
    createPart("WallLeft", Vector3.new(1, 6, 10), position + Vector3.new(-5.5, 4, 0), wallColor)
    createPart("WallRight", Vector3.new(1, 6, 10), position + Vector3.new(5.5, 4, 0), wallColor)
    createPart("Roof", Vector3.new(14, 1, 12), position + Vector3.new(0, 7.5, 0), roofColor)
    createPart("Door", Vector3.new(2, 4, 0.5), position + Vector3.new(0, 2.5, 4.8), doorColor)
    
    -- Thiết lập hit detection
    houseHealth[houseModel] = 100
    for _, part in ipairs(houseModel:GetChildren()) do
        if part:IsA("BasePart") then
            part.Touched:Connect(function(hitPart)
                onHouseHit(houseModel, hitPart)
            end)
        end
    end
    
    table.insert(activeHouses, houseModel)
    
    return houseModel
end
-- ========== HỆ THỐNG MATCHMAKING ==========
-- Hàm lấy danh sách người chơi trong queue (tất cả server)
local function getGlobalQueueList(mode)
	local queue = globalQueues[mode]
	if not queue then return {} end
	
	local playerList = {}
	for _, playerData in ipairs(queue) do
		table.insert(playerList, playerData.Name)
	end
	return playerList
end
-- Hàm kiểm tra player có trong queue không (local)
local function isPlayerInLocalQueue(player, mode)
	local queue = localQueues[mode]
	if not queue then return false end
	
	for _, p in ipairs(queue) do
		if p == player then
			return true
		end
	end
	return false
end
-- Hàm kiểm tra player có trong queue không (global)
local function isPlayerInGlobalQueue(playerName, mode)
	local queue = globalQueues[mode]
	if not queue then return false end
	
	for _, playerData in ipairs(queue) do
		if playerData.Name == playerName then
			return true
		end
	end
	return false
end
-- Hàm lấy tên players từ player data
local function getMatchPlayerNames(players)
	local names = {}
	for _, p in ipairs(players) do
		if type(p) == "table" and p.Name then
			table.insert(names, p.Name)
		elseif type(p) == "userdata" then
			table.insert(names, p.Name)
		end
	end
	return names
end
-- Hàm broadcast queue update đến tất cả server
local function broadcastQueueUpdate(mode)
	-- Chỉ gửi thông tin cần thiết để tránh vượt quá 1KB limit
	local playerList = {}
	for _, playerData in ipairs(globalQueues[mode]) do
		table.insert(playerList, {
			Name = playerData.Name,
			UserId = playerData.UserId,
			isBot = playerData.isBot or false,
			JoinTime = playerData.JoinTime,
			-- Rank info (compact)
			RankIndex = playerData.RankIndex,
			RankTier = playerData.RankTier,
			RankDisplayName = playerData.RankDisplayName
		})
	end
	
	local queueData = {
		action = "queueUpdate",
		mode = mode,
		players = playerList,
		count = #globalQueues[mode],
		needed = playersNeeded[mode],
		timestamp = tick()
	}
	
	local success, err = pcall(function()
		MessagingService:PublishAsync("MatchmakingQueue", queueData)
	end)
	
	if not success then
		warn("[Matchmaking] Lỗi broadcast queue update:", err)
		-- Fallback: Gửi thông tin tối thiểu
		local minimalData = {
			action = "queueUpdate",
			mode = mode,
			count = #globalQueues[mode],
			needed = playersNeeded[mode]
		}
		pcall(function()
			MessagingService:PublishAsync("MatchmakingQueue", minimalData)
		end)
	end
end
-- Hàm điền bot vào queue khi timeout (chỉ cho rank dưới Kim Cương)
local function fillQueueWithBots(mode, neededBots, targetRankInfo)
	-- ========== KIỂM TRA LẠI SỐ PLAYER THẬT ==========
	-- Đếm số player thật trong queue
	local realPlayerCount = 0
	for _, playerData in ipairs(globalQueues[mode]) do
		if not playerData.isBot then
			realPlayerCount = realPlayerCount + 1
		end
	end
	
	-- Nếu đã đủ player thật, KHÔNG spawn bot
	if realPlayerCount >= playersNeeded[mode] then
		return false
	end
	-- ==================================================
	
	-- Kiểm tra rank có cho phép bot không
	if not canUseBots(targetRankInfo) then
		return false
	end
	
	local BotManager = _G.BotManager
	if not BotManager then
		warn("[Matchmaking] BotManager chưa sẵn sàng! _G.BotManager = " .. tostring(_G.BotManager))
		return false
	end
	
	-- Tạo bot data cho queue với rank phù hợp
	local botDataList = {}
	for i = 1, neededBots do
		local botId = 9000000 + math.random(1, 999999)
		local botName = string.format("[BOT] Shadow%d", i)
		
		-- Bot có rank tương đương (±1 tier)
		local botRankIndex = targetRankInfo.rankIndex
		local botTier = targetRankInfo.tier
		
		-- Random ±1 tier cho bot
		local tierOffset = math.random(-1, 1)
		botTier = math.max(1, math.min(3, botTier + tierOffset))
		
		-- Nếu tier vượt quá 3, chuyển sang rank tiếp theo
		if botTier > 3 then
			botRankIndex = math.max(1, botRankIndex - 1)
			botTier = 3
		elseif botTier < 1 then
			botRankIndex = math.min(8, botRankIndex + 1)
			botTier = 1
		end
		
		local botRankValue = (botRankIndex * 10) + (4 - botTier)
		local botRankName = RankingSystem.GetAllRanks()[botRankIndex].name
		local botDisplayName = botRankName .. " " .. botTier
		local botData = {
			Name = botName,
			UserId = botId,
			ServerId = game.JobId,
			JoinTime = tick(),
			isBot = true,
			-- Thông tin rank của bot
			RankName = botRankName,
			RankTier = botTier,
			RankIndex = botRankIndex,
			RankValue = botRankValue,
			RankDisplayName = botDisplayName
		}
		table.insert(botDataList, botData)
		table.insert(globalQueues[mode], botData)
	end
	-- KHÔNG broadcast queue update ở đây - sẽ broadcast sau khi match found
	-- Điều này tránh việc MessagingService handler reset queue trước khi match found logic chạy
	-- broadcastQueueUpdate(mode)
	return true, botDataList
end
-- Hàm kiểm tra và điền bot nếu cần
local function checkAndFillBots(mode)
	local queue = globalQueues[mode]
	if not queue then 
		return 
	end
	-- ========== DEBOUNCE CHECK ==========
	-- Nếu đang fill bot cho mode này, không fill lại
	if botFillInProgress[mode] then
		return
	end
	-- =====================================
	local needed = playersNeeded[mode]
	local current = #queue
	
	-- ========== KIỂM TRA SỐ PLAYER THẬT ==========
	-- Đếm số player thật (không phải bot) trong queue
	local realPlayerCount = 0
	for _, playerData in ipairs(queue) do
		if not playerData.isBot then
			realPlayerCount = realPlayerCount + 1
		end
	end
	
	-- Nếu đã đủ player thật, KHÔNG spawn bot nhưng VẪN ghép trận
	if realPlayerCount >= needed then
		-- KHÔNG return ở đây - để code bên dưới xử lý ghép trận
	else
	end
	-- =============================================
	-- Nếu đã đủ người, kiểm tra ghép trận ngay
	if current >= needed then
		-- Trigger match found logic
		local matchedPlayers = {}
		local matchedIndices = {}
		for i = 1, needed do
			table.insert(matchedPlayers, queue[i])
			table.insert(matchedIndices, i)
		end
		
		-- Gọi logic ghép trận
		-- Tạo match ID
		matchIdCounter = matchIdCounter + 1
		local matchId = "match_" .. tostring(matchIdCounter) .. "_" .. tostring(tick())
		
		-- Kiểm tra có bot không
		local hasBots = false
		local botPlayers = {}
		for _, p in ipairs(matchedPlayers) do
			if p.isBot then
				hasBots = true
				table.insert(botPlayers, p)
			end
		end
		
		-- Lưu bot info vào cache
		if hasBots then
			matchDataCache[matchId] = {
				botPlayers = botPlayers,
				hasBots = true
			}
			for mid, data in pairs(matchDataCache) do
			end
		end
		
		-- Xóa players khỏi queue
		for i = #matchedIndices, 1, -1 do
			table.remove(globalQueues[mode], matchedIndices[i])
		end
		
		-- Broadcast match found
		local matchPlayersCompact = {}
		for _, p in ipairs(matchedPlayers) do
			table.insert(matchPlayersCompact, {
				Name = p.Name,
				UserId = p.UserId,
				isBot = p.isBot or false,
				RankDisplayName = p.RankDisplayName
			})
		end
		
		local matchData = {
			action = "matchFound",
			mode = mode,
			players = matchPlayersCompact,
			matchId = matchId,
			hasBots = hasBots,
			timestamp = tick()
		}
		
		pcall(function()
			MessagingService:PublishAsync("MatchmakingMatch", matchData)
		end)
		
		
		-- Thông báo cho real players trong local queue
		for _, player in ipairs(localQueues[mode]) do
			MatchFound:FireClient(player, {
				mode = mode,
				players = getMatchPlayerNames(matchedPlayers),
				matchId = matchId,
				hasBots = hasBots
			})
		end
		
		-- Xóa khỏi local queue
		for _, mp in ipairs(matchedPlayers) do
			for i = #localQueues[mode], 1, -1 do
				if localQueues[mode][i].Name == mp.Name then
					table.remove(localQueues[mode], i)
					break
				end
			end
		end
		
		-- Broadcast queue update
		broadcastQueueUpdate(mode)
		return
	end
	-- Nếu chưa đủ người và đã chờ quá lâu
	if current < needed then
		-- Tính thời gian chờ của player đầu tiên trong queue
		local firstPlayer = queue[1]
		print(string.format("[Matchmaking] firstPlayer: %s, isBot: %s", 
			tostring(firstPlayer and firstPlayer.Name), tostring(firstPlayer and firstPlayer.isBot)))
		
		if firstPlayer and firstPlayer.JoinTime then
			local waitTime = tick() - firstPlayer.JoinTime
			
			print(string.format("[Matchmaking] Bot fill check: %s đã chờ %.1fs (timeout: %ds)", 
				firstPlayer.Name or "Unknown", waitTime, BOT_FILL_TIMEOUT))
			if waitTime >= BOT_FILL_TIMEOUT then
				-- ========== SET DEBOUNCE FLAG ==========
				botFillInProgress[mode] = true
				-- Clear sau khi match found hoặc timeout
				task.delay(BOT_FILL_COOLDOWN, function()
					botFillInProgress[mode] = nil
				end)
				-- ========================================
				
				-- Lấy thông tin rank của player đầu tiên
				local targetRankInfo = {
					rankIndex = firstPlayer.RankIndex or 1,
					tier = firstPlayer.RankTier or 3,
					displayName = firstPlayer.RankDisplayName or "Sắt 3"
				}
				
				print(string.format("[Matchmaking] Player rank: %s (index: %d, tier: %d)", 
					targetRankInfo.displayName, targetRankInfo.rankIndex, targetRankInfo.tier))
				
				-- Kiểm tra rank có cho phép bot không
				local canUseBot = canUseBots(targetRankInfo)
				print(string.format("[Matchmaking] canUseBots = %s (NO_BOT_RANK_INDEX = %d)", 
					tostring(canUseBot), NO_BOT_RANK_INDEX))
				
				if not canUseBot then
					-- Rank cao không có bot, tiếp tục chờ
					botFillInProgress[mode] = nil -- Clear flag
					return
				end
				
				-- KIỂM TRA BotManager TRƯỚC KHI GỌI
				local BotManager = _G.BotManager
				
				if not BotManager then
					warn("[Matchmaking] BotManager KHÔNG KHẢ DỤNG! Không thể spawn bot!")
					botFillInProgress[mode] = nil -- Clear flag
					return
				end
				
				local neededBots = needed - current
				local success, botDataList = fillQueueWithBots(mode, neededBots, targetRankInfo)
				print(string.format("[Matchmaking] fillQueueWithBots result: success=%s, botCount=%d", 
					tostring(success), botDataList and #botDataList or 0))
				if success then
					-- SAU KHI THÊM BOT, KIỂM TRA XEM ĐÃ ĐỦ NGƯỜI CHƯA
					
					if #globalQueues[mode] >= playersNeeded[mode] then
						
						-- Trigger match found
						local matchPlayers = {}
						local matchPlayersCompact = {} -- Compact version for broadcast
						local botPlayers = {} -- Lưu thông tin bot để spawn sau
						for i = 1, needed do
							local playerData = globalQueues[mode][1]
							table.insert(matchPlayers, playerData)
							-- Compact data for broadcast
							table.insert(matchPlayersCompact, {
								Name = playerData.Name,
								UserId = playerData.UserId,
								isBot = playerData.isBot or false,
								RankDisplayName = playerData.RankDisplayName
							})
							-- Lưu bot info
							if playerData.isBot then
								table.insert(botPlayers, playerData)
							end
							table.remove(globalQueues[mode], 1)
						end
						-- Tạo match ID
						matchIdCounter = matchIdCounter + 1
						local matchId = "match_" .. tostring(matchIdCounter) .. "_" .. tostring(tick())
						-- Lưu bot info vào cache để sử dụng khi spawn bot
						matchDataCache[matchId] = {
							botPlayers = botPlayers,
							hasBots = true
						}
						-- Broadcast match found (compact data)
						local matchData = {
							action = "matchFound",
							mode = mode,
							players = matchPlayersCompact,
							matchId = matchId,
							hasBots = true,
							timestamp = tick()
						}
						local success2, err = pcall(function()
							MessagingService:PublishAsync("MatchmakingMatch", matchData)
						end)
						if success2 then
							
							-- Thông báo cho real players trong local queue
							for _, player in ipairs(localQueues[mode]) do
								MatchFound:FireClient(player, {
									mode = mode,
									players = getMatchPlayerNames(matchPlayers),
									matchId = matchId,
									hasBots = true
								})
							end
							
							-- Xóa khỏi local queue SAU khi đã gửi tất cả events
							for i = #localQueues[mode], 1, -1 do
								local playerName = localQueues[mode][i].Name
								for _, mp in ipairs(matchPlayers) do
									if mp.Name == playerName then
										table.remove(localQueues[mode], i)
										break
									end
								end
							end
						else
							warn("[Matchmaking] Lỗi broadcast match found với bot:", err)
						end
						
						-- Broadcast queue update SAU khi match found
						broadcastQueueUpdate(mode)
					end
				end
			end
		end
	end
end
-- Loop kiểm tra timeout và điền bot
-- SỬA: Kiểm tra globalQueues thay vì localQueues để đảm bảo bot check chạy đúng cho tất cả chế độ
task.spawn(function()
	local loopCount = 0
	while true do
		task.wait(2) -- Kiểm tra mỗi 2 giây (nhanh hơn nữa)
		loopCount = loopCount + 1
		
		-- Debug: In ra loop count mỗi 5 lần (10 giây)
		if loopCount % 5 == 0 then
		end
		for mode, _ in pairs(globalQueues) do
			-- Kiểm tra global queue có players không (để fill bot hoặc ghép trận)
			if #globalQueues[mode] > 0 then
				checkAndFillBots(mode)
			end
			
			-- Kiểm tra timeout 60s cho mỗi player trong local queue
			if #localQueues[mode] > 0 then
				local playersToRemove = {}
				for i, player in ipairs(localQueues[mode]) do
					local joinTime = playerJoinTime[player]
					if joinTime then
						local waitTime = tick() - joinTime
						if waitTime >= QUEUE_TIMEOUT then
							table.insert(playersToRemove, player)
						end
					end
				end
				
				-- Xóa players đã timeout
				for _, player in ipairs(playersToRemove) do
					
					-- Thông báo cho player
					QueueStatus:FireClient(player, {
						action = "timeout",
						message = "Hết thời gian chờ! Vui lòng thử lại."
					})
					
					-- Xóa khỏi queue
					removeFromQueue(player)
				end
			end
		end
	end
end)
-- Hàm thêm player vào queue
local function addToQueue(player, mode)
	if not localQueues[mode] then
		return false, "Chế độ chơi không hợp lệ"
	end
	
	-- ========== KIỂM TRA PLAYER ĐANG TRONG TRẬN ==========
	-- Sử dụng _G.IsPlayerInMatch từ MatchManager
	local IsPlayerInMatch = _G.IsPlayerInMatch
	if IsPlayerInMatch then
		local inMatch, matchId, matchData = IsPlayerInMatch(player)
		if inMatch then
			return false, "Bạn đang trong trận đấu! Hãy thoát trận trước khi tìm trận mới."
		end
	else
		-- Fallback: Kiểm tra team của player
		local playerTeam = player.Team
		if playerTeam and (playerTeam.Name == "Team1" or playerTeam.Name == "Team2") then
			return false, "Bạn đang trong trận đấu! Hãy thoát trận trước khi tìm trận mới."
		end
	end
	-- ================================================
	
	-- Kiểm tra player đã trong queue chưa (local)
	for queueMode, _ in pairs(localQueues) do
		if isPlayerInLocalQueue(player, queueMode) then
			return false, "Bạn đã ở trong queue " .. queueMode
		end
	end
	
	-- Kiểm tra player đã trong queue chưa (global)
	if isPlayerInGlobalQueue(player.Name, mode) then
		return false, "Bạn đã ở trong queue " .. mode
	end
	
	-- Lấy thông tin rank của player
	local rankInfo = getPlayerRankInfo(player)
	local rankValue = getRankValue(rankInfo)
	
	-- Thêm vào local queue
	table.insert(localQueues[mode], player)
	playerJoinTime[player] = tick()
	
	-- Thêm vào global queue với thông tin rank
	local playerData = {
		Name = player.Name,
		UserId = player.UserId,
		ServerId = currentJobId,
		JoinTime = tick(),
		-- Thông tin rank
		RankName = rankInfo.rankName,
		RankTier = rankInfo.tier,
		RankIndex = rankInfo.rankIndex,
		RankValue = rankValue,
		RankDisplayName = rankInfo.displayName
	}
	table.insert(globalQueues[mode], playerData)
	
	print(string.format("[Matchmaking] %s đã join queue %s | Rank: %s (value: %d)", 
		player.Name, mode, rankInfo.displayName, rankValue))
	
	-- Broadcast queue update đến tất cả server
	broadcastQueueUpdate(mode)
	
	-- Gửi cập nhật cho player VỚI action joinResult
	QueueStatus:FireClient(player, {
		action = "joinResult",
		success = true,
		message = "Đã tham gia queue " .. mode,
		mode = mode,
		players = getGlobalQueueList(mode),
		count = #globalQueues[mode],
		needed = playersNeeded[mode],
		rankInfo = rankInfo,
		timeout = QUEUE_TIMEOUT
	})
	
	-- ========== GHÉP TRẬN THEO RANK ==========
	-- Tìm players có rank phù hợp trong queue
	local function findMatchingPlayers()
		local matchedPlayers = {}
		local matchedIndices = {}
		
		-- Tìm tất cả players có rank phù hợp với player đầu tiên
		local firstPlayer = globalQueues[mode][1]
		if not firstPlayer then return nil end
		
		local firstRank = {
			rankIndex = firstPlayer.RankIndex,
			tier = firstPlayer.RankTier
		}
		
		for i, pData in ipairs(globalQueues[mode]) do
			local playerRank = {
				rankIndex = pData.RankIndex,
				tier = pData.RankTier
			}
			
			if canMatchByRank(firstRank, playerRank) then
				table.insert(matchedPlayers, pData)
				table.insert(matchedIndices, i)
				
				if #matchedPlayers >= playersNeeded[mode] then
					break
				end
			end
		end
		
		if #matchedPlayers >= playersNeeded[mode] then
			return matchedPlayers, matchedIndices
		end
		
		return nil
	end
	
	-- Kiểm tra đủ người để ghép trận
	
	-- Debug: In rank của tất cả players trong queue
	for i, p in ipairs(globalQueues[mode]) do
		print(string.format("  %d. %s - Rank: %s (index: %d, tier: %d, value: %d)", 
			i, p.Name, p.RankDisplayName or "Unknown", p.RankIndex or 0, p.RankTier or 0, p.RankValue or 0))
	end
	
	-- SỬA: Kiểm tra đủ players TRƯỚC, không cần rank matching
	if #globalQueues[mode] >= playersNeeded[mode] then
		matchedPlayers = {}
		matchedIndices = {}
		for i = 1, playersNeeded[mode] do
			table.insert(matchedPlayers, globalQueues[mode][i])
			table.insert(matchedIndices, i)
		end
	else
		-- Nếu chưa đủ, thử tìm theo rank
		matchedPlayers, matchedIndices = findMatchingPlayers()
		if matchedPlayers then
		else
		end
	end
	
	if matchedPlayers and #matchedPlayers >= playersNeeded[mode] then
		
		-- Lấy danh sách players cho trận đấu
		local matchPlayers = {}
		local botPlayers = {} -- Lưu thông tin bot để spawn sau
		for i = 1, math.min(playersNeeded[mode], #matchedPlayers) do
			table.insert(matchPlayers, matchedPlayers[i])
			-- Lưu bot info
			if matchedPlayers[i].isBot then
				table.insert(botPlayers, matchedPlayers[i])
			end
		end
		
		
		-- Xóa players đã match khỏi queue (từ cuối đến đầu để không bị sai index)
		table.sort(matchedIndices, function(a, b) return a > b end)
		for _, idx in ipairs(matchedIndices) do
			if #matchPlayers >= playersNeeded[mode] then
				table.remove(globalQueues[mode], idx)
			end
		end
		
		-- Tạo match ID
		matchIdCounter = matchIdCounter + 1
		local matchId = "match_" .. tostring(matchIdCounter) .. "_" .. tostring(tick())
		
		-- Kiểm tra có bot không
		local hasBots = #botPlayers > 0
		
		-- Lưu bot info vào cache nếu có bot
		if hasBots then
			matchDataCache[matchId] = {
				botPlayers = botPlayers,
				hasBots = true
			}
		end
		
		-- Broadcast match found (compact data to avoid 1KB limit)
		local matchPlayersCompact = {}
		for _, p in ipairs(matchPlayers) do
			table.insert(matchPlayersCompact, {
				Name = p.Name,
				UserId = p.UserId,
				isBot = p.isBot or false,
				RankDisplayName = p.RankDisplayName
			})
		end
		
		local matchData = {
			action = "matchFound",
			mode = mode,
			players = matchPlayersCompact,
			matchId = matchId,
			hasBots = hasBots,
			timestamp = tick()
		}
		
		local success, err = pcall(function()
			MessagingService:PublishAsync("MatchmakingMatch", matchData)
		end)
		
		if success then
			local playerNames = {}
			for _, p in ipairs(matchPlayers) do
				table.insert(playerNames, p.Name .. " (" .. (p.RankDisplayName or "Sắt 3") .. ")")
			end
			
			-- SỬA: Thông báo trực tiếp cho players trong local queue
			for _, player in ipairs(localQueues[mode]) do
				-- Kiểm tra player có trong match không
				local inMatch = false
				for _, mp in ipairs(matchPlayers) do
					if mp.Name == player.Name then
						inMatch = true
						break
					end
				end
				
				if inMatch then
					MatchFound:FireClient(player, {
						mode = mode,
						players = getMatchPlayerNames(matchPlayers),
						matchId = matchId,
						hasBots = hasBots
					})
				end
			end
			
			-- Xóa players đã match khỏi local queue
			for _, mp in ipairs(matchPlayers) do
				for i = #localQueues[mode], 1, -1 do
					if localQueues[mode][i].Name == mp.Name then
						table.remove(localQueues[mode], i)
						break
					end
				end
			end
		else
			warn("[Matchmaking] Lỗi broadcast match found:", err)
		end
	end
	
	return true, "Đã tham gia queue " .. mode
end
-- Hàm xóa player khỏi queue
local function removeFromQueue(player)
	-- Xóa từ local queue
	for mode, queue in pairs(localQueues) do
		for i, p in ipairs(queue) do
			if p == player then
				table.remove(queue, i)
				
				-- Xóa từ global queue
				for j, playerData in ipairs(globalQueues[mode]) do
					if playerData.Name == player.Name then
						table.remove(globalQueues[mode], j)
						break
					end
				end
				
				-- Broadcast queue update
				broadcastQueueUpdate(mode)
				
				playerJoinTime[player] = nil
				return true, "Đã rời queue " .. mode
			end
		end
	end
	playerJoinTime[player] = nil
	return false, "Bạn không ở trong queue nào"
end
-- Lắng nghe queue update từ các server khác
MessagingService:SubscribeAsync("MatchmakingQueue", function(message)
	local success, err = pcall(function()
		local data = message.Data
		if data.action == "queueUpdate" then
			-- KHÔNG ghi đè global queue - chỉ cập nhật nếu khác server
			-- Điều này tránh race condition khi broadcast từ chính server này
			-- globalQueues[data.mode] = data.players
			
			
			if data.players then
				for i, p in ipairs(data.players) do
				end
			end
			
			-- Gửi cập nhật cho tất cả players trong local queue
			if localQueues[data.mode] then
				for _, player in ipairs(localQueues[data.mode]) do
					QueueStatus:FireClient(player, {
						mode = data.mode,
						players = getGlobalQueueList(data.mode),
						count = data.count,
						needed = data.needed
					})
				end
			end
			
			-- KIỂM TRA BOT FILL - sử dụng globalQueues local thay vì data.players
			-- Điều này đảm bảo bot fill chạy đúng
			if #globalQueues[data.mode] > 0 then
				checkAndFillBots(data.mode)
			end
			
		end
	end)
	
	if not success then
		warn("[Matchmaking] Lỗi trong MessagingService handler: " .. tostring(err))
	end
end)
-- Lắng nghe match found từ các server khác
MessagingService:SubscribeAsync("MatchmakingMatch", function(message)
	local data = message.Data
	if data.action == "matchFound" then
		
		-- Xóa players đã match khỏi global queue (đồng bộ giữa các server)
		local removedCount = 0
		for _, playerData in ipairs(data.players) do
			for i = #globalQueues[data.mode], 1, -1 do
				if globalQueues[data.mode][i].Name == playerData.Name then
					table.remove(globalQueues[data.mode], i)
					removedCount = removedCount + 1
					break
				end
			end
		end
		
		
		-- Kiểm tra xem có player nào trong local queue thuộc match không
		for _, playerData in ipairs(data.players) do
			-- Tìm player trong local queue
			for i, player in ipairs(localQueues[data.mode]) do
				if player.Name == playerData.Name then
					-- Thông báo cho player
					MatchFound:FireClient(player, {
						mode = data.mode,
						players = getMatchPlayerNames(data.players),
						matchId = data.matchId,
						hasBots = data.hasBots or false
					})
					
					-- Xóa khỏi local queue
					table.remove(localQueues[data.mode], i)
					break
				end
			end
		end
		
		-- Broadcast queue update sau khi xóa players
		broadcastQueueUpdate(data.mode)
		
	end
end)
-- Xử lý khi player join queue
JoinQueue.OnServerEvent:Connect(function(player, mode)
	-- ========== DEBUG: Log exactly what we receive ==========
	
	-- ========== SECURITY: Rate limiting & validation ==========
	local Security = _G.Security
	if Security then
		-- Rate limit check
		local allowed, rateMsg = Security.RateLimiter.Check(player, "JoinQueue")
		if not allowed then
			QueueStatus:FireClient(player, {
				action = "joinResult",
				success = false,
				message = rateMsg,
				mode = mode
			})
			return
		end
		
		-- Input validation
		local valid, validatedMode = Security.InputValidator.ValidateMode(mode)
		if not valid then
			QueueStatus:FireClient(player, {
				action = "joinResult",
				success = false,
				message = tostring(validatedMode),
				mode = mode
			})
			return
		end
		mode = validatedMode
		
		-- Anti-cheat check
		if Security.AntiCheat.IsSuspicious(player) then
			QueueStatus:FireClient(player, {
				action = "joinResult",
				success = false,
				message = "Account under review. Please contact support.",
				mode = mode
			})
			return
		end
	else
	end
	
	local success, message = addToQueue(player, mode)
	-- KHÔNG gửi thêm event vì addToQueue đã gửi rồi
end)
-- Xử lý khi player leave queue
LeaveQueue.OnServerEvent:Connect(function(player)
	-- ========== SECURITY: Rate limiting ==========
	local Security = _G.Security
	if Security then
		local allowed, rateMsg = Security.RateLimiter.Check(player, "LeaveQueue")
		if not allowed then
			QueueStatus:FireClient(player, {
				action = "leaveResult",
				success = false,
				message = rateMsg
			})
			return
		end
	end
	
	local success, message = removeFromQueue(player)
	QueueStatus:FireClient(player, {
		action = "leaveResult",
		success = success,
		message = message
	})
end)
-- Xử lý khi player rời game
Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)
-- ========== TEST FUNCTION: Simulate player joining queue ==========
-- Sử dụng: _G.TestJoinQueue(playerName, mode)
_G.TestJoinQueue = function(playerName, mode)
	local player = Players:FindFirstChild(playerName)
	if not player then
		return false, "Player not found: " .. playerName
	end
	
	mode = mode or "1v1"
	
	local success, message = addToQueue(player, mode)
	return success, message
end
-- ĐÃ TẮT: Bot không còn tham gia trận đấu
-- Người chơi sẽ phải chờ đủ số lượng người thật để bắt đầu trận
-- Vòng lặp thêm bot đã bị vô hiệu hóa
-- Lắng nghe khi trận đấu bắt đầu (từ client)
-- Sử dụng MatchStart RemoteEvent đã tồn tại trong RemoteEvents
local MatchStart = remoteEvents:WaitForChild("MatchStart")
-- Lưu thông tin match đang chờ
local pendingMatches = {}
-- Đợi _G.StartMatch sẵn sàng
local function waitForStartMatch()
	local maxWait = 10
	local startTime = tick()
	while not _G.StartMatch and (tick() - startTime) < maxWait do
		task.wait(0.1)
	end
	return _G.StartMatch ~= nil
end
MatchStart.OnServerEvent:Connect(function(player, matchData)
	if matchData.players then
		for i, p in ipairs(matchData.players) do
		end
	end
	
	-- Tạo match ID nếu chưa có
	local matchId = matchData.matchId
	if not matchId then
		matchIdCounter = matchIdCounter + 1
		matchId = "match_" .. tostring(matchIdCounter) .. "_" .. tostring(tick())
	end
	
	-- Kiểm tra xem match đã được khởi tạo chưa
	if not pendingMatches[matchId] then
		-- Lấy thông tin bot từ cache (được lưu khi ghép trận)
		local cachedMatchData = matchDataCache[matchId]
		if cachedMatchData then
		else
		end
		
		pendingMatches[matchId] = {
			mode = matchData.mode,
			players = {},
			playerNames = matchData.players or {},
			startTime = tick(),
			hasBots = matchData.hasBots or false,
			-- Thêm bot info từ cache
			botPlayers = cachedMatchData and cachedMatchData.botPlayers or {}
		}
		
		-- Nếu có bot trong match, tạo bot characters
		if matchData.hasBots then
			
			-- Đếm số bot cần tạo từ cache hoặc từ player names
			local botCount = 0
			if cachedMatchData and cachedMatchData.botPlayers then
				botCount = #cachedMatchData.botPlayers
			else
				for _, playerName in ipairs(matchData.players) do
					if playerName:find("%[BOT%]") then
						botCount = botCount + 1
					end
				end
			end
			
		end
	end
	
	-- Thêm player vào match
	table.insert(pendingMatches[matchId].players, player)
	
	-- KHÔNG spawn nhà mới - sử dụng 2 base có sẵn (Team1Base và Team2Base)
	
	-- Kiểm tra xem tất cả players đã sẵn sàng chưa
	local playersNeeded = matchData.mode == "1v1" and 2 or matchData.mode == "2v2" and 4 or 6
	
	
	-- Đếm số bot trong match
	local botCount = 0
	for _, playerName in ipairs(pendingMatches[matchId].playerNames) do
		if playerName:find("%[BOT%]") then
			botCount = botCount + 1
		end
	end
	
	-- Tính tổng số players (real + bots)
	local totalPlayers = #pendingMatches[matchId].players + botCount
	
	
	-- NẾU KHÔNG ĐỦ PLAYERS, TẠO BOT NGAY LẬP TỨC
	if totalPlayers < playersNeeded then
		local neededBots = playersNeeded - totalPlayers
		
		-- Tạo bot data
		for i = 1, neededBots do
			local botId = 9000000 + math.random(1, 999999)
			local botName = string.format("[BOT] Shadow%d", i)
			table.insert(pendingMatches[matchId].playerNames, botName)
			botCount = botCount + 1
		end
		
		-- Cập nhật hasBots
		pendingMatches[matchId].hasBots = true
		matchData.hasBots = true
		
		-- Cập nhật totalPlayers
		totalPlayers = #pendingMatches[matchId].players + botCount
	end
	
	if totalPlayers >= playersNeeded then
		
		-- Tạo danh sách tất cả players (real + bot data)
		local allPlayersList = {}
		
		-- Thêm real players
		for _, p in ipairs(pendingMatches[matchId].players) do
			table.insert(allPlayersList, {
				player = p,
				name = p.Name,
				userId = p.UserId,
				isBot = false
			})
		end
		
		-- Thêm bot data từ cache (nếu có) hoặc từ player names
		if pendingMatches[matchId].botPlayers and #pendingMatches[matchId].botPlayers > 0 then
			-- Sử dụng bot info từ cache
			for _, botInfo in ipairs(pendingMatches[matchId].botPlayers) do
				table.insert(allPlayersList, {
					name = botInfo.Name,
					userId = botInfo.UserId or 9000000 + #allPlayersList,
					isBot = true,
					rankInfo = botInfo.RankDisplayName
				})
			end
		else
			-- Fallback: sử dụng player names
			for _, playerName in ipairs(pendingMatches[matchId].playerNames) do
				if playerName:find("%[BOT%]") then
					table.insert(allPlayersList, {
						name = playerName,
						userId = 9000000 + #allPlayersList,
						isBot = true
					})
				end
			end
		end
		
		-- Shuffle players để random team
		for i = #allPlayersList, 2, -1 do
			local j = math.random(1, i)
			allPlayersList[i], allPlayersList[j] = allPlayersList[j], allPlayersList[i]
		end
		
		-- Chia team sau khi shuffle
		local team1 = {}
		local team2 = {}
		local allPlayers = {}
		
		for i, p in ipairs(allPlayersList) do
			local playerData = {
				playerId = p.userId,
				name = p.name,
				isBot = p.isBot
			}
			table.insert(allPlayers, playerData)
			
			if i % 2 == 1 then
				table.insert(team1, playerData)
			else
				table.insert(team2, playerData)
			end
		end
		
		
		-- Debug: Log chi tiết từng team
		local team1Bots = 0
		local team2Bots = 0
		for _, p in ipairs(team1) do
			if p.isBot then team1Bots = team1Bots + 1 end
		end
		for _, p in ipairs(team2) do
			if p.isBot then team2Bots = team2Bots + 1 end
		end
		
		-- Spawn bot characters nếu có
		if matchData.hasBots then
			
			local BotManager = _G.BotManager
			
			if BotManager then
				-- Đếm số bot cần spawn
				local botCount = 0
				for i, playerData in ipairs(allPlayersList) do
					if playerData.isBot then
						botCount = botCount + 1
					end
				end
				
				
				-- Spawn bots cho mỗi team - SỬA: Spawn gần arena spawn points
				local team1BotCount = 0
				local team2BotCount = 0
				
				-- Lấy vị trí spawn từ arena (gần base)
				-- Mỗi player/bot spawn tại base riêng
				local mapSpawns = {
					["1v1"] = {
						team1 = {Vector3.new(-291, 3, -1040)},
						team2 = {Vector3.new(317, 3, -1041)}
					},
					["2v2"] = {
						team1 = {Vector3.new(-291, 3, -1947), Vector3.new(-291, 3, -2151)},
						team2 = {Vector3.new(317, 3, -1855), Vector3.new(317, 3, -2191)}
					},
					["3v3"] = {
						team1 = {Vector3.new(-1014, 3, -823), Vector3.new(-1014, 3, -1246), Vector3.new(-1014, 3, -1015)},
						team2 = {Vector3.new(-1441, 3, -777), Vector3.new(-1441, 3, -1011), Vector3.new(-1441, 3, -1260)}
					}
				}
				local arenaSpawn = mapSpawns[matchData.mode] or mapSpawns["2v2"]
				
				-- SỬA: Spawn bot dựa trên team assignment thực tế
				-- Mỗi bot spawn tại base riêng
				local team1SpawnIndex = 1
				local team2SpawnIndex = 1
				
				-- Spawn bots cho Team1
				for _, playerData in ipairs(team1) do
					if playerData.isBot then
						local teamName = "Team1"
						local spawnPositions = arenaSpawn.team1
						local spawnIndex = ((team1SpawnIndex - 1) % #spawnPositions) + 1
						local baseSpawnPos = spawnPositions[spawnIndex]
						local spawnPos = baseSpawnPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
										
						team1BotCount = team1BotCount + 1
						team1SpawnIndex = team1SpawnIndex + 1
						local botData = BotManager.SpawnBotForTeam(teamName, spawnPos, matchData.mode)
					end
				end
				
				-- Spawn bots cho Team2
				for _, playerData in ipairs(team2) do
					if playerData.isBot then
						local teamName = "Team2"
						local spawnPositions = arenaSpawn.team2
						local spawnIndex = ((team2SpawnIndex - 1) % #spawnPositions) + 1
						local baseSpawnPos = spawnPositions[spawnIndex]
						local spawnPos = baseSpawnPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))						
						team2BotCount = team2BotCount + 1
						team2SpawnIndex = team2SpawnIndex + 1
						local botData = BotManager.SpawnBotForTeam(teamName, spawnPos, matchData.mode)
					end
				end
				
			else
				warn("[Matchmaking] BotManager KHÔNG KHẢ DỤNG để spawn bots! _G.BotManager = " .. tostring(_G.BotManager))
			end
		end
		
		-- Tạo danh sách player IDs (chỉ real players)
		local playerIds = {}
		for _, p in ipairs(pendingMatches[matchId].players) do
			table.insert(playerIds, p.UserId)
		end
		
		-- Khởi tạo base riêng cho mỗi player (nếu là 2v2 hoặc 3v3)
		local IndividualBaseManager = _G.IndividualBaseManager
		if IndividualBaseManager then
			IndividualBaseManager.InitializeBasesForMatch({
				mode = matchData.mode,
				team1 = team1,
				team2 = team2
			})
		else
			warn("[Matchmaking] IndividualBaseManager chưa sẵn sàng!")
		end
		
		-- Khởi tạo WinConditionChecker
		local WinConditionChecker = _G.WinConditionChecker
		if WinConditionChecker then
			WinConditionChecker.InitializeMatch({
				matchId = matchId,
				mode = matchData.mode,
				team1 = team1,
				team2 = team2
			})
		else
			warn("[Matchmaking] WinConditionChecker chưa sẵn sàng!")
		end
		
		-- Gọi MatchManager để bắt đầu trận
		-- Đợi _G.StartMatch sẵn sàng
		if not waitForStartMatch() then
			warn("[Matchmaking] Không thể tìm thấy _G.StartMatch sau 10 giây!")
			return
		end
		
		_G.StartMatch(matchId, {
			mode = matchData.mode,
			players = playerIds,
			team1 = team1,
			team2 = team2,
			allPlayers = allPlayers
		})
		
		-- Xóa match khỏi pending
		pendingMatches[matchId] = nil
	end
end)
