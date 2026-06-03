-- DevTool - Server-side dev commands for testing
-- Chat /dev to unlock all skills, /dev cd to toggle cooldown bypass, /dev reset to reset skills

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local devModePlayers = {} -- [userId] = true

local function getRemoteEvents()
	return ReplicatedStorage:FindFirstChild("RemoteEvents")
end

local function sendDevMode(player, enabled)
	local remotes = getRemoteEvents()
	if not remotes then return end
	local devRemote = remotes:FindFirstChild("DevModeRemote")
	if devRemote then
		devRemote:FireClient(player, enabled)
	end
end

local function onChatted(player, message)
	local msg = string.lower(message)

	if msg == "/dev" then
		-- Unlock all skills
		if _G.DevUnlockAllSkills then
			local success = _G.DevUnlockAllSkills(player)
			if success then
				-- Also enable cooldown bypass
				devModePlayers[player.UserId] = true
				sendDevMode(player, true)

				-- Give max level and gold for testing
				local PlayerData = ReplicatedStorage.Modules:FindFirstChild("PlayerData")
				if PlayerData then
					local pd = require(PlayerData)
					local data = pd.Get(player)
					if data then
						pd.Set(player, "Money", 99999)
						pd.Set(player, "Level", 50)
					end
				end

				print("[DevTool] Unlocked all skills for", player.Name)
			end
		else
			warn("[DevTool] DevUnlockAllSkills function not found!")
		end

	elseif msg == "/dev cd" then
		-- Toggle cooldown bypass
		if devModePlayers[player.UserId] then
			devModePlayers[player.UserId] = nil
			sendDevMode(player, false)
			print("[DevTool] Cooldown bypass OFF for", player.Name)
		else
			devModePlayers[player.UserId] = true
			sendDevMode(player, true)
			print("[DevTool] Cooldown bypass ON for", player.Name)
		end

	elseif msg == "/dev reset" then
		-- Reset skills to default (only Fireball on Z)
		if _G.DevUnlockAllSkills then
			-- We need to reset playerSkillData - use a global reset function
			-- For now, just re-init by clearing and re-adding
			-- This is handled by rejoining, but we provide a command
		end
		devModePlayers[player.UserId] = nil
		sendDevMode(player, false)
		print("[DevTool] Dev mode reset for", player.Name, "(rejoin to fully reset skills)")

	elseif msg == "/dev gacha" then
		-- Give 10 more gacha rolls
		if _G.GiveGachaRoll then
			for i = 1, 10 do
				_G.GiveGachaRoll(player)
			end
			print("[DevTool] Gave 10 gacha rolls to", player.Name)
		end

	elseif msg == "/dev help" then
		print("[DevTool] Commands:")
		print("  /dev       - Unlock all skills + cooldown bypass + max gold/level")
		print("  /dev cd     - Toggle cooldown bypass")
		print("  /dev gacha  - Give 10 gacha rolls")
		print("  /dev reset  - Disable dev mode")
		print("  /dev help   - Show this help")
	end
end

local function onPlayerAdded(player)
	player.Chatted:Connect(function(msg)
		onChatted(player, msg)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[DevTool] Loaded - type /dev help in chat for commands")