extends "res://scripts/enemies/Enemy.gd"
## SwarmEnemy — 群体型 (噬灵蜂)
##
## Very low HP, low attack, very fast.
## Always spawns in groups of 3 (handled by DungeonController).
## Erratic movement with random offset to navigation target.

# ─── Swarm-Specific Constants ─────────────────────────────────
@export var erratic_offset_range: float = 2.0
@export var offset_change_interval: float = 0.8

# ─── Runtime ───────────────────────────────────────────────────
var erratic_offset: Vector3 = Vector3.ZERO
var offset_timer: float = 0.0

func _ready() -> void:
	model_type = "swarm"
	model_scale = 0.5
	super()
	# Override base stats for swarm type
	max_hp = 20.0
	attack_power = 4.0
	defense = 1.0
	move_speed = 6.0
	chase_range = 15.0
	attack_range = 1.8
	attack_cooldown = 1.0
	enemy_name = "噬灵蜂"

	current_hp = max_hp
	_update_hp_label()

	nav_agent.path_desired_distance = 0.8
	nav_agent.target_desired_distance = 1.0

	# Start with a random offset
	_randomize_offset()

	call_deferred("_find_player")
	print("[SwarmEnemy] Spawned — HP:%.0f ATK:%.0f SPD:%.0f" % [max_hp, attack_power, move_speed])

func _physics_process(delta: float) -> void:
	if current_state == AIState.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update attack cooldown
	if attack_timer > 0.0:
		attack_timer -= delta

	# Update erratic offset timer
	offset_timer -= delta
	if offset_timer <= 0.0:
		_randomize_offset()
		offset_timer = offset_change_interval

	match current_state:
		AIState.IDLE:
			_process_swarm_idle()
		AIState.CHASE:
			_process_swarm_chase(delta)
		AIState.ATTACK:
			_process_swarm_attack(delta)

	move_and_slide()

# ─── Swarm State Processing ───────────────────────────────────
func _process_swarm_idle() -> void:
	# Slight erratic idle movement
	velocity.x = erratic_offset.x * 0.5
	velocity.z = erratic_offset.z * 0.5

	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= chase_range:
		_change_state(AIState.CHASE)

func _process_swarm_chase(delta: float) -> void:
	if player_ref == null:
		_change_state(AIState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Lost interest
	if dist > chase_range * 1.5:
		_change_state(AIState.IDLE)
		return

	# Close enough to attack
	if dist <= attack_range:
		_change_state(AIState.ATTACK)
		return

	# Navigate toward player with erratic offset
	var target_pos := player_ref.global_position + erratic_offset
	nav_agent.target_position = target_pos

	if nav_agent.is_navigation_finished():
		velocity.x = erratic_offset.x
		velocity.z = erratic_offset.z
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0.0

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	# Rotate quickly (erratic)
	if direction.length() > 0.1:
		var target_rot := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 12.0 * delta)

func _process_swarm_attack(delta: float) -> void:
	# Swarm enemies keep moving slightly while attacking
	if player_ref == null:
		_change_state(AIState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Out of range — chase again
	if dist > attack_range * 1.5:
		_change_state(AIState.CHASE)
		return

	# Slight erratic movement during attack
	velocity.x = erratic_offset.x * 0.3
	velocity.z = erratic_offset.z * 0.3

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	# Attack when cooldown ready
	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

# ─── Helpers ───────────────────────────────────────────────────
func _randomize_offset() -> void:
	"""Generate a new random erratic offset."""
	erratic_offset = Vector3(
		randf_range(-erratic_offset_range, erratic_offset_range),
		0.0,
		randf_range(-erratic_offset_range, erratic_offset_range)
	)

# Override base state processors to use swarm versions
func _process_idle() -> void:
	_process_swarm_idle()

func _process_chase(delta: float) -> void:
	_process_swarm_chase(delta)

func _process_attack(delta: float) -> void:
	_process_swarm_attack(delta)
