local PlayerData = {}

local data = {}

-- ========== SECURE DEFAULT DATA ==========
local DEFAULT_DATA = {
	HP = 150,
	MaxHP = 150,
	Level = 1,
	Exp = 0,
	Money = 0,
	-- Ranking data (SINGLE RANK - không tách theo mode)
	RankPoints = 0,
	Wins = 0,
	Losses = 0,
	Draws = 0,
	TotalMatches = 0,
	LastPlayed = 0,
}

-- ========== VALID KEYS (chỉ cho phép sửa các key này) ==========
local VALID_KEYS = {
	HP = true,
	MaxHP = true,
	Level = true,
	Exp = true,
	Money = true,
	RankPoints = true,
	Wins = true,
	Losses = true,
	Draws = true,
	TotalMatches = true,
	LastPlayed = true,
}

-- ========== VALUE LIMITS ==========
local VALUE_LIMITS = {
	HP = {min = 1, max = 1000},
	MaxHP = {min = 1, max = 1000},
	Level = {min = 1, max = 100},
	Exp = {min = 0, max = 1000000},
	Money = {min = 0, max = 10000000},
	RankPoints = {min = 0, max = 100000},
	Wins = {min = 0, max = 100000},
	Losses = {min = 0, max = 100000},
	Draws = {min = 0, max = 100000},
	TotalMatches = {min = 0, max = 100000},
	LastPlayed = {min = 0, max = 9999999999},
}

function PlayerData.Init(player)
	-- ========== SECURITY: Load từ DataStore nếu có ==========
	local Security = _G.Security
	local loadedData = nil
	
	if Security and Security.SecureDataStore then
		loadedData = Security.SecureDataStore.Load(player)
		Security.AntiCheat.Init(player)
	end
	
	-- Dùng UserId làm key (an toàn hơn)
	if loadedData then
		data[player.UserId] = loadedData
	else
		data[player.UserId] = table.clone(DEFAULT_DATA)
	end
	
	-- Gán player vào Lobby team
	local Teams = game:GetService("Teams")
	local lobbyTeam = Teams:FindFirstChild("Lobby")
	if lobbyTeam then
		player.Team = lobbyTeam
		player.Neutral = false
	end
	
	-- KHÔNG tạo leaderstats ở lobby (ẩn hoàn toàn)
	-- Leaderstats chỉ hiện khi vào trận
	
	-- Sync HP vào character
	local function syncCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxHealth = data[player.UserId].MaxHP
		humanoid.Health = data[player.UserId].HP
	end
	
	if player.Character then
		syncCharacter(player.Character)
	end
	
	player.CharacterAdded:Connect(syncCharacter)
	
end

-- Hiện leaderstats khi vào trận
function PlayerData.ShowLeaderstats(player)
	if not data[player.UserId] then return end
	
	-- Xóa leaderstats cũ nếu có
	local oldLeaderstats = player:FindFirstChild("leaderstats")
	if oldLeaderstats then
		oldLeaderstats:Destroy()
	end
	
	-- Tạo leaderstats mới
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	-- Thêm Team trước (hiển thị đầu tiên)
	local teamStat = Instance.new("StringValue")
	teamStat.Name = "Team"
	teamStat.Value = player.Team and player.Team.Name or "None"
	teamStat.Parent = leaderstats
	
	-- Chỉ hiện các stats quan trọng trên leaderboard (thứ tự quan trọng)
	local displayStats = {"Level", "Exp", "Money"}
	for _, key in ipairs(displayStats) do
		local value = data[player.UserId][key]
		if value ~= nil then
			local stat = Instance.new("IntValue")
			stat.Name = key
			stat.Value = value
			stat.Parent = leaderstats
		end
	end
	
end

-- Ẩn leaderstats khi hết trận
function PlayerData.HideLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats:Destroy()
	end
	
	-- Reset team về Lobby
	local Teams = game:GetService("Teams")
	local lobbyTeam = Teams:FindFirstChild("Lobby")
	if lobbyTeam then
		player.Team = lobbyTeam
		player.Neutral = false
	end
end

function PlayerData.Get(player)
	return data[player.UserId]
end

function PlayerData.Set(player, key, value)
	-- ========== SECURITY: Validate input ==========
	if not data[player.UserId] then
		warn("[PlayerData] No data for player: " .. player.Name)
		return false
	end
	
	-- Validate key
	if not VALID_KEYS[key] then
		warn("[PlayerData] Invalid key: " .. tostring(key))
		return false
	end
	
	-- Validate value type
	if type(value) ~= "number" then
		warn("[PlayerData] Value must be number for key: " .. key)
		return false
	end
	
	-- Validate value range
	local limits = VALUE_LIMITS[key]
	if limits then
		if value < limits.min or value > limits.max then
			warn("[PlayerData] Value out of range for " .. key .. ": " .. value)
			value = math.clamp(value, limits.min, limits.max)
		end
	end
	
	-- Special validation for HP <= MaxHP
	if key == "HP" then
		local maxHP = data[player.UserId].MaxHP
		if value > maxHP then
			value = maxHP
		end
	end
	
	-- Apply change
	data[player.UserId][key] = value
	
	-- Update cache in SecureDataStore
	local Security = _G.Security
	if Security and Security.SecureDataStore then
		Security.SecureDataStore.UpdateCache(player, key, value)
	end
	
	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local stat = leaderstats:FindFirstChild(key)
		if stat then
			stat.Value = value
			
			-- Sync HP/MaxHP vào character
			if key == "HP" or key == "MaxHP" then
				local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
				if humanoid then
					if key == "MaxHP" then
						humanoid.MaxHealth = value
					elseif key == "HP" then
						humanoid.Health = value
					end
				end
			end
		end
	end
	
	return true
end

function PlayerData.Remove(player)
	-- ========== SECURITY: Save data before cleanup ==========
	local Security = _G.Security
	if Security and Security.SecureDataStore then
		Security.SecureDataStore.Save(player)
		Security.SecureDataStore.Cleanup(player)
		Security.RateLimiter.Cleanup(player)
		Security.AntiCheat.Cleanup(player)
	end
	
	data[player.UserId] = nil
end

return PlayerData
