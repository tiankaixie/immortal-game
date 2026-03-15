extends "res://scripts/enemies/Enemy.gd"
## EliteEnemy — 幽冥蛛后 (Phantom Spider Queen)
##
## Elite mini-boss with two abilities:
## 1. Poison Web — AoE DoT in a 2m radius (3 ticks over 3s)
## 2. Summon Spiderlings — Spawns 2 SwarmEnemy nearby
## Drops 15-25 spirit stones + 50% chance equipment on death.

# ─── Elite-Specific Constants ─────────────────────────────────
@export var poison_web_cooldown: float = 8.0
@export var poison_web_radius: float = 2.0
@export var poison_tick_damage: float = 6.0
@export var poison_ticks: int = 3
@export var poison_tick_interval: float = 1.0

@export var summon_cooldown: float = 15.0
@export var summon_count: int = 2

# ─── Elite AI States ──────────────────────────────────────────
enum EliteState { IDLE, CHASE, MELEE, POISON_WEB, SUMMON, DEAD }
var elite_state: EliteState = EliteState.IDLE

# ─── Runtime ───────────────────────────────────────────────────
var poison_timer: float = 4.0   # Start offset so first cast isn't immediate
var summon_timer: float = 8.0
var poison_dot_timer: float = 0.0
var poison_dot_ticks_remaining: int = 0

# Preloaded swarm scene for summoning
var swarm_scene: PackedScene = null

# ─── Signals ───────────────────────────────────────────────────
signal elite_defeated()

func _ready() -> void:
	model_type = "elite"
	model_scale = 1.3
	super()  # Call Enemy._ready() for add_to_group("enemies") etc.
	# Elite stats — 幽冥蛛后
	max_hp = 200.0
	attack_power = 22.0
	defense = 8.0
	move_speed = 3.2
	chase_range = 16.0
	attack_range = 2.2
	attack_cooldown = 1.5
	enemy_name = "幽冥蛛后"

	current_hp = max_hp
	_update_hp_label()

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

	# Preload SwarmEnemy scene for summon ability
	swarm_scene = load("res://scenes/enemies/SwarmEnemy.tscn")

	call_deferred("_find_player")
	print("[EliteEnemy] 幽冥蛛后 spawned — HP:%.0f ATK:%.0f DEF:%.0f" % [max_hp, attack_power, defense])

func _physics_process(delta: float) -> void:
	if elite_state == EliteState.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update cooldowns
	if attack_timer > 0.0:
		attack_timer -= delta
	if poison_timer > 0.0:
		poison_timer -= delta
	if summon_timer > 0.0:
		summon_timer -= delta

	# Process poison DoT on player
	_process_poison_dot(delta)

	match elite_state:
		EliteState.IDLE:
			_process_elite_idle()
		EliteState.CHASE:
			_process_elite_chase(delta)
		EliteState.MELEE:
			_process_elite_melee(delta)
		EliteState.POISON_WEB:
			_process_poison_web()
		EliteState.SUMMON:
			_process_summon()

	move_and_slide()

# ─── Elite State Processing ───────────────────────────────────
func _process_elite_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= chase_range:
		_change_elite_state(EliteState.CHASE)

func _process_elite_chase(delta: float) -> void:
	if player_ref == null:
		_change_elite_state(EliteState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Priority: summon spiderlings if cooldown ready
	if summon_timer <= 0.0:
		_change_elite_state(EliteState.SUMMON)
		return

	# Poison web if player within range and cooldown ready
	if dist <= poison_web_radius * 2.0 and poison_timer <= 0.0:
		_change_elite_state(EliteState.POISON_WEB)
		return

	# Close enough to melee
	if dist <= attack_range:
		_change_elite_state(EliteState.MELEE)
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

func _process_elite_melee(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		_change_elite_state(EliteState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	if dist > attack_range * 1.3:
		_change_elite_state(EliteState.CHASE)
		return

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

func _process_poison_web() -> void:
	"""Cast poison web — AoE DoT if player within radius."""
	velocity.x = 0.0
	velocity.z = 0.0

	_cast_poison_web()
	poison_timer = poison_web_cooldown
	_change_elite_state(EliteState.CHASE)

func _process_summon() -> void:
	"""Summon spiderlings near the elite."""
	velocity.x = 0.0
	velocity.z = 0.0

	_summon_spiderlings()
	summon_timer = summon_cooldown
	_change_elite_state(EliteState.CHASE)

# ─── Ability: Poison Web ──────────────────────────────────────
func _cast_poison_web() -> void:
	"""Cast a poison web at the player's position. If within radius, apply DoT."""
	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Spawn visual effect at player position
	_spawn_poison_web_vfx(player_ref.global_position)

	if dist <= poison_web_radius:
		# Apply poison DoT
		poison_dot_ticks_remaining = poison_ticks
		poison_dot_timer = 0.0  # First tick immediately
		print("[EliteEnemy] 毒网命中！DoT applied: %d ticks of %.0f damage" % [poison_ticks, poison_tick_damage])
	else:
		print("[EliteEnemy] 毒网 cast — player dodged (%.1fm away)" % dist)

func _process_poison_dot(delta: float) -> void:
	"""Process active poison DoT ticking on the player."""
	if poison_dot_ticks_remaining <= 0:
		return

	poison_dot_timer -= delta
	if poison_dot_timer <= 0.0:
		# Apply a tick of poison damage
		if player_ref != null and player_ref.has_method("take_damage"):
			player_ref.take_damage(poison_tick_damage)
			CombatSystem.damage_dealt.emit(player_ref, poison_tick_damage, false)
			print("[EliteEnemy] 毒伤 tick → %.0f damage (%d remaining)" % [poison_tick_damage, poison_dot_ticks_remaining - 1])

		poison_dot_ticks_remaining -= 1
		poison_dot_timer = poison_tick_interval

func _spawn_poison_web_vfx(target_pos: Vector3) -> void:
	"""Spawn purple-green poison web particles at the target position."""
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 2.0
	particles.one_shot = true
	particles.explosiveness = 0.8

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.5, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -1.0, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.1
	mat.scale_max = 0.3

	# Emission shape: sphere matching web radius
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = poison_web_radius

	# Color ramp: purple-green poison colors
	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.4, 0.1, 0.7, 1.0))
	gradient.add_point(0.5, Color(0.2, 0.6, 0.3, 0.7))
	gradient.set_color(1, Color(0.1, 0.3, 0.1, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat

	# Quad mesh for particles
	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.25, 0.25)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.4, 0.2, 0.6)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.3, 0.5, 0.2)
	draw_mat.emission_energy_multiplier = 1.5
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = target_pos + Vector3(0, 0.3, 0)
	get_tree().current_scene.add_child(particles)

	# Cleanup
	var cleanup_timer := get_tree().create_timer(3.0)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

