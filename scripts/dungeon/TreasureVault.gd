extends Node3D
## TreasureVault — 宝库房间
##
## A treasure room with 2 golden chests placed symmetrically.
## Press F to open a chest: 50% chance of boon selection, 50% spirit stones.
## Chest plays open animation (scale tween + golden particles).

const SPIRIT_STONE_REWARD_MIN: int = 30
const SPIRIT_STONE_REWARD_MAX: int = 60

var chests_opened: int = 0
var player_ref: Node3D = null

func _ready() -> void:
	call_deferred("_setup_chests")

func _setup_chests() -> void:
	"""Initialize player reference and tag chest nodes for interaction."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	# Also find player as direct child (initial room load)
	if player_ref == null:
		player_ref = get_node_or_null("Player")

	# Tag chest nodes with metadata so _try_open_nearest_chest can find them
	for child in get_children():
		if child.name.begins_with("Chest"):
			child.set_meta("is_treasure_chest", true)
			child.set_meta("chest_opened", false)
	print("[TreasureVault] Chests initialized")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_try_open_nearest_chest()

func _try_open_nearest_chest() -> void:
	"""Find the nearest unopened chest within range and open it."""
	if player_ref == null or not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]
		else:
			return

	var nearest_chest: Node3D = null
	var nearest_dist: float = 999.0

	for child in get_children():
		if child.has_meta("is_treasure_chest") and child.get_meta("is_treasure_chest") == true:
			if child.has_meta("chest_opened") and child.get_meta("chest_opened") == true:
				continue
			var dist: float = player_ref.global_position.distance_to(child.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_chest = child

	if nearest_chest == null or nearest_dist > 3.0:
		return

	_open_chest(nearest_chest)

func _open_chest(chest: Node3D) -> void:
	"""Open a chest with animation and reward."""
	if chest.has_meta("chest_opened") and chest.get_meta("chest_opened") == true:
		return

	chest.set_meta("chest_opened", true)
	chests_opened += 1
	print("[TreasureVault] Chest opened! (%d/2)" % chests_opened)

	# Play open animation: scale up then back
	var tween := create_tween()
	tween.tween_property(chest, "scale", Vector3(1.2, 1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(chest, "scale", Vector3(1.0, 1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)

	# Spawn golden particles
	_spawn_golden_particles(chest.global_position + Vector3(0, 0.8, 0))

	# Play SFX
	AudioManager.play_sfx("pickup")

	# Hide the interaction label
	var label := chest.get_node_or_null("Label3D")
	if label:
		label.text = "✦ 已开启 ✦"
		label.modulate = Color(0.6, 0.6, 0.6)

	# 50/50: boon selection or spirit stones
	if randf() < 0.5:
		# Grant spirit stones
		var stones := randi_range(SPIRIT_STONE_REWARD_MIN, SPIRIT_STONE_REWARD_MAX)
		GameManager.run_spirit_stones += stones
		PlayerData.spirit_stones += stones
		print("[TreasureVault] Granted %d spirit stones!" % stones)
		_show_reward_text(chest.global_position, "灵石 +%d" % stones)
	else:
		# Show boon selection
		call_deferred("_show_boon_selection")

func _show_boon_selection() -> void:
	"""Display boon UI for the player to choose."""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var boon_ui_scene := load("res://scenes/ui/BoonUI.tscn")
	if boon_ui_scene:
		var boon_ui := boon_ui_scene.instantiate()
		add_child(boon_ui)
		if boon_ui.has_signal("boon_chosen"):
			boon_ui.boon_chosen.connect(_on_boon_chosen)
	else:
		push_warning("[TreasureVault] BoonUI.tscn not found")

func _on_boon_chosen(_boon_id: String) -> void:
	"""Boon was chosen, resume gameplay."""
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _show_reward_text(pos: Vector3, text: String) -> void:
	"""Show floating 3D text at the reward position."""
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.85, 0.2)
	label.global_position = pos + Vector3(0, 1.5, 0)
	get_tree().current_scene.add_child(label)

	# Float up and fade out
	var tween := label.create_tween()
	tween.tween_property(label, "global_position:y", pos.y + 3.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

func _spawn_golden_particles(pos: Vector3) -> void:
	"""Create a burst of golden particles at the given position."""
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 1.2
	particles.global_position = pos

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -5, 0)
	mat.color = Color(1.0, 0.85, 0.2)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-cleanup after particles finish
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(particles.queue_free)
