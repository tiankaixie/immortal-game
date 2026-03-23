extends Node
## SkillDatabase — Global Autoload Singleton
##
## Central registry of all cultivation techniques (skills).
## Each skill is a Dictionary with standardized keys.
## Skills are unlocked based on cultivation realm and spiritual root.

# ─── Skill Registry ───────────────────────────────────────────
var _skills: Dictionary = {}

func _ready() -> void:
	_register_all_skills()
	print("[SkillDatabase] Initialized — %d skills registered" % _skills.size())

# ─── Skill Definitions ────────────────────────────────────────
func _register_all_skills() -> void:
	"""Register all starter combat arts."""
	
	_register({
		"id": "fire_bolt",
		"name_zh": "灰烬矢",
		"name_en": "Fire Bolt",
		"sp_cost": 8.0,
		"cooldown": 1.5,
		"damage_multiplier": 1.8,
		"range": 10.0,
		"aoe_radius": 0.0,
		"element": "fire",
		"description": "压缩灰烬与火星形成灼热飞矢，精准射穿前方敌人。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "fire_nova",
		"name_zh": "焚火爆环",
		"name_en": "Fire Nova",
		"sp_cost": 22.0,
		"cooldown": 6.0,
		"damage_multiplier": 2.5,
		"range": 5.0,
		"aoe_radius": 4.0,
		"element": "fire",
		"description": "在身旁引爆灼热火环，焚烧所有贴身目标。",
		"unlock_realm": 2,
	})
	
	_register({
		"id": "frost_slash",
		"name_zh": "霜痕斩",
		"name_en": "Frost Slash",
		"sp_cost": 10.0,
		"cooldown": 2.0,
		"damage_multiplier": 1.6,
		"range": 3.0,
		"aoe_radius": 0.0,
		"element": "water",
		"description": "凝出寒霜刀锋劈开前方，冰冷气流会拖慢敌人的动作。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "water_shield",
		"name_zh": "冰潮护幕",
		"name_en": "Water Shield",
		"sp_cost": 15.0,
		"cooldown": 8.0,
		"damage_multiplier": 0.0,
		"range": 0.0,
		"aoe_radius": 0.0,
		"element": "water",
		"description": "召出潮汐般的护幕短暂护体，大幅提升防御。",
		"unlock_realm": 1,
	})
	
	_register({
		"id": "metal_edge",
		"name_zh": "断钢重斩",
		"name_en": "Metal Edge",
		"sp_cost": 12.0,
		"cooldown": 2.5,
		"damage_multiplier": 2.8,
		"range": 3.0,
		"aoe_radius": 0.0,
		"element": "metal",
		"description": "将全身力量压到剑锋上猛然劈下，适合正面破甲。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "wood_heal",
		"name_zh": "荆棘祷愈",
		"name_en": "Wood Heal",
		"sp_cost": 14.0,
		"cooldown": 10.0,
		"damage_multiplier": 0.0,
		"range": 0.0,
		"aoe_radius": 0.0,
		"element": "wood",
		"description": "让荆棘之力缠绕伤口，快速恢复自身生命。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "earth_wall",
		"name_zh": "黑岩壁垒",
		"name_en": "Earth Wall",
		"sp_cost": 18.0,
		"cooldown": 12.0,
		"damage_multiplier": 0.0,
		"range": 0.0,
		"aoe_radius": 3.5,
		"element": "earth",
		"description": "唤起厚重岩壁阻挡来敌，并压制范围内敌人的速度。",
		"unlock_realm": 1,
	})
	
	_register({
		"id": "lightning_step",
		"name_zh": "雷鸣突袭",
		"name_en": "Lightning Step",
		"sp_cost": 28.0,
		"cooldown": 5.0,
		"damage_multiplier": 2.2,
		"range": 8.0,
		"aoe_radius": 2.0,
		"element": "lightning",
		"description": "以雷光突进拉近距离，沿途迸射的电弧会灼伤敌人。",
		"unlock_realm": 3,
	})

	# ─── 雷灵根专属技能 ───────────────────────────────────────
	_register({
		"id": "thunder_palm",
		"name_zh": "雷殛重击",
		"name_en": "Thunder Palm",
		"sp_cost": 14.0,
		"cooldown": 4.0,
		"damage_multiplier": 1.9,
		"range": 8.0,
		"aoe_radius": 0.0,
		"element": "lightning",
		"effect": "stun",
		"effect_duration": 2.0,
		"description": "将风暴之力砸入单个目标体内，强电流会令其麻痹 2 秒。",
		"unlock_realm": 0,
	})

	_register({
		"id": "chain_lightning",
		"name_zh": "风暴连锁",
		"name_en": "Chain Lightning",
		"sp_cost": 22.0,
		"cooldown": 6.5,
		"damage_multiplier": 1.4,
		"range": 12.0,
		"aoe_radius": -1.0,  # Special: chain logic (negative = chain mode)
		"chain_count": 3,    # Number of targets to chain to
		"element": "lightning",
		"description": "让雷弧在敌群之间跳跃，最多连锁 3 个目标。",
		"unlock_realm": 1,
	})

	# ─── 虚灵根专属技能 ───────────────────────────────────────
	_register({
		"id": "void_blink",
		"name_zh": "影袭跃步",
		"name_en": "Void Blink",
		"sp_cost": 18.0,
		"cooldown": 5.0,
		"damage_multiplier": 2.5,
		"range": 15.0,
		"aoe_radius": 0.0,
		"element": "void",
		"effect": "blink",
		"description": "借深渊裂隙闪到目标背后，打出致命的背袭重击。",
		"unlock_realm": 0,
	})

	_register({
		"id": "void_drain",
		"name_zh": "噬魂虹吸",
		"name_en": "Void Drain",
		"sp_cost": 20.0,
		"cooldown": 8.0,
		"damage_multiplier": 1.5,
		"range": 10.0,
		"aoe_radius": 0.0,
		"element": "void",
		"effect": "lifesteal",
		"lifesteal_ratio": 0.6,
		"description": "抽离目标的生命精华，造成伤害的 60% 会返还为自身生命。",
		"unlock_realm": 1,
	})

