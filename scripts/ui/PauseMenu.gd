extends CanvasLayer
## PauseMenu — 暂停菜单
##
## ESC键触发，暂停游戏。
## 按钮：继续、设置（占位）、回到主菜单
## 深紫色/金色边框风格，与其他UI统一。

# ─── Signals ──────────────────────────────────────────────────
signal closed()

func _ready() -> void:
	# 暂停菜单自身不受暂停影响
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	get_tree().paused = true
	AudioManager.play_sfx("ui_open")
	print("[PauseMenu] Opened — game paused")

func _build_ui() -> void:
	"""构建暂停菜单UI。"""
	# 半透明暗色背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 主面板
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -160
	panel.offset_bottom = 160
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
	panel_style.border_color = Color(0.7, 0.55, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "✦ 暂停 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# 间隔
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# 继续按钮
	var resume_btn := _create_button("继续")
	resume_btn.pressed.connect(resume)
	vbox.add_child(resume_btn)

	# 设置按钮（占位）
	var settings_btn := _create_button("设置")
	settings_btn.pressed.connect(_on_settings)
	vbox.add_child(settings_btn)

	# 回到主菜单按钮
	var main_menu_btn := _create_button("回到主菜单")
	main_menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(main_menu_btn)

	# 淡入动画
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func _create_button(text: String) -> Button:
	"""创建统一风格的菜单按钮。"""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 44)
	btn.add_theme_font_size_override("font_size", 18)

	# 按钮样式
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.12, 0.28, 0.9)
	normal_style.border_color = Color(0.5, 0.4, 0.2)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.22, 0.18, 0.38, 0.95)
	hover_style.border_color = Color(0.8, 0.65, 0.3)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.1, 0.08, 0.2, 0.95)
	pressed_style.border_color = Color(0.7, 0.55, 0.2)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(6)
	pressed_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

# ─── Button Handlers ─────────────────────────────────────────
func resume() -> void:
	"""关闭暂停菜单，恢复游戏。"""
	get_tree().paused = false
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)
	print("[PauseMenu] Resumed — game unpaused")

func _on_settings() -> void:
	"""打开设置面板。"""
	var settings_scene := load("res://scenes/ui/SettingsPanel.tscn")
	if settings_scene:
		var settings_panel := settings_scene.instantiate()
		add_child(settings_panel)
		if settings_panel.has_signal("closed"):
			settings_panel.closed.connect(_on_settings_closed)
		print("[PauseMenu] Settings panel opened")
	else:
		push_warning("[PauseMenu] SettingsPanel.tscn not found")

func _on_settings_closed() -> void:
	"""设置面板关闭后的回调。"""
	print("[PauseMenu] Settings panel closed")

func _on_main_menu() -> void:
	"""回到主菜单。"""
	get_tree().paused = false
	closed.emit()
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	GameManager.goto_scene("res://scenes/ui/MainMenu.tscn")
	queue_free()
	print("[PauseMenu] Returning to main menu")

# ─── Input ───────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			resume()
			get_viewport().set_input_as_handled()
