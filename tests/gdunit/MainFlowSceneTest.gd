@warning_ignore_start("redundant_await")
class_name MainFlowSceneTest
extends GdUnitTestSuite

const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const SPIRIT_ROOT_SELECTION_PATH := "res://scenes/ui/SpiritRootSelection.tscn"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const MAX_SCENE_WAIT_FRAMES := 120
const TEST_SAVE_PATH := "/tmp/main_flow_test_save.json"

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
	_delete_test_save()
	RunStats.reset()
	BoonDatabase.reset_run()

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
	_delete_test_save()

func after_test() -> void:
	var scene := get_tree().current_scene
	if scene != null and is_instance_valid(scene):
		get_tree().current_scene = null
		scene.free()

func test_main_menu_exposes_primary_actions() -> void:
	var runner := scene_runner(MAIN_MENU_PATH)

	assert_object(runner.find_child("NewGameButton")).is_not_null()
	assert_object(runner.find_child("ContinueButton")).is_not_null()
	assert_object(runner.find_child("QuitButton")).is_not_null()

func test_new_game_routes_through_root_selection_into_main_scene() -> void:
	var runner := scene_runner(MAIN_MENU_PATH)
	get_tree().current_scene = runner.scene()

	runner.invoke("_on_new_game")

	var root_selection := await _await_current_scene(SPIRIT_ROOT_SELECTION_PATH)
	assert_object(root_selection).is_not_null()

	root_selection._select_card(0)
	root_selection._on_confirm()

	var main_scene := await _await_current_scene(MAIN_SCENE_PATH)
	assert_object(main_scene).is_not_null()
	assert_int(PlayerData.spiritual_root).is_equal(PlayerData.SpiritualRoot.METAL)

func test_continue_loads_saved_player_data_and_enters_main_scene() -> void:
	_write_test_save({
		"version": GameManager.SAVE_VERSION,
		"timestamp": "2026-03-19 12:00:00",
		"player_data": {
			"player_name": "测试修士",
			"spiritual_root": PlayerData.SpiritualRoot.FIRE,
			"cultivation_realm": PlayerData.CultivationRealm.QI_CONDENSATION,
			"cultivation_stage": PlayerData.CultivationStage.EARLY,
			"cultivation_xp": 25.0,
			"cultivation_xp_required": 100.0,
			"base_hp": 100.0,
			"base_spiritual_power": 50.0,
			"base_attack": 11.5,
			"base_defense": 5.0,
			"base_speed": 1.0,
			"base_luck": 1.0,
			"sp": 42.0,
			"sp_max": 50.0,
			"spirit_stones": 123,
			"high_grade_stones": 0,
			"equipped_items": {
				"weapon": null,
				"armor": null,
				"accessory_1": null,
				"accessory_2": null,
				"talisman": null,
			},
			"inventory": [],
			"unlocked_skills": ["fire_bolt"],
			"equipped_skills": ["fire_bolt"],
			"skill_slots": 2,
		},
		"run_state": {
			"current_dungeon_id": "test_run",
			"current_floor": 2,
			"current_room": 2,
			"run_spirit_stones": 9,
			"run_items": [],
			"is_run_active": true,
		},
		"run_stats": {
			"enemies_killed": 3,
			"spirit_stones_collected": 9,
			"rooms_cleared": 1,
			"skills_used": 4,
			"boons_acquired": 1,
			"damage_dealt_total": 88,
			"run_start_time": 1773921600.0,
		},
		"boon_state": {
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
		},
		"run_layout": {
			"boss_type": "res://scenes/enemies/BossEnemy.tscn",
			"shop_room_number": 3,
			"treasure_rooms": [2, 4],
		},
		"game_state": GameManager.GameState.DUNGEON_RUN,
	})

	var runner := scene_runner(MAIN_MENU_PATH)
	get_tree().current_scene = runner.scene()

	var continue_button := runner.find_child("ContinueButton") as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.disabled).is_false()

	runner.invoke("_on_continue")

	var main_scene := await _await_current_scene(MAIN_SCENE_PATH)
	assert_object(main_scene).is_not_null()
	assert_int(PlayerData.spiritual_root).is_equal(PlayerData.SpiritualRoot.FIRE)
	assert_int(PlayerData.spirit_stones).is_equal(123)
	assert_float(PlayerData.base_attack).is_equal(11.5)
	assert_int(GameManager.current_floor).is_equal(2)
	assert_int(GameManager.current_room).is_equal(2)
	assert_bool(GameManager.is_run_active).is_true()
	assert_int(RunStats.rooms_cleared).is_equal(1)
	assert_int(RunStats.spirit_stones_collected).is_equal(9)
	assert_array(BoonDatabase.acquired_boons).contains_exactly(["atk_up"])
	assert_float(BoonDatabase.atk_multiplier).is_equal(1.15)
	assert_bool(GameManager.run_layout.has("treasure_rooms")).is_true()

	var dungeon_controller := main_scene.find_child("DungeonController", true, false)
	assert_object(dungeon_controller).is_not_null()
	assert_int(dungeon_controller.current_room_number).is_equal(2)

	var hud := main_scene.find_child("HUD", true, false)
	assert_object(hud).is_not_null()
	assert_str(hud.room_label.text).is_equal("第 2/5 间")
	assert_str(hud.dungeon_progress_label.text).is_equal("2 / 5")
	assert_str(hud.room_type_label.text).is_equal("— 宝藏间 —")
	assert_str(hud.stones_label.text).is_equal("灵石: 123")

