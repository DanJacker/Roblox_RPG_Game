-- SkillBarController - Main client controller for skill bar, gacha, and inventory
-- Handles Z/X/C/V input, cooldown display, gacha rolls, and skill slot assignment

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local SkillConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SkillConfig"))

-- ========== STATE ==========
local skillInventory = {"Fireball"} -- Skills the player owns
local skillSlots = {Z = "Fireball", X = nil, C = nil, V = nil} -- Current slot assignments
local pendingGachaRolls = 0
local cooldownTimers = {} -- [skillId] = lastUseTime
local selectedInventorySkill = nil -- Currently selected skill in inventory UI
local isGachaOpen = false
local isInventoryOpen = false
local devMode = false -- Dev mode bypasses cooldowns

-- ========== GUI REFERENCES (built programmatically) ==========
local screenGui
local skillBarFrame
local slotFrames = {} -- ["Z"] = frame, etc.
local cooldownOverlays = {} -- ["Z"] = imageLabel
local cooldownSweeps = {} -- ["Z"] = UIGradient for circular sweep
local cooldownFlashFrames = {} -- ["Z"] = flash frame for ready effect
local keyLabels = {} -- ["Z"] = textLabel
local gachaOverlay
local gachaPanel
local inventoryOverlay
local inventoryPanel

-- ========== UTILITY FUNCTIONS ==========
local function getSkillInfo(skillId)
	return SkillConfig.Skills[skillId]
end

local function isOnCooldown(skillId)
	if devMode then return false end
	local info = getSkillInfo(skillId)
	if not info then return false end
	local lastUse = cooldownTimers[skillId] or 0
	return (tick() - lastUse) < info.cooldown
end

local function getCooldownRemaining(skillId)
	local info = getSkillInfo(skillId)
	if not info then return 0 end
	local lastUse = cooldownTimers[skillId] or 0
	return math.max(0, info.cooldown - (tick() - lastUse))
end

local recentlyReady = {} -- [key] = true when cooldown just finished (for flash)
local updateSkillBar

local function startCooldown(skillId)
	cooldownTimers[skillId] = tick()
end

-- ========== FIRE SKILL ==========
local function fireSkill(skillId)
	if not skillId then return end
	if isOnCooldown(skillId) then return end

	local info = getSkillInfo(skillId)
	if not info then return end

	-- Check player has a character
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Fire based on skill
	if skillId == "Fireball" then
		if _G.FireFireball then
			_G.FireFireball()
		end
	elseif skillId == "IceShard" then
		if _G.FireIceShard then
			_G.FireIceShard()
		end
	elseif skillId == "LightBeam" then
		if _G.FireLightBeam then
			_G.FireLightBeam()
		end
	elseif skillId == "JinxRocket" then
		if _G.FireJinxRocket then
			_G.FireJinxRocket()
		end
	else
		-- Generic skill - fire to server
		local genericRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if genericRemote then
			local remote = genericRemote:FindFirstChild("GenericSkillRemote")
			if remote then
				local handPos = hrp.Position + hrp.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
				remote:FireServer({skillId = skillId, position = handPos})
			end
		end
	end

	startCooldown(skillId)
end

