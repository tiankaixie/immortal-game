extends "res://scripts/enemies/Enemy.gd"
## TribulationBoss — 天劫 (Heavenly Tribulation Boss)
##
## High-difficulty lightning-themed boss with 3 phases:
## Phase 1 (HP > 50%): Melee + Lightning Strike AoE (4m radius, 1.8x dmg, 4s CD)
## Phase 2 (HP 20-50%): Speed increase + Heavenly Thunder Chain (2.2x dmg, 8s CD) + gold/white visual
## Phase 3 (HP ≤ 20%): Tribulation Storm — 5 sequential lightning bolts (0.3s delay, 1.5x each)
## Drops 50-80 spirit stones + guaranteed rare equipment on death.

# ─── Boss-Specific Constants ──────────────────────────────────
@export var lightning_strike_range: float = 8.0
@export var lightning_strike_radius: float = 4.0
@export var lightning_strike_multiplier: float = 1.8
@export var lightning_strike_cooldown: float = 4.0

@export var thunder_chain_range: float = 10.0
@export var thunder_chain_multiplier: float = 2.2
@export var thunder_chain_cooldown: float = 8.0

@export var storm_bolt_count: int = 5
@export var storm_bolt_delay: float = 0.3
@export var storm_bolt_multiplier: float = 1.5
@export var storm_cooldown: float = 10.0

@export var phase2_speed: float = 5.0

# ─── Boss AI States ───────────────────────────────────────────
enum BossState { IDLE, CHASE, MELEE, LIGHTNING_STRIKE, THUNDER_CHAIN, TRIBULATION_STORM, STAGGER, DEAD }
var boss_state: BossState = BossState.IDLE

# ─── Phase Tracking ───────────────────────────────────────────
enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
var current_phase: BossPhase = BossPhase.PHASE_1

# ─── Runtime ───────────────────────────────────────────────────
var lightning_timer: float = 2.0
var chain_timer: float = 4.0
var storm_timer: float = 6.0
var stagger_timer: float = 0.0
var has_transitioned_p2: bool = false
var has_transitioned_p3: bool = false

# Tribulation Storm state
var storm_active: bool = false
var storm_bolts_remaining: int = 0
var storm_bolt_timer: float = 0.0
var storm_target_pos: Vector3 = Vector3.ZERO

# ─── Signals ───────────────────────────────────────────────────
signal boss_defeated()
signal phase_changed(phase: int)

func _ready() -> void:
	model_type = "tribulation"
	model_scale = 1.5
	super()
	max_hp = 700.0
	attack_power = 45.0
	defense = 20.0
	move_speed = 3.5
	chase_range = 20.0
	attack_range = 2.5
	attack_cooldown = 1.6
	enemy_name = "天劫"

	current_hp = max_hp
	_update_hp_label()

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

	call_deferred("_find_player")

func _physics_process(delta: float) -> void:
	if boss_state == BossState.DEAD:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update cooldowns
	if attack_timer > 0.0:
		attack_timer -= delta
	if lightning_timer > 0.0:
		lightning_timer -= delta
	if chain_timer > 0.0:
		chain_timer -= delta
	if storm_timer > 0.0:
		storm_timer -= delta

	_check_phase_transitions()

	if boss_state == BossState.STAGGER:
		_process_stagger(delta)
		move_and_slide()
		return

	if boss_state == BossState.TRIBULATION_STORM:
		_process_tribulation_storm(delta)
		move_and_slide()
		return

	match boss_state:
		BossState.IDLE:
			_process_boss_idle()
		BossState.CHASE:
			_process_boss_chase(delta)
		BossState.MELEE:
			_process_boss_melee(delta)
		BossState.LIGHTNING_STRIKE:
			_process_lightning_strike()
		BossState.THUNDER_CHAIN:
			_process_thunder_chain()

	move_and_slide()

