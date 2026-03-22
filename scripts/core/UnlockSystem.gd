extends Node
## UnlockSystem — Tracks cumulative achievements and unlocks content across runs
##
## Saves unlock state to user://unlocks.json.
## Tracks total_kills, total_runs, total_completions, total_spirit_stones.
## Provides methods: record_run(), is_unlocked(), get_unlocks(), check_new_unlocks().

const DEFAULT_SAVE_PATH: String = "user://unlocks.json"

# Cumulative stats across all runs
var cumulative_stats: Dictionary = {
	"total_kills": 0,
	"total_runs": 0,
	"total_completions": 0,  # Cleared all 5 rooms
	"total_spirit_stones": 0,
}

# Set of unlocked item IDs
var unlocked: Array[String] = []

# Unlock definitions: id → { name, description, condition_text, check: Callable }
const MAX_ROOMS: int = 5

var unlock_definitions: Array[Dictionary] = []
var _save_path: String = DEFAULT_SAVE_PATH

func _ready() -> void:
	# Define unlocks (can't use const with Callables)
	unlock_definitions = [
		{
			"id": "spirit_root_thunder",
			"name": "雷灵根",
			"description": "雷霆万钧，一击制敌，攻击附带麻痹效果",
			"condition_text": "累计击杀 50 个敌人",
			"check": func() -> bool: return cumulative_stats["total_kills"] >= 50,
		},
		{
			"id": "spirit_root_void",
			"name": "虚灵根",
			"description": "虚实相生，闪现穿越，概率无视伤害",
			"condition_text": "累计通关 3 次",
			"check": func() -> bool: return cumulative_stats["total_completions"] >= 3,
		},
		{
			"id": "hard_mode",
			"name": "劫难模式",
			"description": "敌人更强，挑战更大，奖励更丰",
			"condition_text": "通关 1 次",
			"check": func() -> bool: return cumulative_stats["total_completions"] >= 1,
		},
		{
			"id": "boon_extra_slot",
			"name": "第五祝福栏",
			"description": "每次祝福选择多一个选项",
			"condition_text": "累计游玩 10 次",
			"check": func() -> bool: return cumulative_stats["total_runs"] >= 10,
		},
	]

	_load_data()
	print("[UnlockSystem] Initialized — %d unlocks, stats: %s" % [unlocked.size(), str(cumulative_stats)])

# ─── Public API ────────────────────────────────────────────────

func record_run(run_data: Dictionary) -> void:
	"""Record a completed run's stats into cumulative totals."""
	cumulative_stats["total_kills"] += run_data.get("kills", 0)
	cumulative_stats["total_runs"] += 1
	cumulative_stats["total_spirit_stones"] += run_data.get("spirit_stones", 0)

	# Check if this was a full completion (cleared all 5 rooms)
	var rooms_cleared: int = run_data.get("rooms_cleared", 0)
	if rooms_cleared >= MAX_ROOMS:
		cumulative_stats["total_completions"] += 1

	_save_data()
	print("[UnlockSystem] Run recorded — total runs: %d, kills: %d, completions: %d" % [
		cumulative_stats["total_runs"],
		cumulative_stats["total_kills"],
		cumulative_stats["total_completions"],
	])

func is_unlocked(unlock_id: String) -> bool:
	"""Check if a specific unlock has been earned."""
	return unlock_id in unlocked

func get_unlocks() -> Array[String]:
	"""Return all unlocked item IDs."""
	return unlocked.duplicate()

func get_save_path() -> String:
	return _save_path

func set_save_path(path: String) -> void:
	_save_path = path

func reset_save_path() -> void:
	_save_path = DEFAULT_SAVE_PATH

func check_new_unlocks() -> Array[Dictionary]:
	"""Check all unlock conditions and return newly unlocked items."""
	var newly_unlocked: Array[Dictionary] = []

	for definition in unlock_definitions:
		var uid: String = definition["id"]
		if uid in unlocked:
			continue
		var check_fn: Callable = definition["check"]
		if check_fn.call():
			unlocked.append(uid)
			newly_unlocked.append({
				"id": uid,
				"name": definition["name"],
				"description": definition["description"],
			})
			print("[UnlockSystem] NEW UNLOCK: %s (%s)" % [definition["name"], uid])

	if newly_unlocked.size() > 0:
		_save_data()

	return newly_unlocked

func get_definition(unlock_id: String) -> Dictionary:
	"""Get the full definition for an unlock by ID."""
	for definition in unlock_definitions:
		if definition["id"] == unlock_id:
			return definition
	return {}

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
		push_error("[UnlockSystem] Failed to create save directory %s: %s" % [
			global_base_dir,
			error_string(err),
		])
		return false

	return true

# ─── Persistence ───────────────────────────────────────────────

func _save_data() -> void:
	var data := {
		"cumulative_stats": cumulative_stats,
		"unlocked": unlocked,
	}
	var save_path := get_save_path()
	if not _ensure_save_directory_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_warning("[UnlockSystem] Failed to save: %s" % save_path)

func _load_data() -> void:
	var save_path := get_save_path()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		if data.has("cumulative_stats") and data["cumulative_stats"] is Dictionary:
			for key in cumulative_stats.keys():
				if data["cumulative_stats"].has(key):
					cumulative_stats[key] = int(data["cumulative_stats"][key])
		if data.has("unlocked") and data["unlocked"] is Array:
			unlocked.clear()
			for uid in data["unlocked"]:
				unlocked.append(str(uid))
	else:
		push_warning("[UnlockSystem] Failed to parse unlock data, starting fresh")
