extends "res://scripts/enemies/Enemy.gd"
## BossEnemy — 苍龙天魔 (Azure Dragon Demon)
##
## Two-phase boss with melee + AoE stomp in Phase 1,
## and ranged dragon breath + increased speed in Phase 2.
## Drops guaranteed equipment + spirit stones on death.

# ─── Boss-Specific Constants ──────────────────────────────────
@export var aoe_stomp_radius: float = 3.0
@export var aoe_stomp_multiplier: float = 2.0
@export var aoe_stomp_cooldown: float = 5.0

@export var breath_range: float = 6.0
@export var breath_damage_multiplier: float = 1.5
@export var breath_cooldown: float = 3.0

@export var phase2_speed: float = 4.5

# ─── Boss AI States ───────────────────────────────────────────
enum BossState { IDLE, CHASE, MELEE, AOE_STOMP, BREATH, STAGGER, DEAD }
var boss_state: BossState = BossState.IDLE

# ─── Phase Tracking ───────────────────────────────────────────
enum BossPhase { PHASE_1, PHASE_2 }
var current_phase: BossPhase = BossPhase.PHASE_1

# ─── Runtime ───────────────────────────────────────────────────
var stomp_timer: float = 0.0
var breath_timer: float = 0.0
var stagger_timer: float = 0.0
var has_transitioned: bool = false

# ─── Signals ───────────────────────────────────────────────────
signal boss_defeated()
signal phase_changed(phase: int)

func _ready() -> void:
	model_type = "boss"
	model_scale = 1.8
	super()
	# Boss stats
	max_hp = 500.0
	attack_power = 35.0
	defense = 15.0
	move_speed = 3.0
	chase_range = 18.0
	attack_range = 2.5
	attack_cooldown = 1.8
	enemy_name = "苍龙天魔"

	current_hp = max_hp
	_update_hp_label()

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

	call_deferred("_find_player")
	print("[BossEnemy] 苍龙天魔 spawned — HP:%.0f ATK:%.0f DEF:%.0f" % [max_hp, attack_power, defense])

func _physics_process(delta: float) -> void:
	if boss_state == BossState.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update cooldowns
	if attack_timer > 0.0:
		attack_timer -= delta
	if stomp_timer > 0.0:
		stomp_timer -= delta
	if breath_timer > 0.0:
		breath_timer -= delta

	# Check phase transition
	_check_phase_transition()

	# Stagger state (phase transition animation)
	if boss_state == BossState.STAGGER:
		_process_stagger(delta)
		move_and_slide()
		return

	match boss_state:
		BossState.IDLE:
			_process_boss_idle()
		BossState.CHASE:
			_process_boss_chase(delta)
		BossState.MELEE:
			_process_boss_melee(delta)
		BossState.AOE_STOMP:
			_process_boss_stomp(delta)
		BossState.BREATH:
			_process_boss_breath(delta)

	move_and_slide()

# ─── Phase Transition ─────────────────────────────────────────
func _check_phase_transition() -> void:
	"""Check if boss should transition to Phase 2."""
	if has_transitioned:
		return
	if current_phase == BossPhase.PHASE_1 and current_hp <= max_hp * 0.5:
		_begin_phase_transition()

func _begin_phase_transition() -> void:
	"""Stagger animation + switch to Phase 2."""
	has_transitioned = true
	stagger_timer = 1.5
	_change_boss_state(BossState.STAGGER)
	velocity = Vector3.ZERO

	print("[BossEnemy] 苍龙天魔 entering Phase 2!")

func _process_stagger(delta: float) -> void:
	"""Shake effect during phase transition stagger."""
	velocity.x = 0.0
	velocity.z = 0.0
	stagger_timer -= delta

	# Visual shake: oscillate position slightly
	if mesh:
		mesh.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.15
		mesh.position.z = cos(Time.get_ticks_msec() * 0.07) * 0.1

	if stagger_timer <= 0.0:
		# Reset mesh position
		if mesh:
			mesh.position.x = 0.0
			mesh.position.z = 0.0

		# Activate Phase 2
		current_phase = BossPhase.PHASE_2
		move_speed = phase2_speed

		# Visual: tint red for Phase 2
		var mat := mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(0.8, 0.15, 0.1, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.2, 0.1)
			mat.emission_energy_multiplier = 0.6

		phase_changed.emit(2)
		_change_boss_state(BossState.CHASE)
		print("[BossEnemy] Phase 2 activated — speed:%.1f, dragon breath unlocked!" % move_speed)

