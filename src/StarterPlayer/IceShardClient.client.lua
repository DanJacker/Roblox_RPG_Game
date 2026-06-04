-- IceShard Client - Handles ice shard firing (input handled by SkillBarController)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents", 10)
if not remoteEvents then return end
local iceShardRemote = remoteEvents:FindFirstChild("IceShardRemote", 5)
if not iceShardRemote then return end

-- Function to get hand position
local function getHandPosition()
    local character = player.Character
    if not character then return nil end
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if rightHand then
        return rightHand.Position + Vector3.new(0, 1, 0)
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position + Vector3.new(0, 1.5, 0)
    end
    return nil
end

-- Expose fire function for SkillBarController to call
_G.FireIceShard = function()
    local handPos = getHandPosition()
    if handPos then
        iceShardRemote:FireServer("Launch", handPos)
    end
end