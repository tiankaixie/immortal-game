extends Node
## RunHistory — Tracks best historical runs across sessions
##
## Saves top 5 runs to user://run_history.json, sorted by rooms_cleared desc,
## then kills desc. Provides methods to query best runs and best single-stat records.

const SAVE_PATH: String = "user://run_history.json"
const MAX_RECORDS: int = 5

var _history: Array = []

func _ready() -> void:
	_load_history()
	print("[RunHistory] Initialized — %d historical runs loaded" % _history.size())

# ─── Public API ────────────────────────────────────────────────

func save_run(run_data: Dictionary) -> void:
	"""Save a run record. Keeps only top MAX_RECORDS runs."""
	# Ensure required fields have defaults
	var record := {
		"date": Time.get_datetime_string_from_system(false, true),
		"spiritual_root": run_data.get("spiritual_root", 0),
		"realm": run_data.get("realm", 0),
		"stage": run_data.get("stage", 0),
		"rooms_cleared": run_data.get("rooms_cleared", 0),
		"kills": run_data.get("kills", 0),
		"spirit_stones": run_data.get("spirit_stones", 0),
		"damage_dealt": run_data.get("damage_dealt", 0),
		"duration_seconds": run_data.get("duration_seconds", 0),
		"cause_of_death_room": run_data.get("cause_of_death_room", 0),
	}
	_history.append(record)
	_sort_history()
	# Trim to max records
	if _history.size() > MAX_RECORDS:
		_history.resize(MAX_RECORDS)
	_save_history()
	print("[RunHistory] Run saved — rooms: %d, kills: %d" % [record["rooms_cleared"], record["kills"]])

func get_best_runs() -> Array:
	"""Return all saved runs sorted by rooms_cleared desc, then kills desc."""
	return _history.duplicate()

func get_best_record(stat: String) -> Dictionary:
	"""Return the run with the highest value for a given stat key."""
	if _history.is_empty():
		return {}
	var best: Dictionary = _history[0]
	for run in _history:
		if run.get(stat, 0) > best.get(stat, 0):
			best = run
	return best

func is_new_record(stat: String, value) -> bool:
	"""Check if a value beats all historical records for a stat."""
	if _history.is_empty():
		return true
	for run in _history:
		if run.get(stat, 0) >= value:
			return false
	return true

# ─── Internal ──────────────────────────────────────────────────

func _sort_history() -> void:
	"""Sort by rooms_cleared desc, then kills desc."""
	_history.sort_custom(func(a, b):
		if a.get("rooms_cleared", 0) != b.get("rooms_cleared", 0):
			return a.get("rooms_cleared", 0) > b.get("rooms_cleared", 0)
		return a.get("kills", 0) > b.get("kills", 0)
	)

func _save_history() -> void:
	"""Write history to disk as JSON."""
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_history, "\t"))
		file.close()
	else:
		push_warning("[RunHistory] Failed to save: %s" % SAVE_PATH)

func _load_history() -> void:
	"""Load history from disk."""
	if not FileAccess.file_exists(SAVE_PATH):
		_history = []
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_history = []
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err == OK and json.data is Array:
		_history = json.data
	else:
		push_warning("[RunHistory] Failed to parse history, starting fresh")
		_history = []
