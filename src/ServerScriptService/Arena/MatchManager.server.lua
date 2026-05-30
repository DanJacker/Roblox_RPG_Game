-- Match Manager - Qu?n l? b?t d?u v? k?t th?c tr?n d?u
-- ?? LOCATION: ServerScriptService/Arena/
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========== SHARED CONFIG ==========
local SharedConfig = require(ServerScriptService.Shared.SharedConfig)

-- Modules (v?n ? ReplicatedStorage)
local PlayerData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerData"))
local TeamTagManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TeamTagManager"))
local RankingSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RankingSystem"))

-- T?o ho?c l?y RemoteEvents
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

-- H?m helper d? t?o RemoteEvent n?u chua c?
local function getOrCreateRemoteEvent(name)
	local event = remoteEventsFolder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remoteEventsFolder
	end
	return event
end

-- RemoteEvents
local MatchFound = getOrCreateRemoteEvent("MatchFound")
local MatchEnded = getOrCreateRemoteEvent("MatchEnded")
local MatchTimer = getOrCreateRemoteEvent("MatchTimer")
local MatchResult = getOrCreateRemoteEvent("MatchResult")
local MinimapToggle = getOrCreateRemoteEvent("MinimapToggle")
local SpawnSelect = getOrCreateRemoteEvent("SpawnSelect")
local RankUpdate = getOrCreateRemoteEvent("RankUpdate")
local MatchStart = getOrCreateRemoteEvent("MatchStart")

-- Luu tr? c?c tr?n d?u dang di?n ra
local activeMatches = {}

-- Luu tr? v? tr? spawn d? ch?n c?a m?i player
local playerSpawnPositions = {}

-- Luu tr? nh?ng player d? du?c teleport r?i
local playersAlreadyTeleported = {}

-- V? tr? spawn cho t?ng arena
local arenaSpawns = {
	["1v1"] = {
		team1 = CFrame.new(-28, 3, 0),
		team2 = CFrame.new(28, 3, 0)
	},
	["2v2"] = {
		team1 = CFrame.new(-20, 2, -5),
		team2 = CFrame.new(20, 2, 5)
	},
	["3v3"] = {
		team1 = CFrame.new(-25, 2, -10),
		team2 = CFrame.new(25, 2, 10)
	}
}

-- Forward declaration
local spawnPlayersInMatch

-- H?m b?t d?u tr?n d?u
local function startMatch(matchId, matchData)

	-- ========== RESET BASE STATE FOR NEW MATCH ==========
	-- Reset gameEnded và base health trước khi bắt đầu trận mới
	if _G.ResetBases then
		_G.ResetBases()
	end

	-- ========== SECURITY: Record match start for anti-cheat ==========
	local Security = _G.Security
	if Security then
		for _, playerData in ipairs(matchData.allPlayers) do
			local player = Players:GetPlayerByUserId(playerData.playerId)
			if player then
				Security.AntiCheat.RecordMatchStart(player)
			end
		end
	end

	activeMatches[matchId] = {
		players = matchData.players,
		mode = matchData.mode,
		team1 = matchData.team1,
		team2 = matchData.team2,
		startTime = tick(),
		status = "spawnSelection"
	}

	-- L?u mode/matchId cho respawn ??ng map (RespawnSystem kh?ng d?ng ArenaManager)
	_G.PlayerMatchInfo = _G.PlayerMatchInfo or {}

	-- G?n team v? th?ng b?o spawn selection
	for _, playerData in ipairs(matchData.allPlayers) do
		local player = Players:GetPlayerByUserId(playerData.playerId)
		if player then
			-- X?c d?nh team
			local isTeam1 = false
			for _, team1Player in ipairs(matchData.team1) do
				if team1Player.playerId == playerData.playerId then
					isTeam1 = true
					break
				end
			end

			-- G?n team
			local teamObj = isTeam1 and Teams:FindFirstChild("Team1") or Teams:FindFirstChild("Team2")
			if teamObj then
				player.Team = teamObj
				player.Neutral = false

				_G.PlayerMatchInfo[player.UserId] = {
					matchId = matchId,
					mode = matchData.mode or "1v1"
				}

				-- C?p nh?t name tag tr?c ti?p
				if player.Character then
					TeamTagManager.UpdateNameTag(player, player.Character)
				end
			end

			-- Hi?n leaderstats
			PlayerData.ShowLeaderstats(player)

			-- Hi?n th? minimap
			MinimapToggle:FireClient(player, {
				action = "show",
				matchId = matchId,
				mode = matchData.mode
			})

			-- Th?ng b?o b?t d?u spawn selection
			SpawnSelect:FireClient(player, {
				action = "startSelection",
				matchId = matchId,
				mode = matchData.mode,
				isTeam1 = isTeam1
			})
		end
	end

	-- ??i t?t c? players ch?n spawn ho?c h?t th?i gian
	task.spawn(function()
		local allSelected = false
		local startTime = tick()
		local timeout = 11

		while not allSelected and (tick() - startTime) < timeout do
			task.wait(0.5)

			local selectedCount = 0
			for _, playerId in ipairs(activeMatches[matchId].players) do
				if playerSpawnPositions[playerId] then
					selectedCount = selectedCount + 1
				end
			end

			if selectedCount >= #activeMatches[matchId].players then
				allSelected = true
			end
		end

		-- Spawn t?t c? players
		spawnPlayersInMatch(matchId)
	end)