-- ========== BUILD SKILL BAR GUI ==========
local function buildSkillBar()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkillBarGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Main bar frame (compact, LoL style)
	skillBarFrame = Instance.new("Frame")
	skillBarFrame.Name = "SkillBar"
	skillBarFrame.Size = UDim2.new(0, 320, 0, 52)
	skillBarFrame.Position = UDim2.new(0.5, -160, 1, -59)
	skillBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	skillBarFrame.BackgroundTransparency = 0.2
	skillBarFrame.BorderSizePixel = 0
	skillBarFrame.Parent = screenGui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = skillBarFrame

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(60, 60, 90)
	barStroke.Thickness = 1
	barStroke.Parent = skillBarFrame

	-- Level badge (LoL style, left side)
	local levelBadge = Instance.new("Frame")
	levelBadge.Name = "LevelBadge"
	levelBadge.Size = UDim2.new(0, 36, 0, 36)
	levelBadge.Position = UDim2.new(0, 6, 0.5, -18)
	levelBadge.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	levelBadge.BorderSizePixel = 0
	levelBadge.Parent = skillBarFrame

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 18)
	badgeCorner.Parent = levelBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(80, 130, 255)
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = levelBadge

	local levelText = Instance.new("TextLabel")
	levelText.Name = "LevelText"
	levelText.Size = UDim2.new(1, 0, 1, 0)
	levelText.BackgroundTransparency = 1
	levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelText.Text = "1"
	levelText.Font = Enum.Font.GothamBold
	levelText.TextSize = 16
	levelText.Parent = levelBadge

	-- Inventory button (right side, compact)
	local invBtn = Instance.new("TextButton")
	invBtn.Name = "InventoryBtn"
	invBtn.Size = UDim2.new(0, 26, 0, 26)
	invBtn.Position = UDim2.new(1, -32, 0.5, -13)
	invBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	invBtn.TextColor3 = Color3.fromRGB(160, 160, 200)
	invBtn.Text = "B"
	invBtn.Font = Enum.Font.GothamBold
	invBtn.TextSize = 11
	invBtn.BorderSizePixel = 0
	invBtn.Parent = skillBarFrame

	local invBtnCorner = Instance.new("UICorner")
	invBtnCorner.CornerRadius = UDim.new(0, 6)
	invBtnCorner.Parent = invBtn

	invBtn.MouseButton1Click:Connect(function()
		if isInventoryOpen then
			closeInventory()
		else
			openInventory()
		end
	end)

	-- Build 4 skill slots (compact)
	local slotSize = 44
	local slotGap = 4
	local totalWidth = slotSize * 4 + slotGap * 3
	local levelBadgeSpace = 48
	local invBtnSpace = 38
	local availableWidth = 320 - levelBadgeSpace - invBtnSpace
	local startX = levelBadgeSpace + (availableWidth - totalWidth) / 2

	for i, key in ipairs(SkillConfig.SlotKeys) do
		local x = startX + (i - 1) * (slotSize + slotGap)

		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. key
		slotFrame.Size = UDim2.new(0, slotSize, 0, slotSize)
		slotFrame.Position = UDim2.new(0, x, 0.5, -slotSize / 2)
		slotFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = skillBarFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slotFrame

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Name = "SlotStroke"
		slotStroke.Color = Color3.fromRGB(60, 60, 90)
		slotStroke.Thickness = 1
		slotStroke.Parent = slotFrame

		-- Skill icon (colored square placeholder)
		local icon = Instance.new("Frame")
		icon.Name = "SkillIcon"
		icon.Size = UDim2.new(1, -6, 1, -6)
		icon.Position = UDim2.new(0, 3, 0, 3)
		icon.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		icon.BorderSizePixel = 0
		icon.Visible = false
		icon.Parent = slotFrame

		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, 4)
		iconCorner.Parent = icon

		-- Skill name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "SkillName"
		nameLabel.Size = UDim2.new(1, -2, 0, 10)
		nameLabel.Position = UDim2.new(0, 1, 1, -11)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(200, 200, 240)
		nameLabel.Text = ""
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 7
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = slotFrame

		-- Key label (Z/X/C/V)
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(0, 14, 0, 10)
		keyLabel.Position = UDim2.new(0, 1, 0, 1)
		keyLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		keyLabel.BackgroundTransparency = 0.4
		keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		keyLabel.Text = key
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 8
		keyLabel.BorderSizePixel = 0
		keyLabel.Parent = slotFrame

		local keyCorner = Instance.new("UICorner")
		keyCorner.CornerRadius = UDim.new(0, 2)
		keyCorner.Parent = keyLabel

		-- Cooldown overlay (dark background)
		local cooldownOverlay = Instance.new("Frame")
		cooldownOverlay.Name = "CooldownOverlay"
		cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
		cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		cooldownOverlay.BackgroundTransparency = 0.55
		cooldownOverlay.BorderSizePixel = 0
		cooldownOverlay.Visible = false
		cooldownOverlay.ZIndex = 5
		cooldownOverlay.Parent = slotFrame

		local cdCorner = Instance.new("UICorner")
		cdCorner.CornerRadius = UDim.new(0, 6)
		cdCorner.Parent = cooldownOverlay

		-- Circular cooldown sweep using UIGradient on an ImageLabel
		local sweepImage = Instance.new("ImageLabel")
		sweepImage.Name = "CooldownSweep"
		sweepImage.Size = UDim2.new(1, 0, 1, 0)
		sweepImage.BackgroundTransparency = 1
		sweepImage.Image = "rbxassetid://2619888307"
		sweepImage.ImageColor3 = Color3.fromRGB(0, 0, 0)
		sweepImage.ImageTransparency = 0.3
		sweepImage.Visible = false
		sweepImage.ZIndex = 6
		sweepImage.Parent = slotFrame

		local sweepCorner = Instance.new("UICorner")
		sweepCorner.CornerRadius = UDim.new(0, 6)
		sweepCorner.Parent = sweepImage

		local sweepGradient = Instance.new("UIGradient")
		sweepGradient.Name = "SweepGradient"
		sweepGradient.Rotation = 0
		sweepGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(0.4999, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		})
		sweepGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.4999, 0.3),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sweepGradient.Parent = sweepImage

		local cdText = Instance.new("TextLabel")
		cdText.Name = "CooldownText"
		cdText.Size = UDim2.new(1, 0, 1, 0)
		cdText.BackgroundTransparency = 1
		cdText.TextColor3 = Color3.fromRGB(255, 255, 255)
		cdText.Text = ""
		cdText.Font = Enum.Font.GothamBold
		cdText.TextSize = 14
		cdText.ZIndex = 7
		cdText.Parent = slotFrame

		-- Ready flash overlay (brief white flash when cooldown ends)
		local flashFrame = Instance.new("Frame")
		flashFrame.Name = "ReadyFlash"
		flashFrame.Size = UDim2.new(1, 0, 1, 0)
		flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flashFrame.BackgroundTransparency = 1
		flashFrame.BorderSizePixel = 0
		flashFrame.ZIndex = 8
		flashFrame.Parent = slotFrame

		local flashCorner = Instance.new("UICorner")
		flashCorner.CornerRadius = UDim.new(0, 6)
		flashCorner.Parent = flashFrame

		-- Empty slot indicator
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyLabel"
		emptyLabel.Size = UDim2.new(1, 0, 1, 0)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(80, 80, 110)
		emptyLabel.Text = "+"
		emptyLabel.Font = Enum.Font.GothamBold
		emptyLabel.TextSize = 18
		emptyLabel.Visible = true
		emptyLabel.Parent = slotFrame

		-- Click to open inventory
		local clickBtn = Instance.new("TextButton")
		clickBtn.Name = "ClickArea"
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.Parent = slotFrame

		clickBtn.MouseButton1Click:Connect(function()
			if not isInventoryOpen then
				openInventory()
			end
		end)

		-- Right-click to remove skill from slot
		clickBtn.MouseButton2Click:Connect(function()
			if skillSlots[key] then
				skillSlots[key] = nil
				local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
				if remotes then
					local slotRemote = remotes:FindFirstChild("SkillSlotRemote")
					if slotRemote then
						slotRemote:FireServer({action = "Assign", slot = key, skillId = nil})
					end
				end
				updateSkillBar()
			end
		end)

		slotFrames[key] = slotFrame
		cooldownOverlays[key] = cooldownOverlay
		cooldownSweeps[key] = sweepImage
		cooldownFlashFrames[key] = flashFrame
		keyLabels[key] = keyLabel
		recentlyReady[key] = false
	end
end

-- ========== UPDATE SKILL BAR DISPLAY ==========
local function updateSkillBar()
	for _, key in ipairs(SkillConfig.SlotKeys) do
		local slotFrame = slotFrames[key]
		if not slotFrame then continue end

		local skillId = skillSlots[key]
		local skillIcon = slotFrame:FindFirstChild("SkillIcon")
		local skillName = slotFrame:FindFirstChild("SkillName")
		local emptyLabel = slotFrame:FindFirstChild("EmptyLabel")
		local slotStroke = slotFrame:FindFirstChild("SlotStroke")

		if skillId then
			local info = getSkillInfo(skillId)
			if info then
				skillIcon.Visible = true
				skillIcon.BackgroundColor3 = info.color
				skillName.Text = info.name
				emptyLabel.Visible = false
				if slotStroke then
					slotStroke.Color = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(80, 80, 120)
				end
			end
		else
			skillIcon.Visible = false
			skillName.Text = ""
			emptyLabel.Visible = true
			if slotStroke then
				slotStroke.Color = Color3.fromRGB(60, 60, 90)
			end
		end
	end
