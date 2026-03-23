extends Control
## MainMenu — Title screen
##
## Options:
## - 开始狩猎 (New Game) → loads Main.tscn
## - 继续远征 (Continue) → loads Main.tscn with save data (grayed if no save)
## - 离开战场 (Quit)

@onready var new_game_btn: Button = $VBoxContainer/NewGameButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel

var _hard_mode_btn: Button = null
var _status_label: Label = null

func _ready() -> void:
	# Show cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_visual_style()
	_setup_status_label()
	
	# Check for save file
	if not GameManager.has_save_file():
		_set_continue_enabled(false)
	
	# Connect signals
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(_on_quit)
	
	# Add hard mode toggle if unlocked
	if UnlockSystem.is_unlocked("hard_mode"):
		_add_hard_mode_toggle()
	
	print("[MainMenu] Ready")

func _setup_status_label() -> void:
	var vbox := $VBoxContainer
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(360, 48)
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.4))
	_status_label.visible = false
	vbox.add_child(_status_label)

func _apply_visual_style() -> void:
	title_label.add_theme_font_size_override("font_size", 68)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.85, 0.72))
	subtitle_label.add_theme_color_override("font_color", Color(0.72, 0.64, 0.57))
	for button in [new_game_btn, continue_btn, quit_btn]:
		_style_primary_button(button)

func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.08, 0.08, 0.96)
	normal.border_color = Color(0.58, 0.37, 0.28, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.10, 0.09, 0.98)
	hover.border_color = Color(0.84, 0.56, 0.40, 0.95)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.11, 0.09, 0.98)
	pressed.border_color = Color(0.96, 0.67, 0.45, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", Color(0.93, 0.88, 0.82))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.85))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.88))

func _set_continue_enabled(enabled: bool) -> void:
	continue_btn.disabled = not enabled
	if enabled:
		continue_btn.modulate = Color(1, 1, 1, 1)
	else:
		continue_btn.modulate = Color(0.55, 0.55, 0.55, 0.72)

func _show_status(message: String) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.visible = not message.is_empty()

func _add_hard_mode_toggle() -> void:
	"""Add a 梦魇远征 toggle button below the new game button."""
	var vbox := $VBoxContainer
	_hard_mode_btn = Button.new()
	_hard_mode_btn.custom_minimum_size = Vector2(320, 42)
	_hard_mode_btn.add_theme_font_size_override("font_size", 18)
	_hard_mode_btn.toggle_mode = true
	_hard_mode_btn.button_pressed = GameManager.hard_mode
	_update_hard_mode_label()
	_hard_mode_btn.toggled.connect(_on_hard_mode_toggled)

	# Style: red-ish tint
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.06, 0.05, 0.9)
	style.border_color = Color(0.74, 0.23, 0.16, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_hard_mode_btn.add_theme_stylebox_override("normal", style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.31, 0.08, 0.06, 0.94)
	pressed_style.border_color = Color(0.97, 0.42, 0.26)
	_hard_mode_btn.add_theme_stylebox_override("pressed", pressed_style)

	_hard_mode_btn.add_theme_color_override("font_color", Color(0.92, 0.56, 0.43))
	_hard_mode_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.69, 0.52))

	# Insert after NewGameButton (index 3 = after Title, Subtitle, Spacer, NewGameButton)
	var new_game_idx := new_game_btn.get_index()
	vbox.add_child(_hard_mode_btn)
	vbox.move_child(_hard_mode_btn, new_game_idx + 1)

func _update_hard_mode_label() -> void:
	if _hard_mode_btn:
		if _hard_mode_btn.button_pressed:
			_hard_mode_btn.text = "⚡ 梦魇远征：开启"
		else:
			_hard_mode_btn.text = "梦魇远征：关闭"

func _on_hard_mode_toggled(pressed: bool) -> void:
	GameManager.set_hard_mode(pressed)
	_update_hard_mode_label()

func _on_new_game() -> void:
	"""Go to spirit root selection screen."""
	_show_status("")
	GameManager.goto_scene("res://scenes/ui/SpiritRootSelection.tscn")

func _on_continue() -> void:
	"""Load saved game and continue."""
	_show_status("")
	if GameManager.load_game():
		GameManager.goto_scene("res://scenes/Main.tscn")
	else:
		_show_status(GameManager.get_last_load_error())
		push_warning("[MainMenu] Failed to load save")

func _on_quit() -> void:
	"""Exit the game."""
	get_tree().quit()
