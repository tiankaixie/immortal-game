extends Node
## LootTable — Global Autoload Singleton
##
## Defines loot drop tables by enemy tier.
## Weight-based random selection for drops.
##
## Enemy tiers:
##   0 = 练气妖 (Qi Condensation monsters)
##   1 = 筑基妖 (Foundation Establishment monsters)
##   2 = 结丹妖 (Core Formation monsters)

# ─── Loot Item Types ──────────────────────────────────────────
enum LootType {
	LING_STONE,   # 灵石
	EQUIPMENT,    # 装备
	PILL,         # 丹药
	NOTHING,      # 空 (no drop)
}

# ─── Equipment Grades ─────────────────────────────────────────
enum EquipmentGrade {
	COMMON,       # 凡品
	FINE,         # 精品
	RARE,         # 上品 (higher tiers only)
}

# ─── Pill Types ────────────────────────────────────────────────
enum PillType {
	HP_RESTORE,   # 回血丹
	SP_RESTORE,   # 回灵丹
	HP_SP_BOTH,   # 混元丹 (restores both)
}

# ─── Drop Tables ───────────────────────────────────────────────
## Each entry: { "type": LootType, "weight": int, ... extra data }
## Higher weight = more likely to drop

# 练气妖 drop table
var _tier_0_table: Array[Dictionary] = [
	{ "type": LootType.NOTHING, "weight": 30 },
	{ "type": LootType.LING_STONE, "weight": 40, "min_amount": 5, "max_amount": 15 },
	{ "type": LootType.PILL, "weight": 20, "pill_type": PillType.HP_RESTORE, "restore_amount": 30.0 },
	{ "type": LootType.PILL, "weight": 8, "pill_type": PillType.SP_RESTORE, "restore_amount": 20.0 },
	{ "type": LootType.EQUIPMENT, "weight": 2, "grade": EquipmentGrade.COMMON },
]

# 筑基妖 drop table
var _tier_1_table: Array[Dictionary] = [
	{ "type": LootType.NOTHING, "weight": 15 },
	{ "type": LootType.LING_STONE, "weight": 35, "min_amount": 15, "max_amount": 40 },
	{ "type": LootType.PILL, "weight": 18, "pill_type": PillType.HP_RESTORE, "restore_amount": 60.0 },
	{ "type": LootType.PILL, "weight": 12, "pill_type": PillType.SP_RESTORE, "restore_amount": 40.0 },
	{ "type": LootType.PILL, "weight": 5, "pill_type": PillType.HP_SP_BOTH, "restore_amount": 35.0 },
	{ "type": LootType.EQUIPMENT, "weight": 10, "grade": EquipmentGrade.COMMON },
	{ "type": LootType.EQUIPMENT, "weight": 5, "grade": EquipmentGrade.FINE },
]

# 结丹妖 drop table
var _tier_2_table: Array[Dictionary] = [
	{ "type": LootType.NOTHING, "weight": 5 },
	{ "type": LootType.LING_STONE, "weight": 30, "min_amount": 30, "max_amount": 80 },
	{ "type": LootType.PILL, "weight": 15, "pill_type": PillType.HP_RESTORE, "restore_amount": 100.0 },
	{ "type": LootType.PILL, "weight": 12, "pill_type": PillType.SP_RESTORE, "restore_amount": 70.0 },
	{ "type": LootType.PILL, "weight": 8, "pill_type": PillType.HP_SP_BOTH, "restore_amount": 60.0 },
	{ "type": LootType.EQUIPMENT, "weight": 15, "grade": EquipmentGrade.COMMON },
	{ "type": LootType.EQUIPMENT, "weight": 10, "grade": EquipmentGrade.FINE },
	{ "type": LootType.EQUIPMENT, "weight": 5, "grade": EquipmentGrade.RARE },
]

# ─── Signals ───────────────────────────────────────────────────
signal loot_dropped(items: Array)

func _ready() -> void:
	print("[LootTable] Initialized")

# ─── Public API ────────────────────────────────────────────────
func roll_loot(enemy_tier: int) -> Array:
	"""Roll loot for a defeated enemy based on tier.
	
	Returns an Array of loot item dictionaries.
	Each item: { "type": LootType, "name": String, "data": Dictionary }
	"""
	var table := _get_table_for_tier(enemy_tier)
	var results: Array = []
	
	# Roll 1-2 items per enemy (higher tiers get bonus roll chance)
	var num_rolls := 1
	if randf() < 0.3 + (enemy_tier * 0.15):
		num_rolls = 2
	
	for _i in range(num_rolls):
		var entry := _weighted_random(table)
		if entry["type"] == LootType.NOTHING:
			continue
		
		var loot_item := _create_loot_item(entry)
		if not loot_item.is_empty():
			results.append(loot_item)
	
	if results.size() > 0:
		loot_dropped.emit(results)
		for item in results:
			print("[LootTable] Dropped: %s" % item["name"])
	
	return results