end

-- ========== COOLDOWN UPDATE LOOP ==========
local function updateCooldowns()
	for _, key in ipairs(SkillConfig.SlotKeys) do
		local skillId = skillSlots[key]
		local overlay = cooldownOverlays[key]
		local sweep = cooldownSweeps[key]
		local flashFrame = cooldownFlashFrames[key]
		local keyLabel = keyLabels[key]
		local slotFrame = slotFrames[key]
		if not overlay then continue end

		if skillId and isOnCooldown(skillId) then
			recentlyReady[key] = true -- Mark that we were on cooldown (for flash when done)

			overlay.Visible = true
			if sweep then sweep.Visible = true end

			local remaining = getCooldownRemaining(skillId)
			local info = getSkillInfo(skillId)
			local cdText = slotFrame and slotFrame:FindFirstChild("CooldownText")
			if cdText then
				cdText.Visible = true
				if remaining >= 10 then
					cdText.Text = string.format("%.0f", remaining)
				else
					cdText.Text = string.format("%.1f", remaining)
				end
			end

			-- Circular sweep: rotation goes from 0 (full cooldown) to 360 (ready)
			if info and sweep then
				local progress = remaining / info.cooldown -- 1 = just started, 0 = ready
				local rotation = (1 - progress) * 360
				local gradient = sweep:FindFirstChild("SweepGradient")
				if gradient then
					gradient.Rotation = rotation
				end
			end

			-- Dim key label when on cooldown
			if keyLabel then
				keyLabel.TextColor3 = Color3.fromRGB(150, 80, 80)
			end

			-- Dim slot border when on cooldown
			if slotFrame then
				local stroke = slotFrame:FindFirstChild("SlotStroke")
				if stroke then
					stroke.Color = Color3.fromRGB(50, 50, 70)
				end
			end
		else
			overlay.Visible = false
			if sweep then sweep.Visible = false end

			local cdText = slotFrame and slotFrame:FindFirstChild("CooldownText")
			if cdText then
				cdText.Visible = false
			end

			-- Restore key label color
			if keyLabel then
				keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end

			-- Restore slot border color
			if slotFrame and skillId then
				local info = getSkillInfo(skillId)
				local stroke = slotFrame:FindFirstChild("SlotStroke")
				if stroke and info then
					stroke.Color = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(80, 80, 120)
				end
			end

			-- Flash effect when cooldown just finished
			if recentlyReady[key] and flashFrame then
				recentlyReady[key] = false
				task.spawn(function()
					if not flashFrame or not flashFrame.Parent then return end
					-- Flash in
					TweenService:Create(flashFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 0.3,
					}):Play()
					task.wait(0.15)
					-- Flash out
					if flashFrame and flashFrame.Parent then
						TweenService:Create(flashFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							BackgroundTransparency = 1,
						}):Play()
					end
				end)
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	updateCooldowns()

	-- Update level badge
	if skillBarFrame then
		local badge = skillBarFrame:FindFirstChild("LevelBadge")
		if badge then
			local lt = badge:FindFirstChild("LevelText")
			if lt then
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local levelStat = leaderstats:FindFirstChild("Level")
					if levelStat then
						lt.Text = tostring(levelStat.Value)
					end
				end
			end
		end
	end
end)

