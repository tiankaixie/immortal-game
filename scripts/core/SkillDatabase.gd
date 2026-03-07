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
	"""Register all starter techniques."""
	
	_register({
		"id": "fire_bolt",
		"name_zh": "火球术",
		"name_en": "Fire Bolt",
		"sp_cost": 8.0,
		"cooldown": 1.5,
		"damage_multiplier": 1.8,
		"range": 10.0,
		"aoe_radius": 0.0,
		"element": "fire",
		"description": "凝聚灵力化为火球，直射敌人。入门级火系术法。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "fire_nova",
		"name_zh": "烈炎爆",
		"name_en": "Fire Nova",
		"sp_cost": 22.0,
		"cooldown": 6.0,
		"damage_multiplier": 2.5,
		"range": 5.0,
		"aoe_radius": 4.0,
		"element": "fire",
		"description": "引爆周身烈焰，焚尽近身之敌。结丹期方可修炼。",
		"unlock_realm": 2,
	})
	
	_register({
		"id": "frost_slash",
		"name_zh": "寒冰剑",
		"name_en": "Frost Slash",
		"sp_cost": 10.0,
		"cooldown": 2.0,
		"damage_multiplier": 1.6,
		"range": 3.0,
		"aoe_radius": 0.0,
		"element": "water",
		"description": "以灵力凝冰为剑，斩出寒气侵体，减缓敌人身法。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "water_shield",
		"name_zh": "水罗盾",
		"name_en": "Water Shield",
		"sp_cost": 15.0,
		"cooldown": 8.0,
		"damage_multiplier": 0.0,
		"range": 0.0,
		"aoe_radius": 0.0,
		"element": "water",
		"description": "以水灵力凝结护盾，短时间内大幅提升防御。筑基期方可修炼。",
		"unlock_realm": 1,
	})
	
	_register({
		"id": "metal_edge",
		"name_zh": "金剑斩",
		"name_en": "Metal Edge",
		"sp_cost": 12.0,
		"cooldown": 2.5,
		"damage_multiplier": 2.8,
		"range": 3.0,
		"aoe_radius": 0.0,
		"element": "metal",
		"description": "凝金气于剑锋，一斩之力可裂金石。金系入门重击术。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "wood_heal",
		"name_zh": "木灵愈",
		"name_en": "Wood Heal",
		"sp_cost": 14.0,
		"cooldown": 10.0,
		"damage_multiplier": 0.0,
		"range": 0.0,
		"aoe_radius": 0.0,
		"element": "wood",
		"description": "引木灵之气修复肉身，恢复自身气血。",
		"unlock_realm": 0,
	})
	
	_register({
		"id": "earth_wall",
		"name_zh": "土盾术",
		"name_en": "Earth Wall",
		"sp_cost": 18.0,
		"cooldown": 12.0,
		"damage_multiplier": 0.0,
		"range": 0.0,
		"aoe_radius": 3.5,
		"element": "earth",
		"description": "召唤土墙阻挡来敌，范围内敌人减速。筑基期方可修炼。",
		"unlock_realm": 1,
	})
	
	_register({
		"id": "lightning_step",
		"name_zh": "雷步",
		"name_en": "Lightning Step",
		"sp_cost": 28.0,
		"cooldown": 5.0,
		"damage_multiplier": 2.2,
		"range": 8.0,
		"aoe_radius": 2.0,
		"element": "lightning",
		"description": "化身雷电瞬移至敌身旁，途中电弧伤敌。元婴期以上方可修炼。",
		"unlock_realm": 3,
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
			return ["fire_bolt", "frost_slash"]
		PlayerData.SpiritualRoot.VOID:
			return ["metal_edge", "fire_bolt"]
		_:
			return ["fire_bolt", "frost_slash"]

func is_skill_available(skill_id: String, realm: int) -> bool:
	"""Check if a skill can be used at the given realm."""
	var skill := get_skill(skill_id)
	if skill.is_empty():
		return false
	return realm >= skill["unlock_realm"]
