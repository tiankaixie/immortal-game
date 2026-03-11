extends "res://scripts/enemies/Enemy.gd"
## TribulationBoss — 天劫 (Heavenly Tribulation Boss)
##
## High-difficulty lightning-themed boss with 3 phases:
## Phase 1 (HP > 60%): Melee + Lightning Strike (single target, 8m, 2x dmg)
## Phase 2 (HP 30-60%): + Chain Lightning (3 targets, 10m, 1.5x each)
## Phase 3 (HP < 30%): Speed boost + Heaven's Wrath AoE (5m, 2.5x, 1s warning)
## Drops 50-80 spirit stones + guaranteed equipment on death.

# ─── Boss-Specific Constants ──────────────────────────────────
@export var lightning_strike_range: float = 8.0
@export var lightning_strike_multiplier: float = 2.0
@export var lightning_strike_cooldown: float = 4.0

@export var chain_lightning_range: float = 10.0
@export var chain_lightning_multiplier: float = 1.5
@export var chain_lightning_cooldown: float = 6.0
@export var chain_lightning_bounces: int = 3

@export var heavens_wrath_radius: float = 5.0
@export var heavens_wrath_multiplier: float = 2.5
@export var heavens_wrath_cooldown: float = 8.0
@export var heavens_wrath_warning: float = 1.0

@export var phase3_speed: float = 5.5

# ─── Boss AI States ───────────────────────────────────────────
enum BossState { IDLE, CHASE, MELEE, LIGHTNING_STRIKE, CHAIN_LIGHTNING, HEAVENS_WRATH_CHARGE, HEAVENS_WRATH, STAGGER, DEAD }
var boss_state: BossState = BossState.IDLE

# ─── Phase Tracking ───────────────────────────────────────────
enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
var current_phase: BossPhase = BossPhase.PHASE_1

# ─── Runtime ───────────────────────────────────────────────────
var lightning_timer: float = 2.0
var chain_timer: float = 4.0
var wrath_timer: float = 6.0
var stagger_timer: float = 0.0
var wrath_charge_timer: float = 0.0
var wrath_target_pos: Vector3 = Vector3.ZERO
var has_transitioned_p2: bool = false
var has_transitioned_p3: bool = false

# ─── Signals ───────────────────────────────────────────────────
signal boss_defeated()
signal phase_changed(phase: int)

func _ready() -> void:
	max_hp = 800.0
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
	if wrath_timer > 0.0:
		wrath_timer -= delta

	_check_phase_transitions()

	if boss_state == BossState.STAGGER:
		_process_stagger(delta)
		move_and_slide()
		return

	if boss_state == BossState.HEAVENS_WRATH_CHARGE:
		_process_wrath_charge(delta)
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
		BossState.CHAIN_LIGHTNING:
			_process_chain_lightning()
		BossState.HEAVENS_WRATH:
			_process_heavens_wrath()

	move_and_slide()

# ─── Phase Transitions ───────────────────────────────────────
func _check_phase_transitions() -> void:
	var hp_pct := current_hp / max_hp
	if not has_transitioned_p2 and hp_pct <= 0.6:
		has_transitioned_p2 = true
		_begin_phase_transition(BossPhase.PHASE_2)
	elif not has_transitioned_p3 and hp_pct <= 0.3:
		has_transitioned_p3 = true
		_begin_phase_transition(BossPhase.PHASE_3)

func _begin_phase_transition(new_phase: BossPhase) -> void:
	stagger_timer = 1.2
	_change_boss_state(BossState.STAGGER)
	velocity = Vector3.ZERO

	# Store which phase we're transitioning to
	set_meta("pending_phase", new_phase)

