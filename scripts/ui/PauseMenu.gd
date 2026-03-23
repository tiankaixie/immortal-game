extends CanvasLayer
## PauseMenu — 战术停顿面板
##
## ESC 键触发，暂停游戏。
## 按钮：返回战斗、战场设置、返回营地。
## 黑铁/余烬/旧金属风格，与主菜单和 HUD 统一。

# ─── Signals ──────────────────────────────────────────────────
signal closed()

var _background: ColorRect = null
var _panel: PanelContainer = null

func _ready() -> void:
	# 暂停菜单自身不受暂停影响
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	get_tree().paused = true
	if AudioManager.has_method("has_sfx") and AudioManager.has_sfx("ui_open"):
		AudioManager.play_sfx("ui_open")
	print("[PauseMenu] Opened — game paused")

func _build_ui() -> void:
	"""构建暂停菜单UI。"""
	# 半透明战场幕布
	_background = ColorRect.new()
	_background.color = Color(0.03, 0.02, 0.02, 0.78)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	# 主面板
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -180
	_panel.offset_right = 180
	_panel.offset_top = -160
	_panel.offset_bottom = 160
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.09, 0.07, 0.96)
	panel_style.border_color = Color(0.52, 0.39, 0.25, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(28)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "战 术 停 顿"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.66))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "整备装备、校准战场选项，或撤回营地。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.76, 0.69, 0.61))
	vbox.add_child(subtitle)

	# 间隔
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# 继续按钮
	var resume_btn := _create_button("返回战斗")
	resume_btn.pressed.connect(resume)
	vbox.add_child(resume_btn)

	# 设置按钮
	var settings_btn := _create_button("战场设置")
	settings_btn.pressed.connect(_on_settings)
	vbox.add_child(settings_btn)

	# 回到主菜单按钮
	var main_menu_btn := _create_button("返回营地")
	main_menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(main_menu_btn)

	# 淡入动画
	_background.modulate = Color(1, 1, 1, 0)
	_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(_background, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.25)

func _create_button(text: String) -> Button:
	"""创建统一风格的黑铁按钮。"""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.84))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.86, 0.7))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.19, 0.13, 0.1, 0.95)
	normal_style.border_color = Color(0.46, 0.33, 0.22, 0.95)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.29, 0.16, 0.11, 0.98)
	hover_style.border_color = Color(0.75, 0.53, 0.31, 0.98)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.12, 0.08, 0.06, 0.98)
	pressed_style.border_color = Color(0.65, 0.46, 0.28, 0.98)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(6)
	pressed_style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

# ─── Button Handlers ─────────────────────────────────────────
func resume() -> void:
	"""关闭暂停菜单，恢复游戏。"""
	get_tree().paused = false
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _background:
		tween.parallel().tween_property(_background, "modulate:a", 0.0, 0.2)
	if _panel:
		tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)
	print("[PauseMenu] Resumed — game unpaused")

func _on_settings() -> void:
	"""打开设置面板。"""
	var settings_scene = load("res://scenes/ui/SettingsPanel.tscn")
	if settings_scene:
		var settings_panel: Node = settings_scene.instantiate()
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
	if GameManager.is_run_active and GameManager.current_state == GameManager.GameState.DUNGEON_RUN:
		GameManager.save_game()
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
