extends Node
## PlayerData — Global Autoload Singleton
##
## Stores all persistent player data:
## - Cultivation realm and stage
## - Spiritual root type
## - Stats
## - Equipment inventory
## - Spirit stones (currency)
## - Unlocked techniques/skills
##
## This data persists between runs and is saved to disk.

# ─── Cultivation Realms ────────────────────────────────────────
## Enum values match GDD cultivation progression (9 realms)
enum CultivationRealm {
	QI_CONDENSATION,         # 练气期
	FOUNDATION_ESTABLISHMENT, # 筑基期
	CORE_FORMATION,          # 结丹期
	NASCENT_SOUL,            # 元婴期
	SOUL_TRANSFORMATION,     # 化神期
	VOID_REFINEMENT,         # 炼虚期
	BODY_INTEGRATION,        # 合体期
	MAHAYANA,                # 大乘期
	TRIBULATION_TRANSCENDENCE, # 渡劫期
}

## Sub-stages within each realm
enum CultivationStage {
	EARLY,   # 初期
	MID,     # 中期
	LATE,    # 后期
	PEAK,    # 巅峰
}

# ─── Spiritual Roots (五行灵根) ────────────────────────────────
enum SpiritualRoot {
	METAL,     # 金 — Attack bonus, sharp/cutting techniques
	WOOD,      # 木 — Healing bonus, growth/nature techniques
	WATER,     # 水 — Defense bonus, ice/flow techniques
	FIRE,      # 火 — AoE damage bonus, flame techniques
	EARTH,     # 土 — HP/stamina bonus, shield/stone techniques
	# Special roots (unlockable)
	LIGHTNING, # 雷 — Speed + crit bonus
	VOID,      # 空 — Spatial manipulation
}

# ─── Persistent Player Data ────────────────────────────────────
var player_name: String = "修士"  # Default: "Cultivator"
var spiritual_root: SpiritualRoot = SpiritualRoot.METAL

# Cultivation
var cultivation_realm: CultivationRealm = CultivationRealm.QI_CONDENSATION
var cultivation_stage: CultivationStage = CultivationStage.EARLY
var cultivation_xp: float = 0.0            # Progress toward next stage
var cultivation_xp_required: float = 100.0  # XP needed for next stage

# Base Stats (modified by cultivation realm, equipment, spiritual root)
var base_hp: float = 100.0          # 气血
var base_spiritual_power: float = 50.0  # 灵力 (base max SP)
var sp: float = 50.0                # 当前灵力 (current SP)
var sp_max: float = 50.0            # 灵力上限 (max SP, computed from base + bonuses)
var base_attack: float = 10.0       # 攻击
var base_defense: float = 5.0       # 防御
var base_speed: float = 1.0         # 身法
var base_luck: float = 1.0          # 气运
var in_combat: bool = false         # 是否在战斗中 (for SP regen)

# Economy
var spirit_stones: int = 0           # 灵石 (primary currency)
var high_grade_stones: int = 0       # 上品灵石 (premium currency)

# Equipment (slot_name → equipment_data dictionary)
var equipped_items: Dictionary = {
	"weapon": null,      # 法器/灵剑
	"armor": null,       # 法袍
	"accessory_1": null, # 灵佩
	"accessory_2": null, # 灵戒
	"talisman": null,    # 护身符
}

# Inventory
var inventory: Array = []           # Array of equipment/item dictionaries
var max_inventory_size: int = 50

# Unlocked skills/techniques
var unlocked_skills: Array[String] = []  # Skill IDs from the Library Pavilion
var equipped_skills: Array[String] = []  # Currently equipped skill IDs (max = skill_slots)
var skill_slots: int = 2                  # Increases with cultivation realm

# ─── Signals ───────────────────────────────────────────────────
signal cultivation_advanced(realm: CultivationRealm, stage: CultivationStage)
signal cultivation_xp_gained(amount: float, total: float)
signal spirit_stones_changed(new_total: int)
signal equipment_changed(slot: String)
signal inventory_changed()
signal sp_updated(current: float, maximum: float)
signal skill_learned(skill_id: String)
signal realm_changed(realm: int, stage: int)

func _ready() -> void:
	_recalculate_sp_max()
	print("[PlayerData] Initialized — Realm: %s, Stage: %s" % [
		CultivationRealm.keys()[cultivation_realm],
		CultivationStage.keys()[cultivation_stage]
	])

# ─── Cultivation ───────────────────────────────────────────────
func add_cultivation_xp(amount: float) -> void:
	"""Add cultivation XP. Automatically triggers advancement if threshold met."""
	cultivation_xp += amount
	cultivation_xp_gained.emit(amount, cultivation_xp)
	
	while cultivation_xp >= cultivation_xp_required:
		_advance_cultivation()

