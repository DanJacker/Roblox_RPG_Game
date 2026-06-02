-- Security Manager - Quản lý bảo mật toàn game
-- Chuyển thành ModuleScript để đảm bảo load trước các script khác

local SecurityManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ========== CONFIGURATION ==========
local CONFIG = {
	-- Rate Limiting (requests per second)
	RATE_LIMITS = {
		JoinQueue = 2,
		LeaveQueue = 5,
		SpawnSelect = 10,
		MatchStart = 3,
		CombatRemote = 20,
		default = 10
	},
	
	-- Anti-Cheat thresholds
	MAX_RANK_POINTS_PER_MATCH = 50, -- Max points gain per match
	MAX_MATCHES_PER_HOUR = 30,
	MIN_MATCH_DURATION = 60, -- Minimum match duration (seconds)
	
	-- Data validation
	VALID_MODES = {"1v1", "2v2", "3v3"},
	MAX_SPAWN_DISTANCE = 100, -- Max distance from base
	
	-- DataStore
	DATASTORE_NAME = "RankedGame_Data",
	DATASTORE_VERSION = 1,
	
	-- Auto-save interval
	AUTO_SAVE_INTERVAL = 120, -- 2 minutes
}

-- ========== RATE LIMITER ==========
local RateLimiter = {}
local playerRequests = {}

function RateLimiter.Check(player, action)
	local userId = player.UserId
	local now = tick()
	
	if not playerRequests[userId] then
		playerRequests[userId] = {}
	end
	
	if not playerRequests[userId][action] then
		playerRequests[userId][action] = {}
	end
	
	local requests = playerRequests[userId][action]
	local limit = CONFIG.RATE_LIMITS[action] or CONFIG.RATE_LIMITS.default
	
	-- Remove old requests (older than 1 second)
	local validRequests = {}
	for _, reqTime in ipairs(requests) do
		if now - reqTime < 1 then
			table.insert(validRequests, reqTime)
		end
	end
	playerRequests[userId][action] = validRequests
	
	-- Check if over limit
	if #validRequests >= limit then
		return false, "Rate limit exceeded for " .. action
	end
	
	-- Add new request
	table.insert(playerRequests[userId][action], now)
	return true
end

function RateLimiter.Cleanup(player)
	playerRequests[player.UserId] = nil
end

-- ========== INPUT VALIDATOR ==========
local InputValidator = {}

function InputValidator.ValidateMode(mode)
	if type(mode) ~= "string" then
		return false, "Mode must be a string"
	end
	
	for _, validMode in ipairs(CONFIG.VALID_MODES) do
		if mode == validMode then
			return true, mode  -- Trả về cả mode hợp lệ
		end
	end
	
	return false, "Invalid mode: " .. tostring(mode)
end

function InputValidator.ValidatePosition(position)
	if typeof(position) ~= "Vector3" then
		if type(position) == "table" and position.x and position.y and position.z then
			position = Vector3.new(position.x, position.y, position.z)
		else
			return false, "Invalid position type"
		end
	end
	
	-- Check for NaN or Infinity
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
		return false, "Position contains NaN"
	end
	
	if math.abs(position.X) > 10000 or math.abs(position.Y) > 10000 or math.abs(position.Z) > 10000 then
		return false, "Position out of bounds"
	end
	
	return true, position
end

function InputValidator.ValidateNumber(value, min, max, fieldName)
	fieldName = fieldName or "Value"
	
	if type(value) ~= "number" then
		return false, fieldName .. " must be a number"
	end
	
	if value ~= value then -- NaN check
		return false, fieldName .. " is NaN"
	end
	
	if min and value < min then
		return false, fieldName .. " is too small"
	end
	
	if max and value > max then
		return false, fieldName .. " is too large"
	end
	
	return true, value
end

function InputValidator.ValidateString(value, maxLength, fieldName)
	fieldName = fieldName or "String"
	
	if type(value) ~= "string" then
		return false, fieldName .. " must be a string"
	end
	
	if #value > maxLength then
		return false, fieldName .. " is too long"
	end
	
	-- Remove potential injection characters
	local sanitized = string.gsub(value, "[<>\"']", "")
	
	return true, sanitized
