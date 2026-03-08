extends CharacterBody3D
## Player — Third-person character controller
##
## Features:
## - WASD movement relative to camera direction
## - Third-person camera (SpringArm3D + Camera3D)
## - Sprint (Shift) and dash (Space/double-tap)
## - Animation states: Idle, Walk, Run, Dash
## - Integrates with PlayerData for stats
## - Auto-battle toggle (Q key)

# ─── Movement Constants ────────────────────────────────────────
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.5
const DASH_SPEED: float = 18.0
const DASH_DURATION: float = 0.25
const DASH_COOLDOWN: float = 0.8
const ROTATION_SPEED: float = 10.0
const GRAVITY: float = 20.0

# ─── Camera Constants ──────────────────────────────────────────
const CAMERA_MOUSE_SENSITIVITY: float = 0.003
const CAMERA_MIN_PITCH: float = -1.2  # radians (~-70 deg)
const CAMERA_MAX_PITCH: float = 0.5   # radians (~+30 deg)

# ─── Animation States ─────────────────────────────────────────
enum AnimState { IDLE, WALK, RUN, DASH }

# ─── Runtime State ─────────────────────────────────────────────
var current_anim_state: AnimState = AnimState.IDLE
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_sp: float = 50.0   # spiritual power / mana
var max_sp: float = 50.0

# Dash
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

# Camera
var camera_yaw: float = 0.0
var camera_pitch: float = -0.5

# ─── Node References ──────────────────────────────────────────
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D

# ─── Signals ───────────────────────────────────────────────────
signal hp_changed(current: float, maximum: float)
signal sp_changed(current: float, maximum: float)
signal anim_state_changed(new_state: AnimState)
signal died()

func _ready() -> void:
	# Initialize stats from PlayerData
	max_hp = PlayerData.get_total_hp()
	current_hp = max_hp
	max_sp = PlayerData.sp_max
	current_sp = PlayerData.sp

	# Listen for SP changes from PlayerData
	PlayerData.sp_updated.connect(_on_sp_updated)

	# Capture mouse for camera control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	hp_changed.emit(current_hp, max_hp)
	sp_changed.emit(current_sp, max_sp)
	print("[Player] Ready — HP: %.0f, SP: %.0f/%.0f" % [max_hp, current_sp, max_sp])

func _unhandled_input(event: InputEvent) -> void:
	# Camera rotation via mouse
	if event is InputEventMouseMotion:
		camera_yaw -= event.relative.x * CAMERA_MOUSE_SENSITIVITY
		camera_pitch -= event.relative.y * CAMERA_MOUSE_SENSITIVITY
		camera_pitch = clamp(camera_pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Auto-battle toggle
	if event.is_action_pressed("toggle_auto_battle"):
		CombatSystem.toggle_auto_battle()

	# Skill hotkeys [1]-[4]
	if event is InputEventKey and event.pressed and not event.echo:
		var hotkey_index := -1
		match event.keycode:
			KEY_1: hotkey_index = 0
			KEY_2: hotkey_index = 1
			KEY_3: hotkey_index = 2
			KEY_4: hotkey_index = 3
		if hotkey_index >= 0:
			_use_skill_hotkey(hotkey_index)

func _physics_process(delta: float) -> void:
	_update_camera()
	_update_dash_timers(delta)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	move_and_slide()
	_update_animation_state()

# ─── Camera ────────────────────────────────────────────────────
func _update_camera() -> void:
	spring_arm.rotation.x = camera_pitch
	spring_arm.rotation.y = camera_yaw

# ─── Movement ──────────────────────────────────────────────────
func _process_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	input_dir = input_dir.normalized()

	# Movement relative to camera direction
	var cam_basis := spring_arm.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var move_dir := (forward * -input_dir.y + right * input_dir.x)

	# Sprint check
	var is_sprinting := Input.is_action_pressed("sprint") and move_dir.length() > 0.1
	var speed := RUN_SPEED if is_sprinting else WALK_SPEED

	if move_dir.length() > 0.1:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		# Rotate character to face movement direction
		var target_rot := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)

	# Dash initiation
	if Input.is_action_just_pressed("dodge") and dash_cooldown_timer <= 0.0:
		_start_dash(move_dir if move_dir.length() > 0.1 else -global_transform.basis.z)

# ─── Dash ──────────────────────────────────────────────────────
func _start_dash(direction: Vector3) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_direction = direction.normalized()

func _process_dash(_delta: float) -> void:
	velocity.x = dash_direction.x * DASH_SPEED
	velocity.z = dash_direction.z * DASH_SPEED

func _update_dash_timers(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

# ─── Animation State Machine ──────────────────────────────────
func _update_animation_state() -> void:
	var new_state: AnimState
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	if is_dashing:
		new_state = AnimState.DASH
	elif horizontal_speed > RUN_SPEED * 0.8:
		new_state = AnimState.RUN
	elif horizontal_speed > 0.5:
		new_state = AnimState.WALK
	else:
		new_state = AnimState.IDLE

	if new_state != current_anim_state:
		current_anim_state = new_state
		anim_state_changed.emit(new_state)
		# TODO: Drive AnimationTree parameters here

# ─── Combat Integration ───────────────────────────────────────
func take_damage(amount: float) -> void:
	"""Called by CombatSystem when player takes a hit."""
	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		_on_death()

func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func use_spiritual_power(amount: float) -> bool:
	"""Attempt to spend SP. Returns false if insufficient."""
	if current_sp >= amount:
		current_sp -= amount
		sp_changed.emit(current_sp, max_sp)
		return true
	return false

func _on_sp_updated(current: float, maximum: float) -> void:
	"""Sync SP display when PlayerData SP changes (regen, skill use, etc.)."""
	current_sp = current
	max_sp = maximum
	sp_changed.emit(current_sp, max_sp)

# ─── Skill Hotkeys ─────────────────────────────────────────────
func _use_skill_hotkey(index: int) -> void:
	"""Activate a skill by hotkey index (0-3)."""
	# Build the same list the HUD skill panel uses
	var skills_to_use: Array[String] = []
	for sid in PlayerData.equipped_skills:
		skills_to_use.append(sid)
	if skills_to_use.size() == 0:
		for sid in PlayerData.unlocked_skills:
			if skills_to_use.size() >= 4:
				break
			skills_to_use.append(sid)

	if index >= skills_to_use.size():
		return  # No skill in that slot

	var skill_id: String = skills_to_use[index]

	# Find target: use CombatSystem's current target, or find nearest enemy
	var target: Node = CombatSystem.current_target
	if target == null or not is_instance_valid(target):
		target = _find_nearest_enemy()

	if target == null:
		print("[Player] No target for skill %s" % skill_id)
		return

	# Signal manual input to CombatSystem
	CombatSystem.on_manual_input()
	CombatSystem.execute_skill(skill_id, target)

func _find_nearest_enemy() -> Node:
	"""Find the nearest enemy in the 'enemies' group."""
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest: Node = null
	var nearest_dist := INF
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy
	return nearest

func _on_death() -> void:
	died.emit()
	print("[Player] Defeated!")
	# TODO: Trigger death animation, end run
