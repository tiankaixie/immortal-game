extends Node3D
## CharacterModel — Utility for loading glTF models and providing
## backward-compatible mesh/animation access.
## Uses GLTFDocument API to load at runtime (no editor import needed).

## Map of character type → resource path.
## Current defaults use the latest user-downloaded semi-realistic FBX characters.
const MODEL_PATHS: Dictionary = {
	"player": "res://assets/external/ren/blender/Ren-fixed.glb",
	"enemy": "res://assets/external/downloads/lizard-man-warrior/blender/LizardManWarrior1.glb",
	"swarm": "res://assets/external/downloads/lizard-man-warrior/blender/LizardManWarrior1.glb",
	"ranged": "res://assets/external/downloads/stella/blender/Stella.glb",
	"tank": "res://assets/external/downloads/sett/blender/Sett.glb",
	"elite": "res://assets/external/downloads/leocetus-leader/blender/LeocetusLeader.glb",
	"boss": "res://assets/external/downloads/leocetus-leader/blender/LeocetusLeader.glb",
	"tribulation": "res://assets/external/downloads/sett/blender/Sett.glb",
}

const MODEL_SCALE_MULTIPLIERS: Dictionary = {
	"player": 1.0,
	"enemy": 0.62,
	"swarm": 0.42,
	"ranged": 0.54,
	"tank": 0.48,
	"elite": 0.56,
	"boss": 0.64,
	"tribulation": 0.62,
}

const MODEL_HEIGHT_OFFSETS: Dictionary = {
	"enemy": -0.26,
	"swarm": -0.14,
	"ranged": -0.3,
	"tank": -0.36,
	"elite": -0.34,
	"boss": -0.44,
	"tribulation": -0.5,
}

## Animation name mapping — KayKit models use different names than our game.
## Each game anim name maps to a list of possible KayKit alternatives (tried in order).
const ANIM_MAP: Dictionary = {
	"Idle": ["Idle", "Idle_Combat", "Unarmed_Idle"],
	"Walk": ["Walking_A", "Walking_B", "Walking_C", "Walk"],
	"Run": ["Running_A", "Running_B", "Running_C", "Run"],
	"Jump": ["Jump_Full_Short", "Jump_Full_Long", "Jump_Start", "Dodge_Forward"],
	"Death": ["Death_A", "Death_B", "Death_C_Skeletons"],
	"Punch": ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Stab", "Unarmed_Melee_Attack_Punch_A"],
	"HitReact": ["Hit_A", "Hit_B", "Block_Hit"],
	"Weapon": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Spin", "Dualwield_Melee_Attack_Chop"],
}

var mesh_instance: MeshInstance3D = null
var anim_player: AnimationPlayer = null
var _model_root: Node3D = null
var facing_yaw_offset: float = 0.0
var _loaded_model_type: String = ""
var _section_clips: Dictionary = {}
var _section_active: bool = false
var _section_start: float = 0.0
var _section_end: float = 0.0
var _section_loop: bool = false
var _section_source: String = ""
var _procedural_player_anim_enabled: bool = false
var _procedural_anim_name: String = "Idle"
var _procedural_anim_time: float = 0.0
var _procedural_action_name: String = ""
var _procedural_action_elapsed: float = 0.0
var _procedural_action_duration: float = 0.0
var _procedural_visual_root: Node3D = null
var _procedural_base_position: Vector3 = Vector3.ZERO
var _procedural_base_rotation: Vector3 = Vector3.ZERO
var _procedural_base_scale: Vector3 = Vector3.ONE