end

-- ========== ANTI-CHEAT ==========
local AntiCheat = {}
local playerStats = {}
local suspiciousPlayers = {}

function AntiCheat.Init(player)
	playerStats[player.UserId] = {
		matchesPlayed = 0,
		totalPointsGained = 0,
		lastMatchStart = 0,
		lastMatchEnd = 0,
		warnings = 0,
	}
end

function AntiCheat.RecordMatchStart(player)
	local stats = playerStats[player.UserId]
	if stats then
		stats.lastMatchStart = tick()
		stats.matchesPlayed = stats.matchesPlayed + 1
	end
end

function AntiCheat.RecordMatchEnd(player, pointsGained)
	local stats = playerStats[player.UserId]
	if not stats then return end
	
	stats.lastMatchEnd = tick()
	stats.totalPointsGained = stats.totalPointsGained + pointsGained
	
	-- Check for suspicious activity
	local matchDuration = stats.lastMatchEnd - stats.lastMatchStart
	
	-- Warning 1: Match too short
	if matchDuration < CONFIG.MIN_MATCH_DURATION then
		AntiCheat.AddWarning(player, "Match too short: " .. math.floor(matchDuration) .. "s")
	end
	
	-- Warning 2: Too many points gained
	if pointsGained > CONFIG.MAX_RANK_POINTS_PER_MATCH then
		AntiCheat.AddWarning(player, "Suspicious points gain: " .. pointsGained)
	end
	
	-- Warning 3: Too many matches in short time
	local hourStart = tick() - 3600
	if stats.matchesPlayed > CONFIG.MAX_MATCHES_PER_HOUR then
		AntiCheat.AddWarning(player, "Too many matches: " .. stats.matchesPlayed)
	end
end

function AntiCheat.AddWarning(player, reason)
	local stats = playerStats[player.UserId]
	if not stats then return end
	
	stats.warnings = stats.warnings + 1
	
	
	-- Auto-kick after 5 warnings
	if stats.warnings >= 5 then
		player:Kick("Suspicious activity detected. Please contact support if this is an error.")
		suspiciousPlayers[player.UserId] = {reason = reason, time = tick()}
	end
end

function AntiCheat.IsSuspicious(player)
	return suspiciousPlayers[player.UserId] ~= nil
end

function AntiCheat.Cleanup(player)
	playerStats[player.UserId] = nil
end

-- ========== SECURE DATASTORE ==========
local SecureDataStore = {}
local DataStoreService = game:GetService("DataStoreService")
local dataStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
local cache = {}
local pendingSaves = {}

function SecureDataStore.GetKey(userId)
	return "Player_" .. userId .. "_v" .. CONFIG.DATASTORE_VERSION
end

function SecureDataStore.Load(player)
	local key = SecureDataStore.GetKey(player.UserId)
	
	-- In Studio mode, return default data
	if RunService:IsStudio() then
		local defaultData = {
			HP = 150,
			MaxHP = 150,
			Level = 1,
			Exp = 0,
			Money = 0,
			RankPoints = 0,
			Wins = 0,
			Losses = 0,
			Draws = 0,
			TotalMatches = 0,
			LastPlayed = 0,
		}
		cache[player.UserId] = defaultData
		return defaultData
	end
	
	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)
	
	if success and result then
		-- Validate loaded data
		local validatedData = SecureDataStore.ValidateData(result)
		cache[player.UserId] = validatedData
		return validatedData
	elseif not success then
		warn("[DataStore] Failed to load data for " .. player.Name .. ": " .. tostring(result))
	end
	
	-- Return default data if load failed or no data
	local defaultData = {
		HP = 150,
		MaxHP = 150,
		Level = 1,
		Exp = 0,
		Money = 0,
		RankPoints = 0,
		Wins = 0,
		Losses = 0,
		Draws = 0,
		TotalMatches = 0,
		LastPlayed = 0,
	}
	cache[player.UserId] = defaultData
	return defaultData
