extends CanvasLayer
## SettingsPanel — 游戏设置面板
##
## Sections: 音频 (Audio), 画面 (Graphics), 游戏 (Gameplay)
## Saves/loads settings to user://settings.json
## Dark purple/gold style, consistent with PauseMenu.

const SETTINGS_PATH: String = "user://settings.json"

# ─── Settings Data ─────────────────────────────────────────────
var settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 1.0,
	"fullscreen": false,
	"vsync": true,
	"auto_battle_default": true,
	"camera_sensitivity": 0.5,
}

# ─── Signals ───────────────────────────────────────────────────
signal closed()

# ─── Node References (created in _build_ui) ───────────────────
var master_slider: HSlider = null
var sfx_slider: HSlider = null
var music_slider: HSlider = null
var fullscreen_toggle: CheckButton = null
var vsync_toggle: CheckButton = null
var auto_battle_toggle: CheckButton = null
var camera_slider: HSlider = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22  # Above PauseMenu (layer 20)
	_load_settings()
	_build_ui()
	print("[SettingsPanel] Opened")

func _build_ui() -> void:
	"""构建设置面板UI。"""
	# Semi-transparent background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Scroll container for settings
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.anchor_top = 0.5
	scroll.anchor_bottom = 0.5
	scroll.offset_left = -260
	scroll.offset_right = 260
	scroll.offset_top = -280
	scroll.offset_bottom = 280
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(scroll)

	# Main panel
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(500, 540)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
	panel_style.border_color = Color(0.7, 0.55, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	scroll.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "✦ 设置 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	_add_spacer(vbox, 8)

	# ─── 音频 Section ──────────────────────────────────────────
	_add_section_header(vbox, "♪ 音频")

	master_slider = _add_slider_row(vbox, "主音量", settings["master_volume"])
	master_slider.value_changed.connect(_on_master_volume_changed)

	sfx_slider = _add_slider_row(vbox, "音效", settings["sfx_volume"])
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	music_slider = _add_slider_row(vbox, "音乐", settings["music_volume"])
	music_slider.value_changed.connect(_on_music_volume_changed)

	_add_separator(vbox)

	# ─── 画面 Section ──────────────────────────────────────────
	_add_section_header(vbox, "◈ 画面")

	fullscreen_toggle = _add_toggle_row(vbox, "全屏", settings["fullscreen"])
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

	vsync_toggle = _add_toggle_row(vbox, "垂直同步", settings["vsync"])
	vsync_toggle.toggled.connect(_on_vsync_toggled)

	_add_separator(vbox)

	# ─── 游戏 Section ──────────────────────────────────────────
	_add_section_header(vbox, "⚔ 游戏")

	auto_battle_toggle = _add_toggle_row(vbox, "默认自动战斗", settings["auto_battle_default"])
	auto_battle_toggle.toggled.connect(_on_auto_battle_toggled)

	camera_slider = _add_slider_row(vbox, "镜头灵敏度", settings["camera_sensitivity"])
	camera_slider.value_changed.connect(_on_camera_sensitivity_changed)

	_add_spacer(vbox, 16)

	# ─── Back Button ───────────────────────────────────────────
	var back_btn := _create_button("返回")
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

	# Fade in
	self.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

# ─── UI Builder Helpers ───────────────────────────────────────
func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	parent.add_child(label)

func _add_slider_row(parent: VBoxContainer, label_text: String, initial_value: float) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 20)
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%d%%" % int(initial_value * 100)
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hbox.add_child(value_label)

	# Update value label on change
	slider.value_changed.connect(func(val: float):
		value_label.text = "%d%%" % int(val * 100)
	)

	return slider

func _add_toggle_row(parent: VBoxContainer, label_text: String, initial_value: bool) -> CheckButton:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	hbox.add_child(label)

	var toggle := CheckButton.new()
	toggle.button_pressed = initial_value
	hbox.add_child(toggle)

	return toggle

func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.25, 0.5, 0.6))
	parent.add_child(sep)

func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _create_button(text: String) -> Button:
	"""创建统一风格的菜单按钮（与PauseMenu一致）。"""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 44)
	btn.add_theme_font_size_override("font_size", 18)

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

