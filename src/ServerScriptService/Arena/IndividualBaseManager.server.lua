-- Individual Base Manager - Quản lý base riêng cho mỗi player trong 2v2 và 3v3
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- Lưu trữ base của mỗi player
local playerBases = {} -- {playerName = {base = Model, team = "Team1"/"Team2", alive = true}}

-- Lưu trữ match data
local currentMatch = nil

-- Cấu hình
local BASE_SPACING = 30 -- Khoảng cách giữa các base
local BASE_HEALTH = 1000

-- Tạo base mới cho player (từ scratch, không clone)
local function createPlayerBase(playerName, teamName, position)
	-- Tạo model mới
	local newBase = Instance.new("Model")
	newBase.Name = playerName .. "_Base"
	
	-- Màu theo team
	local teamColor = teamName == "Team1" and Color3.fromRGB(0, 100, 255) or Color3.fromRGB(255, 50, 50)
	
	-- Tạo Tower (trụ chính)
	local tower = Instance.new("Part")
	tower.Name = "Tower"
	tower.Size = Vector3.new(4, 12, 4)
	tower.Position = position + Vector3.new(0, 6, 0)
	tower.Color = teamColor
	tower.Material = Enum.Material.Neon
	tower.Anchored = true
	tower.CanCollide = true
	tower.Parent = newBase
	
	-- Thêm attribute để track owner
	tower:SetAttribute("Owner", playerName)
	tower:SetAttribute("Team", teamName)
	
	-- Tạo Baseplate (nền)
	local baseplate = Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Size = Vector3.new(10, 1, 10)
	baseplate.Position = position + Vector3.new(0, 0.5, 0)
	baseplate.Color = teamColor
	baseplate.Material = Enum.Material.SmoothPlastic
	baseplate.Anchored = true
	baseplate.CanCollide = true
	baseplate.Parent = newBase
	
	-- Tạo NameLabel (hiển thị tên)
	local nameLabel = Instance.new("BillboardGui")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 200, 0, 50)
	nameLabel.StudsOffset = Vector3.new(0, 8, 0)
	nameLabel.Adornee = tower
	nameLabel.AlwaysOnTop = true
	nameLabel.Parent = tower
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = playerName
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextSize = 20
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Parent = nameLabel
	
	-- Tạo HealthBar (thanh máu)
	local healthBar = Instance.new("BillboardGui")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(0, 100, 0, 20)
	healthBar.StudsOffset = Vector3.new(0, 14, 0)
	healthBar.Adornee = tower
	healthBar.AlwaysOnTop = true
	healthBar.Parent = tower
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	frame.BorderSizePixel = 0
	frame.Parent = healthBar
	
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = frame
	
	local healthText = Instance.new("TextLabel")
	healthText.Name = "TextLabel"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = tostring(BASE_HEALTH) .. "/" .. tostring(BASE_HEALTH)
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextSize = 14
	healthText.Font = Enum.Font.GothamBold
	healthText.Parent = frame
	
	-- Thêm vào workspace
	newBase.Parent = workspace
	
	-- Lưu thông tin
	playerBases[playerName] = {
		base = newBase,
		team = teamName,
		alive = true,
		health = BASE_HEALTH
	}
	
	
	return newBase
end

-- Xử lý khi base bị đánh
local function onBaseAttacked(baseModel, attackerName, damage)
	local tower = baseModel:FindFirstChild("Tower")
	if not tower then return end
	
	local ownerName = tower:GetAttribute("Owner")
	if not ownerName then return end
	
	local baseData = playerBases[ownerName]
	if not baseData or not baseData.alive then return end
	
	-- Giảm health
	baseData.health = baseData.health - damage
	
	-- Cập nhật health bar
	local healthBar = tower:FindFirstChild("HealthBar")
	if healthBar then
		local frame = healthBar:FindFirstChild("Frame")
		if frame then
			local healthFill = frame:FindFirstChild("HealthFill")
			local healthText = frame:FindFirstChild("TextLabel")
			if healthFill and healthText then
				local healthPercent = baseData.health / BASE_HEALTH
				healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
				healthText.Text = tostring(math.floor(baseData.health)) .. "/" .. tostring(BASE_HEALTH)
				
				-- Đổi màu theo health
				if healthPercent > 0.5 then
					healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
				elseif healthPercent > 0.25 then
					healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
				else
					healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
				end
			end
		end
	end
	
	-- Kiểm tra nếu base bị phá hủy
	if baseData.health <= 0 then
		baseData.alive = false
		
		-- Thông báo player bị loại
		local player = Players:FindFirstChild(ownerName)
		if player then
			-- Gửi event cho client
			local baseDestroyedEvent = ReplicatedStorage:FindFirstChild("BaseDestroyed")
			if baseDestroyedEvent then
				baseDestroyedEvent:FireClient(player, ownerName)
			end
			
			-- Thêm vào chế độ quan sát (chỉ cho 2v2 và 3v3)
			local SpectatorSystem = _G.SpectatorSystem
			if SpectatorSystem and currentMatch and currentMatch.mode ~= "1v1" then
				SpectatorSystem.AddSpectator(player, baseData.team)
			end
			
		end
		
		-- Xóa base
		baseModel:Destroy()
		
		-- Kiểm tra điều kiện thắng
		local WinConditionChecker = _G.WinConditionChecker
		if WinConditionChecker then
			WinConditionChecker.CheckWinCondition()
		end
	end
