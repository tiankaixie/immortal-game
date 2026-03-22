@warning_ignore_start("redundant_await")
class_name RunEndSceneTest
extends GdUnitTestSuite

const PLAYER_SCENE_PATH := "res://scenes/player/Player.tscn"
const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const DEATH_SCREEN_PATH := "res://scenes/ui/DeathScreen.tscn"
const DUNGEON_CONTROLLER_SCRIPT_PATH := "res://scripts/dungeon/DungeonController.gd"
const MAX_SCENE_WAIT_FRAMES := 480

const TEST_GAME_SAVE_PATH := "/tmp/run_end_game_save.json"
const TEST_RUN_HISTORY_PATH := "/tmp/run_end_history.json"
const TEST_UNLOCKS_PATH := "/tmp/run_end_unlocks.json"

var _player_snapshot: Dictionary = {}
var _game_snapshot: Dictionary = {}
var _run_stats_snapshot: Dictionary = {}
var _run_history_snapshot: Array = []
var _unlock_stats_snapshot: Dictionary = {}
var _unlock_unlocked_snapshot: Array[String] = []

var _game_save_path_snapshot: String = ""
var _run_history_path_snapshot: String = ""
var _unlocks_path_snapshot: String = ""

func before_test() -> void:
	_player_snapshot = PlayerData.to_dict()
	_game_snapshot = {
		"current_state": GameManager.current_state,
		"previous_state": GameManager.previous_state,
		"hard_mode": GameManager.hard_mode,
		"current_dungeon_id": GameManager.current_dungeon_id,
		"current_floor": GameManager.current_floor,
		"current_room": GameManager.current_room,
		"run_spirit_stones": GameManager.run_spirit_stones,
		"run_items": GameManager.run_items.duplicate(true),
		"is_run_active": GameManager.is_run_active,
	}
	_run_stats_snapshot = {
		"enemies_killed": RunStats.enemies_killed,
		"spirit_stones_collected": RunStats.spirit_stones_collected,
		"rooms_cleared": RunStats.rooms_cleared,
		"skills_used": RunStats.skills_used,
		"boons_acquired": RunStats.boons_acquired,
		"damage_dealt_total": RunStats.damage_dealt_total,
		"run_start_time": RunStats.run_start_time,
	}
	_run_history_snapshot = RunHistory.get_best_runs()
	_unlock_stats_snapshot = UnlockSystem.cumulative_stats.duplicate(true)
	_unlock_unlocked_snapshot = UnlockSystem.unlocked.duplicate()

	_game_save_path_snapshot = GameManager.get_save_path()
	_run_history_path_snapshot = RunHistory.get_save_path()
	_unlocks_path_snapshot = UnlockSystem.get_save_path()

	GameManager.set_save_path(TEST_GAME_SAVE_PATH)
	RunHistory.set_save_path(TEST_RUN_HISTORY_PATH)
	UnlockSystem.set_save_path(TEST_UNLOCKS_PATH)

	_delete_test_file(TEST_GAME_SAVE_PATH)
	_delete_test_file(TEST_RUN_HISTORY_PATH)
	_delete_test_file(TEST_UNLOCKS_PATH)

	RunHistory._history = []
	UnlockSystem.cumulative_stats = {
		"total_kills": 0,
		"total_runs": 0,
		"total_completions": 0,
		"total_spirit_stones": 0,
	}
	UnlockSystem.unlocked.clear()
	_reset_run_stats()

func after() -> void:
	PlayerData.from_dict(_player_snapshot)

	GameManager.current_state = _game_snapshot["current_state"]
	GameManager.previous_state = _game_snapshot["previous_state"]
	GameManager.hard_mode = _game_snapshot["hard_mode"]
	GameManager.current_dungeon_id = _game_snapshot["current_dungeon_id"]
	GameManager.current_floor = _game_snapshot["current_floor"]
	GameManager.current_room = _game_snapshot["current_room"]
	GameManager.run_spirit_stones = _game_snapshot["run_spirit_stones"]
	GameManager.run_items = _game_snapshot["run_items"].duplicate(true)
	GameManager.is_run_active = _game_snapshot["is_run_active"]

	RunStats.enemies_killed = _run_stats_snapshot["enemies_killed"]
	RunStats.spirit_stones_collected = _run_stats_snapshot["spirit_stones_collected"]
	RunStats.rooms_cleared = _run_stats_snapshot["rooms_cleared"]
	RunStats.skills_used = _run_stats_snapshot["skills_used"]
	RunStats.boons_acquired = _run_stats_snapshot["boons_acquired"]
	RunStats.damage_dealt_total = _run_stats_snapshot["damage_dealt_total"]
	RunStats.run_start_time = _run_stats_snapshot["run_start_time"]

	RunHistory._history = _run_history_snapshot.duplicate(true)
	UnlockSystem.cumulative_stats = _unlock_stats_snapshot.duplicate(true)
	UnlockSystem.unlocked = _unlock_unlocked_snapshot.duplicate()

	GameManager.set_save_path(_game_save_path_snapshot)
	RunHistory.set_save_path(_run_history_path_snapshot)
	UnlockSystem.set_save_path(_unlocks_path_snapshot)

	_delete_test_file(TEST_GAME_SAVE_PATH)
	_delete_test_file(TEST_RUN_HISTORY_PATH)
	_delete_test_file(TEST_UNLOCKS_PATH)

	CombatSystem.current_state = CombatSystem.CombatState.IDLE
	CombatSystem.player_entity = null
	CombatSystem.current_target = null
	CombatSystem.enemies.clear()

