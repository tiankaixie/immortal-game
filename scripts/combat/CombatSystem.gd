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

# ─── Constants ─────────────────────────────────────────────────
const BASIC_ATTACK_RANGE: float = 2.5
const BASIC_ATTACK_COOLDOWN: float = 0.8

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

# Basic attack cooldown tracker
var basic_attack_timer: float = 0.0

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
	
	# Update basic attack timer
	if basic_attack_timer > 0.0:
		basic_attack_timer -= delta

# ─── Combat Lifecycle ──────────────────────────────────────────
func start_combat(player: Node, enemy_list: Array[Node]) -> void:
	"""Initialize a combat encounter."""
	player_entity = player
	enemies = enemy_list
	current_target = _find_nearest_enemy()
	basic_attack_timer = 0.0
	skill_cooldowns.clear()
	
	PlayerData.in_combat = true
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
	PlayerData.in_combat = false
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
	
	# Try to use best available skill
	var best_skill := _get_best_available_skill()
	if best_skill != "":
		execute_skill(best_skill, current_target)
		return
	
	# Basic attack if in range, otherwise move toward target
	_perform_basic_attack(current_target)

func _get_best_available_skill() -> String:
	"""Determine the highest-priority skill that's off cooldown.
	
	Priority order (configurable by player):
	1. Defensive skills (if HP below threshold)
	2. AoE skills (if multiple enemies nearby)
	3. Highest damage single-target skill
	"""
	for skill_id in PlayerData.equipped_skills:
		if not skill_cooldowns.has(skill_id) or skill_cooldowns[skill_id] <= 0:
			# Check if player has enough SP
			var skill := SkillDatabase.get_skill(skill_id)
			if skill.is_empty():
				continue
			if skill["sp_cost"] > PlayerData.sp:
				continue
			# Check realm requirement
			if not SkillDatabase.is_skill_available(skill_id, PlayerData.cultivation_realm):
				continue
			return skill_id
	return ""

# ─── Basic Attack ──────────────────────────────────────────────
func _perform_basic_attack(target: Node) -> void:
	"""Perform a melee basic attack on the target.
	
	If in range: deal damage. If out of range: move toward target.
	"""
	if player_entity == null or target == null or not is_instance_valid(target):
		return
	
	var distance: float = player_entity.global_position.distance_to(target.global_position)
	
	if distance <= BASIC_ATTACK_RANGE:
		# In range — attack if cooldown is ready
		if basic_attack_timer <= 0.0:
			var damage_info := calculate_damage(
				PlayerData.get_total_attack(),
				target.defense if "defense" in target else 0.0,
				1.0
			)
			
			if target.has_method("take_damage"):
				target.take_damage(damage_info["amount"])
			
			damage_dealt.emit(target, damage_info["amount"], damage_info["is_critical"])
			basic_attack_timer = BASIC_ATTACK_COOLDOWN
			
			var crit_str := " (CRIT!)" if damage_info["is_critical"] else ""
			print("[CombatSystem] Basic attack → %.1f damage%s" % [damage_info["amount"], crit_str])
	else:
		# Out of range — move toward target
		_move_toward(target)

func _move_toward(target: Node) -> void:
	"""Move the player entity toward a target."""
	if player_entity == null or target == null:
		return
	
	var direction: Vector3 = (target.global_position - player_entity.global_position).normalized()
	
	# Use the player's move speed if available, otherwise default
	var move_speed: float = PlayerData.base_speed * 5.0  # Convert to world units/sec
	
	if player_entity.has_method("move_toward_position"):
		player_entity.move_toward_position(target.global_position)
	elif player_entity is CharacterBody3D:
		player_entity.velocity = direction * move_speed
		player_entity.move_and_slide()

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