func _register(skill: Dictionary) -> void:
	"""Add a skill to the registry."""
	_skills[skill["id"]] = skill

# ─── Query Methods ─────────────────────────────────────────────
func get_skill(id: String) -> Dictionary:
	"""Look up a skill by ID. Returns empty dict if not found."""
	if _skills.has(id):
		return _skills[id]
	push_warning("[SkillDatabase] Skill not found: %s" % id)
	return {}

func get_all_skills() -> Array[Dictionary]:
	"""Return all registered skills."""
	var result: Array[Dictionary] = []
	for skill in _skills.values():
		result.append(skill)
	return result

func get_skills_for_realm(realm: int) -> Array[Dictionary]:
	"""Return all skills unlockable at or below the given cultivation realm."""
	var result: Array[Dictionary] = []
	for skill in _skills.values():
		if skill["unlock_realm"] <= realm:
			result.append(skill)
	return result

func get_starter_skills(root: int) -> Array[String]:
	"""Return 2 starter skill IDs based on the player's spiritual root.
	
	Each root gets its element's realm-0 skill + a complementary skill.
	"""
	match root:
		PlayerData.SpiritualRoot.METAL:
			return ["metal_edge", "fire_bolt"]
		PlayerData.SpiritualRoot.WOOD:
			return ["wood_heal", "frost_slash"]
		PlayerData.SpiritualRoot.WATER:
			return ["frost_slash", "wood_heal"]
		PlayerData.SpiritualRoot.FIRE:
			return ["fire_bolt", "metal_edge"]
		PlayerData.SpiritualRoot.EARTH:
			return ["metal_edge", "frost_slash"]
		PlayerData.SpiritualRoot.LIGHTNING:
			return ["thunder_palm", "chain_lightning"]
		PlayerData.SpiritualRoot.VOID:
			return ["void_blink", "void_drain"]
		_:
			return ["fire_bolt", "frost_slash"]

func is_skill_available(skill_id: String, realm: int) -> bool:
	"""Check if a skill can be used at the given realm."""
	var skill := get_skill(skill_id)
	if skill.is_empty():
		return false
	return realm >= skill["unlock_realm"]
