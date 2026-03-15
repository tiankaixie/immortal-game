extends Node3D
## CharacterModel — Utility for loading glTF models and providing
## backward-compatible mesh/animation access.
## Uses GLTFDocument API to load at runtime (no editor import needed).

## Map of character type → glTF resource path
const MODEL_PATHS: Dictionary = {
	"player": "res://assets/characters/Ninja.gltf",
	"enemy": "res://assets/characters/Demon.gltf",
	"swarm": "res://assets/characters/Frog.gltf",
	"ranged": "res://assets/characters/Alien.gltf",
	"tank": "res://assets/characters/Orc.gltf",
	"elite": "res://assets/characters/BlueDemon.gltf",
	"boss": "res://assets/characters/Dino.gltf",
	"tribulation": "res://assets/characters/MushroomKing.gltf",
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

## Play an animation by name with optional crossfade.
func play(anim_name: String, crossfade: float = 0.2) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name, crossfade)

## Check if an animation exists.
func has_animation(anim_name: String) -> bool:
	return anim_player != null and anim_player.has_animation(anim_name)

## Get surface override material (backward compat with old mesh usage).
func get_surface_override_material(index: int) -> Material:
	if mesh_instance:
		return mesh_instance.get_surface_override_material(index)
	return null

## Set surface override material.
func set_surface_override_material(index: int, mat: Material) -> void:
	if mesh_instance:
		mesh_instance.set_surface_override_material(index, mat)
