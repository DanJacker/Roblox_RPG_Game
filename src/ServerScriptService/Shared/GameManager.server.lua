-- Game Manager - Quản lý kill counter và win condition
-- 📍 LOCATION: ServerScriptService/Shared/
-- Dùng chung cho cả Lobby và Arena

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========== SHARED CONFIG ==========
local SharedConfig = require(ServerScriptService.Shared.SharedConfig)

-- Biến đếm kill
local team1Kills = 0
local team2Kills = 0

-- Export kill count to _G for MatchTimer
_G.Team1Kills = 0
_G.Team2Kills = 0

-- Trạng thái game
local gameEnded = false

-- Tạo RemoteEvent để sync kill count
local killEvent = Instance.new("RemoteEvent")
killEvent.Name = "KillEvent"
killEvent.Parent = ReplicatedStorage

-- Tạo RemoteEvent để thông báo win
local winEvent = Instance.new("RemoteEvent")
winEvent.Name = "WinEvent"
winEvent.Parent = ReplicatedStorage

-- KHÔNG chia team ở lobby - Team chỉ được gán khi vào trận
-- Player sẽ ở trạng thái Neutral khi ở lobby

-- Hàm tăng kill count
local function addKill(teamName)
    if gameEnded then return end
    
    if teamName == "Team1" then
        team1Kills = team1Kills + 1
        _G.Team1Kills = team1Kills
    elseif teamName == "Team2" then
        team2Kills = team2Kills + 1
        _G.Team2Kills = team2Kills
    end
    
    -- Gửi kill count cho tất cả players
    for _, player in pairs(Players:GetPlayers()) do
        killEvent:FireClient(player, team1Kills, team2Kills)
    end
    
end

-- Hàm kiểm tra win condition
local function checkWinCondition(destroyedTeam)
    if gameEnded then return end
    
    gameEnded = true
    
    local winner = ""
    if destroyedTeam == "Team1" then
        winner = "Team2"
    else
        winner = "Team1"
    end
    
    -- Thông báo winner cho tất cả players
    for _, player in pairs(Players:GetPlayers()) do
        winEvent:FireClient(player, winner, team1Kills, team2Kills)
    end
    
end

-- Lắng nghe khi player join
Players.PlayerAdded:Connect(function(player)
    -- Gán player vào Lobby team
    local lobbyTeam = Teams:FindFirstChild("Lobby")
    if lobbyTeam then
        player.Team = lobbyTeam
        player.Neutral = false
    end
    
    
    -- Lắng nghe khi character spawn
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        
        -- Khi player chết, tăng kill cho team đối thủ (chỉ khi đang trong trận)
        humanoid.Died:Connect(function()
            if player.Team and player.Team.Name ~= "Lobby" then
                local enemyTeam = player.Team.Name == "Team1" and "Team2" or "Team1"
                addKill(enemyTeam)
            end
        end)
    end)
end)

-- Lắng nghe khi base bị phá
local function setupBaseHealth(baseModel, teamName)
    local humanoid = baseModel:FindFirstChild("BaseHumanoid")
    if humanoid then
        humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and not gameEnded then
                checkWinCondition(teamName)
            end
        end)
    end
end

-- Setup base health monitoring
local function setupBases()
    -- Tìm base trong Maps folder
    local function findTeamBase(teamName)
        local mapsFolder = Workspace:FindFirstChild("Maps")
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
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and string.find(obj.Name, teamName .. "Base", 1, true) then
                return obj
            end
        end
        return nil
    end
    
    local team1Base = findTeamBase("Team1")
    local team2Base = findTeamBase("Team2")

    if team1Base then
        setupBaseHealth(team1Base, "Team1")
    end

    if team2Base then
        setupBaseHealth(team2Base, "Team2")
    end
end

-- Xử lý players đã có trong game
for _, player in pairs(Players:GetPlayers()) do
    -- Gán player vào Lobby team
    local lobbyTeam = Teams:FindFirstChild("Lobby")
    if lobbyTeam then
        player.Team = lobbyTeam
        player.Neutral = false
    end
end

-- Setup bases
setupBases()

