-- TeamTagManager Module - Quản lý team tags
local TeamTagManager = {}

local TEAM_COLORS = {
	["Team1"] = Color3.fromRGB(0, 170, 255),	-- Xanh dương
	["Team2"] = Color3.fromRGB(255, 85, 85),	-- Đỏ
	["Lobby"] = Color3.fromRGB(85, 255, 127)	-- Xanh lá
}

-- Hàm cập nhật name tag theo team
function TeamTagManager.UpdateNameTag(player, character)
	if not character then return end
	
	local teamTag = character:FindFirstChild("TeamNameTag")
	if not teamTag then return end
	
	local container = teamTag:FindFirstChild("Container")
	if not container then return end
	
	local nameLabel = container:FindFirstChild("PlayerName")
	local teamTagFrame = container:FindFirstChild("TeamTag")
	local teamLabel = teamTagFrame and teamTagFrame:FindFirstChild("TeamLabel")
	
	if not nameLabel or not teamTagFrame then return end
	
	-- Lấy thông tin team
	local team = player.Team
	local teamName = team and team.Name or "Lobby"
	local teamColor = TEAM_COLORS[teamName] or Color3.new(1, 1, 1)
	
	-- Cập nhật màu tên
	nameLabel.TextColor3 = teamColor
	
	-- Cập nhật team tag
	teamTagFrame.BackgroundColor3 = teamColor
	if teamLabel then
		teamLabel.Text = teamName == "Lobby" and "LOBBY" or (teamName == "Team1" and "BLUE" or "RED")
	end
	
	-- Cập nhật leaderstats Team
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local teamStat = leaderstats:FindFirstChild("Team")
		if teamStat then
			teamStat.Value = teamName
		end
	end
	
	print("[TeamTag] " .. player.Name .. " -> " .. teamName .. " (" .. tostring(teamColor) .. ")")
end

-- Hàm tạo name tag cho character
function TeamTagManager.CreateNameTag(player, character)
	-- Xóa tag cũ nếu có
	local oldTag = character:FindFirstChild("TeamNameTag")
	if oldTag then
		oldTag:Destroy()
	end
	
	-- Tạo BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "TeamNameTag"
	billboardGui.Size = UDim2.new(0, 200, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Adornee = character:WaitForChild("Head")
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = character
	
	-- Container chính
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = billboardGui
	
	-- Layout ngang
	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.FillDirection = Enum.FillDirection.Horizontal
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	uiListLayout.Padding = UDim.new(0, 5)
	uiListLayout.Parent = container
	
	-- Team Tag (hình chữ nhật nhỏ)
	local teamTag = Instance.new("Frame")
	teamTag.Name = "TeamTag"
	teamTag.Size = UDim2.new(0, 50, 0, 20)
	teamTag.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	teamTag.BackgroundTransparency = 0.3
	teamTag.Parent = container
	
	local teamTagCorner = Instance.new("UICorner")
	teamTagCorner.CornerRadius = UDim.new(0, 4)
	teamTagCorner.Parent = teamTag
	
	local teamTagLabel = Instance.new("TextLabel")
	teamTagLabel.Name = "TeamLabel"
	teamTagLabel.Size = UDim2.new(1, 0, 1, 0)
	teamTagLabel.BackgroundTransparency = 1
	teamTagLabel.Text = "TEAM"
	teamTagLabel.TextColor3 = Color3.new(1, 1, 1)
	teamTagLabel.TextSize = 12
	teamTagLabel.Font = Enum.Font.GothamBold
	teamTagLabel.Parent = teamTag
	
	-- Tên player
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(0, 0, 0, 25)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = container
	
	-- Cập nhật ngay lập tức
	TeamTagManager.UpdateNameTag(player, character)
	
	return billboardGui
end

function TeamTagManager.GetTeamColor(teamName)
	return TEAM_COLORS[teamName] or Color3.new(1, 1, 1)
end

return TeamTagManager