end

-- ??nh nghia h?m spawnPlayersInMatch
spawnPlayersInMatch = function(matchId)
	local matchData = activeMatches[matchId]
	if not matchData then return end

	matchData.status = "active"

	-- ========== S? D?NG MATCH TELEPORTER ==========
	-- Teleport t?t c? players d?n spawn points trong map
	local MatchTeleporter = _G.MatchTeleporter
	if MatchTeleporter then
		MatchTeleporter.TeleportPlayersToMatch(matchId, matchData.mode, matchData.team1, matchData.team2)
	else
		-- Fallback: S? d?ng c?ch cu n?u MatchTeleporter kh?ng c?
		warn("[MatchManager] MatchTeleporter kh?ng kh? d?ng, s? d?ng fallback")
		for _, playerId in ipairs(matchData.players) do
			local player = Players:GetPlayerByUserId(playerId)
			if player then
				if playersAlreadyTeleported[playerId] then
				else
					playersAlreadyTeleported[playerId] = true

					if player.Character then
						local spawnPos = playerSpawnPositions[playerId]

						if not spawnPos then
							local isTeam1 = player.Team and player.Team.Name == "Team1"
							local spawnCFrame = arenaSpawns[matchData.mode]
							if spawnCFrame then
								spawnPos = isTeam1 and spawnCFrame.team1.Position or spawnCFrame.team2.Position
							end
						end

						if spawnPos then
							player.Character:PivotTo(CFrame.new(spawnPos))
						end
					end
				end

				SpawnSelect:FireClient(player, {
					action = "endSelection"
				})
			end
		end
	end

	if _G.AssignBaseOwnersFromMatch then
		_G.AssignBaseOwnersFromMatch(matchData)
	end

	-- X?a v? tr? spawn d? luu
	for _, playerId in ipairs(matchData.players) do
		playerSpawnPositions[playerId] = nil
		playersAlreadyTeleported[playerId] = nil
	end

	-- B?t d?u timer tr?n d?u
	if _G.StartMatchTimer then
		_G.StartMatchTimer(matchId, matchData)
	end

	-- B?t d?u h? th?ng base damage
	if _G.StartBaseMatch then
		_G.StartBaseMatch(matchId)
	end

	-- B?t d?u theo d?i th?ng k? match end conditions
	if _G.MatchEndConditions then
		_G.MatchEndConditions.StartMatch(matchId)
	end

	-- B?t d?u theo d?i MVP
	if _G.MVPSystem then

		-- Debug: In t?n c?c players
		if matchData.team1 then
			for i, pd in ipairs(matchData.team1) do
			end
		end
		if matchData.team2 then
			for i, pd in ipairs(matchData.team2) do
			end
		end

		_G.MVPSystem.StartMatch(matchData)
	else
		warn("[MatchManager] MVPSystem KH?NG KH? D?NG!")
	end

	-- Th?ng b?o b?t d?u tr?n d?u
	for _, playerId in ipairs(matchData.players) do
		local player = Players:GetPlayerByUserId(playerId)
		if player then
			-- G?i MatchStart event d? k?ch ho?t GUI
			MatchStart:FireClient(player, {
				matchId = matchId,
				mode = matchData.mode
			})

			MatchTimer:FireClient(player, {
				action = "start",
				matchId = matchId,
				mode = matchData.mode,
				duration = 300 -- 5 ph?t
			})

			-- G?i th?ng tin rank hi?n t?i
			local playerData = PlayerData.Get(player)
			if playerData then
				local rankInfo = RankingSystem.GetRankFromPoints(playerData.RankPoints or 0)
				RankUpdate:FireClient(player, rankInfo)
			end
		end
	end