-- ========== BUILD GACHA GUI ==========
local function buildGachaGui()
	-- Full screen overlay
	gachaOverlay = Instance.new("Frame")
	gachaOverlay.Name = "GachaOverlay"
	gachaOverlay.Size = UDim2.new(1, 0, 1, 0)
	gachaOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	gachaOverlay.BackgroundTransparency = 0.5
	gachaOverlay.Visible = false
	gachaOverlay.ZIndex = 50
	gachaOverlay.Parent = screenGui

	-- Main panel
	gachaPanel = Instance.new("Frame")
	gachaPanel.Name = "GachaPanel"
	gachaPanel.Size = UDim2.new(0, 400, 0, 480)
	gachaPanel.Position = UDim2.new(0.5, -200, 0.5, -240)
	gachaPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	gachaPanel.BorderSizePixel = 0
	gachaPanel.ZIndex = 51
	gachaPanel.Parent = gachaOverlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = gachaPanel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(255, 170, 0)
	panelStroke.Thickness = 2
	panelStroke.Parent = gachaPanel

	-- Level up title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 15)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 50)
	title.Text = "LEVEL UP!"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 36
	title.ZIndex = 52
	title.Parent = gachaPanel

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 30)
	subtitle.Position = UDim2.new(0, 0, 0, 60)
	subtitle.BackgroundTransparency = 1
	subtitle.TextColor3 = Color3.fromRGB(200, 200, 255)
	subtitle.Text = "Ban duoc 1 luot Gacha Skill!"
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 16
	subtitle.ZIndex = 52
	subtitle.Parent = gachaPanel

	-- Pending rolls display
	local rollsLabel = Instance.new("TextLabel")
	rollsLabel.Name = "RollsLabel"
	rollsLabel.Size = UDim2.new(1, 0, 0, 25)
	rollsLabel.Position = UDim2.new(0, 0, 0, 90)
	rollsLabel.BackgroundTransparency = 1
	rollsLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	rollsLabel.Text = "Luot gacha: 0"
	rollsLabel.Font = Enum.Font.GothamBold
	rollsLabel.TextSize = 14
	rollsLabel.ZIndex = 52
	rollsLabel.Parent = gachaPanel

	-- Card reveal area
	local cardArea = Instance.new("Frame")
	cardArea.Name = "CardArea"
	cardArea.Size = UDim2.new(0, 200, 0, 200)
	cardArea.Position = UDim2.new(0.5, -100, 0, 130)
	cardArea.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	cardArea.BorderSizePixel = 0
	cardArea.ZIndex = 52
	cardArea.Parent = gachaPanel

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = cardArea

	-- Card back (shown before reveal)
	local cardBack = Instance.new("Frame")
	cardBack.Name = "CardBack"
	cardBack.Size = UDim2.new(1, 0, 1, 0)
	cardBack.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
	cardBack.BorderSizePixel = 0
	cardBack.ZIndex = 53
	cardBack.Parent = cardArea

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 14)
	backCorner.Parent = cardBack

	local backStroke = Instance.new("UIStroke")
	backStroke.Color = Color3.fromRGB(150, 100, 255)
	backStroke.Thickness = 3
	backStroke.Parent = cardBack

	local backText = Instance.new("TextLabel")
	backText.Size = UDim2.new(1, 0, 1, 0)
	backText.BackgroundTransparency = 1
	backText.TextColor3 = Color3.fromRGB(200, 180, 255)
	backText.Text = "?"
	backText.Font = Enum.Font.GothamBold
	backText.TextSize = 60
	backText.ZIndex = 54
	backText.Parent = cardBack

	-- Card front (shown after reveal)
	local cardFront = Instance.new("Frame")
	cardFront.Name = "CardFront"
	cardFront.Size = UDim2.new(1, 0, 1, 0)
	cardFront.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	cardFront.BorderSizePixel = 0
	cardFront.Visible = false
	cardFront.ZIndex = 53
	cardFront.Parent = cardArea

	local frontCorner = Instance.new("UICorner")
	frontCorner.CornerRadius = UDim.new(0, 14)
	frontCorner.Parent = cardFront

	-- Skill icon on card
	local cardSkillIcon = Instance.new("Frame")
	cardSkillIcon.Name = "SkillIcon"
	cardSkillIcon.Size = UDim2.new(0, 80, 0, 80)
	cardSkillIcon.Position = UDim2.new(0.5, -40, 0, 20)
	cardSkillIcon.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
	cardSkillIcon.BorderSizePixel = 0
	cardSkillIcon.ZIndex = 54
	cardSkillIcon.Parent = cardFront

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 12)
	iconCorner.Parent = cardSkillIcon

	-- Skill name on card
	local cardSkillName = Instance.new("TextLabel")
	cardSkillName.Name = "SkillName"
	cardSkillName.Size = UDim2.new(1, -10, 0, 24)
	cardSkillName.Position = UDim2.new(0, 5, 0, 110)
	cardSkillName.BackgroundTransparency = 1
	cardSkillName.TextColor3 = Color3.fromRGB(255, 255, 255)
	cardSkillName.Text = "Skill Name"
	cardSkillName.Font = Enum.Font.GothamBold
	cardSkillName.TextSize = 16
	cardSkillName.ZIndex = 54
	cardSkillName.Parent = cardFront

	-- Rarity label on card
	local cardRarity = Instance.new("TextLabel")
	cardRarity.Name = "RarityLabel"
	cardRarity.Size = UDim2.new(1, -10, 0, 20)
	cardRarity.Position = UDim2.new(0, 5, 0, 134)
	cardRarity.BackgroundTransparency = 1
	cardRarity.TextColor3 = Color3.fromRGB(255, 170, 0)
	cardRarity.Text = "Legendary"
	cardRarity.Font = Enum.Font.GothamBold
	cardRarity.TextSize = 13
	cardRarity.ZIndex = 54
	cardRarity.Parent = cardFront

	-- Description on card
	local cardDesc = Instance.new("TextLabel")
	cardDesc.Name = "Description"
	cardDesc.Size = UDim2.new(1, -16, 0, 40)
	cardDesc.Position = UDim2.new(0, 8, 0, 158)
	cardDesc.BackgroundTransparency = 1
	cardDesc.TextColor3 = Color3.fromRGB(180, 180, 200)
	cardDesc.Text = "Description"
	cardDesc.Font = Enum.Font.Gotham
	cardDesc.TextSize = 12
	cardDesc.TextWrapped = true
	cardDesc.ZIndex = 54
	cardDesc.Parent = cardFront

	-- Duplicate label
	local dupLabel = Instance.new("TextLabel")
	dupLabel.Name = "DuplicateLabel"
	dupLabel.Size = UDim2.new(1, 0, 0, 20)
	dupLabel.Position = UDim2.new(0, 0, 0, 200)
	dupLabel.BackgroundTransparency = 1
	dupLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	dupLabel.Text = ""
	dupLabel.Font = Enum.Font.GothamBold
	dupLabel.TextSize = 12
	dupLabel.Visible = false
	dupLabel.ZIndex = 54
	dupLabel.Parent = cardArea

	-- ROLL button
	local rollBtn = Instance.new("TextButton")
	rollBtn.Name = "RollButton"
	rollBtn.Size = UDim2.new(0, 180, 0, 50)
	rollBtn.Position = UDim2.new(0.5, -90, 0, 350)
	rollBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	rollBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	rollBtn.Text = "ROLL!"
	rollBtn.Font = Enum.Font.GothamBold
	rollBtn.TextSize = 24
	rollBtn.BorderSizePixel = 0
	rollBtn.ZIndex = 52
	rollBtn.AutoButtonColor = true
	rollBtn.Parent = gachaPanel

	local rollCorner = Instance.new("UICorner")
	rollCorner.CornerRadius = UDim.new(0, 12)
	rollCorner.Parent = rollBtn

	-- Equip button (shown after reveal)
	local equipBtn = Instance.new("TextButton")
	equipBtn.Name = "EquipButton"
	equipBtn.Size = UDim2.new(0, 140, 0, 40)
	equipBtn.Position = UDim2.new(0.5, -140, 0, 350)
	equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
	equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipBtn.Text = "Trang Bi"
	equipBtn.Font = Enum.Font.GothamBold
	equipBtn.TextSize = 16
	equipBtn.BorderSizePixel = 0
	equipBtn.Visible = false
	equipBtn.ZIndex = 52
	equipBtn.Parent = gachaPanel

	local equipCorner = Instance.new("UICorner")
	equipCorner.CornerRadius = UDim.new(0, 10)
	equipCorner.Parent = equipBtn

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 140, 0, 40)
	closeBtn.Position = UDim2.new(0.5, 0, 0, 350)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
	closeBtn.Text = "Dong"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Visible = false
	closeBtn.ZIndex = 52
	closeBtn.Parent = gachaPanel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = closeBtn

	-- Store references (use FindFirstChild instead of dot notation on Instances)
	-- rollBtn, equipBtn, closeBtn are accessed via gachaPanel:FindFirstChild("RollButton") etc.

	-- Roll button click
	rollBtn.MouseButton1Click:Connect(function()
		if pendingGachaRolls <= 0 then return end

		rollBtn.Visible = false

		-- Fire gacha roll to server
		local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remotes then
			local gachaRemote = remotes:FindFirstChild("GachaRollRemote")
			if gachaRemote then
				gachaRemote:FireServer("Roll")
			end
		end

		-- Show card back with shake animation
		local cardBackRef = cardArea:FindFirstChild("CardBack")
		local cardFrontRef = cardArea:FindFirstChild("CardFront")
		if cardBackRef then
			cardBackRef.Visible = true
			cardFrontRef.Visible = false

			-- Shake animation
			task.spawn(function()
				for i = 1, 8 do
					local offset = (i % 2 == 0 and 1 or -1) * 4
					cardBackRef.Position = UDim2.new(0, offset, 0, 0)
					task.wait(0.06)
				end
				cardBackRef.Position = UDim2.new(0, 0, 0, 0)
			end)
		end
	end)

	-- Equip button click
	equipBtn.MouseButton1Click:Connect(function()
		closeGacha()
		openInventory()
	end)

	-- Close button click
	closeBtn.MouseButton1Click:Connect(function()
		closeGacha()
	end)
