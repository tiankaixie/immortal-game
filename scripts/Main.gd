extends Node3D
## Main — Top-level game scene
##
## Wires together the TestRoom, Player, HUD, DungeonController,
## and WorldEnvironment. Sets up initial game state.

@onready var hud: CanvasLayer = $HUD
@onready var test_room: Node3D = $TestRoom

var dungeon_controller: Node = null
const DamageNumberScene = preload("res://scenes/ui/DamageNumber.tscn")
const SkillVFXScene = preload("res://scenes/vfx/SkillVFX.tscn")

# Track last skill used for VFX element lookup
var _last_skill_element: String = ""

func _ready() -> void:
	# Load saved settings (audio, display, gameplay)
	var SettingsPanel := load("res://scripts/ui/SettingsPanel.gd")
	if SettingsPanel and SettingsPanel.has_method("load_settings_on_startup"):
		SettingsPanel.load_settings_on_startup()

	# Set game state
	GameManager.change_state(GameManager.GameState.DUNGEON_RUN)

	# Reset run stats for fresh run
	RunStats.reset()

	# Reset boon state for fresh run
	BoonDatabase.reset_run()

	# Add DungeonController
	_setup_dungeon_controller()

	# Setup world environment and lighting
	_setup_world_environment()

	# Find player and connect to HUD
	var player := test_room.get_node("Player")
	if player:
		player.add_to_group("player")
		hud.connect_to_player(player)

		# Register enemies with CombatSystem
		var enemies: Array[Node] = []
		for child in test_room.get_children():
			if child.has_method("take_damage") and child != player:
				enemies.append(child)

		if enemies.size() > 0:
			CombatSystem.start_combat(player, enemies)

	# 连接伤害信号，生成浮动伤害数字 + VFX
	CombatSystem.damage_dealt.connect(_on_damage_dealt)
	CombatSystem.skill_used.connect(_on_skill_used_for_vfx)

	print("[Main] Scene ready — %d enemies spawned" % test_room.get_children().filter(
		func(c): return c.has_method("take_damage") and c.name != "Player"
	).size())

func _setup_dungeon_controller() -> void:
	"""Create and add the DungeonController node."""
	var dc_script := load("res://scripts/dungeon/DungeonController.gd")
	if dc_script:
		dungeon_controller = Node.new()
		dungeon_controller.name = "DungeonController"
		dungeon_controller.set_script(dc_script)
		add_child(dungeon_controller)

		# Connect room number changes to HUD
		if dungeon_controller.has_signal("room_number_changed"):
			dungeon_controller.room_number_changed.connect(_on_room_number_changed)
		if dungeon_controller.has_signal("room_type_changed"):
			dungeon_controller.room_type_changed.connect(_on_room_type_changed)

		print("[Main] DungeonController added")

func _on_room_number_changed(room: int, total: int) -> void:
	"""Update HUD with current room number."""
	if hud and hud.has_method("update_room_display"):
		hud.update_room_display(room, total)

func _on_room_type_changed(room_type: int, room_type_name: String) -> void:
	"""Update HUD with current room type."""
	if hud and hud.has_method("update_room_type_display"):
		hud.update_room_type_display(room_type_name)

func _setup_world_environment() -> void:
	"""Create a mystical xianxia atmosphere with procedural sky and lighting."""
	# WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()

	# Procedural sky — purple/blue celestial gradient
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.05, 0.25)      # Deep purple
	sky_material.sky_horizon_color = Color(0.25, 0.15, 0.45)   # Lighter purple
	sky_material.ground_bottom_color = Color(0.05, 0.03, 0.1)  # Dark ground
	sky_material.ground_horizon_color = Color(0.15, 0.1, 0.3)  # Purple horizon
	sky_material.sky_energy_multiplier = 0.6
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Ambient light — cool mystical purple tone
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.25, 0.55)
	env.ambient_light_energy = 0.4

	# Tonemap for richer colors
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0

	# Glow for mystical feel
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Fog for depth
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.15, 0.35)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.3

	world_env.environment = env
	add_child(world_env)

	# DirectionalLight3D — sun casting shadows at an angle
	var dir_light := DirectionalLight3D.new()
	dir_light.name = "SunLight"
	dir_light.light_color = Color(0.9, 0.8, 0.95)  # Slightly purple-white
	dir_light.light_energy = 0.8
	dir_light.shadow_enabled = true
	dir_light.shadow_bias = 0.05
	# Angle: rotate to cast diagonal shadows (pitch down ~50°, yaw ~30°)
	dir_light.rotation_degrees = Vector3(-50, 30, 0)
	dir_light.directional_shadow_max_distance = 60.0
	add_child(dir_light)

	# Secondary fill light — opposite direction, softer
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color(0.4, 0.3, 0.7)  # Purple fill
	fill_light.light_energy = 0.25
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-30, -150, 0)
	add_child(fill_light)

	print("[Main] WorldEnvironment + lighting configured")

# ─── Skill VFX Tracking ──────────────────────────────────────
func _on_skill_used_for_vfx(skill_id: String) -> void:
	"""Track last used skill element for VFX spawning."""
	var skill := SkillDatabase.get_skill(skill_id)
	if not skill.is_empty():
		_last_skill_element = skill.get("element", "")
	# Auto-clear after a short delay (so basic attacks don't inherit element)
	get_tree().create_timer(0.5).timeout.connect(func(): _last_skill_element = "")

# ─── Floating Damage Numbers ─────────────────────────────────
func _on_damage_dealt(target: Node, amount: float, is_critical: bool) -> void:
	"""Spawn a floating damage number and VFX at the target's position."""
	if target == null or not is_instance_valid(target):
		return

	var dmg_num := DamageNumberScene.instantiate()
	# 在目标头顶上方生成
	var spawn_pos: Vector3 = target.global_position + Vector3(0, 1.8, 0)
	add_child(dmg_num)
	dmg_num.global_position = spawn_pos
	dmg_num.setup(amount, is_critical)

	# Spawn skill VFX if a skill was recently used
	if _last_skill_element != "":
		_spawn_skill_vfx(target.global_position + Vector3(0, 1.0, 0), _last_skill_element)

func _spawn_skill_vfx(pos: Vector3, element: String) -> void:
	"""Instantiate a SkillVFX at the given position with the given element."""
	var vfx := SkillVFXScene.instantiate()
	vfx.element = element
	add_child(vfx)
	vfx.global_position = pos
