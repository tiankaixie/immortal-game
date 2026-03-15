extends Node
## DungeonAtmosphere — Adds atmospheric effects to dungeon rooms
##
## Auto-attaches to the current scene and provides:
## - WorldEnvironment (sky, fog, tonemap, SSAO, glow/bloom)
## - Ambient floating particles (spiritual dust)
## - Per-room-type lighting variations

# ─── Room Atmosphere Presets ──────────────────────────────────
const PRESETS: Dictionary = {
	"normal": {
		"fog_color": Color(0.08, 0.06, 0.12),
		"fog_density": 0.03,
		"ambient_color": Color(0.15, 0.12, 0.2),
		"ambient_energy": 0.4,
		"glow_intensity": 0.6,
		"particle_color": Color(0.4, 0.3, 0.6, 0.4),
	},
	"boss": {
		"fog_color": Color(0.15, 0.04, 0.04),
		"fog_density": 0.04,
		"ambient_color": Color(0.25, 0.1, 0.1),
		"ambient_energy": 0.3,
		"glow_intensity": 0.8,
		"particle_color": Color(0.8, 0.2, 0.1, 0.5),
	},
	"treasure": {
		"fog_color": Color(0.1, 0.08, 0.02),
		"fog_density": 0.02,
		"ambient_color": Color(0.3, 0.25, 0.1),
		"ambient_energy": 0.5,
		"glow_intensity": 1.0,
		"particle_color": Color(1.0, 0.85, 0.3, 0.5),
	},
	"elite": {
		"fog_color": Color(0.05, 0.05, 0.15),
		"fog_density": 0.05,
		"ambient_color": Color(0.1, 0.1, 0.25),
		"ambient_energy": 0.3,
		"glow_intensity": 0.7,
		"particle_color": Color(0.3, 0.3, 0.9, 0.5),
	},
}

var world_env: WorldEnvironment = null
var dust_particles: GPUParticles3D = null
var torch_lights: Array[OmniLight3D] = []
var decorations: Array[Node3D] = []

# Decorative props to scatter around rooms (glb files from Kenney + KayKit dungeon)
const WALL_PROPS: Array[String] = [
	"res://assets/environments/banner.glb",
	"res://assets/environments/shield-round.glb",
	"res://assets/environments/wood-support.glb",
	"res://assets/kaykit/dungeon/banner_red.gltf.glb",
	"res://assets/kaykit/dungeon/banner_blue.gltf.glb",
	"res://assets/kaykit/dungeon/banner_shield_red.gltf.glb",
	"res://assets/kaykit/dungeon/sword_shield.gltf.glb",
	"res://assets/kaykit/dungeon/shelf_small_candles.gltf.glb",
	"res://assets/kaykit/dungeon/keyring_hanging.gltf.glb",
]
const CORNER_PROPS: Array[String] = [
	"res://assets/environments/barrel.glb",
	"res://assets/environments/rocks.glb",
	"res://assets/environments/stones.glb",
	"res://assets/environments/chest.glb",
	"res://assets/environments/wood-structure.glb",
	"res://assets/kaykit/dungeon/barrel_large.gltf.glb",
	"res://assets/kaykit/dungeon/barrel_small_stack.gltf.glb",
	"res://assets/kaykit/dungeon/keg.gltf.glb",
	"res://assets/kaykit/dungeon/crates_stacked.gltf.glb",
	"res://assets/kaykit/dungeon/box_stacked.gltf.glb",
	"res://assets/kaykit/dungeon/trunk_large_A.gltf.glb",
	"res://assets/kaykit/dungeon/rubble_large.gltf.glb",
	"res://assets/kaykit/dungeon/stool.gltf.glb",
	"res://assets/kaykit/dungeon/bed_floor.gltf.glb",
	"res://assets/kaykit/dungeon/candle_triple.gltf.glb",
]
const CENTER_PROPS: Array[String] = [
	"res://assets/environments/column.glb",
	"res://assets/kaykit/dungeon/column.gltf.glb",
	"res://assets/kaykit/dungeon/pillar.gltf.glb",
	"res://assets/kaykit/dungeon/pillar_decorated.gltf.glb",
	"res://assets/kaykit/dungeon/table_medium.gltf.glb",
	"res://assets/kaykit/dungeon/table_small.gltf.glb",
]

func setup(room_type: String = "normal", room_size: Vector2 = Vector2(20, 20)) -> void:
	"""Call this after room is loaded to add atmosphere."""
	var preset: Dictionary = PRESETS.get(room_type, PRESETS["normal"])
	_create_world_environment(preset)
	_create_ambient_particles(preset, room_size)
	_create_torch_lights(room_size)
	_enhance_existing_lights()
	_enhance_room_materials(preset)
	_place_decorations(room_size)