## Load and instantiate a glTF model by type key.
func load_model(model_type: String, model_scale: float = 1.0) -> Node3D:
	var path: String = MODEL_PATHS.get(model_type, "")
	if path == "":
		push_warning("[CharacterModel] No model path for type: %s" % model_type)
		return self

	_loaded_model_type = model_type
	facing_yaw_offset = PI if model_type == "player" else 0.0

	# Try standard resource loading first (works if editor has imported the file)
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			_model_root = scene.instantiate() as Node3D
			if _model_root:
				_apply_model_fixes(model_type)
				var effective_scale := _get_effective_model_scale(model_type, model_scale)
				_model_root.scale = Vector3.ONE * effective_scale
				add_child(_model_root)
				_find_nodes(_model_root)
				_configure_animation_support(model_type)
				if anim_player:
					var anim_list := anim_player.get_animation_list()
					print("[CharacterModel] %s animations: %s" % [model_type, str(anim_list)])
					play("Idle")
				print("[CharacterModel] Loaded %s via resource" % model_type)
				return self

	# Fallback: use GLTFDocument runtime loading
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path) and not FileAccess.file_exists(path):
		push_warning("[CharacterModel] File not found: %s" % path)
		return self

	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var err: int = gltf_doc.append_from_file(abs_path, gltf_state)
	if err != OK:
		push_warning("[CharacterModel] GLTFDocument failed for %s: error %d" % [model_type, err])
		return self

	_model_root = gltf_doc.generate_scene(gltf_state) as Node3D
	if _model_root == null:
		push_warning("[CharacterModel] Failed to generate scene: %s" % model_type)
		return self

	_apply_model_fixes(model_type)
	var effective_scale := _get_effective_model_scale(model_type, model_scale)
	_model_root.scale = Vector3.ONE * effective_scale
	add_child(_model_root)

	# Find key nodes in the glTF tree
	_find_nodes(_model_root)
	_configure_animation_support(model_type)

	if anim_player:
		var anim_list := anim_player.get_animation_list()
		print("[CharacterModel] %s animations: %s" % [model_type, str(anim_list)])
		play("Idle")

	print("[CharacterModel] Loaded %s via GLTFDocument" % model_type)
	return self

func _apply_model_fixes(model_type: String) -> void:
	if _model_root == null:
		return

	_model_root.position.y = float(MODEL_HEIGHT_OFFSETS.get(model_type, 0.0))

	if model_type == "player" and MODEL_PATHS.get(model_type, "").ends_with("Ren-fixed.glb"):
		facing_yaw_offset = 0.0
	elif model_type == "player" and MODEL_PATHS.get(model_type, "").ends_with("Ren-1.fbx"):
		var imported_root := _model_root.get_node_or_null("RootNode2") as Node3D
		if imported_root != null:
			imported_root.rotation_degrees = Vector3(180.0, 0.0, 0.0)
		# Ren's authored forward points 90 degrees off from our gameplay-facing convention.
		facing_yaw_offset = -PI * 0.5

		var preview_camera := _model_root.get_node_or_null("Preview_Camera")
		if preview_camera != null:
			if preview_camera is Node3D:
				preview_camera.visible = false

func _get_effective_model_scale(model_type: String, base_scale: float) -> float:
	return base_scale * float(MODEL_SCALE_MULTIPLIERS.get(model_type, 1.0))

func _configure_animation_support(model_type: String) -> void:
	_section_clips.clear()
	_section_active = false
	_section_start = 0.0
	_section_end = 0.0
	_section_loop = false
	_section_source = ""
	_procedural_player_anim_enabled = false
	_procedural_anim_name = "Idle"
	_procedural_anim_time = 0.0
	_procedural_action_name = ""
	_procedural_action_elapsed = 0.0
	_procedural_action_duration = 0.0
	_procedural_visual_root = null
	set_process(false)

	if _model_root == null:
		return

	var required_anims: Array[String] = ["Idle", "Walk", "Run", "Punch", "Weapon", "HitReact", "Death"]
	var has_full_gameplay_set := true
	for anim_name in required_anims:
		if _resolve_anim(anim_name) == "":
			has_full_gameplay_set = false
			break

	if has_full_gameplay_set:
		return

	if model_type == "player" and MODEL_PATHS.get(model_type, "").ends_with("Ren-fixed.glb") and anim_player != null and anim_player.has_animation("RootNode|FBXExportClip_0"):
		# Blender re-export normalizes the source FBX into an upright glTF track, so these slices are
		# now safe to use as gameplay actions.
		_section_clips = {
			"Idle": {"source": "RootNode|FBXExportClip_0", "start": 1.39, "end": 3.3, "loop": true, "speed": 1.0},
			"Walk": {"source": "RootNode|FBXExportClip_0", "start": 3.42, "end": 4.19, "loop": true, "speed": 0.82},
			"Run": {"source": "RootNode|FBXExportClip_0", "start": 3.42, "end": 4.19, "loop": true, "speed": 1.0},
			"Jump": {"source": "RootNode|FBXExportClip_0", "start": 88.0, "end": 92.8, "loop": false, "speed": 1.0},
			"Punch": {"source": "RootNode|FBXExportClip_0", "start": 14.97, "end": 17.27, "loop": false, "speed": 1.0},
			"Weapon": {"source": "RootNode|FBXExportClip_0", "start": 14.97, "end": 17.27, "loop": false, "speed": 1.05},
			"HitReact": {"source": "RootNode|FBXExportClip_0", "start": 54.0, "end": 54.4, "loop": false, "speed": 1.0},
			"Death": {"source": "RootNode|FBXExportClip_0", "start": 83.0, "end": 87.4, "loop": false, "speed": 0.9},
		}
		set_process(true)
		return

	if model_type == "player" and MODEL_PATHS.get(model_type, "").ends_with("Ren-1.fbx") and anim_player != null and anim_player.has_animation("FBXExportClip_0"):
		# Keep the original FBX around as fallback source data only.
		_section_clips = {}

	# These imported FBX models generally only expose a single baked clip, so drive them with
	# lightweight procedural posing until we plug in dedicated split animation sets.
	_procedural_visual_root = _resolve_procedural_visual_root()
	if _procedural_visual_root == null:
		_procedural_visual_root = _model_root

	_procedural_base_position = _procedural_visual_root.position
	_procedural_base_rotation = _procedural_visual_root.rotation
	_procedural_base_scale = _procedural_visual_root.scale
	_procedural_player_anim_enabled = true

	if anim_player != null:
		anim_player.stop()

	set_process(true)

