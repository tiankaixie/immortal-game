extends "res://scripts/enemies/Enemy.gd"
## RangedEnemy — 远程射击型 (灵箭妖弓手)
##
## Keeps distance from player, retreats if too close.
## Fires instant-hit ranged attack every 2.5s.
## Lower HP/defense, higher attack.

# ─── Ranged-Specific Constants ─────────────────────────────────
@export var preferred_range_min: float = 6.0
@export var preferred_range_max: float = 8.0
@export var retreat_range: float = 4.0
@export var ranged_attack_cooldown: float = 2.5

# ─── Ranged AI States ─────────────────────────────────────────
enum RangedState { IDLE, REPOSITION, ATTACK, RETREAT, DEAD }
var ranged_state: RangedState = RangedState.IDLE

# ─── Runtime ───────────────────────────────────────────────────
var ranged_attack_timer: float = 0.0

func _ready() -> void:
	model_type = "ranged"
	model_scale = 0.8
	super()
	# Override base stats for ranged type
	max_hp = 35.0
	attack_power = 12.0
	defense = 2.0
	move_speed = 3.5
	chase_range = 14.0
	attack_range = preferred_range_max  # Override base attack_range
	attack_cooldown = ranged_attack_cooldown
	enemy_name = "灵箭妖弓手"

	current_hp = max_hp
	_update_hp_label()

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

	call_deferred("_find_player")
	print("[RangedEnemy] Spawned — HP:%.0f ATK:%.0f DEF:%.0f" % [max_hp, attack_power, defense])

func _physics_process(delta: float) -> void:
	if ranged_state == RangedState.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update ranged attack timer
	if ranged_attack_timer > 0.0:
		ranged_attack_timer -= delta

	match ranged_state:
		RangedState.IDLE:
			_process_ranged_idle()
		RangedState.REPOSITION:
			_process_reposition(delta)
		RangedState.ATTACK:
			_process_ranged_attack(delta)
		RangedState.RETREAT:
			_process_retreat(delta)

	move_and_slide()

# ─── Ranged State Processing ──────────────────────────────────
func _process_ranged_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= chase_range:
		if dist < retreat_range:
			_change_ranged_state(RangedState.RETREAT)
		elif dist <= preferred_range_max:
			_change_ranged_state(RangedState.ATTACK)
		else:
			_change_ranged_state(RangedState.REPOSITION)

func _process_reposition(delta: float) -> void:
	"""Move to preferred firing range."""
	if player_ref == null:
		_change_ranged_state(RangedState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Lost interest
	if dist > chase_range * 1.5:
		_change_ranged_state(RangedState.IDLE)
		return

	# Player too close — retreat
	if dist < retreat_range:
		_change_ranged_state(RangedState.RETREAT)
		return

	# In firing range — switch to attack
	if dist >= preferred_range_min and dist <= preferred_range_max:
		_change_ranged_state(RangedState.ATTACK)
		return

	# Navigate toward player to get in range
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
		rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)

func _process_ranged_attack(delta: float) -> void:
	"""Stand and fire at player from range."""
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		_change_ranged_state(RangedState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Player rushed in — retreat
	if dist < retreat_range:
		_change_ranged_state(RangedState.RETREAT)
		return

	# Player moved out of range — reposition
	if dist > preferred_range_max * 1.3:
		_change_ranged_state(RangedState.REPOSITION)
		return

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	# Fire when cooldown ready
	if ranged_attack_timer <= 0.0:
		_perform_ranged_attack()
		ranged_attack_timer = ranged_attack_cooldown

func _process_retreat(delta: float) -> void:
	"""Move away from player to regain distance."""
	if player_ref == null:
		_change_ranged_state(RangedState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Far enough — switch to attack or reposition
	if dist >= preferred_range_min:
		_change_ranged_state(RangedState.ATTACK)
		return

	# Move directly away from player
	var away_dir := (global_position - player_ref.global_position).normalized()
	away_dir.y = 0.0

	# Calculate retreat target position
	var retreat_target := global_position + away_dir * 3.0
	nav_agent.target_position = retreat_target

	if not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var direction := (next_pos - global_position).normalized()
		direction.y = 0.0

		# Retreat at slightly faster speed
		velocity.x = direction.x * move_speed * 1.3
		velocity.z = direction.z * move_speed * 1.3
	else:
		# Can't retreat further — stand and fight
		velocity.x = 0.0
		velocity.z = 0.0
		if ranged_attack_timer <= 0.0:
			_perform_ranged_attack()
			ranged_attack_timer = ranged_attack_cooldown

	# Face away from player while retreating
	if away_dir.length() > 0.1:
		var target_rot := atan2(-away_dir.x, -away_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 6.0 * delta)

func _perform_ranged_attack() -> void:
	"""Instant-hit ranged attack using damage calculation."""
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	var damage_info := CombatSystem.calculate_damage(attack_power, PlayerData.get_total_defense(), 1.0)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])
	print("[RangedEnemy:%s] Ranged attack → %.1f damage%s" % [
		enemy_name, damage_info["amount"],
		" (CRIT!)" if damage_info["is_critical"] else ""
	])

# ─── Override base damage handling ─────────────────────────────
func take_damage(amount: float) -> void:
	if ranged_state == RangedState.DEAD:
		return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_label()

	# Aggro on hit — try to retreat if hit
	if ranged_state == RangedState.IDLE:
		_change_ranged_state(RangedState.RETREAT)

	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_change_ranged_state(RangedState.DEAD)
	# Set base state too so base class checks work
	current_state = AIState.DEAD
	defeated.emit(self)
	CombatSystem.on_enemy_defeated(self)

	var mat := mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	collision.set_deferred("disabled", true)

	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 1.0, 0.8)
	tween.tween_callback(queue_free)

	print("[RangedEnemy:%s] Defeated!" % enemy_name)

# ─── Helpers ───────────────────────────────────────────────────
func _change_ranged_state(new_state: RangedState) -> void:
	ranged_state = new_state

# Override base _physics_process to prevent double processing
func _process_idle() -> void:
	pass

func _process_chase(_delta: float) -> void:
	pass

func _process_attack(_delta: float) -> void:
	pass
