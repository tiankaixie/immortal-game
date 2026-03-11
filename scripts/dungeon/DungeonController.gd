extends Node
## DungeonController — Manages dungeon room progression
##
## Handles:
## - Room transitions with fade effects
## - Floor/room tracking (displayed in HUD)
## - Boon selection between rooms
## - Dungeon completion after 5 rooms
## - Return to main menu on completion

const MAX_ROOMS: int = 5
const ROOM_SCENE_PATH: String = "res://scenes/dungeon/TestRoom.tscn"
const BOSS_ROOM_SCENE_PATH: String = "res://scenes/dungeon/BossRoom.tscn"
const MERCHANT_SCENE_PATH: String = "res://scenes/npc/Merchant.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

# Alternative room layouts for variety
const ROOM_LAYOUTS: Array[String] = [
	"res://scenes/dungeon/TestRoom.tscn",
	"res://scenes/dungeon/NarrowRoom.tscn",
	"res://scenes/dungeon/OpenRoom.tscn",
	"res://scenes/dungeon/CrossRoom.tscn",
	"res://scenes/dungeon/CircularRoom.tscn",
]

# Enemy scene paths
const ENEMY_SCENE_PATH: String = "res://scenes/enemies/Enemy.tscn"
const RANGED_ENEMY_SCENE_PATH: String = "res://scenes/enemies/RangedEnemy.tscn"
const TANK_ENEMY_SCENE_PATH: String = "res://scenes/enemies/TankEnemy.tscn"
const SWARM_ENEMY_SCENE_PATH: String = "res://scenes/enemies/SwarmEnemy.tscn"
const BOSS_ENEMY_SCENE_PATH: String = "res://scenes/enemies/BossEnemy.tscn"
const TRIBULATION_BOSS_SCENE_PATH: String = "res://scenes/enemies/TribulationBoss.tscn"
const ELITE_ENEMY_SCENE_PATH: String = "res://scenes/enemies/EliteEnemy.tscn"

# Boss type selection for the run
const BOSS_TYPES: Array[String] = [
	"res://scenes/enemies/BossEnemy.tscn",
	"res://scenes/enemies/TribulationBoss.tscn",
]
var boss_type: String = ""  # Selected boss for this run

# Preloaded enemy scenes
var enemy_scenes: Dictionary = {}

# Enemy compositions per difficulty tier
# Each entry is an array of [scene_path, count] pairs
var easy_compositions: Array[Array] = [
	[[ENEMY_SCENE_PATH, 2]],
	[[ENEMY_SCENE_PATH, 1], [SWARM_ENEMY_SCENE_PATH, 3]],
	[[ENEMY_SCENE_PATH, 2], [RANGED_ENEMY_SCENE_PATH, 1]],
]

var medium_compositions: Array[Array] = [
	[[ENEMY_SCENE_PATH, 2], [RANGED_ENEMY_SCENE_PATH, 1]],
	[[TANK_ENEMY_SCENE_PATH, 1], [ENEMY_SCENE_PATH, 2]],
	[[RANGED_ENEMY_SCENE_PATH, 2], [SWARM_ENEMY_SCENE_PATH, 3]],
	[[ENEMY_SCENE_PATH, 1], [TANK_ENEMY_SCENE_PATH, 1], [SWARM_ENEMY_SCENE_PATH, 3]],
]

var hard_compositions: Array[Array] = [
	[[TANK_ENEMY_SCENE_PATH, 1], [RANGED_ENEMY_SCENE_PATH, 2], [ENEMY_SCENE_PATH, 1]],
	[[TANK_ENEMY_SCENE_PATH, 1], [SWARM_ENEMY_SCENE_PATH, 6]],
	[[RANGED_ENEMY_SCENE_PATH, 2], [ENEMY_SCENE_PATH, 2], [SWARM_ENEMY_SCENE_PATH, 3]],
	[[TANK_ENEMY_SCENE_PATH, 2], [RANGED_ENEMY_SCENE_PATH, 1]],
]

# Shop room appears after room 2 or 3 (50% chance each)
const SHOP_ROOM_CANDIDATES: Array[int] = [3]  # After room 2 (before room 3)

# ─── Room Types ────────────────────────────────────────────────
enum RoomType {
	NORMAL,    # 普通间
	ELITE,     # 精英间
	TREASURE,  # 宝藏间
	BOSS,      # BOSS间
}

