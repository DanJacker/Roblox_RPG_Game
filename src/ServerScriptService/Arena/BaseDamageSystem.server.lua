-- Base Damage System - Hệ thống gây damage khi đánh vào nhà chính
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cấu hình
local BASE_DAMAGE = 25
local BASE_MAX_HEALTH = 1000
local DANGER_THRESHOLD_LOW = 0.15
local DANGER_THRESHOLD_HIGH = 0.25

-- Team colors
local TEAM_COLORS = {
	Team1 = Color3.fromRGB(0, 100, 255),
	Team2 = Color3.fromRGB(255, 50, 50)
}

-- Lưu trữ health cho các base
local multiBaseHealth = {}
local baseOwner = {}
_G.BaseOwner = baseOwner

-- Trạng thái game
local gameEnded = false
local dangerTriggered = {Team1 = false, Team2 = false}
local towerVisualSnapshot = setmetatable({}, { __mode = "k" })

-- Helper functions
local function getBaseHealthKey(baseModel)
	return baseModel and baseModel:GetFullName() or nil
end

local function getBaseHealthByModel(baseModel, teamName)
	local key = getBaseHealthKey(baseModel)
	if key then
		if multiBaseHealth[key] == nil then
			multiBaseHealth[key] = BASE_MAX_HEALTH
		end
		return multiBaseHealth[key]
	end
	return BASE_MAX_HEALTH
end

local function setBaseHealthByModel(baseModel, teamName, health)
	local key = getBaseHealthKey(baseModel)
	if not key then return end
	multiBaseHealth[key] = health
	
	-- Fire event để cập nhật minimap
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEvents then
		local baseHealthEvent = remoteEvents:FindFirstChild("BaseHealthUpdate")
		if baseHealthEvent then
			local basePosition = baseModel:GetPivot().Position
			for _, p in ipairs(Players:GetPlayers()) do
				baseHealthEvent:FireClient(p, baseModel.Name, teamName, health, BASE_MAX_HEALTH, basePosition)
			end
		end
	end
end

local function rememberTowerVisual(tower)
	if not tower or not tower:IsA("BasePart") then return end
	if not towerVisualSnapshot[tower] then
		towerVisualSnapshot[tower] = {
			Color = tower.Color,
			Transparency = tower.Transparency,
		}
	end
end

local function restoreTowerVisual(tower)
	local snap = towerVisualSnapshot[tower]
	if snap and tower and tower.Parent then
		tower.Color = snap.Color
		tower.Transparency = snap.Transparency
	end
end

local function flashTowerDamage(tower)
	if not tower then return end
	rememberTowerVisual(tower)
	tower.Color = Color3.new(1, 0, 0)
	task.delay(0.12, function()
		if tower.Parent then
			restoreTowerVisual(tower)
		end
	end)
end

local function ownerKey(baseModel)
	return baseModel:GetFullName()
end

local function inferTeamFromBaseModel(model)
	local n = model.Name
	if string.find(n, "Team1Base", 1, true) then return "Team1" end
	if string.find(n, "Team2Base", 1, true) then return "Team2" end
	local tw = model:FindFirstChild("Tower")
	if tw then
		local a = tw:GetAttribute("Team")
		if a == "Team1" or a == "Team2" then return a end
	end
	return "Team1"
end

local function getDisplayNameForPlayer(player)
	local d = player.DisplayName
	if type(d) == "string" and d ~= "" then return d end
	return player.Name
end

local function updateOwnerLabel(baseModel, teamName)
	local tower = baseModel:FindFirstChild("Tower")
	if not tower then return end
	local nameLabel = tower:FindFirstChild("NameLabel")
	if not nameLabel then return end
	local textLabel = nameLabel:FindFirstChild("TextLabel")
	if not textLabel then return end
	local owner = baseOwner[ownerKey(baseModel)]
	local teamColor = TEAM_COLORS[teamName] or Color3.new(1, 1, 1)
	if owner then
		local prefix = owner.isBot and "[BOT] " or ""
		textLabel.Text = prefix .. owner.name
	else
		textLabel.Text = teamName
	end
	textLabel.TextColor3 = teamColor
end