func _find_nodes(node: Node) -> void:
	if node is MeshInstance3D and mesh_instance == null:
		mesh_instance = node
	if node is AnimationPlayer and anim_player == null:
		anim_player = node
	for child in node.get_children():
		_find_nodes(child)

## Resolve an animation name through ANIM_MAP fallback.
func _resolve_anim(anim_name: String) -> String:
	if anim_player == null:
		return anim_name
	if anim_player.has_animation(anim_name):
		return anim_name
	# Try ANIM_MAP alternatives
	if ANIM_MAP.has(anim_name):
		for alt: String in ANIM_MAP[anim_name]:
			if anim_player.has_animation(alt):
				return alt
	return ""

## Play an animation by name with optional crossfade.
func play(anim_name: String, crossfade: float = 0.2) -> void:
	if _section_clips.has(anim_name):
		_play_section_clip(anim_name, crossfade)
		return

	if _procedural_player_anim_enabled and _is_procedural_anim(anim_name):
		_set_procedural_anim(anim_name)
		return

	var resolved := _resolve_anim(anim_name)
	if resolved != "" and anim_player:
		anim_player.play(resolved, crossfade)

## Check if an animation exists (including ANIM_MAP alternatives).
func has_animation(anim_name: String) -> bool:
	if _section_clips.has(anim_name):
		return true
	if _procedural_player_anim_enabled and _is_procedural_anim(anim_name):
		return true
	return _resolve_anim(anim_name) != ""

## Get surface override material (backward compat with old mesh usage).
func get_surface_override_material(index: int) -> Material:
	if mesh_instance:
		return mesh_instance.get_surface_override_material(index)
	return null

## Set surface override material.
func set_surface_override_material(index: int, mat: Material) -> void:
	if mesh_instance:
		mesh_instance.set_surface_override_material(index, mat)