const ROOM_TYPE_NAMES: Dictionary = {
	RoomType.NORMAL: "普通间",
	RoomType.ELITE: "精英间",
	RoomType.TREASURE: "宝藏间",
	RoomType.BOSS: "BOSS间",
}

const ROOM_TYPE_COLORS: Dictionary = {
	RoomType.NORMAL: Color(0.8, 0.8, 0.8),
	RoomType.ELITE: Color(1.0, 0.5, 0.2),
	RoomType.TREASURE: Color(1.0, 0.85, 0.2),
	RoomType.BOSS: Color(0.9, 0.2, 0.2),
}

# ─── State ─────────────────────────────────────────────────────
var current_room_number: int = 1
var current_room_type: RoomType = RoomType.NORMAL
var room_node: Node3D = null
var is_transitioning: bool = false
var shop_room_number: int = -1  # Which room is a shop room (-1 = none)
var treasure_rooms: Array[int] = []  # Pre-determined treasure room numbers

# Fade overlay
var fade_overlay: ColorRect = null
var fade_canvas: CanvasLayer = null

# Next-room prompt
var prompt_canvas: CanvasLayer = null

# ─── Signals ───────────────────────────────────────────────────
signal room_number_changed(room: int, total: int)
signal room_type_changed(room_type: int, room_type_name: String)
signal dungeon_completed()

func _ready() -> void:
	# Preload enemy scenes
	_preload_enemy_scenes()

	# Select boss type for this run (random from pool)
	boss_type = BOSS_TYPES[randi() % BOSS_TYPES.size()]

	# Decide if this run has a shop room (50% chance)
	if randf() < 0.5:
		shop_room_number = SHOP_ROOM_CANDIDATES[randi() % SHOP_ROOM_CANDIDATES.size()]
		print("[DungeonController] Shop room scheduled at room %d" % shop_room_number)

	# Pre-determine treasure rooms (20% chance for rooms 1, 2, 4; rooms 3 and 5 are fixed types)
	for r in [1, 2, 4]:
		if randf() < 0.2:
			treasure_rooms.append(r)
	if treasure_rooms.size() > 0:
		print("[DungeonController] Treasure rooms: %s" % str(treasure_rooms))

	# Create persistent fade overlay (hidden by default)
	_create_fade_overlay()
	call_deferred("_connect_room_manager")

func _preload_enemy_scenes() -> void:
	"""Preload all enemy scenes for quick instantiation."""
	enemy_scenes[ENEMY_SCENE_PATH] = load(ENEMY_SCENE_PATH)
	enemy_scenes[RANGED_ENEMY_SCENE_PATH] = load(RANGED_ENEMY_SCENE_PATH)
	enemy_scenes[TANK_ENEMY_SCENE_PATH] = load(TANK_ENEMY_SCENE_PATH)
	enemy_scenes[SWARM_ENEMY_SCENE_PATH] = load(SWARM_ENEMY_SCENE_PATH)
	enemy_scenes[BOSS_ENEMY_SCENE_PATH] = load(BOSS_ENEMY_SCENE_PATH)
	enemy_scenes[TRIBULATION_BOSS_SCENE_PATH] = load(TRIBULATION_BOSS_SCENE_PATH)
	enemy_scenes[ELITE_ENEMY_SCENE_PATH] = load(ELITE_ENEMY_SCENE_PATH)
	print("[DungeonController] Enemy scenes preloaded")

func _connect_room_manager() -> void:
	"""Find and connect to the RoomManager in the current room."""
	var main := get_parent()
	if main == null:
		return

	# Find TestRoom (could be a child of Main)
	room_node = main.find_child("TestRoom", true, false)
	if room_node == null:
		push_warning("[DungeonController] No TestRoom found")
		return

	var rm := room_node.find_child("RoomManager", true, false)
	if rm and rm.has_signal("room_cleared"):
		rm.room_cleared.connect(_on_room_cleared)
		print("[DungeonController] Connected to RoomManager")

	# Initialize room counter and type
	GameManager.current_room = current_room_number
	current_room_type = _determine_room_type(current_room_number)
	room_number_changed.emit(current_room_number, MAX_ROOMS)
	room_type_changed.emit(current_room_type, ROOM_TYPE_NAMES.get(current_room_type, "普通间"))