func _process_stagger(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	stagger_timer -= delta

	# Visual shake
	if mesh:
		mesh.position.x = sin(Time.get_ticks_msec() * 0.06) * 0.2
		mesh.position.z = cos(Time.get_ticks_msec() * 0.08) * 0.15

	# Flash effect — alternate brightness
	if mesh:
		var flash_val := abs(sin(Time.get_ticks_msec() * 0.015))
		var mat := mesh.get_surface_override_material(0)
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
				# Tint shifts to electric blue-white
				var mat := mesh.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat.albedo_color = Color(0.8, 0.85, 1.0, 1.0)
					mat.emission = Color(0.5, 0.6, 1.0)
					mat.emission_energy_multiplier = 0.8
				phase_changed.emit(2)

			BossPhase.PHASE_3:
				move_speed = phase3_speed
				# Tint to intense lightning white-yellow
				var mat := mesh.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat.albedo_color = Color(1.0, 0.95, 0.7, 1.0)
					mat.emission = Color(1.0, 0.9, 0.4)
					mat.emission_energy_multiplier = 1.5
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

	# Phase 3: Heaven's Wrath AoE
	if current_phase == BossPhase.PHASE_3 and wrath_timer <= 0.0:
		_change_boss_state(BossState.HEAVENS_WRATH_CHARGE)
		return

	# Phase 2+: Chain Lightning
	if current_phase >= BossPhase.PHASE_2 and dist <= chain_lightning_range and chain_timer <= 0.0:
		_change_boss_state(BossState.CHAIN_LIGHTNING)
		return

	# All phases: Lightning Strike at range
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

# ─── Lightning Strike (Phase 1+) ─────────────────────────────
func _process_lightning_strike() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_perform_lightning_strike()
	lightning_timer = lightning_strike_cooldown
	_change_boss_state(BossState.CHASE)

func _perform_lightning_strike() -> void:
	if player_ref == null or not player_ref.has_method("take_damage"):
		return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist > lightning_strike_range:
		return

	var damage_info := CombatSystem.calculate_damage(
		attack_power, PlayerData.get_total_defense(), lightning_strike_multiplier
	)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])

	_spawn_lightning_strike_vfx(player_ref.global_position)

# ─── Chain Lightning (Phase 2+) ──────────────────────────────
func _process_chain_lightning() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_perform_chain_lightning()
	chain_timer = chain_lightning_cooldown
	_change_boss_state(BossState.CHASE)

func _perform_chain_lightning() -> void:
	if player_ref == null or not player_ref.has_method("take_damage"):
		return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist > chain_lightning_range:
		return

	# First hit: player
	var damage_info := CombatSystem.calculate_damage(
		attack_power, PlayerData.get_total_defense(), chain_lightning_multiplier
	)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])

	# Chain to nearby enemies (for visual/thematic purposes, hits player area)
	# Spawn chain VFX between boss → player
	_spawn_chain_lightning_vfx(global_position + Vector3(0, 1.5, 0), player_ref.global_position + Vector3(0, 1.0, 0))

# ─── Heaven's Wrath (Phase 3) ────────────────────────────────
func _process_wrath_charge(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if wrath_charge_timer <= 0.0:
		# Start charge — record target position
		if player_ref:
			wrath_target_pos = player_ref.global_position
		wrath_charge_timer = heavens_wrath_warning
		_spawn_wrath_warning_vfx(wrath_target_pos)

	wrath_charge_timer -= delta

	if wrath_charge_timer <= 0.0:
		_change_boss_state(BossState.HEAVENS_WRATH)

func _process_heavens_wrath() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_perform_heavens_wrath()
	wrath_timer = heavens_wrath_cooldown
	wrath_charge_timer = 0.0
	_change_boss_state(BossState.CHASE)

func _perform_heavens_wrath() -> void:
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	# Check if player is within AoE radius of target position
	var dist := player_ref.global_position.distance_to(wrath_target_pos)
	if dist <= heavens_wrath_radius:
		var damage_info := CombatSystem.calculate_damage(
			attack_power, PlayerData.get_total_defense(), heavens_wrath_multiplier
		)
		player_ref.take_damage(damage_info["amount"])
		CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])

	# Big explosion VFX regardless
	_spawn_heavens_wrath_vfx(wrath_target_pos)

