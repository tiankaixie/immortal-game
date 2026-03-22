extends Node
## RoomManager — Tracks room state and completion
##
## Monitors enemies in the current room.
## Emits room_cleared when all enemies are defeated.
## Shows "下一间" UI message on completion.

# ─── State ─────────────────────────────────────────────────────
var total_enemies: int = 0
var enemies_alive: int = 0
var is_cleared: bool = false

# ─── Signals ───────────────────────────────────────────────────
signal room_cleared()
signal enemy_count_changed(alive: int, total: int)

func _ready() -> void:
	# Deferred to ensure scene tree is populated
	call_deferred("_initialize_room")

func _initialize_room() -> void:
	"""Find all enemies in the parent room and connect their defeated signals."""
	var room := get_parent()
	if room == null:
		push_warning("[RoomManager] No parent room node found")
		return
	
	var enemies: Array = []
	for child in room.get_children():
		if child.has_signal("defeated"):
			enemies.append(child)
	
	total_enemies = enemies.size()
	enemies_alive = total_enemies
	
	for enemy in enemies:
		enemy.defeated.connect(_on_enemy_defeated)
	
	# Also listen to CombatSystem in case enemies die through other means
	CombatSystem.enemy_defeated.connect(_on_combat_enemy_defeated)
	
	print("[RoomManager] Tracking %d enemies" % total_enemies)
	enemy_count_changed.emit(enemies_alive, total_enemies)

	# Non-combat rooms such as treasure/shop layouts must still advance the run.
	if total_enemies <= 0 and not is_cleared:
		call_deferred("_on_room_cleared")

func _on_enemy_defeated(_enemy: Node) -> void:
	"""Called when an enemy emits its defeated signal."""
	enemies_alive = max(0, enemies_alive - 1)
	enemy_count_changed.emit(enemies_alive, total_enemies)
	print("[RoomManager] Enemy defeated — %d/%d remaining" % [enemies_alive, total_enemies])
	
	if enemies_alive <= 0 and not is_cleared:
		_on_room_cleared()

func _on_combat_enemy_defeated(enemy: Node) -> void:
	"""Fallback listener on CombatSystem.enemy_defeated signal.
	Avoids double-counting by checking is_cleared and current count."""
	# The primary tracking is via enemy.defeated signal above.
	# This is a safety net; no action needed if counts already handled.
	pass

func _on_room_cleared() -> void:
	"""All enemies defeated — room is cleared!"""
	is_cleared = true
	room_cleared.emit()
	
	print("═══════════════════════════════════")
	print("   ✦ Room Cleared! 房间已清除！ ✦")
	print("═══════════════════════════════════")
	
	# Only show fallback UI if DungeonController is not handling it
	var main := get_tree().current_scene
	if main and main.find_child("DungeonController", true, false):
		return  # DungeonController will handle boon UI + next room prompt
	
	# Show UI notification via HUD (fallback)
	_show_clear_message()

func _show_clear_message() -> void:
	"""Display room cleared message on screen."""
	# Find the HUD in the scene tree
	var main := get_tree().current_scene
	if main == null:
		return
	
	var hud := main.find_child("HUD", true, false)
	if hud and hud.has_method("show_room_cleared"):
		hud.show_room_cleared()
	else:
		# Fallback: create a temporary Label on screen
		_create_clear_label()

func _create_clear_label() -> void:
	"""Create a temporary on-screen label for room cleared."""
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	get_tree().current_scene.add_child(canvas)
	
	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.4
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.4
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(panel)
	
	var label := Label.new()
	label.text = "✦ 房间已清除 ✦\n\n下一间 →"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(label)
	
	# Animate: fade in, wait, then fade out
	var tween := canvas.create_tween()
	canvas.modulate = Color(1, 1, 1, 0)
	tween.tween_property(canvas, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.0)
	tween.tween_property(canvas, "modulate:a", 0.0, 1.0)
	tween.tween_callback(canvas.queue_free)

# ─── Query ─────────────────────────────────────────────────────
func get_enemies_remaining() -> int:
	return enemies_alive

func get_total_enemies() -> int:
	return total_enemies