end

-- Kiểm tra player có thể respawn không
local function canPlayerRespawn(playerName)
	local baseData = playerBases[playerName]
	if not baseData then
		-- Nếu không có base data, có thể là 1v1 mode
		return true
	end
	
	return baseData.alive
end

-- Tìm base của team trong Maps folder
local function findTeamBase(teamName)
	local mapsFolder = workspace:FindFirstChild("Maps")
	if mapsFolder then
		for _, mapFolder in pairs(mapsFolder:GetChildren()) do
			for _, obj in pairs(mapFolder:GetDescendants()) do
				if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
					return obj
				end
			end
		end
	end
	-- Fallback: tìm trong workspace root
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
			return obj
		end
	end
	return nil
end

-- Khởi tạo bases cho match
local function initializeBasesForMatch(matchData)
	currentMatch = matchData
	
	-- Xóa tất cả base cũ (bao gồm cả base gốc)
	for playerName, baseData in pairs(playerBases) do
		if baseData.base and baseData.base.Parent then
			baseData.base:Destroy()
		end
	end
	playerBases = {}
	
	-- Kiểm tra mode
	if matchData.mode == "1v1" then
		-- 1v1: Sử dụng 2 base có sẵn
		return
	end
	
	-- 2v2 hoặc 3v3: Gán player vào base có sẵn trong map
	
	-- Tìm map theo mode
	local mapsFolder = game.Workspace:FindFirstChild("Maps")
	local map = mapsFolder and mapsFolder:FindFirstChild("Map" .. matchData.mode)
	
	if not map then
		warn("[IndividualBaseManager] Không tìm thấy map: Map" .. matchData.mode)
		return
	end
	
	-- Lấy danh sách base theo team
	local team1Bases = {}
	local team2Bases = {}
	
	for _, obj in ipairs(map:GetChildren()) do
		if obj.Name == "Team1Base" then
			table.insert(team1Bases, obj)
		elseif obj.Name == "Team2Base" then
			table.insert(team2Bases, obj)
		end
	end
	
	
	-- Gán player vào base
	for i, playerData in ipairs(matchData.team1) do
		local base = team1Bases[i]
		if base then
			-- Cập nhật tên base với tên player
			base.Name = playerData.name .. "_Base"
			
			-- Tìm part chính để gắn label
			local mainPart = base:FindFirstChild("Tower") or base:FindFirstChild("Base") or base.PrimaryPart
			if not mainPart then
				for _, part in ipairs(base:GetDescendants()) do
					if part:IsA("BasePart") then
						mainPart = part
						break
					end
				end
			end
			
			if mainPart then
				mainPart:SetAttribute("Owner", playerData.name)
				mainPart:SetAttribute("Team", "Team1")
				
				-- Tạo hoặc cập nhật NameLabel
				local nameLabel = mainPart:FindFirstChild("NameLabel")
				if not nameLabel then
					nameLabel = Instance.new("BillboardGui")
					nameLabel.Name = "NameLabel"
					nameLabel.Size = UDim2.new(0, 200, 0, 50)
					nameLabel.StudsOffset = Vector3.new(0, 8, 0)
					nameLabel.Adornee = mainPart
					nameLabel.AlwaysOnTop = true
					nameLabel.Parent = mainPart
					
					local textLabel = Instance.new("TextLabel")
					textLabel.Size = UDim2.new(1, 0, 1, 0)
					textLabel.BackgroundTransparency = 1
					textLabel.Text = playerData.name
					textLabel.TextColor3 = Color3.new(1, 1, 1)
					textLabel.TextSize = 20
					textLabel.Font = Enum.Font.GothamBold
					textLabel.TextStrokeTransparency = 0.5
					textLabel.Parent = nameLabel
				else
					local textLabel = nameLabel:FindFirstChild("TextLabel")
					if textLabel then
						textLabel.Text = playerData.name
					end
				end
			end
			
			-- Lưu vào playerBases
			playerBases[playerData.name] = {
				base = base,
				team = "Team1",
				alive = true
			}
			
		end
	end
	
	for i, playerData in ipairs(matchData.team2) do
		local base = team2Bases[i]
		if base then
			-- Cập nhật tên base với tên player
			base.Name = playerData.name .. "_Base"
			
			-- Tìm part chính để gắn label
			local mainPart = base:FindFirstChild("Tower") or base:FindFirstChild("Base") or base.PrimaryPart
			if not mainPart then
				for _, part in ipairs(base:GetDescendants()) do
					if part:IsA("BasePart") then
						mainPart = part
						break
					end
				end
			end
			
			if mainPart then
				mainPart:SetAttribute("Owner", playerData.name)
				mainPart:SetAttribute("Team", "Team2")
				
				-- Tạo hoặc cập nhật NameLabel
				local nameLabel = mainPart:FindFirstChild("NameLabel")
				if not nameLabel then
					nameLabel = Instance.new("BillboardGui")
					nameLabel.Name = "NameLabel"
					nameLabel.Size = UDim2.new(0, 200, 0, 50)
					nameLabel.StudsOffset = Vector3.new(0, 8, 0)
					nameLabel.Adornee = mainPart
					nameLabel.AlwaysOnTop = true
					nameLabel.Parent = mainPart
					
					local textLabel = Instance.new("TextLabel")
					textLabel.Size = UDim2.new(1, 0, 1, 0)
					textLabel.BackgroundTransparency = 1
					textLabel.Text = playerData.name
					textLabel.TextColor3 = Color3.new(1, 1, 1)
					textLabel.TextSize = 20
					textLabel.Font = Enum.Font.GothamBold
					textLabel.TextStrokeTransparency = 0.5
					textLabel.Parent = nameLabel
				else
					local textLabel = nameLabel:FindFirstChild("TextLabel")
					if textLabel then
						textLabel.Text = playerData.name
					end
				end
			end
			
			-- Lưu vào playerBases
			playerBases[playerData.name] = {
				base = base,
				team = "Team2",
				alive = true
			}
			
		end
	end
	