func _create_world_environment(preset: Dictionary) -> void:
	"""Add WorldEnvironment with sky, fog, bloom, SSAO, tonemap."""
	# Remove existing WorldEnvironment if any
	var existing := get_tree().current_scene.find_child("WorldEnvironment", true, false)
	if existing:
		existing.queue_free()

	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env := Environment.new()

	# Sky — dark procedural sky for underground dungeon feel
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.01, 0.05)
	sky_mat.sky_horizon_color = Color(0.06, 0.04, 0.1)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_mat.ground_horizon_color = Color(0.06, 0.04, 0.1)
	sky_mat.sky_energy_multiplier = 0.1
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Ambient light — soft fill from all directions
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset["ambient_color"]
	env.ambient_light_energy = preset["ambient_energy"]

	# Tonemap — filmic for richer contrast
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1

	# Fog — volumetric dungeon haze
	env.fog_enabled = true
	env.fog_light_color = preset["fog_color"]
	env.fog_density = preset["fog_density"]
	env.fog_aerial_perspective = 0.3

	# Glow / Bloom — makes emissive materials and particles pop
	env.glow_enabled = true
	env.glow_intensity = preset["glow_intensity"]
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# SSAO — subtle ambient occlusion for depth
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.5

	# SSR off (perf), SSIL off (perf)
	env.ssr_enabled = false
	env.ssil_enabled = false

	world_env.environment = env
	get_tree().current_scene.add_child(world_env)

func _create_ambient_particles(preset: Dictionary, room_size: Vector2) -> void:
	"""Floating spiritual dust particles across the room."""
	dust_particles = GPUParticles3D.new()
	dust_particles.name = "AmbientDust"

	var mat := ParticleProcessMaterial.new()
	mat.color = preset["particle_color"]

	# Emission: fill the room volume
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(room_size.x * 0.4, 3.0, room_size.y * 0.4)

	# Slow drifting motion
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.4
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0.05, 0)
	mat.damping_min = 0.5
	mat.damping_max = 1.0

	# Tiny glowing motes
	mat.scale_min = 0.03
	mat.scale_max = 0.08

	# Fade in and out
	mat.color_ramp = _create_fade_gradient(preset["particle_color"])

	dust_particles.process_material = mat
	dust_particles.amount = 200
	dust_particles.lifetime = 6.0
	dust_particles.explosiveness = 0.0  # Continuous emission
	dust_particles.one_shot = false
	dust_particles.position = Vector3(0, 2.0, 0)

	get_tree().current_scene.add_child(dust_particles)
	dust_particles.emitting = true

func _create_fade_gradient(base_color: Color) -> GradientTexture1D:
	"""Create a gradient texture that fades particles in and out."""
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	gradient.add_point(0.2, base_color)
	gradient.add_point(0.8, base_color)
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(base_color.r, base_color.g, base_color.b, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	return tex

func _create_torch_lights(room_size: Vector2) -> void:
	"""Add warm point lights along walls to simulate torches."""
	var half_x: float = room_size.x * 0.45
	var half_z: float = room_size.y * 0.45

	# Place torches at wall midpoints and corners
	var torch_positions: Array[Vector3] = [
		Vector3(-half_x, 3.0, 0),
		Vector3(half_x, 3.0, 0),
		Vector3(0, 3.0, -half_z),
		Vector3(0, 3.0, half_z),
		Vector3(-half_x, 3.0, -half_z),
		Vector3(half_x, 3.0, -half_z),
		Vector3(-half_x, 3.0, half_z),
		Vector3(half_x, 3.0, half_z),
	]

	for pos in torch_positions:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.3)  # Warm torch color
		light.light_energy = 1.2
		light.omni_range = 8.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = true
		light.position = pos
		get_tree().current_scene.add_child(light)
		torch_lights.append(light)

		# Add a small flame particle at each torch
		_create_flame_at(pos)

