extends Node
## BuffSystem — Global Autoload Singleton
##
## Manages timed buffs/debuffs on any entity (player or enemy).
## Buffs modify stats temporarily and expire after their duration.
##
## Usage:
##   BuffSystem.apply_buff(entity, { "type": BuffType.ATK_UP, "magnitude": 5.0, "duration": 10.0 })

# ─── Buff Types ────────────────────────────────────────────────
enum BuffType {
	ATK_UP,      # 攻击提升
	ATK_DOWN,    # 攻击降低
	DEF_UP,      # 防御提升
	DEF_DOWN,    # 防御降低
	SPEED_UP,    # 身法提升
	SPEED_DOWN,  # 身法降低
	REGEN_HP,    # 气血回复
	REGEN_SP,    # 灵力回复
	BURN,        # 灼烧 (DoT)
	FREEZE,      # 冰冻 (速度大幅降低)
	POISON,      # 中毒 (DoT + 攻击降低)
}

# ─── Buff Data Structure ──────────────────────────────────────
## Each active buff is a Dictionary:
## {
##   "type": BuffType,
##   "magnitude": float,     # Effect strength (damage/sec for DoT, flat bonus for stats)
##   "duration": float,      # Total duration in seconds
##   "remaining": float,     # Time left
##   "source": String,       # Who/what applied it (for stacking rules)
##   "tick_timer": float,    # Internal: for DoT tick tracking
## }

# Active buffs: { entity_instance_id: Array[Dictionary] }
var _active_buffs: Dictionary = {}

# DoT tick interval
const DOT_TICK_INTERVAL: float = 1.0

# ─── Signals ───────────────────────────────────────────────────
signal buff_applied(entity: Node, buff: Dictionary)
signal buff_expired(entity: Node, buff: Dictionary)
signal buff_tick(entity: Node, buff: Dictionary, tick_value: float)

func _ready() -> void:
	print("[BuffSystem] Initialized")

func _process(delta: float) -> void:
	tick(delta)

# ─── Public API ────────────────────────────────────────────────
func apply_buff(entity: Node, buff_data: Dictionary) -> void:
	"""Apply a buff/debuff to an entity.
	
	buff_data requires: type (BuffType), magnitude (float), duration (float)
	Optional: source (String)
	"""
	if entity == null or not is_instance_valid(entity):
		return
	
	var buff := {
		"type": buff_data.get("type", BuffType.ATK_UP),
		"magnitude": buff_data.get("magnitude", 1.0),
		"duration": buff_data.get("duration", 5.0),
		"remaining": buff_data.get("duration", 5.0),
		"source": buff_data.get("source", "unknown"),
		"tick_timer": 0.0,
	}
	
	var eid := entity.get_instance_id()
	if not _active_buffs.has(eid):
		_active_buffs[eid] = []
	
	# Check for existing buff of same type+source — refresh duration instead of stacking
	for existing in _active_buffs[eid]:
		if existing["type"] == buff["type"] and existing["source"] == buff["source"]:
			existing["remaining"] = buff["duration"]
			existing["magnitude"] = buff["magnitude"]
			print("[BuffSystem] Refreshed %s on %s" % [BuffType.keys()[buff["type"]], _entity_name(entity)])
			return
	
	_active_buffs[eid].append(buff)
	_apply_stat_modifier(entity, buff, true)
	buff_applied.emit(entity, buff)
	
	print("[BuffSystem] Applied %s (%.1f, %.1fs) on %s" % [
		BuffType.keys()[buff["type"]], buff["magnitude"], buff["duration"], _entity_name(entity)
	])

func remove_buff(entity: Node, buff_type: BuffType, source: String = "") -> void:
	"""Manually remove a specific buff from an entity."""
	if entity == null or not is_instance_valid(entity):
		return
	
	var eid := entity.get_instance_id()
	if not _active_buffs.has(eid):
		return
	
	var buffs: Array = _active_buffs[eid]
	for i in range(buffs.size() - 1, -1, -1):
		var buff: Dictionary = buffs[i]
		if buff["type"] == buff_type:
			if source == "" or buff["source"] == source:
				_apply_stat_modifier(entity, buff, false)
				buff_expired.emit(entity, buff)
				buffs.remove_at(i)

func get_buffs(entity: Node) -> Array:
	"""Get all active buffs on an entity."""
	if entity == null or not is_instance_valid(entity):
		return []
	var eid := entity.get_instance_id()
	return _active_buffs.get(eid, [])

func has_buff(entity: Node, buff_type: BuffType) -> bool:
	"""Check if entity has a specific buff type active."""
	for buff in get_buffs(entity):
		if buff["type"] == buff_type:
			return true
	return false

func clear_all_buffs(entity: Node) -> void:
	"""Remove all buffs from an entity."""
	if entity == null or not is_instance_valid(entity):
		return
	var eid := entity.get_instance_id()
	if _active_buffs.has(eid):
		for buff in _active_buffs[eid]:
			_apply_stat_modifier(entity, buff, false)
			buff_expired.emit(entity, buff)
		_active_buffs.erase(eid)

