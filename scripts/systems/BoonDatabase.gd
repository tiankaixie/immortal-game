extends Node
## BoonDatabase — Autoload singleton for dungeon run boons
##
## Contains all available boons and handles applying them to player stats.
## Boons are temporary buffs that last for the current dungeon run.

# ─── Boon Data Structure ──────────────────────────────────────
# Each boon is a Dictionary with:
#   id: String, name_zh: String, name_en: String,
#   description: String, icon_emoji: String,
#   apply: Callable (called when boon is selected)

var all_boons: Array[Dictionary] = []
var acquired_boons: Array[String] = []  # IDs of boons acquired this run

# Boon stat modifiers (accumulated during run)
var atk_multiplier: float = 1.0
var def_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var hp_regen_per_sec: float = 0.0
var sp_max_bonus: float = 0.0
var dash_cooldown_reduction: float = 0.0
var double_strike_chance: float = 0.0
var iron_body_chance: float = 0.0
var skill_damage_multiplier: float = 1.0
var loot_tier_bonus: int = 0
var skill_slot_bonus: int = 0
var burn_damage_multiplier: float = 1.0

func _ready() -> void:
	_init_boons()
	print("[BoonDatabase] Initialized with %d boons" % all_boons.size())

func _process(delta: float) -> void:
	# Apply HP regen if active
	if hp_regen_per_sec > 0.0:
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if p.has_method("heal") and p.current_hp < p.max_hp:
				p.heal(hp_regen_per_sec * delta)

func _init_boons() -> void:
	all_boons = [
		{
			"id": "atk_up",
			"name_zh": "锐金诀",
			"name_en": "ATK Up",
			"description": "攻击力提升 15%",
			"icon_emoji": "⚔️",
			"rarity": 0,  # 0=common, 1=rare, 2=legendary
		},
		{
			"id": "def_up",
			"name_zh": "玄铁体",
			"name_en": "DEF Up",
			"description": "防御力提升 20%",
			"icon_emoji": "🛡️",
			"rarity": 0,
		},
		{
			"id": "speed_up",
			"name_zh": "御风术",
			"name_en": "Speed Up",
			"description": "移动速度提升 10%",
			"icon_emoji": "💨",
			"rarity": 0,
		},
		{
			"id": "hp_regen",
			"name_zh": "生生不息",
			"name_en": "HP Regen",
			"description": "每秒恢复 2 点气血",
			"icon_emoji": "💚",
			"rarity": 0,
		},
		{
			"id": "sp_max_up",
			"name_zh": "灵海扩容",
			"name_en": "SP Max Up",
			"description": "灵力上限 +20",
			"icon_emoji": "🔮",
			"rarity": 0,
		},
		{
			"id": "dash_reduce",
			"name_zh": "缩地成寸",
			"name_en": "Dash CD Reduce",
			"description": "闪避冷却 -0.2秒",
			"icon_emoji": "⚡",
			"rarity": 1,
		},
		{
			"id": "double_strike",
			"name_zh": "连环剑意",
			"name_en": "Double Strike",
			"description": "10% 概率额外攻击一次",
			"icon_emoji": "🗡️",
			"rarity": 1,
		},
		{
			"id": "iron_body",
			"name_zh": "金刚不坏",
			"name_en": "Iron Body",
			"description": "20% 概率免疫伤害",
			"icon_emoji": "🪨",
			"rarity": 1,
		},
		{
			"id": "spirit_burst",
			"name_zh": "灵力爆发",
			"name_en": "Spirit Burst",
			"description": "技能伤害 +25%",
			"icon_emoji": "✨",
			"rarity": 1,
		},
		{
			"id": "lucky_drop",
			"name_zh": "福星高照",
			"name_en": "Lucky Drop",
			"description": "掉落品质 +1 阶",
			"icon_emoji": "🍀",
			"rarity": 1,
		},
		{
			"id": "swift_hands",
			"name_zh": "千手观音",
			"name_en": "Swift Hands",
			"description": "解锁 +1 技能槽",
			"icon_emoji": "🙌",
			"rarity": 2,
		},
		{
			"id": "eternal_flame",
			"name_zh": "三昧真火",
			"name_en": "Eternal Flame",
			"description": "燃烧的敌人额外承受 5% 伤害",
			"icon_emoji": "🔥",
			"rarity": 2,
		},
	]

# ─── Boon Application ─────────────────────────────────────────
func apply_boon(boon_id: String) -> void:
	"""Apply a boon's effect to the current run."""
	acquired_boons.append(boon_id)

	match boon_id:
		"atk_up":
			atk_multiplier += 0.15
			PlayerData.base_attack *= 1.15
		"def_up":
			def_multiplier += 0.20
			PlayerData.base_defense *= 1.20
		"speed_up":
			speed_multiplier += 0.10
			PlayerData.base_speed *= 1.10
		"hp_regen":
			hp_regen_per_sec += 2.0
		"sp_max_up":
			sp_max_bonus += 20.0
			PlayerData.base_spiritual_power += 20.0
			PlayerData._recalculate_sp_max()
			PlayerData.restore_sp(20.0)
		"dash_reduce":
			dash_cooldown_reduction += 0.2
			# Applied in Player._start_dash
		"double_strike":
			double_strike_chance += 0.10
		"iron_body":
			iron_body_chance += 0.20
		"spirit_burst":
			skill_damage_multiplier += 0.25
		"lucky_drop":
			loot_tier_bonus += 1
		"swift_hands":
			skill_slot_bonus += 1
			PlayerData.skill_slots += 1
		"eternal_flame":
			burn_damage_multiplier += 0.05

	print("[BoonDatabase] Applied boon: %s" % boon_id)

# ─── Random Selection ─────────────────────────────────────────
func get_random_boons(count: int = 3) -> Array[Dictionary]:
	"""Return `count` random boons, avoiding duplicates already acquired (where stackable doesn't apply)."""
	var available := all_boons.duplicate()
	available.shuffle()

	var result: Array[Dictionary] = []
	for boon in available:
		if result.size() >= count:
			break
		result.append(boon)

	return result

# ─── Run Reset ─────────────────────────────────────────────────
func reset_run() -> void:
	"""Reset all boon state for a new run."""
	acquired_boons.clear()
	atk_multiplier = 1.0
	def_multiplier = 1.0
	speed_multiplier = 1.0
	hp_regen_per_sec = 0.0
	sp_max_bonus = 0.0
	dash_cooldown_reduction = 0.0
	double_strike_chance = 0.0
	iron_body_chance = 0.0
	skill_damage_multiplier = 1.0
	loot_tier_bonus = 0
	skill_slot_bonus = 0
	burn_damage_multiplier = 1.0
	print("[BoonDatabase] Run reset — all boons cleared")

# ─── Query ─────────────────────────────────────────────────────
func get_boon_by_id(boon_id: String) -> Dictionary:
	for boon in all_boons:
		if boon["id"] == boon_id:
			return boon
	return {}

func has_boon(boon_id: String) -> bool:
	return boon_id in acquired_boons
