extends Node
## EquipmentSystem — Equipment management, generation, and refinement
##
## Handles:
## - Equipment generation with random affixes
## - Rarity system (6 tiers from Mortal to Immortal)
## - Equipment comparison
## - Refinement (upgrading equipment stats)
## - Soul-binding (persist equipment through death)
## - Set bonus tracking

# ─── Rarity Tiers ─────────────────────────────────────────────
enum Rarity {
	MORTAL,    # 凡品 (White)  — 45% drop rate
	SPIRIT,    # 灵品 (Green)  — 30% drop rate
	TREASURE,  # 宝品 (Blue)   — 15% drop rate
	EARTH,     # 地品 (Purple) — 7% drop rate
	HEAVEN,    # 天品 (Gold)   — 2.5% drop rate
	IMMORTAL,  # 仙品 (Red)    — 0.5% drop rate
}

## Drop rate weights (must sum to 1.0)
const RARITY_WEIGHTS: Dictionary = {
	Rarity.MORTAL: 0.45,
	Rarity.SPIRIT: 0.30,
	Rarity.TREASURE: 0.15,
	Rarity.EARTH: 0.07,
	Rarity.HEAVEN: 0.025,
	Rarity.IMMORTAL: 0.005,
}

## Rarity display colors (for UI)
const RARITY_COLORS: Dictionary = {
	Rarity.MORTAL: Color.WHITE,
	Rarity.SPIRIT: Color.GREEN,
	Rarity.TREASURE: Color.DODGER_BLUE,
	Rarity.EARTH: Color.MEDIUM_PURPLE,
	Rarity.HEAVEN: Color.GOLD,
	Rarity.IMMORTAL: Color.CRIMSON,
}

## Number of random affixes per rarity
const RARITY_AFFIX_COUNT: Dictionary = {
	Rarity.MORTAL: 1,
	Rarity.SPIRIT: 2,
	Rarity.TREASURE: 2,
	Rarity.EARTH: 3,
	Rarity.HEAVEN: 3,
	Rarity.IMMORTAL: 4,
}

# ─── Equipment Slots ──────────────────────────────────────────
const VALID_SLOTS: Array[String] = ["weapon", "armor", "accessory_1", "accessory_2", "talisman"]

# ─── Affix Pool ────────────────────────────────────────────────
## Available random affixes that can roll on equipment
const AFFIX_POOL: Array[Dictionary] = [
	{ "id": "hp_flat", "name": "气血", "stat": "hp", "min": 10, "max": 100, "type": "flat" },
	{ "id": "attack_flat", "name": "攻击", "stat": "attack", "min": 3, "max": 30, "type": "flat" },
	{ "id": "defense_flat", "name": "防御", "stat": "defense", "min": 2, "max": 20, "type": "flat" },
	{ "id": "speed_pct", "name": "身法", "stat": "speed", "min": 0.05, "max": 0.3, "type": "percent" },
	{ "id": "luck_flat", "name": "气运", "stat": "luck", "min": 1, "max": 10, "type": "flat" },
	{ "id": "spirit_power", "name": "灵力", "stat": "spiritual_power", "min": 5, "max": 50, "type": "flat" },
	{ "id": "crit_rate", "name": "暴击率", "stat": "crit_rate", "min": 0.01, "max": 0.1, "type": "percent" },
	{ "id": "crit_damage", "name": "暴击伤害", "stat": "crit_damage", "min": 0.1, "max": 0.5, "type": "percent" },
]

# ─── Signals ───────────────────────────────────────────────────
signal equipment_generated(item: Dictionary)
signal equipment_refined(item: Dictionary, new_level: int)
signal equipment_soul_bound(item: Dictionary)

func _ready() -> void:
	print("[EquipmentSystem] Initialized")

# ─── Equipment Generation ─────────────────────────────────────
func generate_equipment(slot: String, floor_level: int, luck_modifier: float = 1.0) -> Dictionary:
	"""Generate a random piece of equipment.
	
	Args:
		slot: Equipment slot type (weapon, armor, etc.)
		floor_level: Current dungeon floor (affects stat scaling)
		luck_modifier: Player's luck stat affects rarity chances
	
	Returns: Dictionary representing the equipment item
	"""
	assert(slot in VALID_SLOTS, "Invalid slot: %s" % slot)
	
	var rarity := _roll_rarity(luck_modifier)
	var affix_count: int = RARITY_AFFIX_COUNT[rarity]
	var affixes := _roll_affixes(affix_count, floor_level)
	
	var item := {
		"id": _generate_item_id(),
		"slot": slot,
		"rarity": rarity,
		"name": _generate_item_name(slot, rarity),
		"level": floor_level,
		"refinement_level": 0,
		"max_refinement": rarity + 3,  # Higher rarity = more refinement
		"affixes": affixes,
		"set_id": "",  # Empty if not part of a set
		"soul_bound": false,
		"description": "",
	}
	
	# Calculate flattened stats for easy access
	_calculate_item_stats(item)
	
	equipment_generated.emit(item)
	return item