# ─── Phase Transitions ───────────────────────────────────────
func _check_phase_transitions() -> void:
	var hp_pct := current_hp / max_hp
	if not has_transitioned_p2 and hp_pct <= 0.5:
		has_transitioned_p2 = true
		_begin_phase_transition(BossPhase.PHASE_2)
	elif not has_transitioned_p3 and hp_pct <= 0.2:
		has_transitioned_p3 = true
		_begin_phase_transition(BossPhase.PHASE_3)

func _begin_phase_transition(new_phase: BossPhase) -> void:
	stagger_timer = 1.2
	_change_boss_state(BossState.STAGGER)
	velocity = Vector3.ZERO
	set_meta("pending_phase", new_phase)

func _process_stagger(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	stagger_timer -= delta

	# Visual shake
	if mesh:
		mesh.position.x = sin(Time.get_ticks_msec() * 0.06) * 0.2
		mesh.position.z = cos(Time.get_ticks_msec() * 0.08) * 0.15

	# Flash effect
	if mesh:
		var flash_val: float = abs(sin(Time.get_ticks_msec() * 0.015))
		var mat: Material = mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_energy_multiplier = 0.5 + flash_val * 3.0

	if stagger_timer <= 0.0:
		if mesh:
			mesh.position.x = 0.0
			mesh.position.z = 0.0

		var new_phase: BossPhase = get_meta("pending_phase", BossPhase.PHASE_2) as BossPhase
		current_phase = new_phase

		match current_phase:
			BossPhase.PHASE_2:
				move_speed = phase2_speed
				# Tint shifts to gold/white
				var mat := mesh.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat.albedo_color = Color(1.0, 0.95, 0.7, 1.0)
					mat.emission = Color(1.0, 0.9, 0.5)
					mat.emission_energy_multiplier = 1.0
				phase_changed.emit(2)

			BossPhase.PHASE_3:
				# Intense lightning white-gold
				var mat := mesh.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat.albedo_color = Color(1.0, 1.0, 0.85, 1.0)
					mat.emission = Color(1.0, 0.95, 0.6)
					mat.emission_energy_multiplier = 2.0
				phase_changed.emit(3)

		_change_boss_state(BossState.CHASE)

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

	# Phase 3: Tribulation Storm
	if current_phase == BossPhase.PHASE_3 and storm_timer <= 0.0:
		_change_boss_state(BossState.TRIBULATION_STORM)
		return

	# Phase 2+: Heavenly Thunder Chain
	if current_phase >= BossPhase.PHASE_2 and dist <= thunder_chain_range and chain_timer <= 0.0:
		_change_boss_state(BossState.THUNDER_CHAIN)
		return

	# All phases: Lightning Strike AoE at range
	if dist <= lightning_strike_range and dist > attack_range and lightning_timer <= 0.0:
		_change_boss_state(BossState.LIGHTNING_STRIKE)
		return

	# Melee range
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

	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

# ─── Lightning Strike AoE (Phase 1+) ─────────────────────────
func _process_lightning_strike() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_perform_lightning_strike()
	lightning_timer = lightning_strike_cooldown
	_change_boss_state(BossState.CHASE)

func _perform_lightning_strike() -> void:
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	# Target the player's current position for AoE
	var strike_pos := player_ref.global_position
	var dist_to_aoe := player_ref.global_position.distance_to(strike_pos)

	# AoE check: damage if player is within radius
	if dist_to_aoe <= lightning_strike_radius:
		var damage_info := CombatSystem.calculate_damage(
			attack_power, PlayerData.get_total_defense(), lightning_strike_multiplier
		)
		player_ref.take_damage(damage_info["amount"])
		CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])

	_spawn_lightning_strike_vfx(strike_pos)

# ─── Heavenly Thunder Chain (Phase 2+) ───────────────────────
func _process_thunder_chain() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_perform_thunder_chain()
	chain_timer = thunder_chain_cooldown
	_change_boss_state(BossState.CHASE)