end

function SecureDataStore.ValidateData(data)
	-- Ensure all required fields exist with valid values
	local validated = {
		HP = math.clamp(data.HP or 150, 1, 1000),
		MaxHP = math.clamp(data.MaxHP or 150, 1, 1000),
		Level = math.clamp(data.Level or 1, 1, 100),
		Exp = math.max(data.Exp or 0, 0),
		Money = math.max(data.Money or 0, 0),
		RankPoints = math.clamp(data.RankPoints or 0, 0, 100000),
		Wins = math.max(data.Wins or 0, 0),
		Losses = math.max(data.Losses or 0, 0),
		Draws = math.max(data.Draws or 0, 0),
		TotalMatches = math.max(data.TotalMatches or 0, 0),
		LastPlayed = data.LastPlayed or 0,
	}
	
	-- Validate HP <= MaxHP
	if validated.HP > validated.MaxHP then
		validated.HP = validated.MaxHP
	end
	
	return validated
end

function SecureDataStore.Save(player, data)
	-- Skip DataStore writes in Studio mode to avoid API access errors
	if RunService:IsStudio() then
		return true -- Silently succeed in Studio
	end
	
	local key = SecureDataStore.GetKey(player.UserId)
	local dataToSave = data or cache[player.UserId]
	
	if not dataToSave then
		warn("[DataStore] No data to save for " .. player.Name)
		return false
	end
	
	-- Validate before saving
	local validatedData = SecureDataStore.ValidateData(dataToSave)
	
	local success, err = pcall(function()
		dataStore:SetAsync(key, validatedData)
	end)
	
	if success then
		return true
	else
		warn("[DataStore] Failed to save data for " .. player.Name .. ": " .. tostring(err))
		-- Add to pending saves for retry
		table.insert(pendingSaves, {player = player, data = validatedData, time = tick()})
		return false
	end
end

function SecureDataStore.SaveAll()
	local savedCount = 0
	for userId, data in pairs(cache) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			if SecureDataStore.Save(player, data) then
				savedCount = savedCount + 1
			end
		end
	end
end

function SecureDataStore.GetCache(player)
	return cache[player.UserId]
end

function SecureDataStore.UpdateCache(player, key, value)
	if cache[player.UserId] then
		-- Validate the key and value
		local validKeys = {"HP", "MaxHP", "Level", "Exp", "Money", "RankPoints", "Wins", "Losses", "Draws", "TotalMatches", "LastPlayed"}
		local isValidKey = false
		for _, k in ipairs(validKeys) do
			if k == key then
				isValidKey = true
				break
			end
		end
		
		if not isValidKey then
			warn("[DataStore] Invalid key: " .. tostring(key))
			return false
		end
		
		-- Validate value type
		if type(value) ~= "number" then
			warn("[DataStore] Value must be a number: " .. tostring(value))
			return false
		end
		
		cache[player.UserId][key] = value
		return true
	end
	return false
end

function SecureDataStore.Cleanup(player)
	-- Save before cleanup
	SecureDataStore.Save(player)
	cache[player.UserId] = nil
end

-- Auto-save loop
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTO_SAVE_INTERVAL)
		SecureDataStore.SaveAll()
	end
end)

-- Retry pending saves
task.spawn(function()
	while true do
		task.wait(30)
		local now = tick()
		local newPending = {}
		for _, save in ipairs(pendingSaves) do
			if now - save.time < 300 then -- Retry for 5 minutes
				local success = SecureDataStore.Save(save.player, save.data)
				if not success then
					table.insert(newPending, save)
				end
			end
		end
		pendingSaves = newPending
	end
end)

-- ========== INIT FUNCTION ==========
function SecurityManager.Init()
	-- Export to _G for global access
	_G.Security = {
		CONFIG = CONFIG,
		RateLimiter = RateLimiter,
		InputValidator = InputValidator,
		AntiCheat = AntiCheat,
		SecureDataStore = SecureDataStore,
	}
	
	
	return true
end

return SecurityManager