end

-- H?m k?t th?c tr?n d?u
local function endMatch(matchId, reason)
	
	if not activeMatches[matchId] then
		warn("[MatchManager] Match not found in activeMatches! Available matches:")
		for id, data in pairs(activeMatches) do
			warn("[MatchManager]   - " .. tostring(id))
		end
		return
	end

	local matchData = activeMatches[matchId]

	-- D?ng timer
	if _G.StopMatchTimer then
		_G.StopMatchTimer(matchId)
	end

	-- Cleanup Boss khi tr?n k?t th?c
	if _G.BossManager and _G.BossManager.Cleanup then
		_G.BossManager.Cleanup()
	end

	-- X?c d?nh d?i th?ng
	local winnerTeam = nil
	if string.find(reason, "Team1") then
		winnerTeam = "Team1"
	elseif string.find(reason, "Team2") then
		winnerTeam = "Team2"
	end

	-- ========== HI?N TH? VICTORY/LOST UI V? MVP UI ==========
	-- G?i MatchEndHandler d? hi?n th? UI
	if _G.MatchEndHandler and _G.MatchEndHandler.EndMatch then
		_G.MatchEndHandler.EndMatch(winnerTeam, reason)
	else
		warn("[MatchManager] MatchEndHandler KH?NG KH? D?NG!")
	end
	-- ===========================================================

	-- ========== H? TH?NG RANKING ==========
	-- C?p nh?t di?m ranking cho t?t c? players
	
	local rankingResults = {}
	local Security = _G.Security

	for _, playerId in ipairs(matchData.players) do
		local player = Players:GetPlayerByUserId(playerId)
		if player then
			local playerData = PlayerData.Get(player)
			if playerData then
				local playerTeam = player.Team and player.Team.Name
				local result = "lose"

				-- X?c d?nh k?t qu?
				if winnerTeam then
					if playerTeam == winnerTeam then
						result = "win"
					else
						result = "lose"
					end
				else
					result = "draw"
				end

				-- Tính điểm mới (theo chế độ)
				local currentPoints = playerData.RankPoints or 0
				local matchMode = matchData.mode or "1v1"
				local newPoints, pointsChange = RankingSystem.CalculateNewPoints(currentPoints, result, matchMode)

				-- ========== SECURITY: Anti-cheat check ==========
				if Security then
					Security.AntiCheat.RecordMatchEnd(player, pointsChange)
				end

				-- L?y th?ng tin rank thay d?i
				local rankChange = RankingSystem.GetRankChange(currentPoints, newPoints)

				-- C?p nh?t PlayerData (SECURE)
				PlayerData.Set(player, "RankPoints", newPoints)
				PlayerData.Set(player, "TotalMatches", (playerData.TotalMatches or 0) + 1)
				PlayerData.Set(player, "LastPlayed", tick())

				if result == "win" then
					PlayerData.Set(player, "Wins", (playerData.Wins or 0) + 1)
				elseif result == "lose" then
					PlayerData.Set(player, "Losses", (playerData.Losses or 0) + 1)
				else
					PlayerData.Set(player, "Draws", (playerData.Draws or 0) + 1)
				end

				-- Luu k?t qu? d? g?i cho client
				rankingResults[playerId] = {
					result = result,
					pointsChange = pointsChange,
					oldRank = rankChange.oldRank,
					newRank = rankChange.newRank,
					rankUp = rankChange.rankUp,
					rankDown = rankChange.rankDown
				}

				print(string.format("[Ranking] %s: %s | %d -> %d di?m (%+d) | %s -> %s",
					player.Name, result, currentPoints, newPoints, pointsChange,
					rankChange.oldRank.displayName, rankChange.newRank.displayName))

				if rankChange.rankUp then
				end
			end
		end
	end
	-- ======================================

	-- Th?ng b?o k?t qu? v? teleport v? lobby
	for _, playerId in ipairs(matchData.players) do
		local player = Players:GetPlayerByUserId(playerId)
		if player then
			local playerTeam = player.Team
			local playerTeamName = playerTeam and playerTeam.Name or ""
			local loserTeam = winnerTeam == "Team1" and "Team2" or "Team1"

			-- G?i k?t qu? ranking cho client
			local rankResult = rankingResults[playerId]

			MatchEnded:FireClient(player, {
				reason = reason,
				matchId = matchId,
				winner = winnerTeam
			})

			MatchResult:FireClient(player, {
				winner = winnerTeam,
				loser = loserTeam,
				reason = "BASE_DESTROYED",
				playerTeam = playerTeamName,
				-- Ranking info
				ranking = rankResult
			})

			MinimapToggle:FireClient(player, {
				action = "hide",
				matchId = matchId
			})

			task.delay(5, function()
				PlayerData.HideLeaderstats(player)

				local lobbyTeam = Teams:FindFirstChild("Lobby")
				if lobbyTeam then
					player.Team = lobbyTeam
				else
					player.Team = nil
				end
				player.Neutral = true

				if _G.PlayerMatchInfo then
					_G.PlayerMatchInfo[player.UserId] = nil
				end

				local spawnLocation = game.Workspace:FindFirstChild("SpawnLocation")
				if spawnLocation and player.Character then
					player.Character:PivotTo(spawnLocation.CFrame + Vector3.new(0, 3, 0))
				end

				player:LoadCharacter()

			end)
		end
	end

	-- ========== RESET MAP VÀ TELEPORT VỀ LOBBY ==========
	task.delay(6, function()
		-- Reset tất cả spectator status
		if _G.ResetAllSpectators then
			_G.ResetAllSpectators()
		end

		-- Reset map về trạng thái ban đầu
		local mapMode = matchData.mode or "1v1"
		if _G.MapResetSystem then
			_G.MapResetSystem.ResetMap(mapMode)
		else
			-- Fallback: Reset base colors nếu MapResetSystem không có
			if _G.ResetBases then
				_G.ResetBases()
			end
		end
		
		-- Clear tất cả bots
		if _G.BotManager then
			_G.BotManager.ClearAllBots()
		end
	end)

	activeMatches[matchId] = nil

	-- Cleanup spawn points
	local MatchTeleporter = _G.MatchTeleporter
	if MatchTeleporter then
		MatchTeleporter.CleanupMatchSpawns(matchId)
	end

	if _G.ClearActiveMatch then
		_G.ClearActiveMatch(matchId)
	end
