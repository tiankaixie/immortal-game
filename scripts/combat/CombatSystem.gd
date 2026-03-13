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
	damage_dealt.connect(_on_damage_dealt_stats)
	print("[CombatSystem] Initialized")

func _on_damage_dealt_stats(_target: Node, amount: float, _is_critical: bool) -> void:
	"""Track total damage dealt for RunStats."""
	RunStats.damage_dealt_total += int(amount)

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

			# Audio feedback
			if damage_info["is_critical"]:
				AudioManager.play_sfx("crit")
			else:
				AudioManager.play_sfx("hit")

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
		var skill_effect: String = skill.get("effect", "")

		# ── Chain Lightning: jump between multiple enemies ──────
		if skill.get("aoe_radius", 0.0) == -1.0:
			var chain_count: int = skill.get("chain_count", 3)
			var hit_enemies: Array[Node] = []
			var next_target: Node = target

			for _i in range(chain_count):
				if next_target == null or not is_instance_valid(next_target):
					break
				if next_target in hit_enemies:
					break
				hit_enemies.append(next_target)
				var target_def: float = next_target.defense if "defense" in next_target else 0.0
				var damage_info := calculate_damage(base_attack, target_def, skill["damage_multiplier"])
				if next_target.has_method("take_damage"):
					next_target.take_damage(damage_info["amount"])
				damage_dealt.emit(next_target, damage_info["amount"], damage_info["is_critical"])
				total_damage += damage_info["amount"]
				# Spawn lightning arc VFX on hit target
				_spawn_element_vfx(next_target.global_position, "lightning")
				# Find next closest unhit enemy within 12m
				var jump_target: Node = null
				var jump_dist := 12.0
				for e in enemies:
					if is_instance_valid(e) and e not in hit_enemies:
						var d: float = next_target.global_position.distance_to(e.global_position)
						if d < jump_dist:
							jump_dist = d
							jump_target = e
				next_target = jump_target

			print("[CombatSystem] %s used %s — %.1f total damage (%d enemies chained)" % [
				PlayerData.player_name, skill["name_zh"], total_damage, hit_enemies.size()
			])

		# ── Void Blink: teleport behind target, then strike ────
		elif skill_effect == "blink":
			if target != null and is_instance_valid(target) and player_entity != null:
				# Teleport player 1.5m behind the target
				var behind_offset := (target.global_position - player_entity.global_position).normalized() * 1.5
				player_entity.global_position = target.global_position - behind_offset + Vector3(0, 0.1, 0)
				_spawn_element_vfx(player_entity.global_position, "void")
				# Strike
				var target_def: float = target.defense if "defense" in target else 0.0
				var damage_info := calculate_damage(base_attack, target_def, skill["damage_multiplier"])
				if target.has_method("take_damage"):
					target.take_damage(damage_info["amount"])
				damage_dealt.emit(target, damage_info["amount"], damage_info["is_critical"])
				total_damage = damage_info["amount"]
				_spawn_element_vfx(target.global_position, "void")
				print("[CombatSystem] %s used %s — blinked + %.1f damage" % [
					PlayerData.player_name, skill["name_zh"], total_damage
				])

		elif skill.get("aoe_radius", 0.0) > 0.0:
			# Standard AoE: hit all enemies within radius of target position
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
			# Single target (possibly with on-hit effects)
			if target != null and is_instance_valid(target):
				var target_def: float = target.defense if "defense" in target else 0.0
				var damage_info := calculate_damage(base_attack, target_def, skill["damage_multiplier"])

				if target.has_method("take_damage"):
					target.take_damage(damage_info["amount"])

				damage_dealt.emit(target, damage_info["amount"], damage_info["is_critical"])
				total_damage = damage_info["amount"]

				# ── Stun effect (天雷掌) ──────────────────────
				if skill_effect == "stun":
					_apply_stun(target, skill.get("effect_duration", 2.0))

				# ── Lifesteal (虚空吸髓) ──────────────────────
				elif skill_effect == "lifesteal":
					var steal_ratio: float = skill.get("lifesteal_ratio", 0.5)
					var heal_amount: float = damage_info["amount"] * steal_ratio
					if player_entity != null and player_entity.has_method("heal"):
						player_entity.heal(heal_amount)
					print("[CombatSystem] Void Drain healed player for %.1f HP" % heal_amount)

				print("[CombatSystem] %s used %s — %.1f damage%s" % [
					PlayerData.player_name, skill["name_zh"], total_damage,
					" [麻痹]" if skill_effect == "stun" else ""
				])
	else:
		# Non-damage skill (heal, shield, etc.)
		_apply_skill_effect(skill)
		print("[CombatSystem] %s used %s" % [PlayerData.player_name, skill["name_zh"]])
	
	# Set cooldown
	skill_cooldowns[skill_id] = skill["cooldown"]
	
	# Track skill usage
	RunStats.skills_used += 1
	
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
			if player_entity != null and player_entity.has_method("heal"):
				player_entity.heal(heal_amount)
			else:
				PlayerData.base_hp = min(PlayerData.base_hp + heal_amount, PlayerData.get_total_hp())
			print("[CombatSystem] %s healed for %.1f HP" % [PlayerData.player_name, heal_amount])
		"water_shield":
			# Temporary defense boost via BuffSystem
			BuffSystem.apply_buff(player_entity if player_entity else self, {
				"type": BuffSystem.BuffType.DEF_UP,
				"magnitude": PlayerData.get_total_defense() * 0.5,
				"duration": 8.0,
				"source": "water_shield",
			})
			print("[CombatSystem] %s gained water shield (DEF +%.1f for 8s)" % [
				PlayerData.player_name, PlayerData.get_total_defense() * 0.5
			])
		"earth_wall":
			# AoE slow via BuffSystem on all nearby enemies
			if player_entity != null:
				for enemy in enemies:
					if is_instance_valid(enemy):
						var dist: float = player_entity.global_position.distance_to(enemy.global_position)
						if dist <= 3.5:
							BuffSystem.apply_buff(enemy, {
								"type": BuffSystem.BuffType.SPEED_DOWN,
								"magnitude": enemy.move_speed * 0.6 if "move_speed" in enemy else 2.0,
								"duration": 5.0,
								"source": "earth_wall",
							})
							if "move_speed" in enemy:
								enemy.move_speed = max(0.5, enemy.move_speed - 2.0)
			print("[CombatSystem] %s raised an earth wall" % PlayerData.player_name)