func _get_table_for_tier(tier: int) -> Array[Dictionary]:
	match tier:
		0: return _tier_0_table
		1: return _tier_1_table
		2: return _tier_2_table
		_: return _tier_0_table

# ─── Weighted Random Selection ─────────────────────────────────
func _weighted_random(table: Array[Dictionary]) -> Dictionary:
	"""Select a random entry from a weighted table."""
	var total_weight := 0
	for entry in table:
		total_weight += entry["weight"]
	
	var roll := randi() % total_weight
	var cumulative := 0
	
	for entry in table:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry
	
	return table[0]  # Fallback

# ─── Loot Item Creation ───────────────────────────────────────
func _create_loot_item(entry: Dictionary) -> Dictionary:
	"""Create a concrete loot item from a table entry."""
	match entry["type"]:
		LootType.LING_STONE:
			var amount := randi_range(entry["min_amount"], entry["max_amount"])
			return {
				"type": LootType.LING_STONE,
				"name": "灵石 x%d" % amount,
				"data": { "amount": amount },
			}
		
		LootType.PILL:
			var pill_name := _get_pill_name(entry["pill_type"])
			return {
				"type": LootType.PILL,
				"name": pill_name,
				"data": {
					"pill_type": entry["pill_type"],
					"restore_amount": entry["restore_amount"],
				},
			}
		
		LootType.EQUIPMENT:
			return _generate_equipment(entry["grade"])
		
		_:
			return {}

func _get_pill_name(pill_type: PillType) -> String:
	match pill_type:
		PillType.HP_RESTORE: return "回血丹"
		PillType.SP_RESTORE: return "回灵丹"
		PillType.HP_SP_BOTH: return "混元丹"
		_: return "丹药"

func _generate_equipment(grade: EquipmentGrade) -> Dictionary:
	"""Generate a random equipment piece with stats based on grade."""
	var grade_name := ""
	var stat_multiplier := 1.0
	
	match grade:
		EquipmentGrade.COMMON:
			grade_name = "凡品"
			stat_multiplier = 1.0
		EquipmentGrade.FINE:
			grade_name = "精品"
			stat_multiplier = 1.8
		EquipmentGrade.RARE:
			grade_name = "上品"
			stat_multiplier = 3.0
	
	# Random equipment type
	var slot_options := ["weapon", "armor", "accessory_1", "accessory_2", "talisman"]
	var slot: String = slot_options[randi() % slot_options.size()]
	
	var equip_names := {
		"weapon": ["灵剑", "法杖", "飞刃"],
		"armor": ["法袍", "玄甲", "灵衣"],
		"accessory_1": ["灵佩", "玉坠"],
		"accessory_2": ["灵戒", "仙环"],
		"talisman": ["护身符", "灵符"],
	}
	
	var names: Array = equip_names[slot]
	var base_name: String = names[randi() % names.size()]
	var full_name := "%s·%s" % [grade_name, base_name]
	
	# Generate stats based on slot
	var stats: Dictionary = {}
	match slot:
		"weapon":
			stats["attack"] = snapped(randf_range(3.0, 8.0) * stat_multiplier, 0.1)
		"armor":
			stats["defense"] = snapped(randf_range(2.0, 6.0) * stat_multiplier, 0.1)
			stats["hp"] = snapped(randf_range(10.0, 25.0) * stat_multiplier, 0.1)
		"accessory_1", "accessory_2":
			# Random stat
			if randf() > 0.5:
				stats["attack"] = snapped(randf_range(1.0, 4.0) * stat_multiplier, 0.1)
			else:
				stats["defense"] = snapped(randf_range(1.0, 3.0) * stat_multiplier, 0.1)
		"talisman":
			stats["hp"] = snapped(randf_range(5.0, 15.0) * stat_multiplier, 0.1)
			stats["defense"] = snapped(randf_range(1.0, 3.0) * stat_multiplier, 0.1)
	
	stats["name"] = full_name
	stats["slot"] = slot
	stats["grade"] = grade
	
	return {
		"type": LootType.EQUIPMENT,
		"name": full_name,
		"data": stats,
	}

# ─── Loot Application ─────────────────────────────────────────
func apply_loot(items: Array) -> void:
	"""Apply loot items — add to inventory, grant spirit stones, etc."""
	for item in items:
		match item["type"]:
			LootType.LING_STONE:
				PlayerData.add_spirit_stones(item["data"]["amount"])
			LootType.PILL:
				PlayerData.inventory.append(item["data"])
				PlayerData.inventory_changed.emit()
			LootType.EQUIPMENT:
				PlayerData.inventory.append(item["data"])
				PlayerData.inventory_changed.emit()
