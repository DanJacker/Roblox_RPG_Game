-- Light Beam Client - Handles light beam firing (input handled by SkillBarController)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents", 10)
if not remoteEvents then return end
local lightBeamRemote = remoteEvents:FindFirstChild("LightBeamRemote", 5)
if not lightBeamRemote then return end

-- Expose fire function for SkillBarController to call
_G.FireLightBeam = function()
    lightBeamRemote:FireServer("Launch")
end