# ─── Boss State Processing ────────────────────────────────────
func _process_boss_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= chase_range:
		_change_boss_state(BossState.CHASE)

func _process_boss_chase(delta: float) -> void:
	if player_ref == null:
		_change_boss_state(BossState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Phase 2: Use dragon breath at range
	if current_phase == BossPhase.PHASE_2 and dist <= breath_range and dist > attack_range and breath_timer <= 0.0:
		_change_boss_state(BossState.BREATH)
		return

	# AoE stomp when player is close and cooldown ready
	if dist <= aoe_stomp_radius and stomp_timer <= 0.0:
		_change_boss_state(BossState.AOE_STOMP)
		return

	# Close enough to melee
	if dist <= attack_range:
		_change_boss_state(BossState.MELEE)
		return

	# Navigate toward player
	nav_agent.target_position = player_ref.global_position

	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0.0

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if direction.length() > 0.1:
		var target_rot := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 6.0 * delta)

func _process_boss_melee(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		_change_boss_state(BossState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	if dist > attack_range * 1.3:
		_change_boss_state(BossState.CHASE)
		return

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

func _process_boss_stomp(_delta: float) -> void:
	"""AoE stomp attack — damages player if within radius."""
	velocity.x = 0.0
	velocity.z = 0.0

	_perform_aoe_stomp()
	stomp_timer = aoe_stomp_cooldown
	_change_boss_state(BossState.CHASE)

func _process_boss_breath(_delta: float) -> void:
	"""Dragon breath ranged attack."""
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		_change_boss_state(BossState.CHASE)
		return

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	_perform_dragon_breath()
	breath_timer = breath_cooldown
	_change_boss_state(BossState.CHASE)

# ─── Attack Methods ───────────────────────────────────────────
func _perform_aoe_stomp() -> void:
	"""AoE stomp: damages player if within stomp radius."""
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist > aoe_stomp_radius:
		print("[BossEnemy] AoE stomp — player out of range (%.1fm)" % dist)
		return

	var damage_info := CombatSystem.calculate_damage(
		attack_power, PlayerData.get_total_defense(), aoe_stomp_multiplier
	)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])
	print("[BossEnemy] AoE STOMP → %.1f damage%s (%.1fm radius)" % [
		damage_info["amount"],
		" (CRIT!)" if damage_info["is_critical"] else "",
		aoe_stomp_radius
	])

	# Visual feedback: brief scale pulse
	_stomp_visual_effect()

func _stomp_visual_effect() -> void:
	"""Brief visual pulse + particle burst for stomp attack."""
	if mesh == null:
		return
	var original_scale := mesh.scale
	var tween := create_tween()
	tween.tween_property(mesh, "scale", original_scale * 1.3, 0.1)
	tween.tween_property(mesh, "scale", original_scale, 0.2)

	# AoE ring-burst particle effect
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 80
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.9

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.3, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3(0, -3.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.15
	mat.scale_max = 0.35
	mat.color = Color(1.0, 0.5, 0.1)  # Orange

	# Color ramp: orange → red → fade out
	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.6, 0.1, 1.0))
	gradient.add_point(0.5, Color(0.9, 0.2, 0.05, 0.8))
	gradient.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Emission shape: ring
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = aoe_stomp_radius * 0.8
	mat.emission_ring_inner_radius = 0.3
	mat.emission_ring_height = 0.2
	mat.emission_ring_axis = Vector3(0, 1, 0)

	particles.process_material = mat

	# Simple quad mesh for each particle
	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.3, 0.3)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(1.0, 0.7, 0.2)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.5, 0.1)
	draw_mat.emission_energy_multiplier = 1.5
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = global_position
	get_tree().current_scene.add_child(particles)

	# Auto-cleanup after emission
	var cleanup_timer := get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _perform_dragon_breath() -> void:
	"""Ranged dragon breath attack — Phase 2 only."""
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist > breath_range:
		return

	var damage_info := CombatSystem.calculate_damage(
		attack_power, PlayerData.get_total_defense(), breath_damage_multiplier
	)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])
	print("[BossEnemy] DRAGON BREATH → %.1f damage%s" % [
		damage_info["amount"],
		" (CRIT!)" if damage_info["is_critical"] else ""
	])

	# Dragon breath particle effect
	_spawn_breath_particles()