func _perform_thunder_chain() -> void:
	if player_ref == null or not player_ref.has_method("take_damage"):
		return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist > thunder_chain_range:
		return

	var damage_info := CombatSystem.calculate_damage(
		attack_power, PlayerData.get_total_defense(), thunder_chain_multiplier
	)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])

	# Chain VFX: boss → player with gold/white sparks
	_spawn_thunder_chain_vfx(global_position + Vector3(0, 1.5, 0), player_ref.global_position + Vector3(0, 1.0, 0))

# ─── Tribulation Storm (Phase 3) ─────────────────────────────
func _process_tribulation_storm(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if not storm_active:
		# Start the storm sequence
		storm_active = true
		storm_bolts_remaining = storm_bolt_count
		storm_bolt_timer = 0.0  # Fire first bolt immediately
		if player_ref:
			storm_target_pos = player_ref.global_position
		return

	storm_bolt_timer -= delta
	if storm_bolt_timer <= 0.0 and storm_bolts_remaining > 0:
		# Fire a bolt at the player's current position (tracks player)
		if player_ref:
			storm_target_pos = player_ref.global_position

		_fire_storm_bolt(storm_target_pos)
		storm_bolts_remaining -= 1
		storm_bolt_timer = storm_bolt_delay

	# All bolts fired
	if storm_bolts_remaining <= 0 and storm_bolt_timer <= 0.0:
		storm_active = false
		storm_timer = storm_cooldown
		_change_boss_state(BossState.CHASE)

func _fire_storm_bolt(target_pos: Vector3) -> void:
	"""Fire a single lightning bolt at the target position."""
	if player_ref == null or not player_ref.has_method("take_damage"):
		_spawn_storm_bolt_vfx(target_pos)
		return

	# Check if player is within a small radius of the bolt impact
	var dist := player_ref.global_position.distance_to(target_pos)
	if dist <= 2.0:
		var damage_info := CombatSystem.calculate_damage(
			attack_power, PlayerData.get_total_defense(), storm_bolt_multiplier
		)
		player_ref.take_damage(damage_info["amount"])
		CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])

	_spawn_storm_bolt_vfx(target_pos)

