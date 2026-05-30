local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- C?u h�nh respawn
local BASE_RESPAWN_TIME = 10 -- Th?i gian h?i sinh ban d?u: 10s
local RESPAWN_INCREMENT = 3 -- Tang th�m m?i l?n ch?t: 3s
local MAX_RESPAWN_TIME = 30 -- Th?i gian h?i sinh t?i da: 30s
local spawnProtectionTime = 3 -- Th?i gian b?o v? khi spawn: 3s

-- Luu tr? s? l?n ch?t c?a t?ng ngu?i choi
local deathCount = {}

-- Luu tr? ngu?i choi dang du?c b?o v?
local protectedPlayers = {}

-- �?m s? player trong m?i team d? c�n b?ng
local teamCounts = {}

-- T?o RemoteEvent d? th�ng b�o cho client
local respawnEvent = ReplicatedStorage:FindFirstChild("RespawnEvent")
if not respawnEvent then
	respawnEvent = Instance.new("RemoteEvent")
	respawnEvent.Name = "RespawnEvent"
	respawnEvent.Parent = ReplicatedStorage
end


-- T�nh th?i gian respawn d?a tr�n s? l?n ch?t
local function getRespawnTime(player)
	local deaths = deathCount[player.UserId] or 0
	local respawnTime = BASE_RESPAWN_TIME + (deaths * RESPAWN_INCREMENT)
	return math.min(respawnTime, MAX_RESPAWN_TIME)
end

-- T�m spawn location cho team
local function getTeamSpawnLocation(team)
	if not team then return nil end

	-- T�m spawn location trong arena tru?c
	local arena = game.Workspace.Arenas:FindFirstChild("Arena1v1")
	if arena then
		for _, spawn in arena:GetChildren() do
			if spawn:IsA("SpawnLocation") and not spawn.Neutral then
				if spawn.TeamColor == team.TeamColor then
					return spawn
				end
			end
		end
	end

	-- Fallback: t�m trong to�n b? workspace
	for _, spawn in workspace:GetDescendants() do
		if spawn:IsA("SpawnLocation") and not spawn.Neutral then
			if spawn.TeamColor == team.TeamColor then
				return spawn
			end
		end
	end
	return nil
end