# ─── Tick Processing ──────────────────────────────────────────
func tick(delta: float) -> void:
	"""Update all active buffs. Called every frame."""
	var entities_to_clean: Array = []
	
	for eid in _active_buffs:
		var entity := instance_from_id(eid) as Node
		if entity == null or not is_instance_valid(entity):
			entities_to_clean.append(eid)
			continue
		
		var buffs: Array = _active_buffs[eid]
		var expired_indices: Array[int] = []
		
		for i in range(buffs.size()):
			var buff: Dictionary = buffs[i]
			buff["remaining"] -= delta
			
			# Process DoT effects
			if buff["type"] in [BuffType.BURN, BuffType.POISON, BuffType.REGEN_HP, BuffType.REGEN_SP]:
				buff["tick_timer"] += delta
				if buff["tick_timer"] >= DOT_TICK_INTERVAL:
					buff["tick_timer"] -= DOT_TICK_INTERVAL
					_process_dot_tick(entity, buff)
			
			if buff["remaining"] <= 0.0:
				expired_indices.append(i)
		
		# Remove expired (reverse order to preserve indices)
		for i in range(expired_indices.size() - 1, -1, -1):
			var idx: int = expired_indices[i]
			var buff: Dictionary = buffs[idx]
			_apply_stat_modifier(entity, buff, false)
			buff_expired.emit(entity, buff)
			print("[BuffSystem] Expired %s on %s" % [BuffType.keys()[buff["type"]], _entity_name(entity)])
			buffs.remove_at(idx)
	
	# Clean up dead entities
	for eid in entities_to_clean:
		_active_buffs.erase(eid)

func remove_expired_buffs() -> void:
	"""Force-remove all expired buffs (called externally if needed)."""
	tick(0.0)

# ─── Internal: Stat Modifiers ─────────────────────────────────
func _apply_stat_modifier(entity: Node, buff: Dictionary, is_apply: bool) -> void:
	"""Apply or remove a stat modifier from an entity.
	
	is_apply=true: add the modifier. is_apply=false: reverse it.
	DoT effects (BURN, POISON, REGEN_HP, REGEN_SP) don't modify stats directly.
	"""
	var sign := 1.0 if is_apply else -1.0
	var mag: float = buff["magnitude"] * sign
	
	match buff["type"]:
		BuffType.ATK_UP:
			if entity == _get_player_node():
				PlayerData.base_attack += mag
			elif "attack_power" in entity:
				entity.attack_power += mag
		BuffType.ATK_DOWN:
			if entity == _get_player_node():
				PlayerData.base_attack -= mag
			elif "attack_power" in entity:
				entity.attack_power -= mag
		BuffType.DEF_UP:
			if entity == _get_player_node():
				PlayerData.base_defense += mag
			elif "defense" in entity:
				entity.defense += mag
		BuffType.DEF_DOWN:
			if entity == _get_player_node():
				PlayerData.base_defense -= mag
			elif "defense" in entity:
				entity.defense -= mag
		BuffType.SPEED_UP:
			if entity == _get_player_node():
				PlayerData.base_speed += mag
			elif "move_speed" in entity:
				entity.move_speed += mag
		BuffType.SPEED_DOWN:
			if entity == _get_player_node():
				PlayerData.base_speed -= mag
			elif "move_speed" in entity:
				entity.move_speed -= mag
		BuffType.FREEZE:
			# Freeze: massive speed reduction
			if entity == _get_player_node():
				PlayerData.base_speed -= mag
			elif "move_speed" in entity:
				entity.move_speed -= mag
		# DoT types handled in _process_dot_tick
		_:
			pass

func _process_dot_tick(entity: Node, buff: Dictionary) -> void:
	"""Process one tick of a damage/heal-over-time effect."""
	var tick_value: float = buff["magnitude"]
	
	match buff["type"]:
		BuffType.BURN:
			if entity.has_method("take_damage"):
				entity.take_damage(tick_value)
			buff_tick.emit(entity, buff, tick_value)
		BuffType.POISON:
			# Poison does 70% of BURN damage
			var poison_dmg := tick_value * 0.7
			if entity.has_method("take_damage"):
				entity.take_damage(poison_dmg)
			buff_tick.emit(entity, buff, poison_dmg)
		BuffType.REGEN_HP:
			if entity.has_method("heal"):
				entity.heal(tick_value)
			elif entity == _get_player_node():
				var player := _get_player_node()
				if player:
					player.current_hp = min(player.max_hp, player.current_hp + tick_value)
			buff_tick.emit(entity, buff, tick_value)
		BuffType.REGEN_SP:
			if entity == _get_player_node():
				var player := _get_player_node()
				if player:
					player.current_sp = min(player.max_sp, player.current_sp + tick_value)
			buff_tick.emit(entity, buff, tick_value)

# ─── Helpers ───────────────────────────────────────────────────
func _get_player_node() -> Node:
	"""Find the player node in scene tree."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _entity_name(entity: Node) -> String:
	if "enemy_name" in entity:
		return entity.enemy_name
	if "player_name" in entity:
		return entity.player_name
	return entity.name

## ─── Convenience: Get total buff magnitude for a type ─────────
func get_total_magnitude(entity: Node, buff_type: BuffType) -> float:
	"""Sum all active buff magnitudes of a given type on an entity."""
	var total := 0.0
	for buff in get_buffs(entity):
		if buff["type"] == buff_type:
			total += buff["magnitude"]
	return total