end

-- ========== OPEN / CLOSE GACHA ==========
function openGacha()
	if not gachaOverlay then return end
	isGachaOpen = true
	gachaOverlay.Visible = true

	-- Reset card state
	local cardArea = gachaPanel:FindFirstChild("CardArea")
	if cardArea then
		local cardBack = cardArea:FindFirstChild("CardBack")
		local cardFront = cardArea:FindFirstChild("CardFront")
		if cardBack then cardBack.Visible = true end
		if cardFront then cardFront.Visible = false end
	end

	-- Update rolls label
	local rollsLabel = gachaPanel:FindFirstChild("RollsLabel")
	if rollsLabel then
		rollsLabel.Text = "Luot gacha: " .. pendingGachaRolls
	end

	-- Show/hide buttons
	local rollBtn = gachaPanel:FindFirstChild("RollButton")
	local equipBtn = gachaPanel:FindFirstChild("EquipButton")
	local closeBtn = gachaPanel:FindFirstChild("CloseButton")

	if rollBtn then
		rollBtn.Visible = pendingGachaRolls > 0
		if pendingGachaRolls <= 0 then
			rollBtn.Text = "Het luot!"
		end
	end
	if equipBtn then equipBtn.Visible = false end
	if closeBtn then closeBtn.Visible = pendingGachaRolls <= 0 end
end

function closeGacha()
	if not gachaOverlay then return end
	isGachaOpen = false
	gachaOverlay.Visible = false
end

-- ========== HANDLE GACHA RESULT FROM SERVER ==========
local function onGachaResult(data)
	if not data then return end

	-- Handle failed roll (no pending rolls, etc.)
	if data.failed then
		-- Reset card back and show close button
		local cardArea = gachaPanel and gachaPanel:FindFirstChild("CardArea")
		if cardArea then
			local cardBack = cardArea:FindFirstChild("CardBack")
			local cardFront = cardArea:FindFirstChild("CardFront")
			if cardBack then cardBack.Visible = true end
			if cardFront then cardFront.Visible = false end
		end

		local rollBtn = gachaPanel and gachaPanel:FindFirstChild("RollButton")
		local closeBtn = gachaPanel and gachaPanel:FindFirstChild("CloseButton")
		if rollBtn then
			rollBtn.Visible = pendingGachaRolls > 0
			rollBtn.Text = pendingGachaRolls > 0 and ("ROLL! (" .. pendingGachaRolls .. ")") or "Het luot!"
		end
		if closeBtn then closeBtn.Visible = true end
		return
	end

	if not data.skillId then return end

	local skillId = data.skillId
	local isDuplicate = data.isDuplicate
	local info = getSkillInfo(skillId)
	if not info then return end

	-- Update local inventory (sync may have already added it)
	if not isDuplicate then
		if not table.find(skillInventory, skillId) then
			table.insert(skillInventory, skillId)
		end

		-- Auto-equip: assign new skill to first empty slot
		-- Check if skill is already in a slot (from server sync)
		local alreadyInSlot = false
		for _, key in ipairs(SkillConfig.SlotKeys) do
			if skillSlots[key] == skillId then
				alreadyInSlot = true
				break
			end
		end

		if not alreadyInSlot then
			local assigned = false
			for _, key in ipairs(SkillConfig.SlotKeys) do
				if not skillSlots[key] then
					skillSlots[key] = skillId
					assigned = true

					-- Notify server of slot assignment
					local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
					if remotes then
						local slotRemote = remotes:FindFirstChild("SkillSlotRemote")
						if slotRemote then
							slotRemote:FireServer({action = "Assign", slot = key, skillId = skillId})
						end
					end

					break
				end
			end

			if not assigned then
				-- All slots full - player can manually swap via inventory
				print("[Gacha] All skill slots full! Open inventory (B) to assign " .. skillId)
			end
		end
	end

	-- NOTE: Don't decrement pendingGachaRolls here - the SkillSyncRemote already
	-- set it to the correct value (server decrements before syncing).
	-- Just update the display.

	-- Update rolls label
	local rollsLabel = gachaPanel and gachaPanel:FindFirstChild("RollsLabel")
	if rollsLabel then
		rollsLabel.Text = "Luot gacha: " .. pendingGachaRolls
	end

	-- Card flip animation
	local cardArea = gachaPanel:FindFirstChild("CardArea")
	if cardArea then
		local cardBack = cardArea:FindFirstChild("CardBack")
		local cardFront = cardArea:FindFirstChild("CardFront")

		task.delay(0.5, function()
			-- Flip: hide back, show front
			if cardBack then cardBack.Visible = false end
			if cardFront then
				cardFront.Visible = true

				-- Update card front with skill info
				local icon = cardFront:FindFirstChild("SkillIcon")
				local name = cardFront:FindFirstChild("SkillName")
				local rarity = cardFront:FindFirstChild("RarityLabel")
				local desc = cardFront:FindFirstChild("Description")

				if icon then icon.BackgroundColor3 = info.color end
				if name then name.Text = info.name end
				if rarity then
					rarity.Text = SkillConfig.RarityLabels[info.rarity] or info.rarity
					rarity.TextColor3 = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(255, 255, 255)
				end
				if desc then desc.Text = info.description end

				-- Rarity glow on card
				local frontStroke = cardFront:FindFirstChildOfClass("UIStroke")
				if not frontStroke then
					frontStroke = Instance.new("UIStroke")
					frontStroke.Parent = cardFront
				end
				frontStroke.Color = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(150, 150, 150)
				frontStroke.Thickness = 3

				-- Scale pop animation
				cardFront.Size = UDim2.new(0.8, 0, 0.8, 0)
				cardFront.Position = UDim2.new(0.1, 0, 0.1, 0)
				TweenService:Create(cardFront, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(1, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
				}):Play()
			end

			-- Duplicate label
			local dupLabel = cardArea:FindFirstChild("DuplicateLabel")
			if dupLabel then
				if isDuplicate then
					dupLabel.Text = "Da so huu! +" .. tostring(SkillConfig.DuplicateGold[info.rarity] or 20) .. " Gold"
					dupLabel.Visible = true
				else
					dupLabel.Text = "Skill moi!"
					dupLabel.Visible = true
				end
			end
		end)
	end

	-- Show equip/close buttons after reveal
	local rollBtn = gachaPanel:FindFirstChild("RollButton")
	local equipBtn = gachaPanel:FindFirstChild("EquipButton")
	local closeBtn = gachaPanel:FindFirstChild("CloseButton")

	task.delay(1, function()
		if pendingGachaRolls > 0 then
			if rollBtn then
				rollBtn.Visible = true
				rollBtn.Text = "ROLL! (" .. pendingGachaRolls .. ")"
			end
			if equipBtn then equipBtn.Visible = true end
			if closeBtn then closeBtn.Visible = true end
			equipBtn.Position = UDim2.new(0.5, -140, 0, 350)
			closeBtn.Position = UDim2.new(0.5, 0, 0, 350)
		else
			if rollBtn then rollBtn.Visible = false end
			if equipBtn then
				equipBtn.Visible = true
				equipBtn.Position = UDim2.new(0.5, -70, 0, 350)
			end
			if closeBtn then
				closeBtn.Visible = true
				closeBtn.Position = UDim2.new(0.5, 0, 0, 400)
			end
		end
	end)

	updateSkillBar()
