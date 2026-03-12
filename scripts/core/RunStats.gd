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
