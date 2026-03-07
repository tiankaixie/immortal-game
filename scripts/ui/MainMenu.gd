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
	
	print("[MainMenu] Ready")

func _on_new_game() -> void:
	"""Start a fresh game."""
	# Reset PlayerData to defaults
	PlayerData.cultivation_realm = PlayerData.CultivationRealm.QI_CONDENSATION
	PlayerData.cultivation_stage = PlayerData.CultivationStage.EARLY
	PlayerData.cultivation_xp = 0.0
	PlayerData.spirit_stones = 0
	PlayerData.sp = PlayerData.sp_max
	
	# Give starter skills
	var starters := SkillDatabase.get_starter_skills(PlayerData.spiritual_root)
	PlayerData.unlocked_skills = starters
	PlayerData.equipped_skills = starters
	
	GameManager.goto_scene("res://scenes/Main.tscn")

func _on_continue() -> void:
	"""Load saved game and continue."""
	if GameManager.load_game():
		GameManager.goto_scene("res://scenes/Main.tscn")
	else:
		push_warning("[MainMenu] Failed to load save")

func _on_quit() -> void:
	"""Exit the game."""
	get_tree().quit()
