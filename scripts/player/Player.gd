extends CharacterBody3D
## Player — Third-person character controller
##
## Features:
## - WASD movement relative to camera direction
## - Third-person camera (SpringArm3D + Camera3D)
## - Sprint (Shift) and dash (Space/double-tap)
## - Animation states: Idle, Walk, Run, Dash
## - Integrates with PlayerData for stats
## - Auto-battle toggle (X key)

const CharacterModelScript = preload("res://scripts/core/CharacterModel.gd")

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

# Combat animation lock — prevents movement anims from overriding attack/skill anims
var _combat_anim_lock: float = 0.0

# Camera
var camera_yaw: float = 0.0
var camera_pitch: float = -0.5

# ─── Node References ──────────────────────────────────────────
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
var character_model: Node3D = null
var anim_player: AnimationPlayer = null
var model_yaw_offset: float = PI

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

	# Load 3D character model
	_setup_character_model()

	# Capture mouse for camera control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	hp_changed.emit(current_hp, max_hp)
	sp_changed.emit(current_sp, max_sp)
	print("[Player] Ready — HP: %.0f, SP: %.0f/%.0f" % [max_hp, current_sp, max_sp])

func _setup_character_model() -> void:
	"""Load 3D character model, hide placeholder capsule."""
	character_model = CharacterModelScript.new()
	character_model.name = "CharacterModel"
	add_child(character_model)
	character_model.load_model("player", 1.3)
	model_yaw_offset = character_model.facing_yaw_offset if "facing_yaw_offset" in character_model else PI
	character_model.rotation.y = model_yaw_offset
	if character_model.mesh_instance:
		mesh.visible = false
		anim_player = character_model.anim_player

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

	# Skill hotkeys Q/E/R/T — check both keycode and physical_keycode for IME compat
	if event is InputEventKey and event.pressed and not event.echo:
		var hotkey_index := -1
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		match key:
			KEY_Q: hotkey_index = 0
			KEY_E: hotkey_index = 1
			KEY_R: hotkey_index = 2
			KEY_T: hotkey_index = 3
		if hotkey_index >= 0:
			_use_skill_hotkey(hotkey_index)

func _physics_process(delta: float) -> void:
	_update_camera()
	_update_dash_timers(delta)

	# Tick combat animation lock
	if _combat_anim_lock > 0.0:
		_combat_anim_lock -= delta

	# Manual attack (left click)
	if Input.is_action_just_pressed("attack"):
		var target := _find_nearest_enemy()
		if target != null:
			CombatSystem.on_manual_input()
			CombatSystem._perform_basic_attack(target)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Fall off platform detection — take damage and respawn on platform
	if global_position.y < -10.0:
		_on_fall_off_platform()

	if is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	_update_combat_facing(delta)

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

	var move_dir := (forward * input_dir.y + right * input_dir.x)

	# Sprint check — scale by spiritual root speed bonus
	var is_sprinting := Input.is_action_pressed("sprint") and move_dir.length() > 0.1
	var root_speed := PlayerData.get_speed_multiplier()
	var speed := (RUN_SPEED if is_sprinting else WALK_SPEED) * root_speed

	if move_dir.length() > 0.1:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		# Rotate model to face movement direction (not the CharacterBody3D,
		# because SpringArm3D is a child and would shift the camera basis)
		var target_rot := atan2(move_dir.x, move_dir.z)
		if character_model:
			character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rot + model_yaw_offset, ROTATION_SPEED * delta)
		else:
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rot, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)

	# Dash initiation
	if Input.is_action_just_pressed("dodge") and dash_cooldown_timer <= 0.0:
		var cam_forward := -spring_arm.global_transform.basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		_start_dash(move_dir if move_dir.length() > 0.1 else cam_forward)

func _update_combat_facing(delta: float) -> void:
	"""Keep the model oriented toward the current combat target when auto-battling or attacking."""
	if not PlayerData.in_combat or is_dashing:
		return

	var target: Node = CombatSystem.current_target
	if target == null or not is_instance_valid(target):
		return

	var should_track_target := CombatSystem.current_state == CombatSystem.CombatState.AUTO_BATTLE
	should_track_target = should_track_target or _combat_anim_lock > 0.0
	should_track_target = should_track_target or Vector2(velocity.x, velocity.z).length() < 0.15

	if should_track_target:
		face_toward_position(target.global_position, delta, false)