func _spawn_breath_particles() -> void:
	"""Spawn teal/cyan dragon breath particles toward the player."""
	if player_ref == null:
		return

	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 60
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.7

	# Direction toward player
	var dir := (player_ref.global_position - global_position).normalized()

	var mat := ParticleProcessMaterial.new()
	mat.direction = dir
	mat.spread = 15.0  # Cone-shaped
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 14.0
	mat.gravity = Vector3(0, -1.0, 0)
	mat.damping_min = 1.0
	mat.damping_max = 3.0
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.2, 0.9, 0.85)  # Teal/cyan

	# Color ramp: bright cyan → dark teal → fade
	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 1.0, 0.95, 1.0))
	gradient.add_point(0.4, Color(0.1, 0.7, 0.8, 0.8))
	gradient.set_color(1, Color(0.05, 0.3, 0.4, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat

	# Quad mesh for breath particles
	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.25, 0.25)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.3, 0.9, 0.85)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.2, 0.8, 0.75)
	draw_mat.emission_energy_multiplier = 2.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	# Position at boss + slight forward offset
	particles.position = global_position + dir * 1.0 + Vector3(0, 1.0, 0)
	get_tree().current_scene.add_child(particles)

	# Auto-cleanup
	var cleanup_timer := get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

# ─── Override Damage Handling ──────────────────────────────────
func take_damage(amount: float) -> void:
	if boss_state == BossState.DEAD:
		return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_label()

	# Aggro on hit
	if boss_state == BossState.IDLE:
		_change_boss_state(BossState.CHASE)

	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_change_boss_state(BossState.DEAD)
	current_state = AIState.DEAD
	defeated.emit(self)
	boss_defeated.emit()
	CombatSystem.on_enemy_defeated(self)

	# Drop loot
	_drop_boss_loot()

	# Visual: darken and sink
	var mat := mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = false

	collision.set_deferred("disabled", true)

	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 1.5, 1.2)
	tween.tween_callback(queue_free)

	print("[BossEnemy] 苍龙天魔 DEFEATED!")

func _drop_boss_loot() -> void:
	"""Drop guaranteed equipment + spirit stones on death."""
	# Spirit stones: 30-50
	var stones := randi_range(30, 50)
	PlayerData.add_spirit_stones(stones)
	print("[BossEnemy] Dropped %d spirit stones" % stones)

	# Guaranteed equipment drop (random from available pool)
	if GameManager.has_method("grant_random_equipment"):
		var _equip := GameManager.grant_random_equipment()
		PlayerData.add_to_inventory(_equip)
		print("[BossEnemy] Dropped random equipment")
	else:
		# Fallback: just give extra spirit stones if no equipment system
		var bonus := randi_range(20, 40)
		PlayerData.add_spirit_stones(bonus)
		print("[BossEnemy] No equipment system — bonus %d spirit stones instead" % bonus)

# ─── HP Label Override ─────────────────────────────────────────
func _update_hp_label() -> void:
	if hp_label:
		var phase_str := " [Phase 2]" if current_phase == BossPhase.PHASE_2 else ""
		hp_label.text = "%s%s\n%.0f / %.0f" % [enemy_name, phase_str, current_hp, max_hp]
		var hp_pct := current_hp / max_hp
		if hp_pct > 0.5:
			hp_label.modulate = Color(1.0, 0.85, 0.3)  # Boss gold
		elif hp_pct > 0.2:
			hp_label.modulate = Color(1.0, 0.4, 0.1)   # Orange warning
		else:
			hp_label.modulate = Color(1.0, 0.1, 0.1)   # Red danger

# ─── Helpers ───────────────────────────────────────────────────
func _change_boss_state(new_state: BossState) -> void:
	boss_state = new_state

# Override base _physics_process to prevent double processing
func _process_idle() -> void:
	pass

func _process_chase(_delta: float) -> void:
	pass

func _process_attack(_delta: float) -> void:
	pass