func _apply_stun(target: Node, duration: float) -> void:
	"""Stun an enemy by zeroing its move speed for `duration` seconds.
	
	Stores original speed in a metadata key and restores it via a timer.
	"""
	if target == null or not is_instance_valid(target):
		return
	if not "move_speed" in target:
		return

	# Prevent double-stun
	if target.has_meta("stun_original_speed"):
		return

	var original_speed: float = target.move_speed
	target.set_meta("stun_original_speed", original_speed)
	target.move_speed = 0.0

	# Visual: briefly tint the mesh yellow/white for stun
	if "mesh" in target and target.mesh is MeshInstance3D:
		var mat := target.mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(0.9, 0.9, 0.2)

	# Restore after duration
	var timer := target.get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(target):
			target.move_speed = target.get_meta("stun_original_speed", original_speed)
			target.remove_meta("stun_original_speed")
			# Restore original mesh color
			if "mesh" in target and target.mesh is MeshInstance3D:
				var mat := target.mesh.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat.albedo_color = Color(1.0, 0.3, 0.3)  # Reset to red (enemy default)
	)
	print("[CombatSystem] Stunned %s for %.1fs" % [
		target.enemy_name if "enemy_name" in target else "enemy", duration
	])

func _spawn_element_vfx(position: Vector3, element: String) -> void:
	"""Spawn a quick particle burst at a world position for the given element.
	
	Reuses the SkillVFX scene if available, otherwise creates a minimal inline burst.
	"""
	var vfx_scene_path := "res://scenes/vfx/SkillVFX.tscn"
	if ResourceLoader.exists(vfx_scene_path):
		var vfx_res: PackedScene = load(vfx_scene_path)
		if vfx_res:
			var vfx_inst: Node3D = vfx_res.instantiate() as Node3D
			if vfx_inst:
				get_tree().current_scene.add_child(vfx_inst)
				vfx_inst.global_position = position
				if vfx_inst.has_method("play_element"):
					vfx_inst.play_element(element)
				return

	# Fallback: create an inline GPUParticles3D burst
	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	match element:
		"lightning":
			mat.color = Color(0.7, 0.5, 1.0)   # Purple-white lightning
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 6.0
		"void":
			mat.color = Color(0.4, 0.0, 0.8, 0.8)  # Dark violet
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 4.0
		_:
			mat.color = Color(1.0, 0.5, 0.1)
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 5.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.gravity = Vector3(0, 2.0, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	particles.process_material = mat
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 0.95
	particles.one_shot = true
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	# Auto-free after particles finish
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

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
	RunStats.enemies_killed += 1
	
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