# ─── VFX: Lightning Strike AoE ────────────────────────────────
func _spawn_lightning_strike_vfx(target_pos: Vector3) -> void:
	# Ring burst to show AoE radius
	var ring_particles := GPUParticles3D.new()
	ring_particles.emitting = true
	ring_particles.amount = 50
	ring_particles.lifetime = 0.8
	ring_particles.one_shot = true
	ring_particles.explosiveness = 0.9

	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.direction = Vector3(0, 0.3, 0)
	ring_mat.spread = 180.0
	ring_mat.initial_velocity_min = 1.0
	ring_mat.initial_velocity_max = 2.5
	ring_mat.gravity = Vector3(0, -0.5, 0)
	ring_mat.scale_min = 0.1
	ring_mat.scale_max = 0.25
	ring_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ring_mat.emission_ring_radius = lightning_strike_radius
	ring_mat.emission_ring_inner_radius = lightning_strike_radius - 0.4
	ring_mat.emission_ring_height = 0.1
	ring_mat.emission_ring_axis = Vector3(0, 1, 0)

	var ring_gradient := Gradient.new()
	ring_gradient.set_color(0, Color(0.3, 0.8, 1.0, 1.0))
	ring_gradient.add_point(0.5, Color(0.2, 0.5, 1.0, 0.7))
	ring_gradient.set_color(1, Color(0.1, 0.2, 0.8, 0.0))
	var ring_ramp := GradientTexture1D.new()
	ring_ramp.gradient = ring_gradient
	ring_mat.color_ramp = ring_ramp
	ring_particles.process_material = ring_mat

	var ring_mesh := QuadMesh.new()
	ring_mesh.size = Vector2(0.2, 0.2)
	var ring_draw_mat := StandardMaterial3D.new()
	ring_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_draw_mat.albedo_color = Color(0.4, 0.9, 1.0)
	ring_draw_mat.emission_enabled = true
	ring_draw_mat.emission = Color(0.3, 0.8, 1.0)
	ring_draw_mat.emission_energy_multiplier = 2.5
	ring_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ring_mesh.material = ring_draw_mat
	ring_particles.draw_pass_1 = ring_mesh

	ring_particles.position = target_pos + Vector3(0, 0.2, 0)
	get_tree().current_scene.add_child(ring_particles)

	# Central burst
	var burst := GPUParticles3D.new()
	burst.emitting = true
	burst.amount = 60
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 0.95

	var burst_mat := ParticleProcessMaterial.new()
	burst_mat.direction = Vector3(0, 1.0, 0)
	burst_mat.spread = 30.0
	burst_mat.initial_velocity_min = 6.0
	burst_mat.initial_velocity_max = 12.0
	burst_mat.gravity = Vector3(0, -5.0, 0)
	burst_mat.damping_min = 2.0
	burst_mat.damping_max = 4.0
	burst_mat.scale_min = 0.1
	burst_mat.scale_max = 0.3
	burst_mat.color = Color(0.3, 0.9, 1.0)

	var burst_gradient := Gradient.new()
	burst_gradient.set_color(0, Color(0.6, 0.95, 1.0, 1.0))
	burst_gradient.add_point(0.4, Color(0.2, 0.7, 1.0, 0.8))
	burst_gradient.set_color(1, Color(0.1, 0.3, 0.8, 0.0))
	var burst_ramp := GradientTexture1D.new()
	burst_ramp.gradient = burst_gradient
	burst_mat.color_ramp = burst_ramp

	burst_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	burst_mat.emission_sphere_radius = 0.5
	burst.process_material = burst_mat

	var burst_mesh := QuadMesh.new()
	burst_mesh.size = Vector2(0.2, 0.2)
	var burst_draw_mat := StandardMaterial3D.new()
	burst_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burst_draw_mat.albedo_color = Color(0.4, 0.9, 1.0)
	burst_draw_mat.emission_enabled = true
	burst_draw_mat.emission = Color(0.3, 0.8, 1.0)
	burst_draw_mat.emission_energy_multiplier = 2.5
	burst_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	burst_mesh.material = burst_draw_mat
	burst.draw_pass_1 = burst_mesh

	burst.position = target_pos + Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(burst)

	# Cleanup both
	var cleanup := get_tree().create_timer(1.5)
	cleanup.timeout.connect(func():
		if is_instance_valid(ring_particles):
			ring_particles.queue_free()
		if is_instance_valid(burst):
			burst.queue_free()
	)