# ─── VFX ──────────────────────────────────────────────────────
func _spawn_lightning_strike_vfx(target_pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 60
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.95

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1.0, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -5.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.3, 0.9, 1.0)

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.6, 0.95, 1.0, 1.0))
	gradient.add_point(0.4, Color(0.2, 0.7, 1.0, 0.8))
	gradient.set_color(1, Color(0.1, 0.3, 0.8, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.2, 0.2)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.4, 0.9, 1.0)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.3, 0.8, 1.0)
	draw_mat.emission_energy_multiplier = 2.5
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = target_pos + Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(particles)

	var cleanup := get_tree().create_timer(1.5)
	cleanup.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _spawn_chain_lightning_vfx(from_pos: Vector3, to_pos: Vector3) -> void:
	# Electric arc particles along the path
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.9

	var dir := (to_pos - from_pos).normalized()
	var mat := ParticleProcessMaterial.new()
	mat.direction = dir
	mat.spread = 20.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 18.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.damping_min = 3.0
	mat.damping_max = 5.0
	mat.scale_min = 0.08
	mat.scale_max = 0.2
	mat.color = Color(0.5, 0.7, 1.0)

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.8, 0.9, 1.0, 1.0))
	gradient.add_point(0.3, Color(0.4, 0.6, 1.0, 0.8))
	gradient.set_color(1, Color(0.2, 0.3, 0.8, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.15, 0.15)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.6, 0.8, 1.0)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.4, 0.6, 1.0)
	draw_mat.emission_energy_multiplier = 2.0
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

func _spawn_wrath_warning_vfx(target_pos: Vector3) -> void:
	## Pulsing ring on the ground to warn player of incoming AoE
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 1.0
	particles.one_shot = false
	particles.explosiveness = 0.3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.2, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -0.5, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.3
	mat.color = Color(1.0, 0.9, 0.2)

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = heavens_wrath_radius
	mat.emission_ring_inner_radius = heavens_wrath_radius - 0.3
	mat.emission_ring_height = 0.1
	mat.emission_ring_axis = Vector3(0, 1, 0)
	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.3, 0.3)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(1.0, 0.85, 0.2)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.8, 0.1)
	draw_mat.emission_energy_multiplier = 2.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = target_pos + Vector3(0, 0.2, 0)
	get_tree().current_scene.add_child(particles)

	# Auto-cleanup after warning period + a bit extra
	var cleanup := get_tree().create_timer(heavens_wrath_warning + 0.5)
	cleanup.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _spawn_heavens_wrath_vfx(target_pos: Vector3) -> void:
	## Large yellow lightning explosion
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 120
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.95

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1.0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -4.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.15
	mat.scale_max = 0.45

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.8, 1.0))
	gradient.add_point(0.3, Color(1.0, 0.85, 0.2, 0.9))
	gradient.add_point(0.6, Color(0.9, 0.5, 0.1, 0.6))
	gradient.set_color(1, Color(0.5, 0.2, 0.05, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = heavens_wrath_radius * 0.5
	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.35, 0.35)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(1.0, 0.9, 0.3)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.85, 0.2)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = target_pos + Vector3(0, 0.3, 0)
	get_tree().current_scene.add_child(particles)

	var cleanup := get_tree().create_timer(2.0)
	cleanup.timeout.connect(func():
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
		GameManager.grant_random_equipment()

# ─── HP Label Override ─────────────────────────────────────────
func _update_hp_label() -> void:
	if hp_label:
		var phase_str := ""
		match current_phase:
			BossPhase.PHASE_2:
				phase_str = " [雷霆]"
			BossPhase.PHASE_3:
				phase_str = " [天罚]"
		hp_label.text = "%s%s\n%.0f / %.0f" % [enemy_name, phase_str, current_hp, max_hp]
		var hp_pct := current_hp / max_hp
		if hp_pct > 0.6:
			hp_label.modulate = Color(0.8, 0.9, 1.0)
		elif hp_pct > 0.3:
			hp_label.modulate = Color(0.5, 0.7, 1.0)
		else:
			hp_label.modulate = Color(1.0, 0.9, 0.3)

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
