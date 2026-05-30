-- MapResetSystem - Quản lý reset map về trạng thái ban đầu
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")


-- ========== CẤU HÌNH ==========
local MAPS_FOLDER = "Maps"
local BASE_MAX_HEALTH = 1000
local TEAM_COLORS = {
	Team1 = Color3.fromRGB(0, 100, 255), -- Xanh dương
	Team2 = Color3.fromRGB(255, 50, 50)   -- Đỏ
}

-- ========== LƯU TRỮ TEMPLATE ==========
-- Lưu trữ bản gốc của các base khi game bắt đầu
local baseTemplates = {} -- [mapMode][baseName] = clonedModel
local mapStructure = {} -- [mapMode] = {baseNames, spawnNames}

-- ========== HÀM HELPER ==========
local function getMapFolder(mode)
	local mapsFolder = Workspace:FindFirstChild(MAPS_FOLDER)
	if not mapsFolder then return nil end
	
	local mapName = "Map" .. mode
	return mapsFolder:FindFirstChild(mapName)
end

-- Lưu trữ template của tất cả base trong map
local function saveMapTemplates(mode)
	local mapFolder = getMapFolder(mode)
	if not mapFolder then
		warn("[MapResetSystem] Không tìm thấy map folder cho mode: " .. mode)
		return false
	end
	
	baseTemplates[mode] = baseTemplates[mode] or {}
	mapStructure[mode] = mapStructure[mode] or {bases = {}, spawns = {}}
	
	-- Lưu trữ tất cả base trong map
	for _, child in ipairs(mapFolder:GetChildren()) do
		if child:IsA("Model") and (string.find(child.Name, "Team1Base") or string.find(child.Name, "Team2Base")) then
			-- Clone và lưu trữ template
			local template = child:Clone()
			template.Parent = nil -- Không đặt trong Workspace
			
			local baseKey = child.Name .. "_" .. #mapStructure[mode].bases
			baseTemplates[mode][baseKey] = template
			table.insert(mapStructure[mode].bases, {
				name = child.Name,
				key = baseKey,
				originalCFrame = child:GetPivot()
			})
			
		elseif child:IsA("Folder") and child.Name == "Spawns" then
			-- Lưu thông tin spawn points
			for _, spawn in ipairs(child:GetChildren()) do
				if spawn:IsA("SpawnLocation") then
					table.insert(mapStructure[mode].spawns, {
						name = spawn.Name,
						cframe = spawn.CFrame
					})
				end
			end
		end
	end
	
	return true
end

-- ========== RESET MAP ==========
local function resetMap(mode)
	
	local mapFolder = getMapFolder(mode)
	if not mapFolder then
		warn("[MapResetSystem] Không tìm thấy map folder cho mode: " .. mode)
		return false
	end
	
	-- Xóa tất cả base hiện tại (đã bị phá hoặc còn sót)
	local basesRemoved = 0
	for _, child in ipairs(mapFolder:GetChildren()) do
		if child:IsA("Model") and (string.find(child.Name, "Team1Base") or string.find(child.Name, "Team2Base")) then
			child:Destroy()
			basesRemoved = basesRemoved + 1
		end
	end
	
	-- Tạo lại base từ template
	local basesCreated = 0
	if baseTemplates[mode] then
		for baseKey, template in pairs(baseTemplates[mode]) do
			-- Tìm thông tin vị trí gốc
			local originalInfo = nil
			for _, info in ipairs(mapStructure[mode].bases) do
				if info.key == baseKey then
					originalInfo = info
					break
				end
			end
			
			-- Clone base mới
			local newBase = template:Clone()
			newBase.Parent = mapFolder
			
			-- Đặt vị trí gốc
			if originalInfo then
				newBase:PivotTo(originalInfo.originalCFrame)
			end
			
			-- Reset Tower color
			local tower = newBase:FindFirstChild("Tower")
			if tower then
				local teamName = string.find(newBase.Name, "Team1") and "Team1" or "Team2"
				tower.Color = TEAM_COLORS[teamName]
				tower.Transparency = 0
				
				-- Reset HealthBar
				local healthBar = tower:FindFirstChild("HealthBar")
				if healthBar then
					local frame = healthBar:FindFirstChild("Frame")
					if frame then
						local healthFill = frame:FindFirstChild("HealthFill")
						local healthText = frame:FindFirstChild("TextLabel")
						if healthFill then
							healthFill.Size = UDim2.new(1, 0, 1, 0)
							healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
						end
						if healthText then
							healthText.Text = tostring(BASE_MAX_HEALTH) .. "/" .. tostring(BASE_MAX_HEALTH)
						end
					end
				end
				
				-- Reset NameLabel
				local nameLabel = tower:FindFirstChild("NameLabel")
				if nameLabel then
					local textLabel = nameLabel:FindFirstChild("TextLabel")
					if textLabel then
						textLabel.Text = teamName
						textLabel.TextColor3 = TEAM_COLORS[teamName]
					end
				end
			end
			
			basesCreated = basesCreated + 1
		end
	end
	
	
	-- Reset spawn points (nếu cần)
	for _, spawnInfo in ipairs(mapStructure[mode].spawns) do
		local spawn = mapFolder:FindFirstChild("Spawns")
		if spawn then
			local spawnLoc = spawn:FindFirstChild(spawnInfo.name)
			if spawnLoc then
				spawnLoc.CFrame = spawnInfo.cframe
			end
		end
	end
	
	-- Gọi BaseDamageSystem để setup lại click/touch detectors
	if _G.ResetBases then
		_G.ResetBases()
	end
	
	return true
end

-- Reset tất cả maps
local function resetAllMaps()
	
	for mode, _ in pairs(baseTemplates) do
		resetMap(mode)
	end
	
	return true
end

-- ========== KHỞI TẠO ==========
local function init()
	-- Lưu trữ template cho tất cả modes
	saveMapTemplates("1v1")
	saveMapTemplates("2v2")
	saveMapTemplates("3v3")
	
end

-- Export functions
_G.MapResetSystem = {
	ResetMap = resetMap,
	ResetAllMaps = resetAllMaps,
	SaveTemplates = saveMapTemplates
}

init()
