extends Control
## UnlockNotification — Shows newly unlocked items on the death screen
##
## Displays a gold/purple themed panel with fade-in animation.
## Lists each unlocked item with name and description.

signal dismissed()

var _new_unlocks: Array[Dictionary] = []

func setup(unlocks: Array[Dictionary]) -> void:
	"""Set the unlocks to display. Call before adding to scene tree or in _ready."""
	_new_unlocks = unlocks

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(450, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.18, 0.97)
	style.border_color = Color(0.85, 0.7, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "✨ 新解锁！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.85, 0.7, 0.2, 0.5))
	vbox.add_child(sep)

	# List each unlock
	for unlock in _new_unlocks:
		var item_container := VBoxContainer.new()
		item_container.add_theme_constant_override("separation", 2)
		vbox.add_child(item_container)

		var name_label := Label.new()
		name_label.text = "⭐ " + unlock.get("name", "???")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		item_container.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = unlock.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_container.add_child(desc_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Confirm button
	var btn := Button.new()
	btn.text = "确认"
	btn.custom_minimum_size = Vector2(150, 45)
	btn.add_theme_font_size_override("font_size", 22)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.08, 0.25, 0.95)
	btn_style.border_color = Color(0.85, 0.7, 0.2)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 15
	btn_style.content_margin_right = 15
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.18, 0.12, 0.35, 0.95)
	btn.add_theme_stylebox_override("hover", btn_hover)

	btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7))
	btn.pressed.connect(_on_confirm)
	vbox.add_child(btn)

	# Fade-in animation
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_confirm() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		dismissed.emit()
		queue_free()
	)
