extends Node

const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const SPIRIT_ROOT_SELECTION_PATH := "res://scenes/ui/SpiritRootSelection.tscn"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const MAX_SCENE_WAIT_FRAMES := 120

func _ready() -> void:
	if self == get_tree().current_scene:
		call_deferred("_bootstrap")

func _bootstrap() -> void:
	get_tree().current_scene = null
	call_deferred("_run")

func _run() -> void:
	print("[Smoke] Starting main flow smoke test")

	var menu := await _change_to_scene(MAIN_MENU_PATH)
	var new_game_btn := menu.get_node_or_null("VBoxContainer/NewGameButton") as Button
	if new_game_btn == null:
		_fail("Main menu is missing VBoxContainer/NewGameButton")
		return

	print("[Smoke] Main menu loaded")
	new_game_btn.emit_signal("pressed")

	var root_selection := await _wait_for_scene(SPIRIT_ROOT_SELECTION_PATH)
	if root_selection == null:
		return

	print("[Smoke] Spirit root selection loaded")
	root_selection._select_card(0)
	root_selection._on_confirm()

	var main_scene := await _wait_for_scene(MAIN_SCENE_PATH)
	if main_scene == null:
		return

	if PlayerData.spiritual_root != PlayerData.SpiritualRoot.METAL:
		_fail("Expected PlayerData.spiritual_root to be METAL after selecting the first root")
		return

	print("[Smoke] Main gameplay scene loaded")
	print("[Smoke] PASS")
	get_tree().quit(0)

func _change_to_scene(scene_path: String) -> Node:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		_fail("Failed to change scene to %s (error %d)" % [scene_path, err])
		return null
	return await _wait_for_scene(scene_path)

func _wait_for_scene(scene_path: String) -> Node:
	for _i in range(MAX_SCENE_WAIT_FRAMES):
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == scene_path:
			return scene

	_fail("Timed out waiting for scene %s" % scene_path)
	return null

func _fail(message: String) -> void:
	push_error("[Smoke] FAIL: %s" % message)
	get_tree().quit(1)