func _on_room_cleared() -> void:
	"""Room cleared — show boon selection, then next-room prompt."""
	if is_transitioning:
		return

	print("[DungeonController] Room %d/%d cleared" % [current_room_number, MAX_ROOMS])

	# Show boon selection UI first (it will call _on_boon_selected when done)
	var hud := get_parent().find_child("HUD", true, false)
	if hud:
		# Hide the default room-cleared label from RoomManager
		pass

	# Show boon selection
	call_deferred("_show_boon_selection")

func _on_boon_selected() -> void:
	"""Called after player picks a boon. Show next-room prompt or completion."""
	if current_room_number >= MAX_ROOMS:
		_show_dungeon_complete()
	else:
		_show_next_room_prompt()

func _show_next_room_prompt() -> void:
	"""Show a 下一间 button for the player to proceed."""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	prompt_canvas = CanvasLayer.new()
	prompt_canvas.layer = 15
	add_child(prompt_canvas)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_canvas.add_child(bg)

	# Center container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.4
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.6
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_canvas.add_child(vbox)

	var label := Label.new()
	label.text = "✦ 第 %d 间已清除 ✦" % current_room_number
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "下一间 →"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_next_room_pressed)
	vbox.add_child(btn)

	# Fade in
	prompt_canvas.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(prompt_canvas, "modulate:a", 1.0, 0.3)

func _on_next_room_pressed() -> void:
	"""Player confirmed — transition to next room."""
	if prompt_canvas:
		prompt_canvas.queue_free()
		prompt_canvas = null

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_transition_to_next_room()

func _transition_to_next_room() -> void:
	"""Fade out, swap room, fade in."""
	is_transitioning = true
	current_room_number += 1
	GameManager.current_room = current_room_number

	# Fade to black
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(_swap_room)
	tween.tween_interval(0.3)
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.5)
	tween.tween_callback(_on_transition_complete)

func _swap_room() -> void:
	"""Unload current room and instantiate a fresh one."""
	var main := get_parent()
	if main == null:
		return

	# Remove old room
	if room_node and is_instance_valid(room_node):
		room_node.queue_free()
		room_node = null

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Pick room scene: BossRoom for BOSS rooms, random layout for others
	var room_path: String
	if _determine_room_type(current_room_number) == RoomType.BOSS:
		room_path = BOSS_ROOM_SCENE_PATH
	else:
		room_path = ROOM_LAYOUTS[randi() % ROOM_LAYOUTS.size()]

	# Load fresh room
	var packed := load(room_path) as PackedScene
	if packed == null:
		push_error("[DungeonController] Failed to load room scene: %s" % room_path)
		return

	room_node = packed.instantiate()
	main.add_child(room_node)

	# For boss rooms, replace pre-placed boss with selected boss_type and connect signal
	var is_boss_room := _determine_room_type(current_room_number) == RoomType.BOSS
	var is_elite_room := _determine_room_type(current_room_number) == RoomType.ELITE
	if is_boss_room:
		# Remove pre-placed boss and spawn selected boss_type
		_replace_boss_with_selected()
		_connect_boss_signals()
	else:
		# Remove default static enemies from room template (Enemy1, Enemy2, etc.)
		var static_enemies: Array[Node] = []
		for child in room_node.get_children():
			if child.has_method("take_damage") and child.name != "Player":
				static_enemies.append(child)
		for e in static_enemies:
			e.queue_free()

		if is_elite_room:
			# Spawn the EliteEnemy (幽冥蛛后) for elite rooms
			_spawn_elite_enemy()
		else:
			# Spawn enemies based on room difficulty composition
			_spawn_room_enemies()

	# Re-wire player and enemies
	var player := room_node.get_node_or_null("Player")
	if player:
		player.add_to_group("player")
		# Reset player HP/SP for new room
		player.current_hp = player.max_hp
		player.hp_changed.emit(player.current_hp, player.max_hp)
		PlayerData.restore_sp(PlayerData.sp_max)

		# Connect HUD
		var hud := main.find_child("HUD", true, false)
		if hud and hud.has_method("connect_to_player"):
			hud.connect_to_player(player)

		# Register enemies with CombatSystem (re-gather after spawning)
		var enemies: Array[Node] = []
		for child in room_node.get_children():
			if child.has_method("take_damage") and child != player:
				enemies.append(child)
		if enemies.size() > 0:
			CombatSystem.start_combat(player, enemies)

	# Re-connect RoomManager
	var rm := room_node.find_child("RoomManager", true, false)
	if rm and rm.has_signal("room_cleared"):
		rm.room_cleared.connect(_on_room_cleared)

	# Spawn merchant if this is a shop room
	if current_room_number == shop_room_number:
		_spawn_merchant_in_room()

	# Determine and emit room type
	current_room_type = _determine_room_type(current_room_number)
	room_number_changed.emit(current_room_number, MAX_ROOMS)
	room_type_changed.emit(current_room_type, ROOM_TYPE_NAMES.get(current_room_type, "普通间"))

	# Spawn treasure chest in treasure rooms
	if current_room_type == RoomType.TREASURE:
		_spawn_treasure_chest()

	print("[DungeonController] Loaded room %d/%d (%s)" % [current_room_number, MAX_ROOMS, ROOM_TYPE_NAMES.get(current_room_type, "普通间")])

