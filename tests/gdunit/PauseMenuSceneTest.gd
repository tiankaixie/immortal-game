@warning_ignore_start("redundant_await")
class_name PauseMenuSceneTest
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const MAX_SCENE_WAIT_FRAMES := 180
const TEST_SAVE_PATH := "/tmp/pause_menu_resume_test_save.json"

var _player_snapshot: Dictionary = {}
var _game_snapshot: Dictionary = {}
var _run_stats_snapshot: Dictionary = {}
var _boon_snapshot: Dictionary = {}
var _game_save_path_snapshot: String = ""

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
		"run_layout": GameManager.run_layout.duplicate(true),
	}
	_run_stats_snapshot = RunStats.to_dict()
	_boon_snapshot = BoonDatabase.to_dict()
	_game_save_path_snapshot = GameManager.get_save_path()

	GameManager.set_save_path(TEST_SAVE_PATH)
	_delete_test_file(TEST_SAVE_PATH)
	get_tree().paused = false

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
	GameManager.run_layout = _game_snapshot["run_layout"].duplicate(true)
	RunStats.from_dict(_run_stats_snapshot)
	BoonDatabase.from_dict(_boon_snapshot)
	GameManager.set_save_path(_game_save_path_snapshot)
	get_tree().paused = false
	_delete_test_file(TEST_SAVE_PATH)

func after_test() -> void:
	var scene := get_tree().current_scene
	if scene != null and is_instance_valid(scene):
		get_tree().current_scene = null
		scene.free()

func test_pause_menu_returns_to_main_menu_and_continue_restores_run() -> void:
	PlayerData.player_name = "暂停测试修士"
	PlayerData.spirit_stones = 77
	PlayerData.base_attack = 11.5

	GameManager.current_state = GameManager.GameState.DUNGEON_RUN
	GameManager.previous_state = GameManager.GameState.MAIN_MENU
	GameManager.current_dungeon_id = "pause_resume_run"
	GameManager.current_floor = 2
	GameManager.current_room = 3
	GameManager.run_spirit_stones = 11
	GameManager.is_run_active = true
	GameManager.run_layout = {
		"boss_type": "res://scenes/enemies/BossEnemy.tscn",
		"shop_room_number": 4,
		"treasure_rooms": [2, 4],
	}

	RunStats.rooms_cleared = 2
	RunStats.enemies_killed = 5
	RunStats.spirit_stones_collected = 11
	RunStats.skills_used = 3
	RunStats.boons_acquired = 1
	RunStats.damage_dealt_total = 120
	RunStats.run_start_time = 1773921600.0

	BoonDatabase.from_dict({
		"acquired_boons": ["atk_up"],
		"atk_multiplier": 1.15,
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
	})

	var main_scene: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_set_current_scene(main_scene)

	var resumed_scene: Node = await _await_current_scene(MAIN_SCENE_PATH)
	assert_object(resumed_scene).is_not_null()

	var hud: Node = resumed_scene.find_child("HUD", true, false)
	assert_object(hud).is_not_null()
	hud.call("_toggle_pause_menu")

	await await_idle_frame()
	assert_bool(get_tree().paused).is_true()

	var pause_menu: Node = get_tree().root.find_child("PauseMenu", true, false)
	assert_object(pause_menu).is_not_null()

	var main_menu_button: Button = _find_button_by_text(pause_menu, "回到主菜单")
	assert_object(main_menu_button).is_not_null()
	main_menu_button.emit_signal("pressed")

	var main_menu: Node = await _await_current_scene(MAIN_MENU_PATH)
	assert_object(main_menu).is_not_null()
	assert_bool(get_tree().paused).is_false()
	assert_int(GameManager.current_state).is_equal(GameManager.GameState.MAIN_MENU)
	assert_bool(GameManager.is_run_active).is_true()

	var saved_game := _read_json_file(TEST_SAVE_PATH)
	assert_bool(saved_game["run_state"]["is_run_active"]).is_true()
	assert_int(int(saved_game["game_state"])).is_equal(GameManager.GameState.DUNGEON_RUN)
	assert_int(int(saved_game["run_state"]["current_room"])).is_equal(3)

	var continue_button: Button = main_menu.find_child("ContinueButton", true, false) as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.disabled).is_false()
	continue_button.emit_signal("pressed")

	var continued_scene: Node = await _await_current_scene(MAIN_SCENE_PATH)
	assert_object(continued_scene).is_not_null()
	assert_int(GameManager.current_room).is_equal(3)
	assert_int(RunStats.rooms_cleared).is_equal(2)
	assert_array(BoonDatabase.acquired_boons).contains_exactly(["atk_up"])
	assert_float(BoonDatabase.atk_multiplier).is_equal(1.15)

	var continued_hud: Node = continued_scene.find_child("HUD", true, false)
	assert_object(continued_hud).is_not_null()
	assert_str(continued_hud.room_label.text).is_equal("第 3/5 间")
	assert_str(continued_hud.dungeon_progress_label.text).is_equal("3 / 5")
	_assert_stones_label_matches(continued_hud, 77)