func after_test() -> void:
	var scene := get_tree().current_scene
	if scene != null and is_instance_valid(scene):
		get_tree().current_scene = null
		scene.free()

func test_player_death_routes_to_death_screen_and_main_menu() -> void:
	PlayerData.spirit_stones = 10
	GameManager.current_state = GameManager.GameState.DUNGEON_RUN
	GameManager.previous_state = GameManager.GameState.MAIN_MENU
	GameManager.current_floor = 2
	GameManager.current_room = 4
	GameManager.run_spirit_stones = 9
	GameManager.is_run_active = true
	RunStats.rooms_cleared = 4
	RunStats.enemies_killed = 7
	RunStats.spirit_stones_collected = 9
	RunStats.run_start_time = Time.get_unix_time_from_system() - 45

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player := player_scene.instantiate()
	_set_current_scene(player)

	await await_idle_frame()
	player.call("_on_death")

	var death_screen := await _await_current_scene(DEATH_SCREEN_PATH)
	assert_object(death_screen).is_not_null()
	assert_bool(GameManager.is_run_active).is_false()
	assert_int(GameManager.current_state).is_equal(GameManager.GameState.SECT_HUB)
	assert_int(PlayerData.spirit_stones).is_equal(14)

	var saved_game := _read_json_file(TEST_GAME_SAVE_PATH)
	assert_bool(saved_game.has("player_data")).is_true()
	assert_bool(saved_game.has("run_state")).is_true()
	assert_bool(saved_game.has("game_state")).is_true()
	assert_bool(saved_game["run_state"]["is_run_active"]).is_false()
	assert_int(int(saved_game["game_state"])).is_equal(GameManager.GameState.SECT_HUB)

	var menu_button := _find_button_by_text(death_screen, "归返虚无")
	assert_object(menu_button).is_not_null()
	menu_button.emit_signal("pressed")

	var main_menu := await _await_current_scene(MAIN_MENU_PATH)
	assert_object(main_menu).is_not_null()

func test_dungeon_completion_returns_to_main_menu_and_keeps_rewards() -> void:
	PlayerData.spirit_stones = 3
	GameManager.hard_mode = false
	GameManager.current_state = GameManager.GameState.DUNGEON_RUN
	GameManager.previous_state = GameManager.GameState.MAIN_MENU
	GameManager.current_floor = 5
	GameManager.current_room = 5
	GameManager.run_spirit_stones = 12
	GameManager.is_run_active = true

	var harness := Node.new()
	harness.name = "RunEndHarness"
	_set_current_scene(harness)

	var test_room := Node3D.new()
	test_room.name = "TestRoom"
	harness.add_child(test_room)

	var dungeon_controller := Node.new()
	dungeon_controller.name = "DungeonController"
	dungeon_controller.set_script(load(DUNGEON_CONTROLLER_SCRIPT_PATH))
	harness.add_child(dungeon_controller)

	dungeon_controller.call("_show_dungeon_complete")
	await await_idle_frame()

	var return_button := _find_button_by_text(dungeon_controller, "返回主界面")
	assert_object(return_button).is_not_null()
	return_button.emit_signal("pressed")

	var main_menu := await _await_current_scene(MAIN_MENU_PATH)
	assert_object(main_menu).is_not_null()
	assert_bool(GameManager.is_run_active).is_false()
	assert_int(GameManager.current_state).is_equal(GameManager.GameState.SECT_HUB)
	assert_int(PlayerData.spirit_stones).is_equal(15)

	var saved_game := _read_json_file(TEST_GAME_SAVE_PATH)
	assert_bool(saved_game.has("player_data")).is_true()
	assert_bool(saved_game.has("run_state")).is_true()
	assert_bool(saved_game.has("game_state")).is_true()
	assert_bool(saved_game["run_state"]["is_run_active"]).is_false()
	assert_int(int(saved_game["game_state"])).is_equal(GameManager.GameState.SECT_HUB)

func _set_current_scene(scene: Node) -> void:
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene

func _await_current_scene(scene_path: String) -> Node:
	for _i in range(MAX_SCENE_WAIT_FRAMES):
		await await_idle_frame()
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == scene_path:
			return scene

	push_error("Timed out waiting for scene %s" % scene_path)
	return null

func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node

	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found

	return null

func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	assert_int(err).is_equal(OK)
	return json.data as Dictionary

func _delete_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _reset_run_stats() -> void:
	RunStats.enemies_killed = 0
	RunStats.spirit_stones_collected = 0
	RunStats.rooms_cleared = 0
	RunStats.skills_used = 0
	RunStats.boons_acquired = 0
	RunStats.damage_dealt_total = 0
	RunStats.run_start_time = Time.get_unix_time_from_system()