func _on_transition_complete() -> void:
	is_transitioning = false

func _show_dungeon_complete() -> void:
	"""Show completion screen and return to main menu."""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	dungeon_completed.emit()

	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.35
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.65
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "✦ 副本完成！✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var stats := Label.new()
	stats.text = "灵石获得: %d\n修为增长: %s · %s" % [
		GameManager.run_spirit_stones,
		"练气期" if PlayerData.cultivation_realm == 0 else str(PlayerData.cultivation_realm),
		"初期" if PlayerData.cultivation_stage == 0 else str(PlayerData.cultivation_stage),
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 22)
	stats.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(stats)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer2)

	var btn := Button.new()
	btn.text = "返回主界面"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_return_to_menu)
	vbox.add_child(btn)

	# Fade in
	canvas.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(canvas, "modulate:a", 1.0, 0.6)

func _on_return_to_menu() -> void:
	"""End the run and go back to main menu."""
	GameManager.end_run(true)
	GameManager.goto_scene(MAIN_MENU_PATH)

# ─── Room Type Logic ──────────────────────────────────────────
func _determine_room_type(room_num: int) -> RoomType:
	"""Determine the type of a room based on its number."""
	if room_num == 5:
		return RoomType.BOSS
	if room_num == 3:
		return RoomType.ELITE
	if room_num in treasure_rooms:
		return RoomType.TREASURE
	return RoomType.NORMAL