func test_pause_menu_roundtrip_remains_stable_across_multiple_continue_cycles() -> void:
	PlayerData.player_name = "往返测试修士"
	PlayerData.spirit_stones = 41
	PlayerData.base_attack = 10.5

	GameManager.current_state = GameManager.GameState.DUNGEON_RUN
	GameManager.previous_state = GameManager.GameState.MAIN_MENU
	GameManager.current_dungeon_id = "repeat_roundtrip_run"
	GameManager.current_floor = 1
	GameManager.current_room = 4
	GameManager.run_spirit_stones = 6
	GameManager.is_run_active = true
	GameManager.run_layout = {
		"boss_type": "res://scenes/enemies/BossEnemy.tscn",
		"shop_room_number": 3,
		"treasure_rooms": [2, 4],
	}

	RunStats.rooms_cleared = 3
	RunStats.enemies_killed = 7
	RunStats.spirit_stones_collected = 6
	RunStats.skills_used = 2
	RunStats.boons_acquired = 1
	RunStats.damage_dealt_total = 133
	RunStats.run_start_time = 1773921600.0

	BoonDatabase.from_dict({
		"acquired_boons": ["atk_up"],
		"atk_multiplier": 1.15,
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
	})

	var scene: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_set_current_scene(scene)

	for cycle in range(2):
		var active_scene := await _await_current_scene(MAIN_SCENE_PATH)
		assert_object(active_scene).is_not_null()
		var main_menu := await _pause_to_main_menu(active_scene)
		assert_object(main_menu).is_not_null()

		var saved_game := _read_json_file(TEST_SAVE_PATH)
		assert_bool(saved_game["run_state"]["is_run_active"]).is_true()
		assert_int(int(saved_game["run_state"]["current_room"])).is_equal(4)
		assert_int(int(saved_game["version"])).is_equal(GameManager.SAVE_VERSION)

		var continue_button: Button = main_menu.find_child("ContinueButton", true, false) as Button
		assert_object(continue_button).is_not_null()
		assert_bool(continue_button.disabled).is_false()
		continue_button.emit_signal("pressed")

		var continued_scene := await _await_current_scene(MAIN_SCENE_PATH)
		assert_object(continued_scene).is_not_null()
		assert_int(GameManager.current_room).is_equal(4)
		assert_int(RunStats.rooms_cleared).is_equal(3)
		assert_array(BoonDatabase.acquired_boons).contains_exactly(["atk_up"])

		var hud: Node = continued_scene.find_child("HUD", true, false)
		assert_object(hud).is_not_null()
		assert_str(hud.room_label.text).is_equal("第 4/5 间")
		assert_str(hud.dungeon_progress_label.text).is_equal("4 / 5")
		_assert_stones_label_matches(hud, 41)
		assert_bool(get_tree().paused).is_false()
		assert_int(get_tree().root.find_children("PauseMenu", "", true, false).size()).is_equal(0)

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

func _pause_to_main_menu(scene: Node) -> Node:
	var hud: Node = scene.find_child("HUD", true, false)
	assert_object(hud).is_not_null()
	hud.call("_toggle_pause_menu")

	await await_idle_frame()
	assert_bool(get_tree().paused).is_true()

	var pause_menu: Node = get_tree().root.find_child("PauseMenu", true, false)
	assert_object(pause_menu).is_not_null()

	var main_menu_button: Button = _find_button_by_text(pause_menu, "回到主菜单")
	assert_object(main_menu_button).is_not_null()
	main_menu_button.emit_signal("pressed")
	return await _await_current_scene(MAIN_MENU_PATH)

func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	assert_int(err).is_equal(OK)
	return json.data as Dictionary

func _assert_stones_label_matches(hud: Node, minimum_value: int) -> void:
	var current_stones := PlayerData.spirit_stones
	assert_int(current_stones).is_greater_equal(minimum_value)
	assert_str(hud.stones_label.text).is_equal("灵石: %d" % current_stones)

func _delete_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