local function setBaseOwner(baseModel, teamName, ownerName, isBot)
	baseOwner[ownerKey(baseModel)] = {
		name = ownerName,
		team = teamName,
		isBot = isBot or false,
	}
	updateOwnerLabel(baseModel, teamName)
end

local function updateHealthBar(baseModel, teamName)
	local tower = baseModel:FindFirstChild("Tower")
	if not tower then return end
	local healthBar = tower:FindFirstChild("HealthBar")
	if not healthBar then return end
	local healthFrame = healthBar:FindFirstChild("Frame")
	if not healthFrame then return end
	local healthFill = healthFrame:FindFirstChild("HealthFill")
	local healthText = healthFrame:FindFirstChild("TextLabel")
	if healthFill and healthText then
		local currentHealth = getBaseHealthByModel(baseModel, teamName)
		local healthPercent = currentHealth / BASE_MAX_HEALTH
		healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
		if healthPercent > 0.5 then
			healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		elseif healthPercent > 0.25 then
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		else
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		end
		healthText.Text = tostring(math.floor(currentHealth)) .. "/" .. tostring(BASE_MAX_HEALTH)
	end
end

local function hideBase(baseModel)
	print("[BaseDamage] Hiding base: " .. baseModel.Name)
	local humanoid = baseModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		task.wait(0.1)
		humanoid.Health = 0
	end
	local tower = baseModel:FindFirstChild("Tower")
	if tower then
		tower.Transparency = 1
		tower.CanCollide = false
		local healthBar = tower:FindFirstChild("HealthBar")
		if healthBar then healthBar.Enabled = false end
		local nameLabel = tower:FindFirstChild("NameLabel")
		if nameLabel then nameLabel.Enabled = false end
	end
	for _, child in ipairs(baseModel:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = 1
			child.CanCollide = false
			child.Anchored = true
		elseif child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 1
		elseif child:IsA("ClickDetector") then
			child:Destroy()
		elseif child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child.Enabled = false
		end
	end
	print("[BaseDamage] Base hidden successfully: " .. baseModel.Name)
end

local function showBase(baseModel, teamName)
	print("[BaseDamage] Showing base: " .. baseModel.Name)
	local tower = baseModel:FindFirstChild("Tower")
	if tower then
		restoreTowerVisual(tower)
		tower.CanCollide = true
		local healthBar = tower:FindFirstChild("HealthBar")
		if healthBar then healthBar.Enabled = true end
		local nameLabel = tower:FindFirstChild("NameLabel")
		if nameLabel then nameLabel.Enabled = true end
	end
	for _, child in ipairs(baseModel:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = 0
			child.CanCollide = true
			child.Anchored = true  -- Base ph?i anchored d? kh?ng b? monster d?y
		elseif child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 0
		elseif child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child.Enabled = true
		end
	end
	local humanoid = baseModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
	end
	print("[BaseDamage] Base shown successfully: " .. baseModel.Name)
end

local function getMapContainer(model)
	local mapsFolder = workspace:FindFirstChild("Maps")
	if not mapsFolder or not model then return workspace end
	local cur = model
	while cur and cur.Parent do
		if cur.Parent == mapsFolder then return cur end
		cur = cur.Parent
	end
	return workspace
end

local function checkBaseDestroyed(baseModel, teamName)
	local mapContainer = getMapContainer(baseModel)
	local remainingBases = 0
	for _, obj in ipairs(mapContainer:GetDescendants()) do
		if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
			local h = getBaseHealthByModel(obj, teamName)
			if h > 0 then remainingBases = remainingBases + 1 end
		end
	end
	print("[BaseDamage] " .. teamName .. " còn " .. remainingBases .. " bases")
	if remainingBases == 0 and not gameEnded then
		gameEnded = true
		local winnerTeam = teamName == "Team1" and "Team2" or "Team1"
		print("[BaseDamage] " .. winnerTeam .. " WINS! (All bases destroyed)")
		local matchId = _G.GetCurrentMatchId and _G.GetCurrentMatchId()
		if matchId and _G.EndMatch then
			_G.EndMatch(matchId, winnerTeam .. "_wins_base_destroyed")
		elseif _G.MatchEndHandler and _G.MatchEndHandler.EndMatch then
			_G.MatchEndHandler.EndMatch(winnerTeam, "base_destroyed")
		else
			local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
			if remoteEvents then
				local victoryEvent = remoteEvents:FindFirstChild("VictoryAnnouncement")
				if victoryEvent then
					for _, p in ipairs(Players:GetPlayers()) do
						local pTeam = p.Team and p.Team.Name
						victoryEvent:FireClient(p, {
							winnerTeam = winnerTeam,
							playerTeam = pTeam,
							reason = "base_destroyed",
							isWinner = pTeam == winnerTeam
						})
					end
				end
			end
		end
	end
end

local function onBaseAttacked(baseModel, teamName, player)
	local playerTeam = player.Team
	local playerTeamName = playerTeam and playerTeam.Name
	print(string.format("[BaseDamage] %s đang đánh base %s (Base team: %s, Player team: %s)", 
		player.Name, baseModel.Name, teamName, playerTeamName or "nil"))
	if not playerTeamName or playerTeamName == "Lobby" then
		print("[BaseDamage] " .. player.Name .. " không có team hợp lệ!")
		return
	end
	local isEnemy = (teamName == "Team1" and playerTeamName == "Team2") or
		(teamName == "Team2" and playerTeamName == "Team1")
	if not isEnemy then
		print("[BaseDamage] " .. player.Name .. " không thể đánh base của team mình!")
		return
	end
	local currentHealth = getBaseHealthByModel(baseModel, teamName)
	if currentHealth <= 0 then
		print(string.format("[BaseDamage] Base %s đã bị phá hủy, bỏ qua damage!", baseModel.Name))
		return
	end
	currentHealth = currentHealth - BASE_DAMAGE
	currentHealth = math.max(0, currentHealth)
	setBaseHealthByModel(baseModel, teamName, currentHealth)
	setBaseOwner(baseModel, teamName, getDisplayNameForPlayer(player), false)
	if playerTeamName and _G.MatchEndConditions then
		_G.MatchEndConditions.RecordBaseDamage(playerTeamName, BASE_DAMAGE)
	end
	if _G.MVPSystem then
		_G.MVPSystem.RecordBaseDamage(player.Name, BASE_DAMAGE)
	end
	print("[BaseDamage] " .. player.Name .. " đã đánh " .. baseModel.Name .. "! HP: " .. math.floor(currentHealth))
	updateHealthBar(baseModel, teamName)
	if currentHealth <= 0 and not gameEnded then
		print("[BaseDamage] " .. baseModel.Name .. " đã bị phá hủy bởi " .. player.Name .. "!")
		setBaseHealthByModel(baseModel, teamName, 0)
		local tower = baseModel:FindFirstChild("Tower")
		if tower then
			tower.Anchored = true
			tower.Color = Color3.new(1, 0, 0)
			for i = 1, 5 do
				tower.Transparency = i * 0.2
				task.wait(0.05)
			end
		end
		hideBase(baseModel)
		checkBaseDestroyed(baseModel, teamName)
	end
end

local function setupBaseClick(baseModel, teamName)
	local tower = baseModel:FindFirstChild("Tower")
	if not tower then return end
	rememberTowerVisual(tower)
	local clickDetector = tower:FindFirstChild("ClickDetector")
	if not clickDetector then return end
	local key = getBaseHealthKey(baseModel)
	if key and multiBaseHealth[key] == nil then
		multiBaseHealth[key] = BASE_MAX_HEALTH
	end
	clickDetector.MouseClick:Connect(function(player)
		onBaseAttacked(baseModel, teamName, player)
	end)
	print("[BaseDamage] Đã thiết lập click detector cho " .. baseModel.Name)
end

local function setupBaseTouch(baseModel, teamName)
	local tower = baseModel:FindFirstChild("Tower")
	if not tower then return end
	rememberTowerVisual(tower)
	local key = getBaseHealthKey(baseModel)
	if key and multiBaseHealth[key] == nil then
		multiBaseHealth[key] = BASE_MAX_HEALTH
	end
	local debounce = {}
	tower.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			if not debounce[player] then
				debounce[player] = true
				onBaseAttacked(baseModel, teamName, player)
				task.wait(0.5)
				debounce[player] = nil
			end
			return
		end
		local botTeam = character:GetAttribute("Team")
		if botTeam then
			local botId = character.Name
			if not debounce[botId] then
				debounce[botId] = true
				local isEnemy = (teamName == "Team1" and botTeam == "Team2") or
					(teamName == "Team2" and botTeam == "Team1")
				if isEnemy then
					local currentHealth = getBaseHealthByModel(baseModel, teamName)
					if currentHealth <= 0 then return end
					currentHealth = currentHealth - BASE_DAMAGE
					currentHealth = math.max(0, currentHealth)
					setBaseHealthByModel(baseModel, teamName, currentHealth)
					setBaseOwner(baseModel, teamName, character.Name, true)
					if _G.MatchEndConditions then
						_G.MatchEndConditions.RecordBaseDamage(botTeam, BASE_DAMAGE)
					end
					if _G.MVPSystem then
						_G.MVPSystem.RecordBaseDamage(character.Name, BASE_DAMAGE)
					end
					print("[BaseDamage] Bot " .. character.Name .. " đã đánh " .. baseModel.Name .. "! HP: " .. math.floor(currentHealth))
					updateHealthBar(baseModel, teamName)
					flashTowerDamage(tower)
					if currentHealth <= 0 and not gameEnded then
						print("[BaseDamage] " .. baseModel.Name .. " đã bị phá hủy bởi bot " .. character.Name .. "!")
						setBaseHealthByModel(baseModel, teamName, 0)
						tower.Anchored = true
						tower.Color = Color3.new(1, 0, 0)
						for i = 1, 5 do
							tower.Transparency = i * 0.2
							task.wait(0.05)
						end
						hideBase(baseModel)
						checkBaseDestroyed(baseModel, teamName)
					end
				end
				task.wait(0.5)
				debounce[botId] = nil
			end
		end
	end)
	print("[BaseDamage] Đã thiết lập touch detector cho " .. baseModel.Name)
end

local function setupAllBases()
	print("[BaseDamage] setupAllBases: Searching for bases...")
	local foundBases = 0
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			if string.find(obj.Name, "Team1Base") then
				foundBases = foundBases + 1
				print("[BaseDamage] Found Team1Base: " .. obj.Name .. " at " .. obj:GetFullName())
				setupBaseClick(obj, "Team1")
				setupBaseTouch(obj, "Team1")
				updateOwnerLabel(obj, "Team1")
				local key = getBaseHealthKey(obj)
				if key and multiBaseHealth[key] == nil then
					multiBaseHealth[key] = BASE_MAX_HEALTH
				end
			elseif string.find(obj.Name, "Team2Base") then
				foundBases = foundBases + 1
				print("[BaseDamage] Found Team2Base: " .. obj.Name .. " at " .. obj:GetFullName())
				setupBaseClick(obj, "Team2")
				setupBaseTouch(obj, "Team2")
				updateOwnerLabel(obj, "Team2")
				local key = getBaseHealthKey(obj)
				if key and multiBaseHealth[key] == nil then
					multiBaseHealth[key] = BASE_MAX_HEALTH
				end
			end
		end
	end
	local baseCount = 0
	for _ in pairs(multiBaseHealth) do baseCount = baseCount + 1 end
	print("[BaseDamage] setupAllBases complete. Found " .. tostring(foundBases) .. " bases, initialized " .. tostring(baseCount) .. " health entries")
end

local function botAttackBase(baseModel, teamName, botName, botTeam, damage)
	if not baseModel or not baseModel:IsA("Model") then return false, "Invalid baseModel" end
	local isEnemy = (teamName == "Team1" and botTeam == "Team2") or (teamName == "Team2" and botTeam == "Team1")
	if not isEnemy then return false, "Bot cannot attack own team base" end
	local currentHealth = getBaseHealthByModel(baseModel, teamName)
	currentHealth = currentHealth - damage
	setBaseHealthByModel(baseModel, teamName, currentHealth)
	setBaseOwner(baseModel, teamName, botName, true)
	updateHealthBar(baseModel, teamName)
	local tower = baseModel:FindFirstChild("Tower")
	if tower then flashTowerDamage(tower) end
	if _G.MatchEndConditions then _G.MatchEndConditions.RecordBaseDamage(botTeam, damage) end
	if _G.MVPSystem then _G.MVPSystem.RecordBaseDamage(botName, damage) end
	print(string.format("[BaseDamage] Bot %s hit %s! HP: %d", botName, baseModel.Name, math.floor(currentHealth)))
	if currentHealth <= 0 and not gameEnded then
		print("[BaseDamage] " .. baseModel.Name .. " destroyed by bot " .. botName)
		setBaseHealthByModel(baseModel, teamName, 0)
		if tower then
			tower.Color = Color3.new(1, 0, 0)
			task.spawn(function()
				for i = 1, 5 do
					if tower and tower.Parent then tower.Transparency = i * 0.2 end
					task.wait(0.1)
				end
			end)
		end
		hideBase(baseModel)
		checkBaseDestroyed(baseModel, teamName)
	end
	return true, "OK"
end

_G.BotAttackBase = botAttackBase
_G.GetBaseOwnerForModel = function(model)
	if not model or not model:IsA("Model") then return nil end
	return baseOwner[model:GetFullName()] or baseOwner[model.Name]
end

local function collectTeamMainBases(teamName)
	local token = teamName .. "Base"
	local list = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, token, 1, true) then
			table.insert(list, d)
		end
	end
	table.sort(list, function(a, b) return a:GetFullName() < b:GetFullName() end)
	return list
