extends Control
## MainMenu — Title screen
##
## Options:
## - 新的修仙 (New Game) → loads Main.tscn
## - 继续修炼 (Continue) → loads Main.tscn with save data (grayed if no save)
## - 退出 (Quit)

@onready var new_game_btn: Button = $VBoxContainer/NewGameButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

var _hard_mode_btn: Button = null

func _ready() -> void:
	# Show cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Check for save file
	if not GameManager.has_save_file():
		continue_btn.disabled = true
		continue_btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	# Connect signals
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(_on_quit)
	
	# Add hard mode toggle if unlocked
	if UnlockSystem.is_unlocked("hard_mode"):
		_add_hard_mode_toggle()
	
	print("[MainMenu] Ready")

func _add_hard_mode_toggle() -> void:
	"""Add a 劫难模式 toggle button below the new game button."""
	var vbox := $VBoxContainer
	_hard_mode_btn = Button.new()
	_hard_mode_btn.custom_minimum_size = Vector2(250, 40)
	_hard_mode_btn.add_theme_font_size_override("font_size", 18)
	_hard_mode_btn.toggle_mode = true
	_hard_mode_btn.button_pressed = GameManager.hard_mode
	_update_hard_mode_label()
	_hard_mode_btn.toggled.connect(_on_hard_mode_toggled)

	# Style: red-ish tint
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.8)
	style.border_color = Color(0.8, 0.2, 0.2, 0.6)
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
	pressed_style.bg_color = Color(0.3, 0.05, 0.05, 0.9)
	pressed_style.border_color = Color(1.0, 0.3, 0.2)
	_hard_mode_btn.add_theme_stylebox_override("pressed", pressed_style)

	_hard_mode_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	_hard_mode_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.5, 0.3))

	# Insert after NewGameButton (index 3 = after Title, Subtitle, Spacer, NewGameButton)
	var new_game_idx := new_game_btn.get_index()
	vbox.add_child(_hard_mode_btn)
	vbox.move_child(_hard_mode_btn, new_game_idx + 1)

func _update_hard_mode_label() -> void:
	if _hard_mode_btn:
		if _hard_mode_btn.button_pressed:
			_hard_mode_btn.text = "⚡ 劫难模式：开启"
		else:
			_hard_mode_btn.text = "劫难模式：关闭"

func _on_hard_mode_toggled(pressed: bool) -> void:
	GameManager.set_hard_mode(pressed)
	_update_hard_mode_label()

func _on_new_game() -> void:
	"""Go to spirit root selection screen."""
	GameManager.goto_scene("res://scenes/ui/SpiritRootSelection.tscn")

func _on_continue() -> void:
	"""Load saved game and continue."""
	if GameManager.load_game():
		GameManager.goto_scene("res://scenes/Main.tscn")
	else:
		push_warning("[MainMenu] Failed to load save")

func _on_quit() -> void:
	"""Exit the game."""
	get_tree().quit()
