extends Node
## CombatSystem — Manages combat encounters
##
## Handles:
## - Auto-battle loop (primary mode)
## - Manual override detection
## - Skill execution and cooldowns
## - Damage calculation and application
## - Combat state machine
## - Win/lose conditions
##
## Design: Auto-battle runs by default. When the player provides manual
## input (movement, skill use, dodge), auto-battle pauses for that action
## then resumes. Toggle auto-battle with Q key.

# ─── Combat States ─────────────────────────────────────────────
enum CombatState {
	IDLE,          # No combat
	ENGAGING,      # Entering combat (camera transition, etc.)
	AUTO_BATTLE,   # AI controlling player character
	MANUAL,        # Player has taken manual control
	SKILL_CAST,    # Executing a skill animation
	DODGING,       # i-frame dodge
	STUNNED,       # Cannot act
	VICTORY,       # All enemies defeated
	DEFEAT,        # Player HP reached 0
}

# ─── State ─────────────────────────────────────────────────────
var current_state: CombatState = CombatState.IDLE
var auto_battle_enabled: bool = true
var manual_override_timer: float = 0.0  # Seconds since last manual input
const MANUAL_TIMEOUT: float = 3.0       # Return to auto after 3s of no input

# Combat participants
var player_entity: Node = null          # Reference to player CharacterBody3D
var enemies: Array[Node] = []           # Active enemies in current room
var current_target: Node = null         # Auto-battle's current target

# Skill cooldowns: { skill_id: remaining_cooldown }
var skill_cooldowns: Dictionary = {}

# ─── Signals ───────────────────────────────────────────────────
signal combat_started()
signal combat_ended(victory: bool)
signal state_changed(new_state: CombatState)
signal enemy_defeated(enemy: Node)
signal damage_dealt(target: Node, amount: float, is_critical: bool)
signal skill_used(skill_id: String)
signal auto_battle_toggled(enabled: bool)

func _ready() -> void:
	print("[CombatSystem] Initialized")

func _process(delta: float) -> void:
	match current_state:
		CombatState.AUTO_BATTLE:
			_process_auto_battle(delta)
		CombatState.MANUAL:
			_process_manual_mode(delta)
		CombatState.SKILL_CAST:
			pass  # Wait for skill animation to complete
		CombatState.DODGING:
			pass  # Wait for dodge to complete

	# Update skill cooldowns
	_update_cooldowns(delta)

# ─── Combat Lifecycle ──────────────────────────────────────────
func start_combat(player: Node, enemy_list: Array[Node]) -> void:
	"""Initialize a combat encounter."""
	player_entity = player
	enemies = enemy_list
	current_target = _find_nearest_enemy()
	
	_change_state(CombatState.ENGAGING)
	combat_started.emit()
	
	# TODO: Play combat start animation/transition
	# After transition, enter auto or manual based on setting
	if auto_battle_enabled:
		_change_state(CombatState.AUTO_BATTLE)
	else:
		_change_state(CombatState.MANUAL)

func end_combat(victory: bool) -> void:
	"""Clean up after combat ends."""
	current_target = null
	enemies.clear()
	_change_state(CombatState.VICTORY if victory else CombatState.DEFEAT)
	combat_ended.emit(victory)

# ─── Auto-Battle Logic ────────────────────────────────────────
func _process_auto_battle(delta: float) -> void:
	"""AI-controlled combat loop.
	
	Priority:
	1. Dodge telegraphed attacks (if detected)
	2. Use highest-priority available skill
	3. Basic attack nearest enemy
	4. Move toward nearest enemy if out of range
	"""
	if enemies.is_empty():
		end_combat(true)
		return
	
	# Validate current target
	if current_target == null or not is_instance_valid(current_target):
		current_target = _find_nearest_enemy()
		if current_target == null:
			end_combat(true)
			return
	
	# TODO: Check for incoming telegraphed attacks → auto-dodge
	# Auto-dodge is less efficient than manual (70% dodge vs 100%)
	
	# TODO: Try to use best available skill
	var best_skill := _get_best_available_skill()
	if best_skill != "":
		use_skill(best_skill)
		return
	
	# TODO: Basic attack if in range, otherwise move toward target
	# _perform_basic_attack(current_target)
	# _move_toward(current_target)

