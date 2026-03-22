extends "res://scripts/enemies/Enemy.gd"
## TankEnemy — 重甲型 (玄铁石魔)
##
## Very slow, high HP, high defense.
## Has a charge attack when player is at medium range (4-8m).
## Charge deals 1.5x damage with 6s cooldown.

# ─── Charge Attack Constants ──────────────────────────────────
@export var charge_range_min: float = 4.0
@export var charge_range_max: float = 8.0
@export var charge_speed: float = 10.0
@export var charge_damage_multiplier: float = 1.5
@export var charge_cooldown: float = 6.0

# ─── Tank AI States ───────────────────────────────────────────
enum TankState { IDLE, CHASE, ATTACK, CHARGING, DEAD }
var tank_state: TankState = TankState.IDLE

# ─── Runtime ───────────────────────────────────────────────────
var charge_timer: float = 0.0
var charge_target_pos: Vector3 = Vector3.ZERO
var is_charging: bool = false

func _ready() -> void:
	model_type = "tank"
	model_scale = 0.9
	super()
	# Override base stats for tank type
	max_hp = 120.0
	attack_power = 10.0
	defense = 8.0
	move_speed = 2.0
	chase_range = 12.0
	attack_range = 2.5
	attack_cooldown = 2.0
	enemy_name = "玄铁石魔"

	current_hp = max_hp
	_update_hp_label()

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

	call_deferred("_find_player")
	print("[TankEnemy] Spawned — HP:%.0f ATK:%.0f DEF:%.0f" % [max_hp, attack_power, defense])

func _physics_process(delta: float) -> void:
	if tank_state == TankState.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update cooldowns
	if attack_timer > 0.0:
		attack_timer -= delta
	if charge_timer > 0.0:
		charge_timer -= delta

	match tank_state:
		TankState.IDLE:
			_process_tank_idle()
		TankState.CHASE:
			_process_tank_chase(delta)
		TankState.ATTACK:
			_process_tank_attack(delta)
		TankState.CHARGING:
			_process_charge(delta)

	move_and_slide()

# ─── Tank State Processing ────────────────────────────────────
func _process_tank_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= chase_range:
		_change_tank_state(TankState.CHASE)

func _process_tank_chase(delta: float) -> void:
	if player_ref == null:
		_change_tank_state(TankState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Lost interest
	if dist > chase_range * 1.5:
		_change_tank_state(TankState.IDLE)
		return

	# Check for charge opportunity
	if dist >= charge_range_min and dist <= charge_range_max and charge_timer <= 0.0:
		_start_charge()
		return

	# Close enough to melee attack
	if dist <= attack_range:
		_change_tank_state(TankState.ATTACK)
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

func _process_tank_attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		_change_tank_state(TankState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Out of melee range — chase or charge
	if dist > attack_range * 1.3:
		_change_tank_state(TankState.CHASE)
		return

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	# Melee attack when cooldown ready
	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

func _start_charge() -> void:
	"""Begin charging toward the player's current position."""
	if player_ref == null:
		return

	charge_target_pos = player_ref.global_position
	is_charging = true
	if character_model != null:
		character_model.play("Weapon", 0.08)
	_change_tank_state(TankState.CHARGING)
	print("[TankEnemy:%s] CHARGING!" % enemy_name)

func _process_charge(delta: float) -> void:
	"""Rush toward the charge target position at high speed."""
	var dist_to_target := global_position.distance_to(charge_target_pos)

	# Reached charge destination or close enough
	if dist_to_target < 1.5:
		_end_charge()
		return

	# Move directly toward charge target
	var direction := (charge_target_pos - global_position).normalized()
	direction.y = 0.0

	velocity.x = direction.x * charge_speed
	velocity.z = direction.z * charge_speed

	if direction.length() > 0.1:
		rotation.y = atan2(direction.x, direction.z)

	# Check if we hit the player during charge
	if player_ref != null and is_instance_valid(player_ref):
		var dist_to_player := global_position.distance_to(player_ref.global_position)
		if dist_to_player <= attack_range:
			_perform_charge_hit()
			_end_charge()

func _end_charge() -> void:
	"""End the charge and set cooldown."""
	is_charging = false
	charge_timer = charge_cooldown
	velocity.x = 0.0
	velocity.z = 0.0
	_change_tank_state(TankState.CHASE)

func _perform_charge_hit() -> void:
	"""Deal charge damage (1.5x multiplier) to the player."""
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	if character_model != null:
		character_model.play("Weapon", 0.05)

	var damage_info := CombatSystem.calculate_damage(
		attack_power, PlayerData.get_total_defense(), charge_damage_multiplier
	)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])
	print("[TankEnemy:%s] Charge hit → %.1f damage%s" % [
		enemy_name, damage_info["amount"],
		" (CRIT!)" if damage_info["is_critical"] else ""
	])

# ─── Override base damage handling ─────────────────────────────
func take_damage(amount: float) -> void:
	if tank_state == TankState.DEAD:
		return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_label()

	# Aggro on hit
	if tank_state == TankState.IDLE:
		_change_tank_state(TankState.CHASE)

	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_change_tank_state(TankState.DEAD)
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

	print("[TankEnemy:%s] Defeated!" % enemy_name)

# ─── Helpers ───────────────────────────────────────────────────
func _change_tank_state(new_state: TankState) -> void:
	tank_state = new_state
	if character_model == null:
		return
	match new_state:
		TankState.IDLE:
			character_model.play("Idle")
		TankState.CHASE, TankState.CHARGING:
			character_model.play("Run")
		TankState.ATTACK:
			character_model.play("Punch")
		TankState.DEAD:
			character_model.play("Death")

# Override base _physics_process to prevent double processing
func _process_idle() -> void:
	pass

func _process_chase(_delta: float) -> void:
	pass

func _process_attack(_delta: float) -> void:
	pass