func _process(delta: float) -> void:
	if _section_active and anim_player != null:
		var current_pos: float = anim_player.current_animation_position
		if current_pos >= _section_end - 0.01:
			if _section_loop:
				anim_player.seek(_section_start, true)
			else:
				anim_player.pause()
				anim_player.seek(_section_end, true)
				_section_active = false

	if not _procedural_player_anim_enabled or _procedural_visual_root == null:
		return

	_procedural_anim_time += delta
	var pose_position := _procedural_base_position
	var pose_rotation := _procedural_base_rotation
	var pose_scale := _procedural_base_scale

	match _procedural_anim_name:
		"Idle":
			pose_position.y += sin(_procedural_anim_time * 2.4) * 0.04
			pose_rotation.z += sin(_procedural_anim_time * 1.8) * 0.045
			pose_rotation.x += cos(_procedural_anim_time * 1.2) * 0.025
		"Walk":
			pose_position.y += abs(sin(_procedural_anim_time * 6.5)) * 0.16
			pose_position.z += cos(_procedural_anim_time * 6.5) * 0.035
			pose_rotation.x += 0.12 + abs(cos(_procedural_anim_time * 6.5)) * 0.14
			pose_rotation.z += sin(_procedural_anim_time * 6.5) * 0.14
		"Run":
			pose_position.y += abs(sin(_procedural_anim_time * 10.5)) * 0.24
			pose_position.z += cos(_procedural_anim_time * 10.5) * 0.06
			pose_rotation.x += 0.2 + abs(cos(_procedural_anim_time * 10.5)) * 0.22
			pose_rotation.z += sin(_procedural_anim_time * 10.5) * 0.22
			pose_scale.y += abs(sin(_procedural_anim_time * 10.5)) * 0.05
		"Jump":
			pose_position.y += sin(min(_procedural_anim_time * 10.0, PI)) * 0.18
			pose_rotation.x -= 0.18
		"Death":
			pose_position.y -= 0.9
			pose_rotation.z -= 1.3
			pose_rotation.x += 0.15

	if _procedural_action_duration > 0.0:
		_procedural_action_elapsed = min(_procedural_action_elapsed + delta, _procedural_action_duration)
		var t := _procedural_action_elapsed / _procedural_action_duration
		var pulse := sin(t * PI)
		match _procedural_action_name:
			"Punch":
				pose_position.z -= pulse * 0.42
				pose_position.y += sin(t * PI) * 0.08
				pose_rotation.x -= pulse * 0.7
				pose_rotation.y += pulse * 0.28
				pose_rotation.z += sin(t * TAU) * 0.12
				pose_scale.z += pulse * 0.08
			"Weapon":
				pose_position.z -= pulse * 0.6
				pose_position.y += sin(t * PI) * 0.12
				pose_rotation.x -= pulse * 0.95
				pose_rotation.y += pulse * 0.42
				pose_rotation.z += sin(t * TAU) * 0.18
				pose_scale.z += pulse * 0.12
				pose_scale.x -= pulse * 0.04
			"HitReact":
				pose_position.z += pulse * 0.28
				pose_rotation.x += pulse * 0.36
				pose_rotation.z += sin(t * TAU) * 0.1

		if _procedural_action_elapsed >= _procedural_action_duration:
			_procedural_action_name = ""
			_procedural_action_duration = 0.0
			_procedural_action_elapsed = 0.0

	_procedural_visual_root.position = pose_position
	_procedural_visual_root.rotation = pose_rotation
	_procedural_visual_root.scale = pose_scale

func _is_procedural_anim(anim_name: String) -> bool:
	return anim_name in ["Idle", "Walk", "Run", "Jump", "Punch", "Weapon", "HitReact", "Death"]

func _set_procedural_anim(anim_name: String) -> void:
	if _procedural_visual_root == null:
		return

	match anim_name:
		"Punch":
			_procedural_anim_name = "Idle"
			_procedural_action_name = "Punch"
			_procedural_action_duration = 0.3
			_procedural_action_elapsed = 0.0
		"Weapon":
			_procedural_anim_name = "Idle"
			_procedural_action_name = "Weapon"
			_procedural_action_duration = 0.42
			_procedural_action_elapsed = 0.0
		"HitReact":
			_procedural_anim_name = "Idle"
			_procedural_action_name = "HitReact"
			_procedural_action_duration = 0.28
			_procedural_action_elapsed = 0.0
		"Death":
			_procedural_anim_name = "Death"
			_procedural_action_name = ""
			_procedural_action_duration = 0.0
			_procedural_action_elapsed = 0.0
		_:
			_procedural_anim_name = anim_name

func _resolve_procedural_visual_root() -> Node3D:
	if _model_root == null:
		return null

	var preferred_nodes := [
		"RootNode2",
		"RootNode",
		"RL_BoneRoot",
		"b_root",
		"Bip001",
		"bip001",
		"Sett",
		"LizardManWarrior",
	]
	for node_name in preferred_nodes:
		var candidate := _model_root.find_child(node_name, true, false) as Node3D
		if candidate != null:
			return candidate
	return _model_root

func _play_section_clip(anim_name: String, crossfade: float) -> void:
	if anim_player == null:
		return

	var clip: Dictionary = _section_clips.get(anim_name, {})
	if clip.is_empty():
		return

	_section_source = clip.get("source", "")
	_section_start = float(clip.get("start", 0.0))
	_section_end = float(clip.get("end", _section_start))
	_section_loop = bool(clip.get("loop", false))
	_section_active = true

	var clip_speed: float = float(clip.get("speed", 1.0))
	anim_player.play(_section_source, crossfade, clip_speed)
	anim_player.seek(_section_start, true)
