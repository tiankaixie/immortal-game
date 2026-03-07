extends CharacterBody3D
## Enemy — Basic enemy AI with state machine
##
## States: Idle, Chase, Attack, Dead
## Uses NavigationAgent3D for pathfinding
## Connects to CombatSystem for damage

# ─── Constants ─────────────────────────────────────────────────
@export var max_hp: float = 50.0
@export var attack_power: float = 8.0
@export var defense: float = 3.0
@export var move_speed: float = 3.5
@export var chase_range: float = 12.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var enemy_name: String = "妖兽"

const GRAVITY: float = 20.0

# ─── AI States ─────────────────────────────────────────────────
enum AIState { IDLE, CHASE, ATTACK, DEAD }
var current_state: AIState = AIState.IDLE

# ─── Runtime ───────────────────────────────────────────────────
var current_hp: float = 50.0
var attack_timer: float = 0.0
var player_ref: CharacterBody3D = null

# ─── Node References ──────────────────────────────────────────
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var hp_label: Label3D = $HPLabel

# ─── Signals ───────────────────────────────────────────────────
signal hp_changed(current: float, maximum: float)
signal defeated(enemy: Node)

func _ready() -> void:
	current_hp = max_hp
	_update_hp_label()

	# NavigationAgent3D setup
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

	# Find player in scene tree (deferred to ensure scene is ready)
	call_deferred("_find_player")

func _find_player() -> void:
	# Try to find player node
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as CharacterBody3D
	else:
		# Fallback: search by node name
		var root := get_tree().current_scene
		if root:
			player_ref = root.find_child("Player", true, false) as CharacterBody3D

func _physics_process(delta: float) -> void:
	if current_state == AIState.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update attack cooldown
	if attack_timer > 0.0:
		attack_timer -= delta

	match current_state:
		AIState.IDLE:
			_process_idle()
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK:
			_process_attack(delta)

	move_and_slide()

# ─── State Processing ─────────────────────────────────────────
func _process_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= chase_range:
		_change_state(AIState.CHASE)

func _process_chase(delta: float) -> void:
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

	# Rotate to face movement
	if direction.length() > 0.1:
		var target_rot := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)

func _process_attack(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref == null:
		_change_state(AIState.IDLE)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Out of range, chase again
	if dist > attack_range * 1.3:
		_change_state(AIState.CHASE)
		return

	# Face the player
	var dir := (player_ref.global_position - global_position).normalized()
	rotation.y = atan2(dir.x, dir.z)

	# Attack when cooldown ready
	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

func _perform_attack() -> void:
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	var damage_info := CombatSystem.calculate_damage(attack_power, PlayerData.get_total_defense(), 1.0)
	player_ref.take_damage(damage_info["amount"])
	CombatSystem.damage_dealt.emit(player_ref, damage_info["amount"], damage_info["is_critical"])
	print("[Enemy:%s] Attacked player for %.1f damage%s" % [
		enemy_name, damage_info["amount"],
		" (CRIT!)" if damage_info["is_critical"] else ""
	])

# ─── Taking Damage ────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if current_state == AIState.DEAD:
		return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_label()

	# Aggro on hit
	if current_state == AIState.IDLE:
		_change_state(AIState.CHASE)

	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_change_state(AIState.DEAD)
	defeated.emit(self)
	CombatSystem.on_enemy_defeated(self)

	# Visual feedback — turn dark and disable collision
	var mat := mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	collision.set_deferred("disabled", true)

	# Remove after short delay
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 1.0, 0.8)
	tween.tween_callback(queue_free)

	print("[Enemy:%s] Defeated!" % enemy_name)

# ─── Helpers ───────────────────────────────────────────────────
func _change_state(new_state: AIState) -> void:
	current_state = new_state

func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = "%s\n%.0f / %.0f" % [enemy_name, current_hp, max_hp]
		# Color based on HP percentage
		var hp_pct := current_hp / max_hp
		if hp_pct > 0.5:
			hp_label.modulate = Color.WHITE
		elif hp_pct > 0.2:
			hp_label.modulate = Color.YELLOW
		else:
			hp_label.modulate = Color.RED
