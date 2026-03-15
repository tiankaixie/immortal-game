extends Node3D
## CharacterModel — Utility for loading glTF models and providing
## backward-compatible mesh/animation access.
## Uses GLTFDocument API to load at runtime (no editor import needed).

## Map of character type → glTF resource path
const MODEL_PATHS: Dictionary = {
	"player": "res://assets/kaykit/adventurers/Knight.glb",
	"enemy": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
	"swarm": "res://assets/kaykit/skeletons/Skeleton_Minion.glb",
	"ranged": "res://assets/kaykit/skeletons/Skeleton_Mage.glb",
	"tank": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
	"elite": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
	"boss": "res://assets/kaykit/adventurers/Barbarian.glb",
	"tribulation": "res://assets/kaykit/adventurers/Barbarian.glb",
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

## Load and instantiate a glTF model by type key.
func load_model(model_type: String, model_scale: float = 1.0) -> Node3D:
	var path: String = MODEL_PATHS.get(model_type, "")
	if path == "":
		push_warning("[CharacterModel] No model path for type: %s" % model_type)
		return self

	# Try standard resource loading first (works if editor has imported the file)
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			_model_root = scene.instantiate() as Node3D
			if _model_root:
				_model_root.scale = Vector3(model_scale, model_scale, model_scale)
				add_child(_model_root)
				_find_nodes(_model_root)
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

	_model_root.scale = Vector3(model_scale, model_scale, model_scale)
	add_child(_model_root)

	# Find key nodes in the glTF tree
	_find_nodes(_model_root)

	if anim_player:
		var anim_list := anim_player.get_animation_list()
		print("[CharacterModel] %s animations: %s" % [model_type, str(anim_list)])
		play("Idle")

	print("[CharacterModel] Loaded %s via GLTFDocument" % model_type)
	return self

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
	var resolved := _resolve_anim(anim_name)
	if resolved != "" and anim_player:
		anim_player.play(resolved, crossfade)

## Check if an animation exists (including ANIM_MAP alternatives).
func has_animation(anim_name: String) -> bool:
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