end

-- ========== BUILD INVENTORY GUI ==========
local function buildInventoryGui()
	-- Full screen overlay
	inventoryOverlay = Instance.new("Frame")
	inventoryOverlay.Name = "InventoryOverlay"
	inventoryOverlay.Size = UDim2.new(1, 0, 1, 0)
	inventoryOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	inventoryOverlay.BackgroundTransparency = 0.5
	inventoryOverlay.Visible = false
	inventoryOverlay.ZIndex = 40
	inventoryOverlay.Parent = screenGui

	-- Main panel
	inventoryPanel = Instance.new("Frame")
	inventoryPanel.Name = "InventoryPanel"
	inventoryPanel.Size = UDim2.new(0, 500, 0, 450)
	inventoryPanel.Position = UDim2.new(0.5, -250, 0.5, -225)
	inventoryPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	inventoryPanel.BorderSizePixel = 0
	inventoryPanel.ZIndex = 41
	inventoryPanel.Parent = inventoryOverlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = inventoryPanel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(100, 100, 150)
	panelStroke.Thickness = 1.5
	panelStroke.Parent = inventoryPanel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(200, 200, 255)
	title.Text = "Skill Inventory"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.ZIndex = 42
	title.Parent = inventoryPanel

	-- Slot assignment area at top
	local slotArea = Instance.new("Frame")
	slotArea.Name = "SlotArea"
	slotArea.Size = UDim2.new(1, -20, 0, 80)
	slotArea.Position = UDim2.new(0, 10, 0, 55)
	slotArea.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	slotArea.BorderSizePixel = 0
	slotArea.ZIndex = 42
	slotArea.Parent = inventoryPanel

	local slotAreaCorner = Instance.new("UICorner")
	slotAreaCorner.CornerRadius = UDim.new(0, 10)
	slotAreaCorner.Parent = slotArea

	local slotAreaLabel = Instance.new("TextLabel")
	slotAreaLabel.Size = UDim2.new(1, 0, 0, 18)
	slotAreaLabel.Position = UDim2.new(0, 0, 0, 2)
	slotAreaLabel.BackgroundTransparency = 1
	slotAreaLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
	slotAreaLabel.Text = "Phim tat: Z  X  C  V  (Click de gan skill)"
	slotAreaLabel.Font = Enum.Font.Gotham
	slotAreaLabel.TextSize = 11
	slotAreaLabel.ZIndex = 43
	slotAreaLabel.Parent = slotArea

	-- 4 slot boxes in slot area
	local invSlotSize = 56
	local invSlotGap = 12
	local invTotalWidth = invSlotSize * 4 + invSlotGap * 3
	local invStartX = (480 - invTotalWidth) / 2

	for i, key in ipairs(SkillConfig.SlotKeys) do
		local x = invStartX + (i - 1) * (invSlotSize + invSlotGap)

		local invSlot = Instance.new("TextButton")
		invSlot.Name = "InvSlot_" .. key
		invSlot.Size = UDim2.new(0, invSlotSize, 0, invSlotSize)
		invSlot.Position = UDim2.new(0, x, 0, 20)
		invSlot.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		invSlot.TextColor3 = Color3.fromRGB(200, 200, 255)
		invSlot.Text = key
		invSlot.Font = Enum.Font.GothamBold
		invSlot.TextSize = 14
		invSlot.BorderSizePixel = 0
		invSlot.ZIndex = 43
		invSlot.Parent = slotArea

		local invSlotCorner = Instance.new("UICorner")
		invSlotCorner.CornerRadius = UDim.new(0, 8)
		invSlotCorner.Parent = invSlot

		local invSlotStroke = Instance.new("UIStroke")
		invSlotStroke.Name = "SlotStroke"
		invSlotStroke.Color = Color3.fromRGB(80, 80, 120)
		invSlotStroke.Thickness = 1
		invSlotStroke.Parent = invSlot

		-- Skill icon in slot
		local invSlotIcon = Instance.new("Frame")
		invSlotIcon.Name = "SlotIcon"
		invSlotIcon.Size = UDim2.new(1, -6, 1, -20)
		invSlotIcon.Position = UDim2.new(0, 3, 0, 3)
		invSlotIcon.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		invSlotIcon.BorderSizePixel = 0
		invSlotIcon.Visible = false
		invSlotIcon.ZIndex = 44
		invSlotIcon.Parent = invSlot

		local invIconCorner = Instance.new("UICorner")
		invIconCorner.CornerRadius = UDim.new(0, 6)
		invIconCorner.Parent = invSlotIcon

		-- Skill name in slot
		local invSlotName = Instance.new("TextLabel")
		invSlotName.Name = "SlotSkillName"
		invSlotName.Size = UDim2.new(1, 0, 0, 14)
		invSlotName.Position = UDim2.new(0, 0, 1, -14)
		invSlotName.BackgroundTransparency = 1
		invSlotName.TextColor3 = Color3.fromRGB(220, 220, 255)
		invSlotName.Text = ""
		invSlotName.Font = Enum.Font.GothamBold
		invSlotName.TextSize = 8
		invSlotName.ZIndex = 44
		invSlotName.Parent = invSlot

		-- Click to assign selected skill to this slot
		invSlot.MouseButton1Click:Connect(function()
			if selectedInventorySkill then
				-- Assign skill to this slot
				skillSlots[key] = selectedInventorySkill

				-- Send to server
				local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
				if remotes then
					local slotRemote = remotes:FindFirstChild("SkillSlotRemote")
					if slotRemote then
						slotRemote:FireServer({action = "Assign", slot = key, skillId = selectedInventorySkill})
					end
				end

				updateSkillBar()
				updateInventorySlots()
			end
		end)

		-- Right-click to clear slot
		invSlot.MouseButton2Click:Connect(function()
			if skillSlots[key] then
				skillSlots[key] = nil
				local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
				if remotes then
					local slotRemote = remotes:FindFirstChild("SkillSlotRemote")
					if slotRemote then
						slotRemote:FireServer({action = "Assign", slot = key, skillId = nil})
					end
				end
				updateSkillBar()
				updateInventorySlots()
			end
		end)
	end

	-- Skill grid area (scrolling frame)
	local skillGrid = Instance.new("ScrollingFrame")
	skillGrid.Name = "SkillGrid"
	skillGrid.Size = UDim2.new(1, -20, 0, 260)
	skillGrid.Position = UDim2.new(0, 10, 0, 145)
	skillGrid.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	skillGrid.BorderSizePixel = 0
	skillGrid.ScrollBarThickness = 6
	skillGrid.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 200)
	skillGrid.ZIndex = 42
	skillGrid.Parent = inventoryPanel

	local gridCorner = Instance.new("UICorner")
	gridCorner.CornerRadius = UDim.new(0, 10)
	gridCorner.Parent = skillGrid

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 90, 0, 100)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = skillGrid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 8)
	gridPadding.PaddingBottom = UDim.new(0, 8)
	gridPadding.PaddingLeft = UDim.new(0, 8)
	gridPadding.PaddingRight = UDim.new(0, 8)
	gridPadding.Parent = skillGrid

	-- Close button
	local closeInvBtn = Instance.new("TextButton")
	closeInvBtn.Name = "CloseButton"
	closeInvBtn.Size = UDim2.new(0, 120, 0, 36)
	closeInvBtn.Position = UDim2.new(0.5, -60, 1, -46)
	closeInvBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	closeInvBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
	closeInvBtn.Text = "Dong"
	closeInvBtn.Font = Enum.Font.GothamBold
	closeInvBtn.TextSize = 14
	closeInvBtn.BorderSizePixel = 0
	closeInvBtn.ZIndex = 42
	closeInvBtn.Parent = inventoryPanel

	local closeInvCorner = Instance.new("UICorner")
	closeInvCorner.CornerRadius = UDim.new(0, 10)
	closeInvCorner.Parent = closeInvBtn

	closeInvBtn.MouseButton1Click:Connect(function()
		closeInventory()
	end)

	-- Click overlay to close
	inventoryOverlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Check if click is outside the panel
			local pos = inventoryPanel.AbsolutePosition
			local size = inventoryPanel.AbsoluteSize
			local mousePos = input.Position
			if mousePos.X < pos.X or mousePos.X > pos.X + size.X or mousePos.Y < pos.Y or mousePos.Y > pos.Y + size.Y then
				closeInventory()
			end
		end
	end)
