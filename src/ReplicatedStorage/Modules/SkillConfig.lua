-- SkillConfig - Configuration data for the skill system
-- IMPORTANT: This ModuleScript must contain ONLY config data. No server code, no require() calls.

local SkillConfig = {}

-- ========== SLOT KEYS ==========
SkillConfig.SlotKeys = {"Z", "X", "C", "V"}
SkillConfig.SlotKeyCodes = {
	Z = Enum.KeyCode.Z,
	X = Enum.KeyCode.X,
	C = Enum.KeyCode.C,
	V = Enum.KeyCode.V,
}

-- ========== RARITY ==========
SkillConfig.RarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 50, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
}
SkillConfig.RarityLabels = {
	Common = "Common",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
}
SkillConfig.RarityOrder = {"Common", "Rare", "Epic", "Legendary"}

SkillConfig.DuplicateGold = {
	Common = 10,
	Rare = 25,
	Epic = 50,
	Legendary = 100,
}

-- ========== GACHA RATES ==========
SkillConfig.GachaRates = {
	Common = 0.55,
	Rare = 0.28,
	Epic = 0.12,
	Legendary = 0.05,
}

-- ========== SKILLS ==========
SkillConfig.Skills = {
	Fireball = {
		name = "Fireball",
		rarity = "Common",
		color = Color3.fromRGB(255, 80, 20),
		cooldown = 3,
		damage = 15,
		skillType = "Projectile",
		description = "Ban mot luong lua ve phia doi thu.",
	},
	IceShard = {
		name = "Ice Shard",
		rarity = "Common",
		color = Color3.fromRGB(100, 200, 255),
		cooldown = 3.5,
		damage = 12,
		skillType = "Projectile",
		speed = 90,
		size = Vector3.new(1.2, 1.2, 2.5),
		description = "Ban mot mau bang nho.",
	},
	WindSlash = {
		name = "Wind Slash",
		rarity = "Common",
		color = Color3.fromRGB(180, 255, 180),
		cooldown = 2.5,
		damage = 10,
		skillType = "Melee",
		range = 10,
		description = "Tao mot luong gio cat.",
	},
	LightBeam = {
		name = "Light Beam",
		rarity = "Rare",
		color = Color3.fromRGB(255, 255, 150),
		cooldown = 5,
		damage = 25,
		skillType = "Projectile",
		description = "Tia sang phang doi thu.",
	},
	ShadowStrike = {
		name = "Shadow Strike",
		rarity = "Rare",
		color = Color3.fromRGB(80, 0, 120),
		cooldown = 4,
		damage = 22,
		skillType = "Melee",
		range = 7,
		description = "Tan cong tu bong toi.",
	},
	ThunderBolt = {
		name = "Thunder Bolt",
		rarity = "Rare",
		color = Color3.fromRGB(255, 255, 50),
		cooldown = 4.5,
		damage = 28,
		skillType = "AoE",
		radius = 12,
		description = "Goi set danh doi thu.",
	},
	JinxRocket = {
		name = "Jinx Rocket",
		rarity = "Epic",
		color = Color3.fromRGB(255, 50, 150),
		cooldown = 6,
		damage = 35,
		skillType = "Projectile",
		description = "Ban ten lua no lon.",
	},
	FrostNova = {
		name = "Frost Nova",
		rarity = "Epic",
		color = Color3.fromRGB(50, 150, 255),
		cooldown = 7,
		damage = 30,
		skillType = "AoE",
		radius = 18,
		description = "No bang vung rong lam cham doi thu.",
	},
	MeteorStrike = {
		name = "Meteor Strike",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 100, 0),
		cooldown = 10,
		damage = 50,
		skillType = "AoE",
		radius = 22,
		description = "Goi thien thach tu tren troi xuong!",
	},
	VoidBlast = {
		name = "Void Blast",
		rarity = "Legendary",
		color = Color3.fromRGB(100, 0, 200),
		cooldown = 9,
		damage = 45,
		skillType = "AoE",
		radius = 16,
		description = "Phat no nang luong khoang khong.",
	},
	DivineShield = {
		name = "Divine Shield",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 215, 0),
		cooldown = 12,
		damage = 0,
		skillType = "Heal",
		healAmount = 80,
		description = "Bao ve than thanh chong sat thuong.",
	},
}

return SkillConfig