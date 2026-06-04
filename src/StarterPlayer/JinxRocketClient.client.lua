-- Jinx Rocket Client - Handles rocket firing (input handled by SkillBarController)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents", 10)
if not remoteEvents then return end
local rocketRemote = remoteEvents:FindFirstChild("JinxRocketRemote", 5)
if not rocketRemote then return end

-- Expose fire function for SkillBarController to call
_G.FireJinxRocket = function()
    rocketRemote:FireServer("Launch")
end