end

-- ========== UPDATE INVENTORY DISPLAY ==========
function updateInventorySlots()
	if not inventoryPanel then return end

	-- Update slot boxes
	local slotArea = inventoryPanel:FindFirstChild("SlotArea")
	if slotArea then
		for _, key in ipairs(SkillConfig.SlotKeys) do
			local invSlot = slotArea:FindFirstChild("InvSlot_" .. key)
			if invSlot then
				local skillId = skillSlots[key]
				local icon = invSlot:FindFirstChild("SlotIcon")
				local name = invSlot:FindFirstChild("SlotSkillName")
				local stroke = invSlot:FindFirstChild("SlotStroke")

				if skillId then
					local info = getSkillInfo(skillId)
					if info then
						if icon then
							icon.Visible = true
							icon.BackgroundColor3 = info.color
						end
						if name then name.Text = info.name end
						if stroke then stroke.Color = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(80, 80, 120) end
					end
				else
					if icon then icon.Visible = false end
					if name then name.Text = "" end
					if stroke then stroke.Color = Color3.fromRGB(80, 80, 120) end
				end
			end
		end
	end

	-- Update skill grid
	local skillGrid = inventoryPanel:FindFirstChild("SkillGrid")
	if skillGrid then
		-- Clear existing cards
		for _, child in skillGrid:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		-- Create skill cards
		for idx, skillId in ipairs(skillInventory) do
			local info = getSkillInfo(skillId)
			if not info then continue end

			local card = Instance.new("TextButton")
			card.Name = "SkillCard_" .. skillId
			card.Size = UDim2.new(0, 90, 0, 100)
			card.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
			card.Text = ""
			card.BorderSizePixel = 0
			card.LayoutOrder = idx
			card.ZIndex = 43
			card.Parent = skillGrid

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local cardStroke = Instance.new("UIStroke")
			cardStroke.Name = "CardStroke"
			cardStroke.Color = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(100, 100, 100)
			cardStroke.Thickness = 2
			cardStroke.Parent = card

			-- Skill icon
			local cardIcon = Instance.new("Frame")
			cardIcon.Size = UDim2.new(0, 50, 0, 50)
			cardIcon.Position = UDim2.new(0.5, -25, 0, 5)
			cardIcon.BackgroundColor3 = info.color
			cardIcon.BorderSizePixel = 0
			cardIcon.ZIndex = 44
			cardIcon.Parent = card

			local cardIconCorner = Instance.new("UICorner")
			cardIconCorner.CornerRadius = UDim.new(0, 8)
			cardIconCorner.Parent = cardIcon

			-- Skill name
			local cardName = Instance.new("TextLabel")
			cardName.Size = UDim2.new(1, -4, 0, 16)
			cardName.Position = UDim2.new(0, 2, 0, 58)
			cardName.BackgroundTransparency = 1
			cardName.TextColor3 = Color3.fromRGB(220, 220, 255)
			cardName.Text = info.name
			cardName.Font = Enum.Font.GothamBold
			cardName.TextSize = 10
			cardName.TextTruncate = Enum.TextTruncate.AtEnd
			cardName.ZIndex = 44
			cardName.Parent = card

			-- Rarity label
			local cardRarity = Instance.new("TextLabel")
			cardRarity.Size = UDim2.new(1, -4, 0, 14)
			cardRarity.Position = UDim2.new(0, 2, 0, 74)
			cardRarity.BackgroundTransparency = 1
			cardRarity.TextColor3 = SkillConfig.RarityColors[info.rarity] or Color3.fromRGB(150, 150, 150)
			cardRarity.Text = SkillConfig.RarityLabels[info.rarity] or info.rarity
			cardRarity.Font = Enum.Font.GothamBold
			cardRarity.TextSize = 9
			cardRarity.ZIndex = 44
			cardRarity.Parent = card

			-- Selected highlight
			if selectedInventorySkill == skillId then
				card.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
				if cardStroke then cardStroke.Thickness = 3 end
			end

			-- Click to select
			card.MouseButton1Click:Connect(function()
				selectedInventorySkill = skillId
				updateInventorySlots()
			end)
		end

		-- Update canvas size
		local count = #skillInventory
		local cols = 4
		local rows = math.ceil(count / cols)
		skillGrid.CanvasSize = UDim2.new(0, 0, 0, rows * 108 + 16)
	end
