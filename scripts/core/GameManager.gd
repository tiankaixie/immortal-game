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
const DEFAULT_SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 2

# ─── Current State ─────────────────────────────────────────────
var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU

# ─── Hard Mode (劫难模式) ──────────────────────────────────────
var hard_mode: bool = false
var _save_path: String = DEFAULT_SAVE_PATH
var _last_load_error: String = ""

# ─── Run Data (reset each dungeon run) ────────────────────────
var current_dungeon_id: String = ""
var current_floor: int = 0
var current_room: int = 0
var run_spirit_stones: int = 0       # Currency earned this run
var run_items: Array = []             # Items found this run
var is_run_active: bool = false
var run_layout: Dictionary = {}

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
		print("[GameManager] Save file detected at %s" % get_save_path())

func set_hard_mode(enabled: bool) -> void:
	"""Toggle hard mode (劫难模式). Enemies deal more damage and have more HP."""
	hard_mode = enabled
	print("[GameManager] Hard mode: %s" % ("ON" if hard_mode else "OFF"))

func get_save_path() -> String:
	return _save_path

func get_global_save_path() -> String:
	return _globalize_path(get_save_path())

func get_last_load_error() -> String:
	return _last_load_error

func set_save_path(path: String) -> void:
	_save_path = path

func reset_save_path() -> void:
	_save_path = DEFAULT_SAVE_PATH

func _globalize_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _ensure_save_directory_exists(path: String) -> bool:
	var base_dir := path.get_base_dir()
	if base_dir.is_empty():
		return true

	var global_base_dir := _globalize_path(base_dir)
	if DirAccess.dir_exists_absolute(global_base_dir):
		return true

	var err := DirAccess.make_dir_recursive_absolute(global_base_dir)
	if err != OK:
		push_error("[GameManager] Failed to create save directory %s: %s" % [
			global_base_dir,
			error_string(err),
		])
		return false

	return true

func _set_last_load_error(message: String) -> void:
	_last_load_error = message