func _advance_cultivation() -> void:
	"""Advance to next cultivation stage or realm."""
	cultivation_xp -= cultivation_xp_required
	
	if cultivation_stage < CultivationStage.PEAK:
		# Advance to next stage within current realm
		cultivation_stage = (cultivation_stage + 1) as CultivationStage
	else:
		# Advance to next realm (requires tribulation in full implementation)
		if cultivation_realm < CultivationRealm.TRIBULATION_TRANSCENDENCE:
			cultivation_realm = (cultivation_realm + 1) as CultivationRealm
			cultivation_stage = CultivationStage.EARLY
			_on_realm_breakthrough()
	
	# Scale XP requirement (each stage requires more)
	cultivation_xp_required *= 1.5
	cultivation_advanced.emit(cultivation_realm, cultivation_stage)

func _on_realm_breakthrough() -> void:
	"""Handle realm-up effects: stat boosts, new skill slots, etc."""
	# TODO: Trigger tribulation challenge before actually advancing
	# TODO: Apply realm-specific stat multipliers

	# Emit realm_changed signal for UI notifications
	realm_changed.emit(cultivation_realm, cultivation_stage)

	# Unlock additional skill slot at key realms
	match cultivation_realm:
		CultivationRealm.FOUNDATION_ESTABLISHMENT:
			skill_slots = 3
		CultivationRealm.NASCENT_SOUL:
			skill_slots = 4
		CultivationRealm.SOUL_TRANSFORMATION:
			skill_slots = 5
		CultivationRealm.BODY_INTEGRATION:
			skill_slots = 6

# ─── SP Management ─────────────────────────────────────────────
func _recalculate_sp_max() -> void:
	"""Recalculate max SP from base + realm bonuses."""
	var realm_multiplier := 1.0 + (cultivation_realm * 0.25)
	var equip_bonus := _get_equipment_stat_bonus("sp")
	sp_max = base_spiritual_power * realm_multiplier + equip_bonus
	sp = min(sp, sp_max)

func spend_sp(amount: float) -> bool:
	"""Attempt to spend SP. Returns false if insufficient."""
	if sp >= amount:
		sp -= amount
		sp_updated.emit(sp, sp_max)
		return true
	return false

func restore_sp(amount: float) -> void:
	"""Restore SP up to max."""
	sp = min(sp_max, sp + amount)
	sp_updated.emit(sp, sp_max)

func regenerate_sp(delta: float) -> void:
	"""Regenerate SP passively when not in combat. 1 SP/sec."""
	if not in_combat and sp < sp_max:
		sp = min(sp_max, sp + 1.0 * delta)
		sp_updated.emit(sp, sp_max)

func _process(delta: float) -> void:
	regenerate_sp(delta)

# ─── Computed Stats (base + equipment + realm bonuses) ─────────
func get_total_hp() -> float:
	"""Calculate total HP from base + equipment + realm modifier."""
	var realm_multiplier := 1.0 + (cultivation_realm * 0.3)
	var equip_bonus := _get_equipment_stat_bonus("hp")
	return base_hp * realm_multiplier + equip_bonus

func get_total_attack() -> float:
	var realm_multiplier := 1.0 + (cultivation_realm * 0.2)
	var equip_bonus := _get_equipment_stat_bonus("attack")
	var root_bonus := 1.1 if spiritual_root == SpiritualRoot.METAL else 1.0
	return base_attack * realm_multiplier * root_bonus + equip_bonus

func get_total_defense() -> float:
	var realm_multiplier := 1.0 + (cultivation_realm * 0.2)
	var equip_bonus := _get_equipment_stat_bonus("defense")
	var root_bonus := 1.1 if spiritual_root == SpiritualRoot.WATER else 1.0
	return base_defense * realm_multiplier * root_bonus + equip_bonus

func get_total_sp_max() -> float:
	"""Calculate total max SP from base + equipment + realm modifier."""
	var realm_multiplier := 1.0 + (cultivation_realm * 0.25)
	var equip_bonus := _get_equipment_stat_bonus("sp")
	return base_spiritual_power * realm_multiplier + equip_bonus

func _get_equipment_stat_bonus(stat_name: String) -> float:
	"""Sum a stat bonus across all equipped items."""
	var total := 0.0
	for slot in equipped_items:
		var item = equipped_items[slot]
		if item != null and item.has(stat_name):
			total += item[stat_name]
	return total

