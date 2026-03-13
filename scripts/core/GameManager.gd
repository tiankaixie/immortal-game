extends Node
## GameManager — Global Autoload Singleton
##
## Responsibilities:
## - Track overall game state (menu, hub, dungeon, combat, paused)
## - Coordinate scene transitions
## - Interface with SaveSystem for persistence
## - Manage run state (current dungeon floor, room, etc.)

# ─── Game States ───────────────────────────────────────────────
enum GameState {
	MAIN_MENU,
	SECT_HUB,       # Between runs — the player's mountain sect
	DUNGEON_RUN,    # Inside a dungeon run
	COMBAT,         # Active combat encounter
	PAUSED,
	LOADING,
}

# ─── Save Constants ───────────────────────────────────────────
const SAVE_PATH: String = "user://savegame.json"

# ─── Current State ─────────────────────────────────────────────
var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU

# ─── Hard Mode (劫难模式) ──────────────────────────────────────
var hard_mode: bool = false

# ─── Run Data (reset each dungeon run) ────────────────────────
var current_dungeon_id: String = ""
var current_floor: int = 0
var current_room: int = 0
var run_spirit_stones: int = 0       # Currency earned this run
var run_items: Array = []             # Items found this run
var is_run_active: bool = false

# ─── Signals ───────────────────────────────────────────────────
signal state_changed(new_state: GameState, old_state: GameState)
signal run_started(dungeon_id: String)
signal run_ended(victory: bool)
signal floor_advanced(new_floor: int)
signal game_saved()
signal game_loaded()

func _ready() -> void:
	print("[GameManager] Initialized")
	# Attempt to load save on startup
	if has_save_file():
		print("[GameManager] Save file detected at %s" % SAVE_PATH)

func set_hard_mode(enabled: bool) -> void:
	"""Toggle hard mode (劫难模式). Enemies deal more damage and have more HP."""
	hard_mode = enabled
	print("[GameManager] Hard mode: %s" % ("ON" if hard_mode else "OFF"))

# ─── State Management ──────────────────────────────────────────
func change_state(new_state: GameState) -> void:
	"""Transition to a new game state. Emits state_changed signal."""
	previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state, previous_state)
	print("[GameManager] State: %s → %s" % [
		GameState.keys()[previous_state],
		GameState.keys()[new_state]
	])

# ─── Run Management ───────────────────────────────────────────
func start_run(dungeon_id: String) -> void:
	"""Begin a new dungeon run. Resets run-specific data."""
	current_dungeon_id = dungeon_id
	current_floor = 1
	current_room = 0
	run_spirit_stones = 0
	run_items.clear()
	is_run_active = true
	change_state(GameState.DUNGEON_RUN)
	run_started.emit(dungeon_id)

func end_run(victory: bool) -> void:
	"""End the current run. Calculate rewards and return to sect."""
	is_run_active = false
	
	# Calculate kept rewards
	var stones_kept := run_spirit_stones if victory else int(run_spirit_stones * 0.5)
	PlayerData.add_spirit_stones(stones_kept)
	
	# TODO: Process soul-bound items
	# TODO: Add cultivation XP based on run performance
	
	change_state(GameState.SECT_HUB)
	run_ended.emit(victory)
	
	# Auto-save after run ends
	save_game()

func advance_floor() -> void:
	"""Move to the next dungeon floor."""
	current_floor += 1
	current_room = 0
	floor_advanced.emit(current_floor)

# ─── Equipment Drops ──────────────────────────────────────────
func grant_random_equipment() -> void:
	"""Grant a random equipment item to the player's inventory from boss loot."""
	var slot_pool := ["weapon", "armor", "accessory_1", "talisman"]
	var slot := slot_pool[randi() % slot_pool.size()]

	# Boss drops: boosted luck (2.0) for higher rarity chance
	var item := EquipmentSystem.generate_equipment(slot, current_floor, 2.0)

	# Add to player inventory
	PlayerData.add_to_inventory(item)
	print("[GameManager] Boss dropped: %s (%s)" % [item.get("name", "Unknown"), item.get("rarity_name", "?")])

# ─── Scene Transitions ────────────────────────────────────────
func goto_scene(scene_path: String) -> void:
	"""Deferred scene change to avoid mid-frame issues."""
	# TODO: Add transition animation (fade to black)
	call_deferred("_deferred_goto_scene", scene_path)

func _deferred_goto_scene(scene_path: String) -> void:
	get_tree().current_scene.free()
	var packed_scene := load(scene_path) as PackedScene
	var new_scene := packed_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

# ─── Save/Load ─────────────────────────────────────────────────
func has_save_file() -> bool:
	"""Check if a save file exists on disk."""
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	"""Save persistent data to disk as JSON."""
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"player_data": PlayerData.to_dict(),
		"run_state": {
			"current_dungeon_id": current_dungeon_id,
			"current_floor": current_floor,
			"current_room": current_room,
			"run_spirit_stones": run_spirit_stones,
			"run_items": run_items,
			"is_run_active": is_run_active,
		},
		"game_state": current_state,
	}
	
	var json_string := JSON.stringify(save_data, "\t")
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("[GameManager] Failed to open save file for writing: %s" % error_string(err))
		return
	
	file.store_string(json_string)
	file.close()
	
	game_saved.emit()
	print("[GameManager] Game saved to %s" % SAVE_PATH)

func load_game() -> bool:
	"""Load persistent data from disk. Returns false if no save exists or on error."""
	if not has_save_file():
		print("[GameManager] No save file found at %s" % SAVE_PATH)
		return false
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("[GameManager] Failed to open save file for reading: %s" % error_string(err))
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		push_error("[GameManager] Save file is empty")
		return false
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("[GameManager] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	
	var save_data: Dictionary = json.data
	if not save_data is Dictionary:
		push_error("[GameManager] Save data is not a valid dictionary")
		return false
	
	# Restore player data
	if save_data.has("player_data"):
		PlayerData.from_dict(save_data["player_data"])
	else:
		push_warning("[GameManager] Save file missing player_data section")
	
	# Restore run state
	if save_data.has("run_state"):
		var run := save_data["run_state"] as Dictionary
		current_dungeon_id = run.get("current_dungeon_id", "")
		current_floor = run.get("current_floor", 0)
		current_room = run.get("current_room", 0)
		run_spirit_stones = run.get("run_spirit_stones", 0)
		run_items = run.get("run_items", [])
		is_run_active = run.get("is_run_active", false)
	
	# Restore game state
	if save_data.has("game_state"):
		current_state = save_data["game_state"] as GameState
	
	game_loaded.emit()
	print("[GameManager] Game loaded from %s (saved: %s)" % [
		SAVE_PATH,
		save_data.get("timestamp", "unknown")
	])
	return true
