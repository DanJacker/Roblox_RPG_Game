-- SkillGachaSystem - Server-side gacha, skill inventory, slot management, and generic skill execution

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local SkillConfig = require(ReplicatedStorage.Modules.SkillConfig)
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

-- ========== PLAYER SKILL DATA STORAGE ==========
local playerSkillData = {} -- [userId] = { inventory = {}, slots = {}, pendingGachaRolls = 0 }

-- ========== HELPER: Get RemoteEvents folder ==========
local function getRemoteEvents()
	return ReplicatedStorage:FindFirstChild("RemoteEvents")
end

-- ========== INIT PLAYER SKILL DATA ==========
local function initPlayerSkillData(player)
	local userId = player.UserId
	if not playerSkillData[userId] then
		playerSkillData[userId] = {
			inventory = {"Fireball"},
			slots = {Z = "Fireball", X = nil, C = nil, V = nil},
			pendingGachaRolls = 0,
		}
	end
	return playerSkillData[userId]
end

local function getSkillData(player)
	return playerSkillData[player.UserId]
end

-- ========== SYNC TO CLIENT ==========
local cachedSyncRemote = nil -- Cached after handlers connect

local function syncToClient(player)
	local data = getSkillData(player)
	if not data then return end

	-- Use cached remote or fall back to finding it
	local syncRemote = cachedSyncRemote
	if not syncRemote then
		local remotes = getRemoteEvents()
		if remotes then
			syncRemote = remotes:FindFirstChild("SkillSyncRemote")
		end
	end

	if syncRemote then
		syncRemote:FireClient(player, {
			inventory = data.inventory,
			slots = data.slots,
			pendingRolls = data.pendingGachaRolls,
		})
	end
end