func _get_best_available_skill() -> String:
	"""Determine the highest-priority skill that's off cooldown.
	
	Priority order (configurable by player):
	1. Defensive skills (if HP below threshold)
	2. AoE skills (if multiple enemies nearby)
	3. Highest damage single-target skill
	"""
	# TODO: Implement skill priority system
	# Check PlayerData.equipped_skills, filter by cooldown, sort by priority
	for skill_id in PlayerData.equipped_skills:
		if not skill_cooldowns.has(skill_id) or skill_cooldowns[skill_id] <= 0:
			return skill_id
	return ""

# ─── Manual Override ───────────────────────────────────────────
func on_manual_input() -> void:
	"""Called when player provides any manual input during combat.
	Switches from auto to manual mode temporarily."""
	if current_state == CombatState.AUTO_BATTLE:
		_change_state(CombatState.MANUAL)
	manual_override_timer = 0.0

func _process_manual_mode(delta: float) -> void:
	"""Track manual mode duration. Return to auto after timeout."""
	manual_override_timer += delta
	if auto_battle_enabled and manual_override_timer >= MANUAL_TIMEOUT:
		_change_state(CombatState.AUTO_BATTLE)
	
	# Check win/lose during manual mode too
	if enemies.is_empty():
		end_combat(true)

func toggle_auto_battle() -> void:
	"""Toggle auto-battle on/off (Q key)."""
	auto_battle_enabled = !auto_battle_enabled
	auto_battle_toggled.emit(auto_battle_enabled)
	
	if auto_battle_enabled and current_state == CombatState.MANUAL:
		_change_state(CombatState.AUTO_BATTLE)
	elif not auto_battle_enabled and current_state == CombatState.AUTO_BATTLE:
		_change_state(CombatState.MANUAL)

# ─── Skills ───────────────────────────────────────────────────
func use_skill(skill_id: String) -> void:
	"""Execute a skill by ID."""
	# TODO: Look up skill data from skill database
	# TODO: Check mana cost, apply cost
	# TODO: Play skill animation
	# TODO: Apply damage/effects to targets
	# TODO: Set cooldown
	
	skill_cooldowns[skill_id] = 5.0  # Placeholder cooldown
	skill_used.emit(skill_id)
	print("[CombatSystem] Skill used: %s" % skill_id)

func _update_cooldowns(delta: float) -> void:
	"""Tick down all skill cooldowns."""
	for skill_id in skill_cooldowns:
		skill_cooldowns[skill_id] = max(0.0, skill_cooldowns[skill_id] - delta)

# ─── Damage Calculation ───────────────────────────────────────
func calculate_damage(attacker_attack: float, defender_defense: float, skill_multiplier: float = 1.0) -> Dictionary:
	"""Calculate damage dealt.
	
	Formula: damage = (attack * skill_multiplier - defense * 0.5) * variance * crit
	Returns: { amount: float, is_critical: bool }
	"""
	var base_damage := attacker_attack * skill_multiplier - defender_defense * 0.5
	base_damage = max(1.0, base_damage)  # Minimum 1 damage
	
	# Variance (±10%)
	var variance := randf_range(0.9, 1.1)
	
	# Critical hit (based on luck stat)
	var crit_chance := 0.05 + (PlayerData.base_luck * 0.02)
	var is_critical := randf() < crit_chance
	var crit_multiplier := 1.5 if is_critical else 1.0
	
	var final_damage := base_damage * variance * crit_multiplier
	
	return {
		"amount": final_damage,
		"is_critical": is_critical,
	}

func apply_damage(target: Node, damage_info: Dictionary) -> void:
	"""Apply calculated damage to a target entity."""
	# TODO: Call target's take_damage method
	# TODO: Check if target is defeated
	# TODO: Show damage number popup
	damage_dealt.emit(target, damage_info["amount"], damage_info["is_critical"])

# ─── Helpers ───────────────────────────────────────────────────
func _find_nearest_enemy() -> Node:
	"""Find the closest living enemy to the player."""
	if player_entity == null or enemies.is_empty():
		return null
	
	var nearest: Node = null
	var nearest_dist := INF
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist: float = player_entity.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy
	
	return nearest

func _change_state(new_state: CombatState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func on_enemy_defeated(enemy: Node) -> void:
	"""Called when an enemy's HP reaches 0."""
	enemies.erase(enemy)
	enemy_defeated.emit(enemy)
	
	if current_target == enemy:
		current_target = _find_nearest_enemy()
	
	# TODO: Drop loot
	# TODO: Grant cultivation XP