end

-- L?ng nghe spawn selection t? client
SpawnSelect.OnServerEvent:Connect(function(player, data)
	if data.action == "selectSpawn" then
		-- ========== SECURITY: Rate limiting & validation ==========
		local Security = _G.Security
		if Security then
			local allowed, rateMsg = Security.RateLimiter.Check(player, "SpawnSelect")
			if not allowed then
				return
			end

			-- Validate position
			local valid, validatedPos = Security.InputValidator.ValidatePosition(data.position)
			if not valid then
				return
			end
			data.position = validatedPos
		end


		playerSpawnPositions[player.UserId] = data.position
		
		-- Lưu vào SpawnSelectionServer để MatchTeleporter sử dụng
		if _G.SpawnSelectionServer then
			_G.SpawnSelectionServer.setSpawnPosition(player.UserId, data.position)
		end

		for matchId, matchData in pairs(activeMatches) do
			local playerInMatch = false
			for _, playerId in ipairs(matchData.players) do
				if playerId == player.UserId then
					playerInMatch = true
					break
				end
			end

			if playerInMatch and matchData.status == "spawnSelection" then
				playersAlreadyTeleported[player.UserId] = true

				if player.Character and data.position then
					player.Character:PivotTo(CFrame.new(data.position))

					SpawnSelect:FireClient(player, {
						action = "endSelection"
					})
				end
				break
			end
		end
	end
end)

-- H?m ki?m tra player c? dang trong tr?n kh?ng
local function isPlayerInMatch(player)
	for matchId, matchData in pairs(activeMatches) do
		for _, playerId in ipairs(matchData.players) do
			if playerId == player.UserId then
				return true, matchId, matchData
			end
		end
	end
	return false, nil, nil
end

-- Hàm lấy current match ID
local function getCurrentMatchId()
	for matchId, matchData in pairs(activeMatches) do
		return matchId -- Return first active match
	end
	warn("[MatchManager] No active matches found!")
	return nil
end

-- Xử lý yêu cầu rank info từ client
local RequestRankUpdate = getOrCreateRemoteEvent("RequestRankUpdate")
if RequestRankUpdate then
	RequestRankUpdate.OnServerEvent:Connect(function(player)
		local playerData = PlayerData.Get(player)
		if playerData then
			local rankInfo = RankingSystem.GetRankFromPoints(playerData.RankPoints or 0)
			RankUpdate:FireClient(player, rankInfo)
		end
	end)
end

-- Export functions
_G.StartMatch = startMatch
_G.EndMatch = endMatch
_G.IsPlayerInMatch = isPlayerInMatch
_G.GetCurrentMatchId = getCurrentMatchId