end

-- Thiết lập touch detection cho tất cả bases
local function setupBaseTouchDetection()
	-- Lắng nghe khi có base mới được tạo
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") and descendant.Name:find("_Base$") then
			local tower = descendant:FindFirstChild("Tower")
			if tower then
				local debounce = {}
				
				tower.Touched:Connect(function(hit)
					local character = hit.Parent
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					
					if not humanoid then return end
					
					-- Lấy tên attacker
					local attackerName = character.Name
					
					-- Kiểm tra debounce
					if debounce[attackerName] then return end
					debounce[attackerName] = true
					
					-- Gây damage
					onBaseAttacked(descendant, attackerName, 25)
					
					task.wait(0.5)
					debounce[attackerName] = nil
				end)
				
			end
		end
	end)
end

-- Public API
local IndividualBaseManager = {}

function IndividualBaseManager.InitializeBasesForMatch(matchData)
	initializeBasesForMatch(matchData)
end

function IndividualBaseManager.CanPlayerRespawn(playerName)
	return canPlayerRespawn(playerName)
end

function IndividualBaseManager.GetPlayerBaseData(playerName)
	if playerName then
		return playerBases[playerName]
	else
		return playerBases
	end
end

function IndividualBaseManager.OnBaseAttacked(baseModel, attackerName, damage)
	onBaseAttacked(baseModel, attackerName, damage)
end

-- Export to _G
_G.IndividualBaseManager = IndividualBaseManager

-- Khởi tạo
setupBaseTouchDetection()


return IndividualBaseManager
