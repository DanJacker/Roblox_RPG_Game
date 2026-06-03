-- EnsureRemoteEvents: Creates `RemoteEvents` folder and required RemoteEvents if missing
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local required = {
    "BaseDangerEffect",
    "BaseDestroyed",
    "BaseHealthUpdate",
    "CombatRemote",
    "FireballRemote",
    "JoinQueue",
    "KillEvent",
    "LeaveQueue",
    "LightBeamRemote",
    "MatchEnded",
    "MatchFound",
    "MatchStart",
    "MinimapEntityUpdate",
    "MinimapToggle",
    "MVPAnnouncement",
    "QueueStatus",
    "RankUpdate",
    "RequestRankUpdate",
    "RespawnEvent",
    "SpawnSelect",
    "VictoryAnnouncement",
    "GachaRollRemote",
    "GenericSkillRemote",
    "LevelUpRemote",
    "SkillSlotRemote",
    "SkillSyncRemote"
}

local function ensure()
    local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RemoteEvents"
        folder.Parent = ReplicatedStorage
        print("[EnsureRemoteEvents] Created RemoteEvents folder in ReplicatedStorage")
    end

    for _, name in ipairs(required) do
        if not folder:FindFirstChild(name) then
            local evt = Instance.new("RemoteEvent")
            evt.Name = name
            evt.Parent = folder
            print("[EnsureRemoteEvents] Created RemoteEvent:", name)
        end
    end
end

-- Run on server start
pcall(ensure)
print("[EnsureRemoteEvents] Done")
