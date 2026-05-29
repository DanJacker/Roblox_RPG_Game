-- MVPSystem Loader - Tự động load MVPSystem khi game start
local ServerScriptService = game:GetService("ServerScriptService")

print("[MVPSystemLoader] Đang load MVPSystem...")

local arenaFolder = ServerScriptService:FindFirstChild("Arena")
if not arenaFolder then
	warn("[MVPSystemLoader] Không tìm thấy Arena folder!")
	return
end

local mvpSystemModule = arenaFolder:FindFirstChild("MVPSystem")
if not mvpSystemModule then
	warn("[MVPSystemLoader] Không tìm thấy MVPSystem module!")
	return
end

-- Require MVPSystem module
local success, result = pcall(function()
	return require(mvpSystemModule)
end)

if success then
	print("[MVPSystemLoader] ✓ MVPSystem loaded successfully!")
	print("[MVPSystemLoader] _G.MVPSystem: " .. tostring(_G.MVPSystem ~= nil))
else
	warn("[MVPSystemLoader] ✗ Failed to load MVPSystem: " .. tostring(result))
end

print("[MVPSystemLoader] Hoàn tất!")