end

-- ========== OPEN / CLOSE INVENTORY ==========
function openInventory()
	if not inventoryOverlay then return end
	isInventoryOpen = true
	inventoryOverlay.Visible = true
	selectedInventorySkill = nil
	updateInventorySlots()
end

function closeInventory()
	if not inventoryOverlay then return end
	isInventoryOpen = false
	inventoryOverlay.Visible = false
	selectedInventorySkill = nil
end

-- ========== INPUT HANDLING ==========
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- Skill hotkeys Z/X/C/V
	for _, key in ipairs(SkillConfig.SlotKeys) do
		if input.KeyCode == SkillConfig.SlotKeyCodes[key] then
			local skillId = skillSlots[key]
			if skillId then
				fireSkill(skillId)
			end
			return
		end
	end

	-- B key to toggle inventory
	if input.KeyCode == Enum.KeyCode.B then
		if isInventoryOpen then
			closeInventory()
		else
			openInventory()
		end
		return
	end

	-- Escape to close GUIs
	if input.KeyCode == Enum.KeyCode.Escape then
		if isGachaOpen then
			closeGacha()
			return
		elseif isInventoryOpen then
			closeInventory()
			return
		end
	end

	-- Ctrl+G: Dev gacha rolls (for testing)
	if input.KeyCode == Enum.KeyCode.G and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		local devGachaRemote = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("DevGachaRemote")
		if devGachaRemote then
			devGachaRemote:FireServer("GiveRolls")
		end
		return
	end
end)

-- ========== REMOTE EVENT HANDLERS ==========
local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
if remotes then
	-- Skill sync from server
	local syncRemote = remotes:FindFirstChild("SkillSyncRemote")
	if syncRemote then
		syncRemote.OnClientEvent:Connect(function(data)
			if data.inventory then
				skillInventory = data.inventory
			end
			if data.slots then
				skillSlots = data.slots
			end
			if data.pendingRolls then
				pendingGachaRolls = data.pendingRolls
			end
			updateSkillBar()
		end)
	end

	-- Level up notification
	local levelUpRemote = remotes:FindFirstChild("LevelUpRemote")
	if levelUpRemote then
		levelUpRemote.OnClientEvent:Connect(function(rolls)
			pendingGachaRolls = rolls
			-- Auto open gacha GUI
			task.delay(0.5, function()
				openGacha()
			end)
		end)
	end

	-- Gacha result
	local gachaRemote = remotes:FindFirstChild("GachaRollRemote")
	if gachaRemote then
		gachaRemote.OnClientEvent:Connect(function(data)
			onGachaResult(data)
		end)
	end

	-- Dev mode toggle from server
	local devRemote = remotes:FindFirstChild("DevModeRemote")
	if devRemote then
		devRemote.OnClientEvent:Connect(function(enabled)
			devMode = enabled
			if enabled then
				print("[SkillBarController] DEV MODE ON - cooldowns bypassed")
			else
				print("[SkillBarController] DEV MODE OFF - normal cooldowns")
			end
		end)
	end
end

-- ========== INITIALIZE ==========
buildSkillBar()
buildGachaGui()
buildInventoryGui()
updateSkillBar()

print("[SkillBarController] Loaded successfully")