func test_continue_migrates_legacy_save_without_run_metadata() -> void:
	_write_test_save({
		"version": 1,
		"timestamp": "2026-03-18 10:00:00",
		"player_data": {
			"player_name": "旧档修士",
			"spiritual_root": PlayerData.SpiritualRoot.WATER,
			"cultivation_realm": PlayerData.CultivationRealm.QI_CONDENSATION,
			"cultivation_stage": PlayerData.CultivationStage.EARLY,
			"cultivation_xp": 10.0,
			"cultivation_xp_required": 100.0,
			"base_hp": 108.0,
			"base_spiritual_power": 55.0,
			"base_attack": 12.0,
			"base_defense": 6.0,
			"base_speed": 1.1,
			"base_luck": 1.0,
			"sp": 48.0,
			"sp_max": 55.0,
			"spirit_stones": 66,
			"high_grade_stones": 0,
			"equipped_items": {
				"weapon": null,
				"armor": null,
				"accessory_1": null,
				"accessory_2": null,
				"talisman": null,
			},
			"inventory": [],
			"unlocked_skills": [],
			"equipped_skills": [],
			"skill_slots": 2,
		},
		"run_state": {
			"current_dungeon_id": "legacy_run",
			"current_floor": 1,
			"current_room": 2,
			"run_spirit_stones": 4,
			"run_items": [],
			"is_run_active": true,
		},
		"game_state": GameManager.GameState.PAUSED,
	})

	var runner := scene_runner(MAIN_MENU_PATH)
	get_tree().current_scene = runner.scene()

	var continue_button := runner.find_child("ContinueButton") as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.disabled).is_false()

	runner.invoke("_on_continue")

	var main_scene := await _await_current_scene(MAIN_SCENE_PATH)
	assert_object(main_scene).is_not_null()
	assert_int(PlayerData.spiritual_root).is_equal(PlayerData.SpiritualRoot.WATER)
	assert_int(PlayerData.spirit_stones).is_equal(66)
	assert_bool(GameManager.is_run_active).is_true()
	assert_int(GameManager.current_floor).is_equal(1)
	assert_int(GameManager.current_room).is_equal(2)
	assert_int(GameManager.current_state).is_equal(GameManager.GameState.DUNGEON_RUN)
	assert_int(RunStats.rooms_cleared).is_equal(0)
	assert_array(BoonDatabase.acquired_boons).is_empty()
	assert_bool(GameManager.run_layout.has("treasure_rooms")).is_true()

	var hud := main_scene.find_child("HUD", true, false)
	assert_object(hud).is_not_null()
	assert_str(hud.room_label.text).is_equal("第 2/5 间")
	assert_str(hud.stones_label.text).is_equal("灵石: 66")

func test_continue_with_corrupted_save_stays_on_menu_and_shows_error() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string("{invalid json")
	file.close()

	var runner := scene_runner(MAIN_MENU_PATH)
	get_tree().current_scene = runner.scene()

	var continue_button := runner.find_child("ContinueButton") as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.disabled).is_false()

	runner.invoke("_on_continue")
	await await_idle_frame()

	var current_scene := get_tree().current_scene
	assert_object(current_scene).is_not_null()
	assert_str(current_scene.scene_file_path).is_equal(MAIN_MENU_PATH)
	assert_str(GameManager.get_last_load_error()).contains("存档")

	var status_label := runner.find_child("StatusLabel") as Label
	assert_object(status_label).is_not_null()
	assert_bool(status_label.visible).is_true()
	assert_str(status_label.text).contains("存档")

func _await_current_scene(scene_path: String) -> Node:
	for _i in range(MAX_SCENE_WAIT_FRAMES):
		await await_idle_frame()
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == scene_path:
			return scene

	push_error("Timed out waiting for scene %s" % scene_path)
	return null

func _write_test_save(data: Dictionary) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(_globalize_test_path(TEST_SAVE_PATH))

func _globalize_test_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path
