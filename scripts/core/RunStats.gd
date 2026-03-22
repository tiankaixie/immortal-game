extends Node
## RunStats — Tracks per-run statistics for death screen and analytics
##
## Reset at the start of each dungeon run.
## Displayed on DeathScreen when player dies.

var enemies_killed: int = 0
var spirit_stones_collected: int = 0
var rooms_cleared: int = 0
var skills_used: int = 0
var boons_acquired: int = 0
var damage_dealt_total: int = 0
var run_start_time: float = 0.0

func _ready() -> void:
	print("[RunStats] Initialized")

func reset() -> void:
	"""Reset all stats for a new run."""
	enemies_killed = 0
	spirit_stones_collected = 0
	rooms_cleared = 0
	skills_used = 0
	boons_acquired = 0
	damage_dealt_total = 0
	run_start_time = Time.get_unix_time_from_system()
	print("[RunStats] Stats reset for new run")

func to_dict() -> Dictionary:
	return {
		"enemies_killed": enemies_killed,
		"spirit_stones_collected": spirit_stones_collected,
		"rooms_cleared": rooms_cleared,
		"skills_used": skills_used,
		"boons_acquired": boons_acquired,
		"damage_dealt_total": damage_dealt_total,
		"run_start_time": run_start_time,
	}

func from_dict(data: Dictionary) -> void:
	enemies_killed = data.get("enemies_killed", 0)
	spirit_stones_collected = data.get("spirit_stones_collected", 0)
	rooms_cleared = data.get("rooms_cleared", 0)
	skills_used = data.get("skills_used", 0)
	boons_acquired = data.get("boons_acquired", 0)
	damage_dealt_total = data.get("damage_dealt_total", 0)
	run_start_time = data.get("run_start_time", Time.get_unix_time_from_system())