-- ========== GACHA ROLL LOGIC ==========
local function performGachaRoll(player)
	local data = getSkillData(player)
	if not data then return nil, nil end
	if data.pendingGachaRolls <= 0 then return nil, nil end

	data.pendingGachaRolls = data.pendingGachaRolls - 1

	-- Determine rarity by weighted random
	local roll = math.random()
	local rarity = "Common"
	local cumulative = 0
	for _, r in ipairs(SkillConfig.RarityOrder) do
		cumulative = cumulative + (SkillConfig.GachaRates[r] or 0)
		if roll <= cumulative then
			rarity = r
			break
		end
	end

	-- Get skills of this rarity
	local availableSkills = {}
	for skillId, skillInfo in pairs(SkillConfig.Skills) do
		if skillInfo.rarity == rarity then
			table.insert(availableSkills, skillId)
		end
	end

	if #availableSkills == 0 then
		return nil, nil
	end

	local chosenSkill = availableSkills[math.random(1, #availableSkills)]
	local isDuplicate = table.find(data.inventory, chosenSkill) ~= nil

	if not isDuplicate then
		table.insert(data.inventory, chosenSkill)

		-- Auto-equip: assign new skill to first empty slot
		for _, slotKey in ipairs(SkillConfig.SlotKeys) do
			if not data.slots[slotKey] then
				data.slots[slotKey] = chosenSkill
				break
			end
		end
	else
		-- Give gold for duplicate
		local goldAmount = SkillConfig.DuplicateGold[rarity] or 20
		local playerData = PlayerData.Get(player)
		if playerData then
			PlayerData.Set(player, "Money", (playerData.Money or 0) + goldAmount)
		end
	end

	syncToClient(player)

	return chosenSkill, isDuplicate
end

-- ========== SLOT ASSIGNMENT ==========
local function onSlotAssign(player, slot, skillId)
	local data = getSkillData(player)
	if not data then return end

	-- Validate slot key
	if not table.find(SkillConfig.SlotKeys, slot) then return end

	-- If skillId is nil/empty, clear the slot
	if not skillId or skillId == "" then
		data.slots[slot] = nil
		syncToClient(player)
		return
	end

	-- Validate skill exists in config
	if not SkillConfig.Skills[skillId] then return end

	-- Validate skill is in inventory
	if not table.find(data.inventory, skillId) then return end

	-- Remove skill from any other slot first (one skill per slot only)
	for s, sk in pairs(data.slots) do
		if sk == skillId then
			data.slots[s] = nil
		end
	end

	-- Assign to slot
	data.slots[slot] = skillId

	syncToClient(player)
end

-- ========== GENERIC SKILL EXECUTION ==========
local function onGenericSkill(player, skillId, position)
	local data = getSkillData(player)
	if not data then return end

	-- Validate skill is in a slot
	local inSlot = false
	for _, sk in pairs(data.slots) do
		if sk == skillId then
			inSlot = true
			break
		end
	end
	if not inSlot then return end

	-- Validate skill is in inventory
	if not table.find(data.inventory, skillId) then return end

	local skillInfo = SkillConfig.Skills[skillId]
	if not skillInfo then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Execute based on skill type
	if skillInfo.skillType == "Projectile" then
		-- Create projectile
		local projectile = Instance.new("Part")
		projectile.Name = skillId .. "Projectile"
		projectile.Size = Vector3.new(1.5, 1.5, 1.5)
		projectile.Shape = Enum.PartType.Ball
		projectile.Color = skillInfo.color
		projectile.Material = Enum.Material.Neon
		projectile.Anchored = false
		projectile.CanCollide = false
		projectile.Position = position or (hrp.Position + hrp.CFrame.LookVector * 3 + Vector3.new(0, 2, 0))
		projectile.Parent = workspace

		-- PointLight for glow
		local light = Instance.new("PointLight")
		light.Color = skillInfo.color
		light.Brightness = 2
		light.Range = 8
		light.Parent = projectile

		-- Velocity
		projectile.Velocity = hrp.CFrame.LookVector * 80

		-- Touch damage
		local hitTargets = {}
		projectile.Touched:Connect(function(otherPart)
			if hitTargets[otherPart] then return end
			hitTargets[otherPart] = true

			local targetChar = otherPart.Parent
			if targetChar == character then return end

			local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
			if targetHumanoid and targetHumanoid.Health > 0 then
				targetHumanoid:TakeDamage(skillInfo.damage)
				-- Impact effect
				local impact = Instance.new("Part")
				impact.Size = Vector3.new(3, 3, 3)
				impact.Shape = Enum.PartType.Ball
				impact.Color = skillInfo.color
				impact.Material = Enum.Material.Neon
				impact.Anchored = true
				impact.CanCollide = false
				impact.Position = projectile.Position
				impact.Parent = workspace
				Debris:AddItem(impact, 0.5)
				task.spawn(function()
					for i = 1, 10 do
						impact.Transparency = i / 10
						impact.Size = impact.Size + Vector3.new(0.5, 0.5, 0.5)
						task.wait(0.03)
					end
				end)
				projectile:Destroy()
			end
		end)

		Debris:AddItem(projectile, 5)

	elseif skillInfo.skillType == "AoE" then
		local radius = 20
		local centerPos = hrp.Position + hrp.CFrame.LookVector * 10

		-- Expanding ring effect
		local effect = Instance.new("Part")
		effect.Name = skillId .. "AoE"
		effect.Shape = Enum.PartType.Cylinder
		effect.Size = Vector3.new(1, 1, 1)
		effect.Color = skillInfo.color
		effect.Material = Enum.Material.Neon
		effect.Anchored = true
		effect.CanCollide = false
		effect.Transparency = 0.4
		effect.Orientation = Vector3.new(0, 0, 90)
		effect.Position = centerPos
		effect.Parent = workspace

		task.spawn(function()
			for i = 1, 20 do
				local scale = (i / 20) * radius * 2
				effect.Size = Vector3.new(1, scale, scale)
				effect.Transparency = 0.4 + (i / 20) * 0.6
				task.wait(0.04)
			end
			effect:Destroy()
		end)

		-- Damage enemies in range
		task.wait(0.3) -- Small delay for visual
		for _, obj in workspace:GetDescendants() do
			if obj:IsA("Humanoid") and obj.Parent ~= character and obj.Health > 0 then
				local rootPart = obj.Parent:FindFirstChild("HumanoidRootPart") or obj.Parent:FindFirstChild("Torso")
				if rootPart and (rootPart.Position - centerPos).Magnitude <= radius then
					obj:TakeDamage(skillInfo.damage)
				end
			end
		end

	elseif skillInfo.skillType == "Heal" then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local healAmt = skillInfo.healAmount or math.abs(skillInfo.damage or 50)
			humanoid.Health = math.min(humanoid.Health + healAmt, humanoid.MaxHealth)
		end

		-- Heal effect: rising particles
		task.spawn(function()
			for i = 1, 12 do
				local particle = Instance.new("Part")
				particle.Size = Vector3.new(1, 1, 1)
				particle.Shape = Enum.PartType.Ball
				particle.Color = skillInfo.color
				particle.Material = Enum.Material.Neon
				particle.Anchored = true
				particle.CanCollide = false
				particle.Transparency = 0.3
				particle.Position = hrp.Position + Vector3.new(
					math.random(-3, 3),
					math.random(0, 2),
					math.random(-3, 3)
				)
				particle.Parent = workspace

				task.spawn(function()
					for j = 1, 15 do
						particle.Position = particle.Position + Vector3.new(0, 0.5, 0)
						particle.Transparency = 0.3 + (j / 15) * 0.7
						task.wait(0.05)
					end
					particle:Destroy()
				end)
				task.wait(0.08)
			end
		end)

	elseif skillInfo.skillType == "Melee" then
		local range = 8

		-- Slash visual
		local effect = Instance.new("Part")
		effect.Name = skillId .. "Slash"
		effect.Size = Vector3.new(range, 6, 2)
		effect.Color = skillInfo.color
		effect.Material = Enum.Material.Neon
		effect.Anchored = true
		effect.CanCollide = false
		effect.Transparency = 0.3
		effect.CFrame = hrp.CFrame * CFrame.new(0, 0, -range / 2)
		effect.Parent = workspace

		task.spawn(function()
			for i = 1, 10 do
				effect.Transparency = 0.3 + (i / 10) * 0.7
				task.wait(0.03)
			end
			effect:Destroy()
		end)

		-- Damage enemies in front
		for _, obj in workspace:GetDescendants() do
			if obj:IsA("Humanoid") and obj.Parent ~= character and obj.Health > 0 then
				local rootPart = obj.Parent:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local dist = (rootPart.Position - hrp.Position).Magnitude
					local toTarget = (rootPart.Position - hrp.Position).Unit
					local dot = hrp.CFrame.LookVector:Dot(toTarget)
					if dist <= range and dot > 0.5 then
						obj:TakeDamage(skillInfo.damage)
					end
				end
			end
		end
	end
end

-- ========== DEV UNLOCK ALL ==========
function _G.DevUnlockAllSkills(player)
	local data = getSkillData(player)
	if not data then
		initPlayerSkillData(player)
		data = getSkillData(player)
	end
	if not data then return false end

	-- Add all skills to inventory
	for skillId, _ in pairs(SkillConfig.Skills) do
		if not table.find(data.inventory, skillId) then
			table.insert(data.inventory, skillId)
		end
	end

	-- Assign first 4 skills to Z/X/C/V slots
	local slotIndex = 1
	for skillId, _ in pairs(SkillConfig.Skills) do
		if slotIndex <= 4 then
			local slotKey = SkillConfig.SlotKeys[slotIndex]
			if slotKey then
				data.slots[slotKey] = skillId
			end
			slotIndex = slotIndex + 1
		end
	end

	-- Give 99 pending gacha rolls
	data.pendingGachaRolls = 99

	syncToClient(player)
	return true
end

-- ========== GIVE GACHA ROLL (called from ExpCollectionSystem on level up) ==========
function _G.GiveGachaRoll(player)
	local data = getSkillData(player)
	if not data then
		initPlayerSkillData(player)
		data = getSkillData(player)
	end
	if not data then return end

	data.pendingGachaRolls = data.pendingGachaRolls + 1
	syncToClient(player)

	-- Notify client about level up + gacha roll
	local remotes = getRemoteEvents()
	if remotes then
		local levelUpRemote = remotes:FindFirstChild("LevelUpRemote")
		if levelUpRemote then
			levelUpRemote:FireClient(player, data.pendingGachaRolls)
		end
	end
end

-- ========== PLAYER LIFECYCLE ==========
local function onPlayerAdded(player)
	initPlayerSkillData(player)
	task.delay(3, function()
		syncToClient(player)
	end)
end

local function onPlayerRemoving(player)
	playerSkillData[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- ========== REMOTE EVENT HANDLERS ==========
-- Wait for RemoteEvents folder and remotes to exist (EnsureRemoteEvents may load after this script)
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
	if not remotes then
		warn("[SkillGachaSystem] RemoteEvents folder not found after 30s - gacha will not work!")
		return
	end

	local gachaRemote = remotes:WaitForChild("GachaRollRemote", 10)
	if gachaRemote then
		gachaRemote.OnServerEvent:Connect(function(player, action)
			if action == "Roll" then
				local skillId, isDuplicate = performGachaRoll(player)
				if skillId then
					gachaRemote:FireClient(player, {skillId = skillId, isDuplicate = isDuplicate})
				else
					-- Always respond so client isn't stuck
					gachaRemote:FireClient(player, {skillId = nil, failed = true})
				end
			end
		end)
		print("[SkillGachaSystem] GachaRollRemote handler connected")
	else
		warn("[SkillGachaSystem] GachaRollRemote not found!")
	end

	local slotRemote = remotes:WaitForChild("SkillSlotRemote", 10)
	if slotRemote then
		slotRemote.OnServerEvent:Connect(function(player, data)
			if data and data.action == "Assign" then
				onSlotAssign(player, data.slot, data.skillId)
			end
		end)
		print("[SkillGachaSystem] SkillSlotRemote handler connected")
	end

	local genericRemote = remotes:WaitForChild("GenericSkillRemote", 10)
	if genericRemote then
		genericRemote.OnServerEvent:Connect(function(player, data)
			if data and data.skillId then
				onGenericSkill(player, data.skillId, data.position)
			end
		end)
		print("[SkillGachaSystem] GenericSkillRemote handler connected")
	end

	-- Cache the sync remote for efficient use in syncToClient
	cachedSyncRemote = remotes:FindFirstChild("SkillSyncRemote")
	if cachedSyncRemote then
		print("[SkillGachaSystem] SkillSyncRemote cached")
	end
end)

print("[SkillGachaSystem] Loaded successfully")