# ─── Dash ──────────────────────────────────────────────────────
func _start_dash(direction: Vector3) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_direction = direction.normalized()
	face_toward_position(global_position + dash_direction, 0.0, true)

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
func play_combat_anim(anim_name: String, duration: float = 0.6) -> void:
	"""Play a combat animation and lock out movement anims for duration."""
	if character_model != null:
		character_model.play(anim_name, 0.1)
		_combat_anim_lock = duration

func _update_animation_state() -> void:
	# Don't override combat animations (attack/skill/hit)
	if _combat_anim_lock > 0.0:
		return

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
		# Drive character model animations
		if character_model:
			match new_state:
				AnimState.IDLE:
					character_model.play("Idle")
				AnimState.WALK:
					character_model.play("Walk")
				AnimState.RUN:
					character_model.play("Run")
				AnimState.DASH:
					character_model.play("Jump")

# ─── Combat Integration ───────────────────────────────────────
func take_damage(amount: float) -> void:
	"""Called by CombatSystem when player takes a hit."""
	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)

	# Play hit reaction animation
	if current_hp > 0.0:
		play_combat_anim("HitReact", 0.4)

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

	print("[Player] Skill hotkey %d pressed — equipped: %s, unlocked: %s, available: %s" % [
		index, str(PlayerData.equipped_skills), str(PlayerData.unlocked_skills), str(skills_to_use)
	])

	if index >= skills_to_use.size():
		print("[Player] No skill in slot %d" % index)
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

func face_toward_position(target_position: Vector3, delta: float = 0.0, instant: bool = false) -> void:
	"""Rotate the visible player model toward a world-space target on the horizontal plane."""
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return

	var target_rot := atan2(direction.x, direction.z)
	var visual_node: Node3D = character_model if character_model != null else mesh
	if visual_node == null:
		return

	if visual_node == character_model:
		target_rot += model_yaw_offset

	if instant or delta <= 0.0:
		visual_node.rotation.y = target_rot
	else:
		visual_node.rotation.y = lerp_angle(visual_node.rotation.y, target_rot, ROTATION_SPEED * delta)

# ─── Fall Detection ───────────────────────────────────────────
func _on_fall_off_platform() -> void:
	"""Player fell off the platform — take damage and teleport back."""
	var fall_damage := max_hp * 0.2  # 20% max HP
	take_damage(fall_damage)
	print("[Player] Fell off platform! Took %.0f fall damage" % fall_damage)

	# Teleport back to room center
	global_position = Vector3(0.0, 2.0, 0.0)
	velocity = Vector3.ZERO

var _death_triggered: bool = false
const DEATH_SCREEN_PATH: String = "res://scenes/ui/DeathScreen.tscn"

func _goto_death_screen() -> void:
	print("[Player] _goto_death_screen called!")
	GameManager.goto_scene(DEATH_SCREEN_PATH)

func _on_death() -> void:
	if _death_triggered:
		return
	_death_triggered = true
	died.emit()
	print("[Player] Defeated!")

	# Play death animation
	if character_model != null:
		character_model.play("Death", 0.1)

	# Stop combat and player processing
	CombatSystem.end_combat(false)
	set_physics_process(false)
	GameManager.end_run(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Death screen overlay
	var death_canvas := CanvasLayer.new()
	death_canvas.layer = 90
	get_tree().current_scene.add_child(death_canvas)

	# Full screen dark background
	var dark_rect := ColorRect.new()
	dark_rect.color = Color(0, 0, 0, 0)
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_canvas.add_child(dark_rect)

	# "道消陨落" death text
	var death_label := Label.new()
	death_label.text = "道 消 陨 落"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.anchor_left = 0.5
	death_label.anchor_top = 0.4
	death_label.anchor_right = 0.5
	death_label.anchor_bottom = 0.4
	death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	death_label.add_theme_font_size_override("font_size", 64)
	death_label.add_theme_color_override("font_color", Color(0.8, 0.15, 0.15))
	death_label.modulate.a = 0.0
	death_canvas.add_child(death_label)

	# Animate: darken → show text → transition
	print("[Player] Starting death tween animation...")
	var tween := death_canvas.create_tween()
	tween.tween_property(dark_rect, "color:a", 0.85, 0.6)
	tween.parallel().tween_property(death_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(1.5)
	tween.tween_callback(_goto_death_screen)
	tween.finished.connect(func(): print("[Player] Death tween finished signal"))
