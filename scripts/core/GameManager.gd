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

# ─── Current State ─────────────────────────────────────────────
var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU

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

func _ready() -> void:
	# TODO: Initialize save system
	# TODO: Load player data from disk
	print("[GameManager] Initialized")

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

func advance_floor() -> void:
	"""Move to the next dungeon floor."""
	current_floor += 1
	current_room = 0
	floor_advanced.emit(current_floor)

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
func save_game() -> void:
	"""Save persistent data to disk."""
	# TODO: Serialize PlayerData to JSON
	# TODO: Write to user://savegame.json
	pass

func load_game() -> bool:
	"""Load persistent data from disk. Returns false if no save exists."""
	# TODO: Read from user://savegame.json
	# TODO: Deserialize into PlayerData
	return false