# ─── Skill Execution ──────────────────────────────────────────
func execute_skill(skill_id: String, target: Node) -> void:
	"""Execute a skill by ID against a target (or AoE around target).
	
	- Looks up skill from SkillDatabase
	- Checks and spends SP
	- Calculates and applies damage
	- Handles AoE if aoe_radius > 0
	- Sets cooldown
	- Grants cultivation XP
	"""
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		push_warning("[CombatSystem] Cannot execute unknown skill: %s" % skill_id)
		return
	
	# Check cooldown
	if skill_cooldowns.has(skill_id) and skill_cooldowns[skill_id] > 0:
		return  # Still on cooldown, silently skip
	
	# Check and spend SP
	var sp_cost: float = skill["sp_cost"]
	if PlayerData.sp < sp_cost:
		print("[CombatSystem] Not enough SP for %s (need %.1f, have %.1f)" % [
			skill["name_zh"], sp_cost, PlayerData.sp
		])
		return
	
	# Spend SP
	PlayerData.spend_sp(sp_cost)
	
	# Calculate base damage
	var base_attack: float = PlayerData.get_total_attack()
	var total_damage: float = 0.0
	
	if skill["damage_multiplier"] > 0.0:
		if skill["aoe_radius"] > 0.0:
			# AoE: hit all enemies within radius of target position
			var aoe_center: Vector3 = target.global_position if target != null and is_instance_valid(target) else player_entity.global_position
			var hit_count: int = 0
			
			for enemy in enemies:
				if is_instance_valid(enemy):
					var dist: float = aoe_center.distance_to(enemy.global_position)
					if dist <= skill["aoe_radius"]:
						var enemy_def: float = enemy.defense if "defense" in enemy else 0.0
						var damage_info := calculate_damage(base_attack, enemy_def, skill["damage_multiplier"])
						
						if enemy.has_method("take_damage"):
							enemy.take_damage(damage_info["amount"])
						
						damage_dealt.emit(enemy, damage_info["amount"], damage_info["is_critical"])
						total_damage += damage_info["amount"]
						hit_count += 1
			
			print("[CombatSystem] %s used %s — %.1f total damage (%d enemies hit)" % [
				PlayerData.player_name, skill["name_zh"], total_damage, hit_count
			])
		else:
			# Single target
			if target != null and is_instance_valid(target):
				var target_def: float = target.defense if "defense" in target else 0.0
				var damage_info := calculate_damage(base_attack, target_def, skill["damage_multiplier"])
				
				if target.has_method("take_damage"):
					target.take_damage(damage_info["amount"])
				
				damage_dealt.emit(target, damage_info["amount"], damage_info["is_critical"])
				total_damage = damage_info["amount"]
				
				print("[CombatSystem] %s used %s — %.1f damage" % [
					PlayerData.player_name, skill["name_zh"], total_damage
				])
	else:
		# Non-damage skill (heal, shield, etc.)
		_apply_skill_effect(skill)
		print("[CombatSystem] %s used %s" % [PlayerData.player_name, skill["name_zh"]])
	
	# Set cooldown
	skill_cooldowns[skill_id] = skill["cooldown"]
	
	# Grant cultivation XP for using a skill
	PlayerData.add_cultivation_xp(5.0)
	
	# Emit signal
	skill_used.emit(skill_id)

func _apply_skill_effect(skill: Dictionary) -> void:
	"""Apply non-damage skill effects (healing, buffs, etc.)."""
	match skill["id"]:
		"wood_heal":
			# Heal 20% of max HP + realm scaling
			var heal_amount: float = PlayerData.get_total_hp() * 0.2
			PlayerData.base_hp = min(PlayerData.base_hp + heal_amount, PlayerData.get_total_hp())
			print("[CombatSystem] %s healed for %.1f HP" % [PlayerData.player_name, heal_amount])
		"water_shield":
			# Temporary defense boost — add flat defense for 8 seconds
			# TODO: Implement buff system with timers
			var shield_amount: float = PlayerData.get_total_defense() * 0.5
			PlayerData.base_defense += shield_amount
			print("[CombatSystem] %s gained %.1f temporary defense" % [PlayerData.player_name, shield_amount])
		"earth_wall":
			# AoE slow + temporary block — mostly handled via aoe_radius
			# TODO: Implement slow debuff on enemies in range
			print("[CombatSystem] %s raised an earth wall" % PlayerData.player_name)

func use_skill(skill_id: String) -> void:
	"""Legacy wrapper — execute a skill against the current target."""
	if current_target != null and is_instance_valid(current_target):
		execute_skill(skill_id, current_target)
	else:
		# Try to find a target first
		current_target = _find_nearest_enemy()
		if current_target != null:
			execute_skill(skill_id, current_target)

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
	if target != null and is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(damage_info["amount"])
		
		damage_dealt.emit(target, damage_info["amount"], damage_info["is_critical"])
		
		# Check if target is defeated
		if "current_hp" in target and target.current_hp <= 0:
			on_enemy_defeated(target)

# ─── Enemy Defeated ───────────────────────────────────────────
func on_enemy_defeated(enemy: Node) -> void:
	"""Called when an enemy's HP reaches 0. Grants rewards."""
	enemies.erase(enemy)
	enemy_defeated.emit(enemy)
	
	if current_target == enemy:
		current_target = _find_nearest_enemy()
	
	# Grant cultivation XP (base 15 per enemy)
	var xp_reward: float = 15.0
	PlayerData.add_cultivation_xp(xp_reward)
	
	# Grant spirit stones (3-12 per enemy)
	var stone_reward: int = randi_range(3, 12)
	PlayerData.add_spirit_stones(stone_reward)
	
	print("[CombatSystem] Enemy defeated! Rewards: +%.1f cultivation XP, +%d 灵石" % [xp_reward, stone_reward])
	
	# Roll loot from LootTable
	var enemy_tier := _get_enemy_tier(enemy)
	var loot := LootTable.roll_loot(enemy_tier)
	if loot.size() > 0:
		LootTable.apply_loot(loot)

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

func _get_enemy_tier(enemy: Node) -> int:
	"""Estimate enemy tier based on stats. Higher stats = higher tier."""
	if not is_instance_valid(enemy):
		return 0
	var hp := enemy.max_hp if "max_hp" in enemy else 50.0
	if hp >= 200.0:
		return 2  # 结丹妖
	elif hp >= 100.0:
		return 1  # 筑基妖
	return 0  # 练气妖

func _change_state(new_state: CombatState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