-- Ch?n team c�n b?ng (�t ngu?i hon)
local function assignBalancedTeam(player)
	local teams = Teams:GetTeams()
	if #teams == 0 then return nil end

	-- �?m s? player trong m?i team
	for _, team in teams do
		teamCounts[team.TeamColor.Number] = 0
	end

	for _, p in Players:GetPlayers() do
		if p.Team and p ~= player then
			local color = p.Team.TeamColor.Number
			teamCounts[color] = (teamCounts[color] or 0) + 1
		end
	end

	-- T�m team �t ngu?i nh?t
	local minCount = math.huge
	local bestTeams = {}
	for _, team in teams do
		local count = teamCounts[team.TeamColor.Number] or 0
		if count < minCount then
			minCount = count
			bestTeams = {team}
		elseif count == minCount then
			table.insert(bestTeams, team)
		end
	end

	-- Random t? c�c team c� s? ngu?i �t nh?t
	return bestTeams[math.random(1, #bestTeams)]
end

-- T�m neutral spawn location (lobby)
local function getLobbySpawnLocation()
	-- T�m spawn location cho Lobby team
	local lobbyTeam = Teams:FindFirstChild("Lobby")
	if lobbyTeam then
		for _, spawn in workspace:GetDescendants() do
			if spawn:IsA("SpawnLocation") and not spawn.Neutral then
				if spawn.TeamColor == lobbyTeam.TeamColor then
					return spawn
				end
			end
		end
	end

	-- Fallback: t�m neutral spawn
	for _, spawn in workspace:GetDescendants() do
		if spawn:IsA("SpawnLocation") and spawn.Neutral then
			return spawn
		end
	end
	return nil
end

-- Spawn player t?i v? tr� team
local function spawnAtTeamLocation(player, character)
	local team = player.Team
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not hrp then return end

	-- N?u ? Lobby team ho?c kh�ng c� team, spawn t?i lobby
	if not team or team.Name == "Lobby" then
		local lobbySpawn = getLobbySpawnLocation()
		if lobbySpawn then
			hrp.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
		else
			hrp.CFrame = CFrame.new(0, 10, 0) -- Fallback
		end
		return
	end

	-- N?u player ?ang trong match, respawn t?i base riêng c?a player
	local playerInfo = _G.PlayerMatchInfo and _G.PlayerMatchInfo[player.UserId]
	if playerInfo and playerInfo.mode then
		-- Ki?m tra xem player c� base riêng kh�ng
		local IndividualBaseManager = _G.IndividualBaseManager
		if IndividualBaseManager then
			local baseData = IndividualBaseManager.GetPlayerBaseData(player.Name)
			if baseData and baseData.base and baseData.base.Parent then
				-- Spawn t?i v? tr� base c?a player
				local basePos = baseData.base:GetPivot().Position
				local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				hrp.CFrame = CFrame.new(basePos + Vector3.new(0, 3, 0) + offset)
				return
			end
		end
		
		-- Fallback: spawn t?i spawn points c?a team
		if _G.MatchTeleporter and _G.MatchTeleporter.GetTeamSpawnPoints then
			local teamKey = (team.Name == "Team1") and "team1" or "team2"
			local spawns = _G.MatchTeleporter.GetTeamSpawnPoints(playerInfo.mode, teamKey)
			if spawns and #spawns > 0 then
				local spawnPoint = spawns[math.random(1, #spawns)]
				local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				hrp.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0) + offset
				return
			end
		end
	end

	-- Spawn t?i base c?a team trong arena
	local spawnLocation = getTeamSpawnLocation(team)
	if spawnLocation then
		-- Spawn t?i v? tr� spawn location v?i offset ng?u nhi�n nh?
		local offset = Vector3.new(
			math.random(-3, 3),
			0,
			math.random(-3, 3)
		)
		hrp.CFrame = spawnLocation.CFrame + offset
	else
		-- Fallback: spawn t?i lobby
		local lobbySpawn = getLobbySpawnLocation()
		if lobbySpawn then
			hrp.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end

local function applySpawnProtection(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- ��nh d?u ngu?i choi dang du?c b?o v?
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		protectedPlayers[player.UserId] = true
	end

	-- Set MaxHealth v? 100 v� kh�i ph?c health
	humanoid.MaxHealth = 100
	humanoid.Health = 100

	-- T?o hi?u ?ng visual b?o v?
	local highlight = Instance.new("Highlight")
	highlight.Name = "SpawnProtection"
	highlight.FillColor = Color3.fromRGB(0, 255, 255) -- M�u xanh duong
	highlight.OutlineColor = Color3.fromRGB(0, 200, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	-- Ch?n damage trong th?i gian b?o v?
	local isProtected = true
	local healthChangedConnection
	healthChangedConnection = humanoid.HealthChanged:Connect(function(newHealth)
		if isProtected and newHealth < 100 then
			humanoid.Health = 100 -- Kh�i ph?c health v? 100 ngay l?p t?c
		end
	end)

	-- �?i h?t th?i gian b?o v?
	task.wait(spawnProtectionTime)

	-- T?t b?o v?
	isProtected = false

	-- X�a b?o v?
	if player then
		protectedPlayers[player.UserId] = nil
	end

	-- Ng?t k?t n?i HealthChanged
	if healthChangedConnection then
		healthChangedConnection:Disconnect()
	end

	-- X�a hi?u ?ng visual
	if highlight and highlight.Parent then
		highlight:Destroy()
	end

	-- �?m b?o health v� MaxHealth d�ng sau khi b?o v? k?t th�c
	if humanoid and humanoid.Parent then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
	end
end

local function onPlayerAdded(player)
	-- Reset s? l?n ch?t khi tham gia
	deathCount[player.UserId] = 0

	-- K?t n?i CharacterAdded TRU?C khi LoadCharacter
	player.CharacterAdded:Connect(function(character)

		-- Spawn t?i v? tr� team
		spawnAtTeamLocation(player, character)

		-- �?i m?t ch�t d? d?m b?o character d� load ho�n to�n
		task.wait(0.1)

		-- �p d?ng b?o v? khi spawn
		applySpawnProtection(character)

		-- X? l� khi player ch?t
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				-- Ki?m tra player c� th? respawn kh�ng
				local canRespawn = true
				local IndividualBaseManager = _G.IndividualBaseManager
				if IndividualBaseManager then
					canRespawn = IndividualBaseManager.CanPlayerRespawn(player.Name)
					if not canRespawn then

						-- G?i th�ng b�o cho client
						respawnEvent:FireClient(player, {
							event = "PlayerEliminated",
							reason = "Base destroyed"
						})
						return
					end
				end

				-- T�nh th?i gian respawn TRU?C khi tang s? l?n ch?t
				local respawnTime = getRespawnTime(player)

				-- Tang s? l?n ch?t
				deathCount[player.UserId] = (deathCount[player.UserId] or 0) + 1


				-- G?i th�ng b�o cho client
				respawnEvent:FireClient(player, {
					event = "PlayerDied",
					respawnTime = respawnTime,
					deathCount = deathCount[player.UserId]
				})

				-- �?i th?i gian respawn
				task.wait(respawnTime)

				-- Ki?m tra l?i tru?c khi h?i sinh
				if IndividualBaseManager then
					canRespawn = IndividualBaseManager.CanPlayerRespawn(player.Name)
					if not canRespawn then

						-- G?i th�ng b�o cho client
						respawnEvent:FireClient(player, {
							event = "PlayerEliminated",
							reason = "Base destroyed"
						})
						return
					end
				end

				-- H?i sinh ngu?i choi
				if player and player.Parent == Players then
					player:LoadCharacter()

					-- Th�ng b�o d� h?i sinh
					respawnEvent:FireClient(player, {
						event = "PlayerRespawned"
					})
				end
			end)
		end
	end)

	-- Spawn character (LoadCharacter du?c g?i SAU khi d� k?t n?i CharacterAdded)
	-- Ch? g?i LoadCharacter n?u player chua c� character
	if not player.Character then
		player:LoadCharacter()
	end
end

-- L?ng nghe ngu?i choi m?i tham gia
Players.PlayerAdded:Connect(onPlayerAdded)

-- X? l� ngu?i choi d� c� trong game khi script ch?y
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- X? l� khi ngu?i choi r?i game
Players.PlayerRemoving:Connect(function(player)
	deathCount[player.UserId] = nil
end)