func _spawn_treasure_chest() -> void:
	"""Spawn a golden chest in the current room that grants a boon on interaction."""
	if room_node == null:
		return

	# Create chest as a StaticBody3D with a capsule mesh
	var chest := StaticBody3D.new()
	chest.name = "TreasureChest"
	chest.position = Vector3(0, 0.4, -3.0)

	# Visual: gold capsule
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 0.5
	mat.metallic = 0.8
	mat.roughness = 0.3
	capsule.material = mat
	mesh_instance.mesh = capsule
	# Lay it on its side to look more chest-like
	mesh_instance.rotation_degrees = Vector3(0, 0, 90)
	chest.add_child(mesh_instance)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.0
	collision.shape = shape
	chest.add_child(collision)

	# Interaction area (Area3D) for player proximity detection
	var area := Area3D.new()
	area.name = "InteractArea"
	var area_collision := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.0
	area_collision.shape = area_shape
	area.add_child(area_collision)
	chest.add_child(area)

	# Floating label
	var label_3d := Label3D.new()
	label_3d.text = "✦ 宝箱 ✦\n[按 F 开启]"
	label_3d.font_size = 48
	label_3d.position = Vector3(0, 1.2, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.modulate = Color(1.0, 0.85, 0.3)
	chest.add_child(label_3d)

	room_node.add_child(chest)

	# Connect interaction via input
	chest.set_meta("is_treasure_chest", true)
	print("[DungeonController] Treasure chest spawned in room %d" % current_room_number)

# ─── Boss Room Handling ────────────────────────────────────────
func _replace_boss_with_selected() -> void:
	"""Replace the pre-placed BossEnemy with the selected boss_type for this run."""
	if room_node == null or boss_type == BOSS_ENEMY_SCENE_PATH or boss_type == "":
		return  # Default boss is already placed, no swap needed

	# Remove pre-placed bosses
	var to_remove: Array[Node] = []
	for child in room_node.get_children():
		if child.has_signal("boss_defeated"):
			to_remove.append(child)
	for node in to_remove:
		node.queue_free()

	# Spawn selected boss
	var scene: PackedScene = enemy_scenes.get(boss_type) as PackedScene
	if scene == null:
		scene = load(boss_type) as PackedScene
	if scene:
		var boss := scene.instantiate()
		boss.position = Vector3(0.0, 0.5, -6.0)
		room_node.add_child(boss)

func _connect_boss_signals() -> void:
	"""Find the BossEnemy in the room and connect its boss_defeated signal + HUD registration."""
	if room_node == null:
		return

	for child in room_node.get_children():
		if child.has_signal("boss_defeated"):
			child.boss_defeated.connect(_on_boss_defeated)

			# Register boss with HUD for boss HP bar display
			var main := get_parent()
			if main:
				var hud := main.find_child("HUD", true, false)
				if hud and hud.has_method("register_boss"):
					hud.register_boss(child)
					print("[DungeonController] Boss registered with HUD")

			print("[DungeonController] Connected to BossEnemy boss_defeated signal")
			return

func _on_boss_defeated() -> void:
	"""Boss killed — show victory message, then trigger room_cleared after delay."""
	print("[DungeonController] ═══ BOSS 已击败！ ═══")

	# Show boss defeated message
	_show_boss_defeated_message()

	# Delay before triggering room cleared (celebration moment)
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(_on_boss_celebration_done)

func _on_boss_celebration_done() -> void:
	"""After celebration delay, trigger normal room cleared flow."""
	_on_room_cleared()

func _show_boss_defeated_message() -> void:
	"""Display a dramatic BOSS defeated message on screen."""
	# Find boss name from the defeated boss
	var boss_name := "Boss"
	if room_node:
		for child in room_node.get_children():
			if child.get("enemy_name") != null and child.get("current_hp") != null:
				if child.current_hp <= 0:
					boss_name = child.enemy_name
					break

	var canvas := CanvasLayer.new()
	canvas.layer = 18
	add_child(canvas)

	var label := Label.new()
	label.text = "✦ BOSS 已击败！ ✦\n%s 陨落" % boss_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.5
	label.anchor_top = 0.3
	label.anchor_right = 0.5
	label.anchor_bottom = 0.3
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	canvas.add_child(label)

	# Animate: scale in, hold, fade out
	canvas.modulate = Color(1, 1, 1, 0)
	var tween := canvas.create_tween()
	tween.tween_property(canvas, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(canvas, "modulate:a", 0.0, 0.8)
	tween.tween_callback(canvas.queue_free)

# ─── Elite Enemy Spawning ──────────────────────────────────────
func _spawn_elite_enemy() -> void:
	"""Spawn the EliteEnemy (幽冥蛛后) in an elite room."""
	if room_node == null:
		return

	var scene: PackedScene = enemy_scenes.get(ELITE_ENEMY_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("[DungeonController] Failed to load EliteEnemy scene")
		return

	var elite := scene.instantiate()
	elite.position = Vector3(0.0, 0.5, -6.0)
	room_node.add_child(elite)

	# Register elite with HUD for boss-style HP bar
	var main := get_parent()
	if main:
		var hud := main.find_child("HUD", true, false)
		if hud and hud.has_method("register_boss"):
			hud.register_boss(elite)

	print("[DungeonController] EliteEnemy 幽冥蛛后 spawned in room %d" % current_room_number)

# ─── Enemy Spawning ───────────────────────────────────────────
func _spawn_room_enemies() -> void:
	"""Spawn enemies based on current room number difficulty."""
	if room_node == null:
		return

	var composition: Array = _get_room_composition()
	var spawn_index: int = 0

	for entry in composition:
		var scene_path: String = entry[0]
		var count: int = entry[1]
		var scene: PackedScene = enemy_scenes.get(scene_path) as PackedScene
		if scene == null:
			push_warning("[DungeonController] Failed to load enemy scene: %s" % scene_path)
			continue

		for i in range(count):
			var enemy := scene.instantiate()
			# Spread enemies around the room (avoid center where player spawns)
			var pos := _get_spawn_position(spawn_index)
			enemy.position = pos
			room_node.add_child(enemy)
			spawn_index += 1

	print("[DungeonController] Spawned %d enemies for room %d" % [spawn_index, current_room_number])

func _get_room_composition() -> Array:
	"""Select an enemy composition based on room difficulty."""
	# Rooms 1-2: easy, Room 3: medium, Rooms 4-5: hard
	var pool: Array[Array]
	if current_room_number <= 2:
		pool = easy_compositions
	elif current_room_number <= 3:
		pool = medium_compositions
	else:
		pool = hard_compositions

	return pool[randi() % pool.size()]

func _get_spawn_position(index: int) -> Vector3:
	"""Calculate a spawn position for an enemy, spread around the room.
	Adapts to different room layouts."""
	var spawn_positions: Array[Vector3] = [
		Vector3(5.0, 0.5, -5.0),
		Vector3(-4.0, 0.5, -3.0),
		Vector3(6.0, 0.5, 3.0),
		Vector3(-5.0, 0.5, 5.0),
		Vector3(3.0, 0.5, -7.0),
		Vector3(-6.0, 0.5, -6.0),
		Vector3(7.0, 0.5, 0.0),
		Vector3(-3.0, 0.5, 7.0),
		Vector3(0.0, 0.5, -8.0),
		Vector3(-7.0, 0.5, 0.0),
		Vector3(4.0, 0.5, 6.0),
		Vector3(-2.0, 0.5, -6.0),
	]

	if index < spawn_positions.size():
		return spawn_positions[index]
	else:
		# Fallback: random position in room bounds
		return Vector3(
			randf_range(-7.0, 7.0),
			0.5,
			randf_range(-7.0, 7.0)
		)

# ─── Merchant Spawning ────────────────────────────────────────
func _spawn_merchant_in_room() -> void:
	"""Place a merchant NPC in the current room."""
	if room_node == null:
		return

	var merchant_scene := load(MERCHANT_SCENE_PATH)
	if merchant_scene == null:
		push_warning("[DungeonController] Merchant scene not found")
		return

	var merchant := merchant_scene.instantiate()
	# Place merchant at a corner of the room, away from enemies
	merchant.position = Vector3(7.0, 0.0, 7.0)
	room_node.add_child(merchant)
	print("[DungeonController] Merchant spawned in room %d" % current_room_number)

# ─── Boon Selection ───────────────────────────────────────────
func _show_boon_selection() -> void:
	"""Create and display the BoonUI for the player to choose a boon."""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var boon_ui_scene := load("res://scenes/ui/BoonUI.tscn")
	if boon_ui_scene:
		var boon_ui := boon_ui_scene.instantiate()
		add_child(boon_ui)
		if boon_ui.has_signal("boon_chosen"):
			boon_ui.boon_chosen.connect(_on_boon_ui_closed)
	else:
		# Fallback: skip boon selection if scene missing
		push_warning("[DungeonController] BoonUI.tscn not found, skipping boon selection")
		_on_boon_selected()

func _on_boon_ui_closed(_boon_id: String) -> void:
	"""Boon UI was closed after selection."""
	_on_boon_selected()

# ─── Treasure Chest Interaction ────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_try_open_chest()

func _try_open_chest() -> void:
	"""Check if player is near a treasure chest and open it."""
	if room_node == null:
		return

	var chest := room_node.get_node_or_null("TreasureChest")
	if chest == null or not is_instance_valid(chest):
		return

	# Check distance to player
	var player: Node = null
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	if player == null:
		return

	var dist: float = player.global_position.distance_to(chest.global_position)
	if dist > 2.5:
		return  # Too far

	# Open chest: grant a random boon
	print("[DungeonController] Treasure chest opened!")
	AudioManager.play_sfx("pickup")
	chest.queue_free()

	# Show boon selection
	_show_boon_selection()

# ─── Fade Overlay ─────────────────────────────────────────────
func _create_fade_overlay() -> void:
	"""Create a full-screen black overlay for transitions."""
	fade_canvas = CanvasLayer.new()
	fade_canvas.layer = 50
	add_child(fade_canvas)

	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_canvas.add_child(fade_overlay)
