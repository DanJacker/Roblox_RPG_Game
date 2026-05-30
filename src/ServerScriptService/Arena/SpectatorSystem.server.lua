-- SpectatorSystem - Hệ thống spectator khi team hết base
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Lưu trữ trạng thái spectator của mỗi player
local playerSpectatorStatus = {} -- [playerId] = {isSpectator = true/false, team = "Team1"}

-- Tạo RemoteEvent để thông báo spectator
local spectatorEvent = Instance.new("RemoteEvent")
spectatorEvent.Name = "SpectatorEvent"
spectatorEvent.Parent = ReplicatedStorage

-- Tạo GUI cho spectator
local function createSpectatorGUI(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	
	-- Xóa GUI cũ nếu có
	local oldGui = playerGui:FindFirstChild("SpectatorGUI")
	if oldGui then oldGui:Destroy() end
	
	-- Tạo GUI mới
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpectatorGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Frame chính
	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.new(0.4, 0, 0.15, 0)
	frame.Position = UDim2.new(0.3, 0, 0.85, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	
	-- Bo góc
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	
	-- Text "SPECTATOR"
	local spectatorLabel = Instance.new("TextLabel")
	spectatorLabel.Name = "SpectatorLabel"
	spectatorLabel.Size = UDim2.new(1, 0, 0.6, 0)
	spectatorLabel.Position = UDim2.new(0, 0, 0, 0)
	spectatorLabel.BackgroundTransparency = 1
	spectatorLabel.Text = "👁️ SPECTATOR MODE"
	spectatorLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	spectatorLabel.TextSize = 28
	spectatorLabel.Font = Enum.Font.GothamBold
	spectatorLabel.Parent = frame
	
	-- Text hướng dẫn
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, 0, 0.4, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.6, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Đang theo dõi đồng đội..."
	infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	infoLabel.TextSize = 16
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.Parent = frame
	
	return screenGui
end

-- Tạo BillboardGui "SPECTATOR" trên đầu player
local function createSpectatorTag(character)
	if not character then return end
	
	-- Xóa tag cũ nếu có
	local oldTag = character:FindFirstChild("SpectatorTag")
	if oldTag then oldTag:Destroy() end
	
	-- Tạo BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SpectatorTag"
	billboard.Size = UDim2.new(0, 150, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = character
	
	-- Text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "👁️ SPECTATOR"
	textLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	textLabel.TextSize = 18
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.Parent = billboard
	
	return billboard
end

-- Xóa spectator tag
local function removeSpectatorTag(character)
	if not character then return end
	
	local tag = character:FindFirstChild("SpectatorTag")
	if tag then tag:Destroy() end
end

-- Set player thành spectator
local function setPlayerSpectator(player, teamName)
	playerSpectatorStatus[player.UserId] = {
		isSpectator = true,
		team = teamName
	}
	
	-- Tạo GUI
	createSpectatorGUI(player)
	
	-- Thêm tag nếu có character
	if player.Character then
		createSpectatorTag(player.Character)
	end
	
	-- Thông báo cho client
	spectatorEvent:FireClient(player, {
		action = "becomeSpectator",
		team = teamName
	})
	
end

-- Kiểm tra nếu player là spectator
local function isPlayerSpectator(player)
	local status = playerSpectatorStatus[player.UserId]
	return status and status.isSpectator or false
end

-- Reset spectator status
local function resetSpectatorStatus(player)
	playerSpectatorStatus[player.UserId] = nil
	
	-- Xóa GUI
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local gui = playerGui:FindFirstChild("SpectatorGUI")
		if gui then gui:Destroy() end
	end
	
	-- Xóa tag trên character
	if player.Character then
		removeSpectatorTag(player.Character)
	end
	
	-- Thông báo cho client
	spectatorEvent:FireClient(player, {
		action = "exitSpectator"
	})
end

-- Reset tất cả spectator status
local function resetAllSpectators()
	for playerId, _ in pairs(playerSpectatorStatus) do
		local player = Players:GetPlayerByUserId(playerId)
		if player then
			resetSpectatorStatus(player)
		end
	end
	playerSpectatorStatus = {}
end

-- Lắng nghe character added
local function onCharacterAdded(player, character)
	-- Kiểm tra nếu player là spectator
	if isPlayerSpectator(player) then
		-- Thêm spectator tag
		createSpectatorTag(character)
	end
end

-- Lắng nghe player join
Players.PlayerAdded:Connect(function(player)
	-- Lắng nghe character spawn
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

-- Xử lý players đã có trong game
for _, player in pairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

-- API toàn cục
_G.SetPlayerSpectator = setPlayerSpectator
_G.IsPlayerSpectator = isPlayerSpectator
_G.ResetSpectatorStatus = resetSpectatorStatus
_G.ResetAllSpectators = resetAllSpectators