func _roll_rarity(luck_modifier: float) -> Rarity:
	"""Roll equipment rarity using weighted random with luck bonus.
	
	Higher luck shifts the distribution toward rarer items.
	"""
	var roll := randf()
	var adjusted_weights := RARITY_WEIGHTS.duplicate()
	
	# Luck shifts weight from common to rare
	if luck_modifier > 1.0:
		var shift := (luck_modifier - 1.0) * 0.05
		adjusted_weights[Rarity.MORTAL] -= shift
		adjusted_weights[Rarity.HEAVEN] += shift * 0.5
		adjusted_weights[Rarity.IMMORTAL] += shift * 0.5
	
	var cumulative := 0.0
	for rarity in Rarity.values():
		cumulative += adjusted_weights.get(rarity, 0.0)
		if roll <= cumulative:
			return rarity
	
	return Rarity.MORTAL  # Fallback

func _roll_affixes(count: int, floor_level: int) -> Array[Dictionary]:
	"""Roll random affixes for equipment."""
	var available := AFFIX_POOL.duplicate()
	available.shuffle()
	
	var result: Array[Dictionary] = []
	for i in range(min(count, available.size())):
		var template: Dictionary = available[i]
		var value_range: float = template["max"] - template["min"]
		var scaled_min: float = template["min"] * (1.0 + floor_level * 0.1)
		var scaled_max: float = template["max"] * (1.0 + floor_level * 0.1)
		var value: float = randf_range(scaled_min, scaled_max)
		
		result.append({
			"id": template["id"],
			"name": template["name"],
			"stat": template["stat"],
			"value": snapped(value, 0.01),
			"type": template["type"],
		})
	
	return result

func _calculate_item_stats(item: Dictionary) -> void:
	"""Flatten affixes into top-level stat keys for easy access."""
	for affix in item["affixes"]:
		item[affix["stat"]] = affix["value"]

# ─── Refinement ────────────────────────────────────────────────
func refine_equipment(item: Dictionary, materials_spent: int) -> bool:
	"""Attempt to refine (upgrade) equipment.
	
	Each refinement level increases all affix values by 10%.
	Returns true if refinement succeeded.
	"""
	if item["refinement_level"] >= item["max_refinement"]:
		print("[EquipmentSystem] Max refinement reached")
		return false
	
	# TODO: Check material cost based on rarity and refinement level
	# TODO: Deduct materials from player inventory
	
	item["refinement_level"] += 1
	
	# Boost all affix values by 10%
	for affix in item["affixes"]:
		affix["value"] *= 1.1
		affix["value"] = snapped(affix["value"], 0.01)
	
	_calculate_item_stats(item)
	equipment_refined.emit(item, item["refinement_level"])
	return true

# ─── Soul Binding ──────────────────────────────────────────────
func soul_bind_item(item: Dictionary) -> bool:
	"""Soul-bind an item so it persists through death.
	
	Limit: 1 soul-bound item per run.
	Cost: High-grade spirit stones.
	"""
	if item["soul_bound"]:
		return false
	
	# TODO: Check if player already soul-bound an item this run
	# TODO: Deduct high-grade spirit stones
	
	item["soul_bound"] = true
	equipment_soul_bound.emit(item)
	return true

# ─── Comparison ────────────────────────────────────────────────
func compare_equipment(item_a: Dictionary, item_b: Dictionary) -> Dictionary:
	"""Compare two equipment pieces, showing stat differences.
	
	Returns: Dictionary of { stat_name: { a: value, b: value, diff: value } }
	"""
	var all_stats: Array[String] = []
	for affix in item_a.get("affixes", []):
		if affix["stat"] not in all_stats:
			all_stats.append(affix["stat"])
	for affix in item_b.get("affixes", []):
		if affix["stat"] not in all_stats:
			all_stats.append(affix["stat"])
	
	var comparison := {}
	for stat in all_stats:
		var val_a: float = item_a.get(stat, 0.0)
		var val_b: float = item_b.get(stat, 0.0)
		comparison[stat] = {
			"a": val_a,
			"b": val_b,
			"diff": val_b - val_a,
		}
	
	return comparison

# ─── Helpers ───────────────────────────────────────────────────
func _generate_item_id() -> String:
	"""Generate a unique item ID."""
	return "item_%d_%d" % [Time.get_unix_time_from_system(), randi()]

func _generate_item_name(slot: String, rarity: Rarity) -> String:
	"""Generate a lore-appropriate item name.
	
	TODO: Pull from a name database with proper xianxia naming conventions.
	For now, use placeholder format.
	"""
	var rarity_prefix: Array[String] = ["凡", "灵", "宝", "地级", "天级", "仙"]
	var slot_names: Dictionary = {
		"weapon": "剑",
		"armor": "袍",
		"accessory_1": "佩",
		"accessory_2": "戒",
		"talisman": "符",
	}
	return "%s%s" % [rarity_prefix[rarity], slot_names.get(slot, "器")]