# ─── Ability: Summon Spiderlings ───────────────────────────────
func _summon_spiderlings() -> void:
	"""Summon SwarmEnemy spiderlings near the elite."""
	if swarm_scene == null:
		print("[EliteEnemy] Cannot summon — SwarmEnemy scene not loaded")
		return

	var spawned: int = 0
	for i in range(summon_count):
		var spider := swarm_scene.instantiate()
		# Spawn at offset positions around the elite
		var angle := (TAU / summon_count) * i + randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle) * 2.0, 0.0, sin(angle) * 2.0)
		spider.position = global_position + offset
		spider.position.y = 0.5

		# Add to scene
		var room := get_parent()
		if room:
			room.add_child(spider)
			# Register with RoomManager: increment counters and connect signal
			var rm := room.find_child("RoomManager", true, false)
			if rm:
				rm.total_enemies += 1
				rm.enemies_alive += 1
				if spider.has_signal("defeated"):
					spider.defeated.connect(rm._on_enemy_defeated)
			spawned += 1

	# Summon visual effect
	_spawn_summon_vfx()
	print("[EliteEnemy] 召唤蛛兵！Spawned %d spiderlings" % spawned)

func _spawn_summon_vfx() -> void:
	"""Purple burst effect when summoning."""
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.9

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1.0, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.25
	mat.color = Color(0.5, 0.1, 0.7)

	particles.process_material = mat

	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.2, 0.2)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color = Color(0.5, 0.15, 0.7)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.4, 0.1, 0.6)
	draw_mat.emission_energy_multiplier = 1.5
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	particles.position = global_position + Vector3(0, 1.0, 0)
	get_tree().current_scene.add_child(particles)

	var cleanup_timer := get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

# ─── Override Damage Handling ──────────────────────────────────
func take_damage(amount: float) -> void:
	if elite_state == EliteState.DEAD:
		return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_label()

	# Aggro on hit
	if elite_state == EliteState.IDLE:
		_change_elite_state(EliteState.CHASE)

	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_change_elite_state(EliteState.DEAD)
	current_state = AIState.DEAD
	defeated.emit(self)
	elite_defeated.emit()
	CombatSystem.on_enemy_defeated(self)

	# Drop loot
	_drop_elite_loot()

	# Visual: darken and sink
	var mat := mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = false

	collision.set_deferred("disabled", true)

	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 1.5, 1.0)
	tween.tween_callback(queue_free)

	print("[EliteEnemy] 幽冥蛛后 DEFEATED!")

func _drop_elite_loot() -> void:
	"""Drop 15-25 spirit stones + 50% chance equipment."""
	var stones := randi_range(15, 25)
	PlayerData.add_spirit_stones(stones)
	print("[EliteEnemy] Dropped %d spirit stones" % stones)

	# 50% chance equipment drop
	if randf() < 0.5:
		if GameManager.has_method("grant_random_equipment"):
			var equip := GameManager.grant_random_equipment()
			PlayerData.add_to_inventory(equip)
			print("[EliteEnemy] Dropped random equipment")
		else:
			var bonus := randi_range(10, 20)
			PlayerData.add_spirit_stones(bonus)
			print("[EliteEnemy] No equipment system — bonus %d spirit stones" % bonus)

# ─── HP Label Override ─────────────────────────────────────────
func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = "%s\n%.0f / %.0f" % [enemy_name, current_hp, max_hp]
		var hp_pct := current_hp / max_hp
		if hp_pct > 0.5:
			hp_label.modulate = Color(0.7, 0.5, 1.0)  # Elite purple
		elif hp_pct > 0.2:
			hp_label.modulate = Color(1.0, 0.4, 0.1)
		else:
			hp_label.modulate = Color(1.0, 0.1, 0.1)

# ─── Helpers ───────────────────────────────────────────────────
func _change_elite_state(new_state: EliteState) -> void:
	elite_state = new_state

# Override base _physics_process to prevent double processing
func _process_idle() -> void:
	pass

func _process_chase(_delta: float) -> void:
	pass

func _process_attack(_delta: float) -> void:
	pass