# ─── VFX: Heavenly Thunder Chain ──────────────────────────────
func _spawn_thunder_chain_vfx(from_pos: Vector3, to_pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.9

	var dir := (to_pos - from_pos).normalized()
	var mat := ParticleProcessMaterial.new()
	mat.direction = dir
	mat.spread = 15.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.damping_min = 3.0
	mat.damping_max = 5.0
	mat.scale_min = 0.08
	mat.scale_max = 0.22

	# Gold/white color for Phase 2 thunder chain
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	gradient.add_point(0.3, Color(1.0, 0.9, 0.4, 0.85))
	gradient.set_color(1, Color(0.8, 0.6, 0.1, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.18, 0.18)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(1.0, 0.95, 0.6)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.9, 0.4)
	draw_mat.emission_energy_multiplier = 2.5
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	var mid := (from_pos + to_pos) * 0.5
	particles.position = mid
	get_tree().current_scene.add_child(particles)

	var cleanup := get_tree().create_timer(1.5)
	cleanup.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

# ─── VFX: Storm Bolt ──────────────────────────────────────────
func _spawn_storm_bolt_vfx(target_pos: Vector3) -> void:
	"""Vertical lightning bolt VFX slamming down from above."""
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.95

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1.0, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -8.0, 0)
	mat.damping_min = 4.0
	mat.damping_max = 6.0
	mat.scale_min = 0.08
	mat.scale_max = 0.2

	# Bright white-gold bolt
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.2, Color(1.0, 0.95, 0.6, 0.9))
	gradient.add_point(0.5, Color(0.8, 0.7, 1.0, 0.7))
	gradient.set_color(1, Color(0.5, 0.3, 0.8, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.3, 4.0, 0.3)
	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.15, 0.15)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(1.0, 0.95, 0.7)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.9, 0.5)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = target_pos + Vector3(0, 4.0, 0)
	get_tree().current_scene.add_child(particles)

	# Ground impact burst
	var impact := GPUParticles3D.new()
	impact.emitting = true
	impact.amount = 30
	impact.lifetime = 0.4
	impact.one_shot = true
	impact.explosiveness = 0.95

	var impact_mat := ParticleProcessMaterial.new()
	impact_mat.direction = Vector3(0, 0.5, 0)
	impact_mat.spread = 180.0
	impact_mat.initial_velocity_min = 3.0
	impact_mat.initial_velocity_max = 6.0
	impact_mat.gravity = Vector3(0, -3.0, 0)
	impact_mat.scale_min = 0.1
	impact_mat.scale_max = 0.25
	impact_mat.color = Color(0.7, 0.5, 1.0)

	var impact_gradient := Gradient.new()
	impact_gradient.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	impact_gradient.add_point(0.4, Color(0.7, 0.5, 1.0, 0.7))
	impact_gradient.set_color(1, Color(0.4, 0.2, 0.6, 0.0))
	var impact_ramp := GradientTexture1D.new()
	impact_ramp.gradient = impact_gradient
	impact_mat.color_ramp = impact_ramp
	impact.process_material = impact_mat

	var impact_mesh := QuadMesh.new()
	impact_mesh.size = Vector2(0.2, 0.2)
	var impact_draw := StandardMaterial3D.new()
	impact_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	impact_draw.albedo_color = Color(0.8, 0.6, 1.0)
	impact_draw.emission_enabled = true
	impact_draw.emission = Color(0.7, 0.5, 1.0)
	impact_draw.emission_energy_multiplier = 2.0
	impact_draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	impact_mesh.material = impact_draw
	impact.draw_pass_1 = impact_mesh

	impact.position = target_pos + Vector3(0, 0.3, 0)
	get_tree().current_scene.add_child(impact)

	var cleanup := get_tree().create_timer(1.5)
	cleanup.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
		if is_instance_valid(impact):
			impact.queue_free()
	)

# ─── Override Damage Handling ──────────────────────────────────
func take_damage(amount: float) -> void:
	if boss_state == BossState.DEAD:
		return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_label()

	if boss_state == BossState.IDLE:
		_change_boss_state(BossState.CHASE)

	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_change_boss_state(BossState.DEAD)
	storm_active = false
	current_state = AIState.DEAD
	defeated.emit(self)
	boss_defeated.emit()
	CombatSystem.on_enemy_defeated(self)

	_drop_boss_loot()

	var mat := mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = false

	collision.set_deferred("disabled", true)

	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 1.5, 1.2)
	tween.tween_callback(queue_free)

func _drop_boss_loot() -> void:
	var stones := randi_range(50, 80)
	PlayerData.add_spirit_stones(stones)

	if GameManager.has_method("grant_random_equipment"):
		var _equip := GameManager.grant_random_equipment()
		PlayerData.add_to_inventory(_equip)

# ─── HP Label Override ─────────────────────────────────────────
func _update_hp_label() -> void:
	if hp_label:
		var phase_str := ""
		match current_phase:
			BossPhase.PHASE_2:
				phase_str = " [雷链]"
			BossPhase.PHASE_3:
				phase_str = " [天罚]"
		hp_label.text = "%s%s\n%.0f / %.0f" % [enemy_name, phase_str, current_hp, max_hp]
		var hp_pct := current_hp / max_hp
		if hp_pct > 0.5:
			hp_label.modulate = Color(0.6, 0.4, 0.9)   # Deep purple
		elif hp_pct > 0.2:
			hp_label.modulate = Color(1.0, 0.9, 0.4)   # Gold
		else:
			hp_label.modulate = Color(1.0, 1.0, 0.8)   # White-gold

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