# ─── Settings Callbacks ───────────────────────────────────────
func _on_master_volume_changed(value: float) -> void:
	settings["master_volume"] = value
	_apply_audio_volume(0, value)
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		AudioManager.set_master_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	settings["sfx_volume"] = value
	_apply_audio_volume(1, value)
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		AudioManager.set_sfx_volume(value)

func _on_music_volume_changed(value: float) -> void:
	settings["music_volume"] = value
	_apply_audio_volume(2, value)
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		AudioManager.set_music_volume(value)

func _on_fullscreen_toggled(pressed: bool) -> void:
	settings["fullscreen"] = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(pressed: bool) -> void:
	settings["vsync"] = pressed
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_auto_battle_toggled(pressed: bool) -> void:
	settings["auto_battle_default"] = pressed
	CombatSystem.auto_battle_enabled = pressed

func _on_camera_sensitivity_changed(value: float) -> void:
	settings["camera_sensitivity"] = value

func _apply_audio_volume(bus_index: int, value: float) -> void:
	"""Apply volume to an audio bus. Creates the bus if it doesn't exist."""
	# Ensure we have enough buses
	while AudioServer.bus_count <= bus_index:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		match idx:
			1:
				AudioServer.set_bus_name(idx, "SFX")
				AudioServer.set_bus_send(idx, "Master")
			2:
				AudioServer.set_bus_name(idx, "Music")
				AudioServer.set_bus_send(idx, "Master")

	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

# ─── Back Button ──────────────────────────────────────────────
func _on_back_pressed() -> void:
	_save_settings()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)
	print("[SettingsPanel] Closed — settings saved")

# ─── Input ────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
			get_viewport().set_input_as_handled()

# ─── Save/Load ────────────────────────────────────────────────
func _save_settings() -> void:
	"""Save settings to user://settings.json."""
	var json_string := JSON.stringify(settings, "\t")
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SettingsPanel] Failed to save settings: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(json_string)
	file.close()
	print("[SettingsPanel] Settings saved to %s" % SETTINGS_PATH)

func _load_settings() -> void:
	"""Load settings from user://settings.json."""
	if not FileAccess.file_exists(SETTINGS_PATH):
		print("[SettingsPanel] No settings file found, using defaults")
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SettingsPanel] Failed to open settings file")
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_warning("[SettingsPanel] Failed to parse settings JSON: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	if data is Dictionary:
		for key in data:
			if settings.has(key):
				settings[key] = data[key]

	# Apply loaded settings
	_apply_all_settings()
	print("[SettingsPanel] Settings loaded from %s" % SETTINGS_PATH)

func _apply_all_settings() -> void:
	"""Apply all loaded settings to the engine."""
	_apply_audio_volume(0, settings["master_volume"])
	_apply_audio_volume(1, settings["sfx_volume"])
	_apply_audio_volume(2, settings["music_volume"])

	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	if settings["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	CombatSystem.auto_battle_enabled = settings["auto_battle_default"]

# ─── Static Loader (call from Main._ready or autoload) ────────
static func load_settings_on_startup() -> void:
	"""Static helper to load and apply settings at game start without UI."""
	var path := SETTINGS_PATH
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		return

	var data: Dictionary = json.data
	if not data is Dictionary:
		return

	# Apply audio
	var master_vol: float = data.get("master_volume", 1.0)
	var sfx_vol: float = data.get("sfx_volume", 1.0)
	var music_vol: float = data.get("music_volume", 1.0)

	# Ensure audio buses exist
	while AudioServer.bus_count < 3:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		match idx:
			1:
				AudioServer.set_bus_name(idx, "SFX")
				AudioServer.set_bus_send(idx, "Master")
			2:
				AudioServer.set_bus_name(idx, "Music")
				AudioServer.set_bus_send(idx, "Master")

	for i in range(3):
		var vol: float = [master_vol, sfx_vol, music_vol][i]
		if vol <= 0.0:
			AudioServer.set_bus_mute(i, true)
		else:
			AudioServer.set_bus_mute(i, false)
			AudioServer.set_bus_volume_db(i, linear_to_db(vol))

	# Apply display
	if data.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if data.get("vsync", true):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Apply gameplay
	CombatSystem.auto_battle_enabled = data.get("auto_battle_default", true)

	print("[SettingsPanel] Settings loaded on startup")