func _create_flame_at(pos: Vector3) -> void:
	"""Small flame particle effect at a torch position."""
	var flame := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()

	mat.color = Color(1.0, 0.6, 0.1, 0.8)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.gravity = Vector3(0, 0.5, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.damping_min = 1.0
	mat.damping_max = 2.0

	flame.process_material = mat
	flame.amount = 20
	flame.lifetime = 0.5
	flame.explosiveness = 0.0
	flame.one_shot = false
	flame.position = pos
	get_tree().current_scene.add_child(flame)
	flame.emitting = true

func _enhance_existing_lights() -> void:
	"""Boost existing DirectionalLight3D in the scene for better visibility."""
	_recursive_enhance_lights(get_tree().current_scene)

func _recursive_enhance_lights(node: Node) -> void:
	if node is DirectionalLight3D:
		node.light_energy = max(node.light_energy, 0.5)
		node.shadow_enabled = true
	for child in node.get_children():
		_recursive_enhance_lights(child)

func _enhance_room_materials(preset: Dictionary) -> void:
	"""Enhance floor/wall materials with roughness, metallic, and subtle emission."""
	_recursive_enhance_materials(get_tree().current_scene, preset)

func _recursive_enhance_materials(node: Node, preset: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		# Check override material first, then mesh surface material
		var mat: Material = mi.get_surface_override_material(0)
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var smat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
			var node_name_lower: String = node.name.to_lower()
			if "floor" in node_name_lower:
				smat.roughness = 0.85
				smat.metallic = 0.05
				# Subtle edge glow on floor
				smat.emission_enabled = true
				smat.emission = preset["ambient_color"] * 0.3
				smat.emission_energy_multiplier = 0.2
			elif "wall" in node_name_lower:
				smat.roughness = 0.7
				smat.metallic = 0.1
				smat.emission_enabled = true
				smat.emission = preset["ambient_color"] * 0.2
				smat.emission_energy_multiplier = 0.15
			elif "pillar" in node_name_lower or "column" in node_name_lower:
				smat.roughness = 0.6
				smat.metallic = 0.2
				smat.emission_enabled = true
				smat.emission = preset["ambient_color"] * 0.4
				smat.emission_energy_multiplier = 0.3
			mi.set_surface_override_material(0, smat)
	for child in node.get_children():
		_recursive_enhance_materials(child, preset)

func _place_decorations(room_size: Vector2) -> void:
	"""Scatter decorative props around the room edges and corners."""
	var half_x: float = room_size.x * 0.4
	var half_z: float = room_size.y * 0.4

	# Place corner props (barrels, rocks, etc.)
	var corners: Array[Vector3] = [
		Vector3(-half_x, 0, -half_z),
		Vector3(half_x, 0, -half_z),
		Vector3(-half_x, 0, half_z),
		Vector3(half_x, 0, half_z),
	]
	for corner in corners:
		if randf() < 0.7 and CORNER_PROPS.size() > 0:
			var prop_path: String = CORNER_PROPS[randi() % CORNER_PROPS.size()]
			_spawn_prop(prop_path, corner, randf() * TAU, 1.5)

	# Place wall props along walls
	var wall_spots: Array[Vector3] = [
		Vector3(-half_x, 0, randf_range(-half_z * 0.5, half_z * 0.5)),
		Vector3(half_x, 0, randf_range(-half_z * 0.5, half_z * 0.5)),
		Vector3(randf_range(-half_x * 0.5, half_x * 0.5), 0, -half_z),
		Vector3(randf_range(-half_x * 0.5, half_x * 0.5), 0, half_z),
	]
	for spot in wall_spots:
		if randf() < 0.5 and WALL_PROPS.size() > 0:
			var prop_path: String = WALL_PROPS[randi() % WALL_PROPS.size()]
			_spawn_prop(prop_path, spot, randf() * TAU, 1.2)

	# Place 1-2 columns near center area (but not blocking center)
	for _i in range(randi_range(1, 2)):
		if CENTER_PROPS.size() > 0:
			var prop_idx: int = randi() % CENTER_PROPS.size()
			var offset := Vector3(
				randf_range(-half_x * 0.3, half_x * 0.3),
				0,
				randf_range(-half_z * 0.3, half_z * 0.3)
			)
			# Don't place too close to center (player spawn)
			if offset.length() > 3.0:
				_spawn_prop(CENTER_PROPS[prop_idx], offset, 0.0, 2.0)

func _spawn_prop(path: String, pos: Vector3, rot_y: float, prop_scale: float) -> void:
	"""Load a .glb prop and place it in the scene."""
	var scene: Node = null

	# Try standard resource loading first (works for imported .glb files)
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed:
			scene = packed.instantiate()

	# Fallback: GLTFDocument runtime loading (fresh instance each time)
	if scene == null:
		var abs_path: String = ProjectSettings.globalize_path(path)
		var gltf_doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err: int = gltf_doc.append_from_file(abs_path, state)
		if err != OK:
			return
		scene = gltf_doc.generate_scene(state)

	if scene == null:
		return
	var wrapper := Node3D.new()
	wrapper.add_child(scene)
	wrapper.position = pos
	wrapper.rotation.y = rot_y
	wrapper.scale = Vector3.ONE * prop_scale
	get_tree().current_scene.add_child(wrapper)
	decorations.append(wrapper)

func cleanup() -> void:
	"""Remove all atmosphere elements."""
	if world_env and is_instance_valid(world_env):
		world_env.queue_free()
	if dust_particles and is_instance_valid(dust_particles):
		dust_particles.queue_free()
	for light in torch_lights:
		if is_instance_valid(light):
			light.queue_free()
	torch_lights.clear()
	for deco in decorations:
		if is_instance_valid(deco):
			deco.queue_free()
	decorations.clear()