func _inspect_save_file() -> Dictionary:
	var save_path := get_save_path()
	if not has_save_file():
		_set_last_load_error("未找到可继续的存档。")
		return {"ok": false, "error": _last_load_error}

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		var read_error := "无法打开存档文件：%s。" % get_global_save_path()
		_set_last_load_error(read_error)
		push_error("[GameManager] Failed to open save file for reading: %s" % error_string(FileAccess.get_open_error()))
		return {"ok": false, "error": _last_load_error}

	var json_string := file.get_as_text()
	file.close()

	if json_string.is_empty():
		_set_last_load_error("存档文件为空，请删除损坏存档后重试。")
		push_error("[GameManager] Save file is empty")
		return {"ok": false, "error": _last_load_error}

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		_set_last_load_error("存档内容已损坏，无法继续游戏。请删除旧存档后重试。")
		push_error("[GameManager] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {"ok": false, "error": _last_load_error}

	if not json.data is Dictionary:
		_set_last_load_error("存档格式无效，无法继续游戏。")
		push_error("[GameManager] Save data is not a valid dictionary")
		return {"ok": false, "error": _last_load_error}

	var save_data := _migrate_save_data(json.data as Dictionary)
	if not save_data.has("player_data") or not save_data["player_data"] is Dictionary:
		_set_last_load_error("存档缺少角色数据，无法继续游戏。")
		push_error("[GameManager] Save file missing valid player_data section")
		return {"ok": false, "error": _last_load_error}

	_set_last_load_error("")
	return {"ok": true, "data": save_data}

func _default_run_state() -> Dictionary:
	return {
		"current_dungeon_id": "",
		"current_floor": 0,
		"current_room": 0,
		"run_spirit_stones": 0,
		"run_items": [],
		"is_run_active": false,
	}

func _default_run_stats() -> Dictionary:
	return {
		"enemies_killed": 0,
		"spirit_stones_collected": 0,
		"rooms_cleared": 0,
		"skills_used": 0,
		"boons_acquired": 0,
		"damage_dealt_total": 0,
		"run_start_time": Time.get_unix_time_from_system(),
	}

func _default_boon_state() -> Dictionary:
	return {
		"acquired_boons": [],
		"atk_multiplier": 1.0,
		"def_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"hp_regen_per_sec": 0.0,
		"sp_max_bonus": 0.0,
		"dash_cooldown_reduction": 0.0,
		"double_strike_chance": 0.0,
		"iron_body_chance": 0.0,
		"skill_damage_multiplier": 1.0,
		"loot_tier_bonus": 0,
		"skill_slot_bonus": 0,
		"burn_damage_multiplier": 1.0,
	}

func _normalize_game_state(value: Variant, is_active_run: bool) -> int:
	var state := int(value)
	if state == GameState.PAUSED and is_active_run:
		return GameState.DUNGEON_RUN
	if state == GameState.MAIN_MENU and is_active_run:
		return GameState.DUNGEON_RUN
	return state

func _migrate_save_data(save_data: Dictionary) -> Dictionary:
	var migrated := save_data.duplicate(true)
	var version := int(migrated.get("version", 1))
	var run_state: Dictionary = _default_run_state()
	if migrated.has("run_state") and migrated["run_state"] is Dictionary:
		run_state.merge(migrated["run_state"], true)

	if version < 2:
		if not migrated.has("run_stats") or not migrated["run_stats"] is Dictionary:
			migrated["run_stats"] = _default_run_stats()
		if not migrated.has("boon_state") or not migrated["boon_state"] is Dictionary:
			migrated["boon_state"] = _default_boon_state()
		if not migrated.has("run_layout") or not migrated["run_layout"] is Dictionary:
			migrated["run_layout"] = {}
		migrated["game_state"] = _normalize_game_state(
			migrated.get("game_state", GameState.MAIN_MENU),
			bool(run_state.get("is_run_active", false))
		)
		migrated["version"] = SAVE_VERSION
	elif version > SAVE_VERSION:
		push_warning("[GameManager] Save version %d is newer than supported version %d; attempting best-effort load" % [
			version,
			SAVE_VERSION,
		])

	if not migrated.has("run_state") or not migrated["run_state"] is Dictionary:
		migrated["run_state"] = run_state
	else:
		migrated["run_state"] = run_state
	if not migrated.has("run_stats") or not migrated["run_stats"] is Dictionary:
		migrated["run_stats"] = _default_run_stats()
	if not migrated.has("boon_state") or not migrated["boon_state"] is Dictionary:
		migrated["boon_state"] = _default_boon_state()
	if not migrated.has("run_layout") or not migrated["run_layout"] is Dictionary:
		migrated["run_layout"] = {}

	migrated["game_state"] = _normalize_game_state(
		migrated.get("game_state", GameState.MAIN_MENU),
		bool((migrated["run_state"] as Dictionary).get("is_run_active", false))
	)

	return migrated

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
	run_layout.clear()
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
func grant_random_equipment(luck_modifier: float = 2.0) -> Dictionary:
	"""Grant a random equipment item with given luck modifier.
	
	Returns the generated item Dictionary (also adds it to inventory unless caller handles it).
	The caller is responsible for adding it to PlayerData.inventory if needed.
	"""
	var slot_pool := ["weapon", "armor", "accessory_1", "talisman"]
	var slot: String = slot_pool[randi() % slot_pool.size()]

	var equip_sys = get_node("/root/EquipmentSystem")
	var item: Dictionary = equip_sys.generate_equipment(slot, current_floor, luck_modifier)
	print("[GameManager] Equipment generated: %s (%s) [luck %.1fx]" % [
		item.get("name", "Unknown"), item.get("rarity_name", "?"), luck_modifier
	])
	return item

# ─── Scene Transitions ────────────────────────────────────────
func goto_scene(scene_path: String) -> void:
	"""Deferred scene change to avoid mid-frame issues."""
	print("[GameManager] goto_scene called: %s" % scene_path)
	call_deferred("_deferred_goto_scene", scene_path)

func _deferred_goto_scene(scene_path: String) -> void:
	print("[GameManager] _deferred_goto_scene: %s" % scene_path)
	var current_scene := get_tree().current_scene
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("[GameManager] Failed to load scene: %s" % scene_path)
		return
	var new_scene := packed_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	print("[GameManager] Scene loaded successfully: %s" % scene_path)

# ─── Save/Load ─────────────────────────────────────────────────
func has_save_file() -> bool:
	"""Check if a save file exists on disk."""
	return FileAccess.file_exists(get_save_path())

func save_game() -> void:
	"""Save persistent data to disk as JSON."""
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
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
		"run_stats": RunStats.to_dict(),
		"boon_state": BoonDatabase.to_dict(),
		"run_layout": run_layout.duplicate(true),
		"game_state": current_state,
	}
	
	var json_string := JSON.stringify(save_data, "\t")
	
	var save_path := get_save_path()
	if not _ensure_save_directory_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("[GameManager] Failed to open save file for writing: %s" % error_string(err))
		return
	
	file.store_string(json_string)
	file.close()
	
	game_saved.emit()
	print("[GameManager] Game saved to %s" % save_path)

func load_game() -> bool:
	"""Load persistent data from disk. Returns false if no save exists or on error."""
	var inspection := _inspect_save_file()
	if not bool(inspection.get("ok", false)):
		print("[GameManager] Load failed: %s" % inspection.get("error", "unknown error"))
		return false

	var save_path := get_save_path()
	var save_data := inspection["data"] as Dictionary
	
	# Restore player data
	PlayerData.from_dict(save_data["player_data"])
	
	# Restore run state
	var run := save_data["run_state"] as Dictionary
	current_dungeon_id = run.get("current_dungeon_id", "")
	current_floor = run.get("current_floor", 0)
	current_room = run.get("current_room", 0)
	run_spirit_stones = run.get("run_spirit_stones", 0)
	run_items = run.get("run_items", [])
	is_run_active = run.get("is_run_active", false)

	RunStats.from_dict(save_data["run_stats"])

	BoonDatabase.from_dict(save_data["boon_state"])

	run_layout = {}
	run_layout = (save_data["run_layout"] as Dictionary).duplicate(true)
	
	# Restore game state
	current_state = save_data["game_state"] as GameState
	
	game_loaded.emit()
	print("[GameManager] Game loaded from %s (saved: %s)" % [
		save_path,
		save_data.get("timestamp", "unknown")
	])
	return true
