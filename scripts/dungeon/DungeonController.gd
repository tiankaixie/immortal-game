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
const MERCHANT_SCENE_PATH: String = "res://scenes/npc/Merchant.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

# Shop room appears after room 2 or 3 (50% chance each)
const SHOP_ROOM_CANDIDATES: Array[int] = [3]  # After room 2 (before room 3)

# ─── State ─────────────────────────────────────────────────────
var current_room_number: int = 1
var room_node: Node3D = null
var is_transitioning: bool = false
var shop_room_number: int = -1  # Which room is a shop room (-1 = none)

# Fade overlay
var fade_overlay: ColorRect = null
var fade_canvas: CanvasLayer = null

# Next-room prompt
var prompt_canvas: CanvasLayer = null

# ─── Signals ───────────────────────────────────────────────────
signal room_number_changed(room: int, total: int)
signal dungeon_completed()

func _ready() -> void:
	# Decide if this run has a shop room (50% chance)
	if randf() < 0.5:
		shop_room_number = SHOP_ROOM_CANDIDATES[randi() % SHOP_ROOM_CANDIDATES.size()]
		print("[DungeonController] Shop room scheduled at room %d" % shop_room_number)

	# Create persistent fade overlay (hidden by default)
	_create_fade_overlay()
	call_deferred("_connect_room_manager")

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

	# Initialize room counter
	GameManager.current_room = current_room_number
	room_number_changed.emit(current_room_number, MAX_ROOMS)

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

	# Load fresh room
	var packed := load(ROOM_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[DungeonController] Failed to load room scene: %s" % ROOM_SCENE_PATH)
		return

	room_node = packed.instantiate()
	main.add_child(room_node)

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

		# Register enemies with CombatSystem
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

	room_number_changed.emit(current_room_number, MAX_ROOMS)
	print("[DungeonController] Loaded room %d/%d" % [current_room_number, MAX_ROOMS])

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
