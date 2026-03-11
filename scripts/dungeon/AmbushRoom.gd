extends Node3D
## AmbushRoom — 伏击房间
##
## Enemies start dormant (scale 0.1, not processing).
## When the player enters the central trigger zone, all enemies
## "awaken" with a scale tween and brief red flash effect.

var ambush_triggered: bool = false
var dormant_enemies: Array[Node3D] = []

func _ready() -> void:
	call_deferred("_setup_ambush")

func _setup_ambush() -> void:
	"""Find all enemies and make them dormant. Connect trigger zone."""
	# Gather enemies
	for child in get_children():
		if child.has_signal("defeated") and child.name != "Player":
			dormant_enemies.append(child)
			# Make dormant: shrink and disable AI
			child.scale = Vector3(0.1, 0.1, 0.1)
			child.set_physics_process(false)
			child.set_process(false)
			# Make nearly invisible
			_set_enemy_transparency(child, 0.2)

	print("[AmbushRoom] %d enemies set to dormant" % dormant_enemies.size())

	# Connect trigger zone
	var trigger := get_node_or_null("AmbushTrigger")
	if trigger and trigger is Area3D:
		trigger.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node3D) -> void:
	"""Player entered the ambush trigger zone."""
	if ambush_triggered:
		return
	if not body.is_in_group("player"):
		return

	ambush_triggered = true
	print("[AmbushRoom] ⚠ AMBUSH TRIGGERED! 伏击！")

	# Warning flash on screen
	_flash_warning()

	# Awaken all dormant enemies with staggered timing
	var delay: float = 0.0
	for enemy in dormant_enemies:
		if is_instance_valid(enemy):
			_awaken_enemy(enemy, delay)
			delay += 0.15

func _awaken_enemy(enemy: Node3D, delay: float) -> void:
	"""Scale enemy to normal size with a red flash, then enable AI."""
	var tween := create_tween()
	if delay > 0:
		tween.tween_interval(delay)

	# Scale up from 0.1 to normal (1.0)
	tween.tween_property(enemy, "scale", Vector3(1.0, 1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Red flash: briefly tint the enemy
	tween.tween_callback(_flash_enemy_red.bind(enemy))
	tween.tween_interval(0.3)
	tween.tween_callback(_restore_enemy_color.bind(enemy))

	# Re-enable AI processing
	tween.tween_callback(func():
		if is_instance_valid(enemy):
			enemy.set_physics_process(true)
			enemy.set_process(true)
			_set_enemy_transparency(enemy, 1.0)
	)

func _flash_enemy_red(enemy: Node3D) -> void:
	"""Apply a brief red tint to an enemy's mesh."""
	if not is_instance_valid(enemy):
		return
	for child in enemy.get_children():
		if child is MeshInstance3D:
			var mat := child.get_active_material(0)
			if mat is StandardMaterial3D:
				mat = mat.duplicate()
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.1, 0.1)
				mat.emission_energy_multiplier = 3.0
				child.set_surface_override_material(0, mat)

func _restore_enemy_color(enemy: Node3D) -> void:
	"""Remove the red flash from enemy mesh."""
	if not is_instance_valid(enemy):
		return
	for child in enemy.get_children():
		if child is MeshInstance3D:
			# Clear override to restore original material
			child.set_surface_override_material(0, null)

func _set_enemy_transparency(enemy: Node3D, alpha: float) -> void:
	"""Set transparency on enemy meshes."""
	for child in enemy.get_children():
		if child is MeshInstance3D:
			var mat := child.get_active_material(0)
			if mat is StandardMaterial3D:
				mat = mat.duplicate()
				if alpha < 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = alpha
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.albedo_color.a = 1.0
				child.set_surface_override_material(0, mat)

func _flash_warning() -> void:
	"""Show a brief red flash overlay to warn the player of ambush."""
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)

	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.05, 0.05, 0.35)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(flash)

	# Warning text
	var label := Label.new()
	label.text = "⚠ 伏击！"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.5
	label.anchor_top = 0.3
	label.anchor_right = 0.5
	label.anchor_bottom = 0.3
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	canvas.add_child(label)

	# Flash then fade
	var tween := canvas.create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(canvas, "modulate:a", 0.0, 0.5)
	tween.tween_callback(canvas.queue_free)