end

local function labelForMatchPlayerData(pd)
	if not pd then return nil, false end
	if pd.isBot then return pd.name or "Bot", true end
	local plr = Players:GetPlayerByUserId(pd.playerId)
	if plr then return getDisplayNameForPlayer(plr), false end
	return pd.name or "Player", false
end

local function assignBaseOwnersFromMatch(matchData)
	if not matchData then return end
	local mode = matchData.mode or "1v1"
	local function wireTeam(teamName, roster)
		if not roster or #roster == 0 then return end
		local bases = collectTeamMainBases(teamName)
		for i, baseModel in ipairs(bases) do
			local pd = roster[math.min(i, #roster)]
			local nm, isBot = labelForMatchPlayerData(pd)
			if nm then
				setBaseOwner(baseModel, teamName, nm, isBot)
				updateHealthBar(baseModel, teamName)
			end
		end
	end
	wireTeam("Team1", matchData.team1)
	wireTeam("Team2", matchData.team2)
end
_G.AssignBaseOwnersFromMatch = assignBaseOwnersFromMatch

local function resetBasesState()
	gameEnded = false
	dangerTriggered.Team1 = false
	dangerTriggered.Team2 = false
	for k in pairs(multiBaseHealth) do multiBaseHealth[k] = nil end
	for k in pairs(baseOwner) do baseOwner[k] = nil end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local isTeamBase = string.find(obj.Name, "Team1Base", 1, true) or string.find(obj.Name, "Team2Base", 1, true)
			if isTeamBase then
				local tName = inferTeamFromBaseModel(obj)
				local key = getBaseHealthKey(obj)
				if key then multiBaseHealth[key] = BASE_MAX_HEALTH end
				showBase(obj, tName)
				updateHealthBar(obj, tName)
				updateOwnerLabel(obj, tName)
				setupBaseClick(obj, tName)
				setupBaseTouch(obj, tName)
				local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
				if remoteEvents then
					local baseHealthEvent = remoteEvents:FindFirstChild("BaseHealthUpdate")
					if baseHealthEvent then
						local basePosition = obj:GetPivot().Position
						for _, p in ipairs(Players:GetPlayers()) do
							baseHealthEvent:FireClient(p, obj.Name, tName, BASE_MAX_HEALTH, BASE_MAX_HEALTH, basePosition)
						end
					end
				end
			end
		end
	end
	print("[BaseDamage] All bases have been reset and restored!")
end
_G.ResetBases = resetBasesState

local function init()
	setupAllBases()
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then
			if string.find(descendant.Name, "Team1Base") then
				setupBaseClick(descendant, "Team1")
				setupBaseTouch(descendant, "Team1")
				updateOwnerLabel(descendant, "Team1")
			elseif string.find(descendant.Name, "Team2Base") then
				setupBaseClick(descendant, "Team2")
				setupBaseTouch(descendant, "Team2")
				updateOwnerLabel(descendant, "Team2")
			end
		end
	end)
	print("[BaseDamage] Base Damage System đã được tải!")
end

init()