# ─── Economy ───────────────────────────────────────────────────
func add_spirit_stones(amount: int) -> void:
	if amount > 0:
		RunStats.spirit_stones_collected += amount
	spirit_stones += amount
	spirit_stones_changed.emit(spirit_stones)

func spend_spirit_stones(amount: int) -> bool:
	"""Attempt to spend spirit stones. Returns false if insufficient."""
	if spirit_stones >= amount:
		spirit_stones -= amount
		spirit_stones_changed.emit(spirit_stones)
		return true
	return false

# ─── Inventory Management ─────────────────────────────────────
func add_to_inventory(item: Dictionary) -> bool:
	"""Add an item to the player's inventory. Returns false if inventory is full."""
	if inventory.size() >= max_inventory_size:
		push_warning("[PlayerData] Inventory full (%d/%d), cannot add item" % [inventory.size(), max_inventory_size])
		return false
	inventory.append(item)
	inventory_changed.emit()
	print("[PlayerData] Item added to inventory: %s (total: %d/%d)" % [item.get("name", "Unknown"), inventory.size(), max_inventory_size])
	return true

func remove_from_inventory(index: int) -> Dictionary:
	"""Remove an item from inventory by index. Returns the removed item or empty dict."""
	if index < 0 or index >= inventory.size():
		return {}
	var item: Dictionary = inventory[index]
	inventory.remove_at(index)
	inventory_changed.emit()
	return item

# ─── Equipment ─────────────────────────────────────────────────
func equip_item(slot: String, item: Dictionary) -> Dictionary:
	"""Equip an item to a slot. Returns the previously equipped item (or empty dict)."""
	if not equipped_items.has(slot):
		push_error("[PlayerData] Invalid equipment slot: %s" % slot)
		return {}
	
	var old_item = equipped_items[slot]
	equipped_items[slot] = item
	equipment_changed.emit(slot)
	
	return old_item if old_item != null else {}

func unequip_item(slot: String) -> Dictionary:
	"""Remove item from slot and return it."""
	var old_item = equipped_items.get(slot)
	equipped_items[slot] = null
	equipment_changed.emit(slot)
	return old_item if old_item != null else {}

# ─── Skill Management ──────────────────────────────────────────
func learn_skill(skill_id: String) -> bool:
	"""Unlock a new skill. Returns false if already unlocked or invalid."""
	if skill_id in unlocked_skills:
		print("[PlayerData] Skill already unlocked: %s" % skill_id)
		return false
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		push_warning("[PlayerData] Cannot learn unknown skill: %s" % skill_id)
		return false
	unlocked_skills.append(skill_id)
	# Auto-equip if there's an open slot
	if equipped_skills.size() < skill_slots and skill_id not in equipped_skills:
		equipped_skills.append(skill_id)
	skill_learned.emit(skill_id)
	print("[PlayerData] Learned skill: %s (%s)" % [skill.get("name_zh", skill_id), skill_id])
	return true

# ─── Serialization ─────────────────────────────────────────────
func to_dict() -> Dictionary:
	"""Serialize player data to dictionary for saving."""
	return {
		"player_name": player_name,
		"spiritual_root": spiritual_root,
		"cultivation_realm": cultivation_realm,
		"cultivation_stage": cultivation_stage,
		"cultivation_xp": cultivation_xp,
		"cultivation_xp_required": cultivation_xp_required,
		"sp": sp,
		"sp_max": sp_max,
		"spirit_stones": spirit_stones,
		"high_grade_stones": high_grade_stones,
		"equipped_items": equipped_items,
		"inventory": inventory,
		"unlocked_skills": unlocked_skills,
		"equipped_skills": equipped_skills,
		"skill_slots": skill_slots,
	}

func from_dict(data: Dictionary) -> void:
	"""Deserialize player data from dictionary."""
	player_name = data.get("player_name", "修士")
	spiritual_root = data.get("spiritual_root", SpiritualRoot.METAL)
	cultivation_realm = data.get("cultivation_realm", CultivationRealm.QI_CONDENSATION)
	cultivation_stage = data.get("cultivation_stage", CultivationStage.EARLY)
	cultivation_xp = data.get("cultivation_xp", 0.0)
	cultivation_xp_required = data.get("cultivation_xp_required", 100.0)
	sp = data.get("sp", base_spiritual_power)
	sp_max = data.get("sp_max", base_spiritual_power)
	spirit_stones = data.get("spirit_stones", 0)
	high_grade_stones = data.get("high_grade_stones", 0)
	equipped_items = data.get("equipped_items", equipped_items)
	inventory = data.get("inventory", [])
	unlocked_skills = data.get("unlocked_skills", [])
	equipped_skills = data.get("equipped_skills", [])
	skill_slots = data.get("skill_slots", 2)
