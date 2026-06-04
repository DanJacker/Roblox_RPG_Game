-- ExpHudClient - LoL-style thin HP and EXP bars
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== CREATE GUI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExpHudGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ========== HP BAR (thin, above skill bar) ==========
local barWidth = 320

local hpBarBg = Instance.new("Frame")
hpBarBg.Name = "HpBarBg"
hpBarBg.Size = UDim2.new(0, barWidth, 0, 8)
hpBarBg.Position = UDim2.new(0.5, -barWidth/2, 1, -69)
hpBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
hpBarBg.BorderSizePixel = 0
hpBarBg.Parent = screenGui

local hpCorner = Instance.new("UICorner")
hpCorner.CornerRadius = UDim.new(0, 3)
hpCorner.Parent = hpBarBg

local hpBarFill = Instance.new("Frame")
hpBarFill.Name = "HpBarFill"
hpBarFill.Size = UDim2.new(1, 0, 1, 0)
hpBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 80)
hpBarFill.BorderSizePixel = 0
hpBarFill.Parent = hpBarBg

local hpFillCorner = Instance.new("UICorner")
hpFillCorner.CornerRadius = UDim.new(0, 3)
hpFillCorner.Parent = hpBarFill

-- HP text (tiny, centered above bar)
local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HpLabel"
hpLabel.Size = UDim2.new(1, 0, 0, 10)
hpLabel.Position = UDim2.new(0, 0, 0, -11)
hpLabel.BackgroundTransparency = 1
hpLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
hpLabel.TextStrokeTransparency = 0.3
hpLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
hpLabel.Font = Enum.Font.GothamBold
hpLabel.TextSize = 8
hpLabel.TextXAlignment = Enum.TextXAlignment.Center
hpLabel.Text = "150/150"
hpLabel.Parent = hpBarBg

-- ========== EXP BAR (very thin, at bottom of screen) ==========
local expBarWidth = 500

local expBarBg = Instance.new("Frame")
expBarBg.Name = "ExpBarBg"
expBarBg.Size = UDim2.new(0, expBarWidth, 0, 5)
expBarBg.Position = UDim2.new(0.5, -expBarWidth/2, 1, -5)
expBarBg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
expBarBg.BorderSizePixel = 0
expBarBg.Parent = screenGui

local expCorner = Instance.new("UICorner")
expCorner.CornerRadius = UDim.new(0, 2)
expCorner.Parent = expBarBg

local expBarFill = Instance.new("Frame")
expBarFill.Name = "ExpBarFill"
expBarFill.Size = UDim2.new(0, 0, 1, 0)
expBarFill.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
expBarFill.BorderSizePixel = 0
expBarFill.Parent = expBarBg

local expFillCorner = Instance.new("UICorner")
expFillCorner.CornerRadius = UDim.new(0, 2)
expFillCorner.Parent = expBarFill

-- EXP text (tiny, centered above bar)
local expLabel = Instance.new("TextLabel")
expLabel.Name = "ExpLabel"
expLabel.Size = UDim2.new(1, 0, 0, 10)
expLabel.Position = UDim2.new(0, 0, 0, -11)
expLabel.BackgroundTransparency = 1
expLabel.TextColor3 = Color3.fromRGB(160, 180, 255)
expLabel.TextStrokeTransparency = 0.3
expLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
expLabel.Font = Enum.Font.GothamBold
expLabel.TextSize = 8
expLabel.TextXAlignment = Enum.TextXAlignment.Center
expLabel.Text = "EXP 0/100  Lv.1"
expLabel.Parent = expBarBg

-- ========== UPDATE EVERY FRAME ==========
local function updateHud()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Update HP bar
	local hp = math.floor(humanoid.Health)
	local maxHp = math.floor(humanoid.MaxHealth)
	local hpPercent = math.clamp(maxHp > 0 and hp / maxHp or 0, 0, 1)

	hpBarFill.Size = UDim2.new(hpPercent, 0, 1, 0)
	hpLabel.Text = string.format("%d/%d", hp, maxHp)

	-- HP color based on health
	if hpPercent > 0.6 then
		hpBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 80)
	elseif hpPercent > 0.3 then
		hpBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	else
		hpBarFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end

	-- Update EXP bar from leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local expStat = leaderstats:FindFirstChild("Exp")
		local levelStat = leaderstats:FindFirstChild("Level")

		local exp = expStat and expStat.Value or 0
		local level = levelStat and levelStat.Value or 1
		local expNeeded = 50 * math.pow(2, level - 1)
		local expPercent = math.clamp(expNeeded > 0 and exp / expNeeded or 0, 0, 1)

		expBarFill.Size = UDim2.new(expPercent, 0, 1, 0)
		expLabel.Text = string.format("EXP %d/%d  Lv.%d", exp, expNeeded, level)
	else
		expBarFill.Size = UDim2.new(0, 0, 1, 0)
		expLabel.Text = "EXP 0/100  Lv.1"
	end
end

RunService.Heartbeat:Connect(updateHud)