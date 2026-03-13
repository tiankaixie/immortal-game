extends Control
## DeathScreen — Shown when the player dies (HP <= 0)
##
## Displays run statistics, realm info, and offers restart/menu options.
## All UI is generated in code — no external assets required.
## Features atmospheric particle effects and historical run records.

const SPIRIT_ROOT_SELECTION_PATH: String = "res://scenes/ui/SpiritRootSelection.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"
const UNLOCK_NOTIFICATION_PATH: String = "res://scenes/ui/UnlockNotification.tscn"

# Realm name mapping
const REALM_NAMES: Array[String] = [
	"练气", "筑基", "结丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"
]
const STAGE_NAMES: Array[String] = [
	"初期", "中期", "后期", "圆满"
]

# Spirit root colors
const SPIRIT_ROOT_COLORS: Dictionary = {
	0: Color(0.75, 0.75, 1.0),   # METAL — 金
	1: Color(0.27, 0.80, 0.27),  # WOOD — 木
	2: Color(0.27, 0.53, 1.0),   # WATER — 水
	3: Color(1.0,  0.40, 0.20),  # FIRE — 火
	4: Color(0.67, 0.53, 0.27),  # EARTH — 土
	5: Color(0.6,  0.4,  1.0),   # LIGHTNING — 雷
	6: Color(0.667, 0.733, 0.8), # VOID — 虚
}

const SPIRIT_ROOT_NAMES: Array[String] = ["金", "木", "水", "火", "土", "雷", "虚"]

var _accent_color: Color = Color(0.75, 0.75, 1.0)
var _run_duration: float = 0.0

func _ready() -> void:
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Get accent color from spirit root
	_accent_color = SPIRIT_ROOT_COLORS.get(PlayerData.spiritual_root, Color(0.75, 0.75, 1.0))

	# Calculate run duration before saving
	_run_duration = Time.get_unix_time_from_system() - RunStats.run_start_time
	if _run_duration < 0:
		_run_duration = 0

	# Save current run to history and check unlocks
	_save_current_run()

	_build_ui()
	_spawn_particles()
	_check_unlocks()

func _save_current_run() -> void:
	"""Save the current run data to RunHistory."""
	var floor_num: int = GameManager.current_room
	if floor_num <= 0:
		floor_num = 1
	var run_data := {
		"spiritual_root": PlayerData.spiritual_root,
		"realm": PlayerData.cultivation_realm,
		"stage": PlayerData.cultivation_stage,
		"rooms_cleared": RunStats.rooms_cleared,
		"kills": RunStats.enemies_killed,
		"spirit_stones": RunStats.spirit_stones_collected,
		"damage_dealt": RunStats.damage_dealt_total,
		"duration_seconds": int(_run_duration),
		"cause_of_death_room": floor_num,
	}
	RunHistory.save_run(run_data)
	UnlockSystem.record_run(run_data)

func _check_unlocks() -> void:
	"""Check for new unlocks and show notification if any."""
	var new_unlocks := UnlockSystem.check_new_unlocks()
	if new_unlocks.size() > 0:
		var notif_scene := load(UNLOCK_NOTIFICATION_PATH)
		if notif_scene:
			var notif := notif_scene.instantiate()
			notif.setup(new_unlocks)
			# Use a CanvasLayer to ensure it renders on top
			var canvas := CanvasLayer.new()
			canvas.layer = 30
			add_child(canvas)
			canvas.add_child(notif)
			notif.dismissed.connect(func(): canvas.queue_free())

# ─── Particle Effects ─────────────────────────────────────────

func _spawn_particles() -> void:
	"""Create atmospheric particle effects purely in code."""
	_create_qi_dissipation_particles()
	_create_dust_particles()

func _create_qi_dissipation_particles() -> void:
	"""灵气消散 — soft glowing orbs floating upward and fading, in spirit root color."""
	var particles := GPUParticles2D.new()
	particles.name = "QiDissipation"
	particles.amount = 20
	particles.lifetime = 4.0
	particles.speed_scale = 0.6
	particles.randomness = 0.8
	particles.visibility_rect = Rect2(-1200, -800, 2400, 1600)

	# Position across the full screen
	particles.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0, get_viewport().get_visible_rect().size.y * 0.7)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(800, 200, 0)

	# Float upward
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, -8, 0)

	# Size: small glowing orbs
	mat.scale_min = 4.0
	mat.scale_max = 10.0

	# Use spirit root color with glow
	var qi_color := _accent_color
	qi_color.a = 0.6
	var qi_color_faded := _accent_color
	qi_color_faded.a = 0.0

	var color_ramp := Gradient.new()
	color_ramp.colors = PackedColorArray([qi_color_faded, qi_color, qi_color, qi_color_faded])
	color_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	# Scale curve: grow in, shrink out
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	particles.process_material = mat

	# Use a simple white circle texture (generated procedurally)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var center := Vector2(8, 8)
	for x in range(16):
		for y in range(16):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / 8.0, 0.0, 1.0)
			alpha = alpha * alpha  # Soft falloff
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex := ImageTexture.create_from_image(img)
	particles.texture = tex

	add_child(particles)

func _create_dust_particles() -> void:
	"""灰尘飘落 — subtle dark grey/white particles drifting down slowly."""
	var particles := GPUParticles2D.new()
	particles.name = "DustFalling"
	particles.amount = 30
	particles.lifetime = 6.0
	particles.speed_scale = 0.4
	particles.randomness = 0.9
	particles.visibility_rect = Rect2(-1200, -800, 2400, 1600)

	# Emit from top of screen
	particles.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0, -20)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(960, 10, 0)

	# Drift downward with slight horizontal sway
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3(0, 5, 0)

	# Tiny particles
	mat.scale_min = 1.5
	mat.scale_max = 3.5

	# Subtle grey-white with low opacity
	var dust_start := Color(0.7, 0.7, 0.75, 0.0)
	var dust_mid := Color(0.6, 0.6, 0.65, 0.25)
	var dust_end := Color(0.5, 0.5, 0.55, 0.0)

	var color_ramp := Gradient.new()
	color_ramp.colors = PackedColorArray([dust_start, dust_mid, dust_mid, dust_end])
	color_ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	particles.process_material = mat

	# Tiny soft dot texture
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var center := Vector2(4, 4)
	for x in range(8):
		for y in range(8):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex := ImageTexture.create_from_image(img)
	particles.texture = tex

	add_child(particles)

# ─── UI Build ─────────────────────────────────────────────────

func _build_ui() -> void:
	# Make this a full-rect control
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# ─── Full-screen dark background ───
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.10, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ─── ScrollContainer for full layout ───
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_left = 0.15
	scroll.anchor_right = 0.85
	scroll.anchor_top = 0.02
	scroll.anchor_bottom = 0.98
	add_child(scroll)

	# ─── Root VBox (centered) ───
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)

	# ─── Title: 「道消陨落」───
	var realm_name := _get_realm_display()
	var floor_num: int = GameManager.current_room
	if floor_num <= 0:
		floor_num = 1

	var title := Label.new()
	title.text = "道 消 陨 落"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.7, 0.15, 0.15))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s 陨落于第 %d 层" % [realm_name, floor_num]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.6, 0.2))
	root.add_child(subtitle)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	root.add_child(spacer1)

	# ─── Stats Panel ───
	var stats_panel := _create_stats_panel()
	root.add_child(stats_panel)

	# ─── Historical Runs Panel ───
	var history_panel := _create_history_panel()
	if history_panel:
		var spacer_hist := Control.new()
		spacer_hist.custom_minimum_size = Vector2(0, 15)
		root.add_child(spacer_hist)
		root.add_child(history_panel)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	root.add_child(spacer2)

	# ─── Buttons ───
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	root.add_child(btn_row)

	var restart_btn := _create_styled_button("再度轮回", _on_restart_pressed)
	btn_row.add_child(restart_btn)

	var menu_btn := _create_styled_button("归返虚无", _on_menu_pressed)
	btn_row.add_child(menu_btn)

	# ─── Fade-in animation ───
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _create_stats_panel() -> PanelContainer:
	"""Build the statistics panel with styled background."""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Style: dark purple background with accent border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.95)
	style.border_color = _accent_color.darkened(0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Panel title
	var panel_title := Label.new()
	panel_title.text = "── 此劫历程 ──"
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.add_theme_font_size_override("font_size", 24)
	panel_title.add_theme_color_override("font_color", _accent_color)
	vbox.add_child(panel_title)

	# Separator
	var sep := HSeparator.new()
	var sep_color := _accent_color.darkened(0.4)
	sep_color.a = 0.6
	sep.add_theme_color_override("separator", sep_color)
	vbox.add_child(sep)

	# Stats rows — check for new records
	var realm_name := _get_realm_display()
	_add_stat_row(vbox, "修为境界", realm_name)
	_add_stat_row(vbox, "坚持层数", "%d 间" % RunStats.rooms_cleared,
		_check_new_record("rooms_cleared", RunStats.rooms_cleared))
	_add_stat_row(vbox, "击杀敌人", "%d 个妖物" % RunStats.enemies_killed,
		_check_new_record("kills", RunStats.enemies_killed))
	_add_stat_row(vbox, "灵石收集", "%d 灵石" % RunStats.spirit_stones_collected,
		_check_new_record("spirit_stones", RunStats.spirit_stones_collected))
	_add_stat_row(vbox, "使用技能", "%d 次" % RunStats.skills_used)
	_add_stat_row(vbox, "获得祝福", "%d 个" % RunStats.boons_acquired)
	_add_stat_row(vbox, "总伤害量", "%d 点" % RunStats.damage_dealt_total,
		_check_new_record("damage_dealt", RunStats.damage_dealt_total))

	# Duration
	var minutes := int(_run_duration) / 60
	var seconds := int(_run_duration) % 60
	_add_stat_row(vbox, "历劫时长", "%d 分 %02d 秒" % [minutes, seconds])

	return panel

func _check_new_record(stat: String, current_value) -> bool:
	"""Check if the current value is a new record (comparing against runs BEFORE this one)."""
	var runs := RunHistory.get_best_runs()
	# Need at least 2 runs (current one is already saved), so compare against others
	if runs.size() < 2:
		return false
	# Check all runs except the most recently saved one (which is our current run)
	for run in runs:
		if run.get(stat, 0) >= current_value:
			# Found a previous run that's equal or better — not a new record
			# (unless it's our current run)
			return false
	return true

func _create_history_panel() -> PanelContainer:
	"""Build the 历代记录 panel showing top past runs."""
	var best_runs := RunHistory.get_best_runs()
	# Only show if there are runs beyond the current one
	if best_runs.size() < 2:
		return null

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.10, 0.90)
	style.border_color = Color(0.5, 0.4, 0.2, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Section title
	var section_title := Label.new()
	section_title.text = "── 历代轮回 ──"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color(0.75, 0.6, 0.2))
	vbox.add_child(section_title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.5, 0.4, 0.2, 0.4))
	vbox.add_child(sep)

	# Show top 3 past runs (skip the first if it matches current run exactly)
	var shown := 0
	for i in range(best_runs.size()):
		if shown >= 3:
			break
		var run: Dictionary = best_runs[i]
		var run_label := Label.new()
		run_label.text = _format_run_summary(run, shown + 1)
		run_label.add_theme_font_size_override("font_size", 16)
		run_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		vbox.add_child(run_label)
		shown += 1

	return panel

func _format_run_summary(run: Dictionary, rank: int) -> String:
	"""Format a past run as a compact one-liner."""
	var root_idx: int = run.get("spiritual_root", 0)
	var root_name: String = SPIRIT_ROOT_NAMES[root_idx] if root_idx < SPIRIT_ROOT_NAMES.size() else "?"

	var realm_idx: int = clampi(run.get("realm", 0), 0, REALM_NAMES.size() - 1)
	var stage_idx: int = clampi(run.get("stage", 0), 0, STAGE_NAMES.size() - 1)
	var realm_str := REALM_NAMES[realm_idx] + STAGE_NAMES[stage_idx]

	var rooms: int = run.get("rooms_cleared", 0)
	var kills: int = run.get("kills", 0)
	var dur: int = run.get("duration_seconds", 0)
	var dur_min := dur / 60
	var dur_sec := dur % 60

	return "#%d  %s灵根 · %s · %d层 · %d杀 · %d分%02d秒" % [
		rank, root_name, realm_str, rooms, kills, dur_min, dur_sec
	]

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String, is_record: bool = false) -> void:
	"""Add a label-value row to the stats panel. Optionally mark as new record."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value := Label.new()
	if is_record:
		value.text = value_text + "  新纪录！"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # Gold
	else:
		value.text = value_text
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)

func _create_styled_button(text: String, callback: Callable) -> Button:
	"""Create a gold-bordered button with dark background."""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 55)
	btn.add_theme_font_size_override("font_size", 24)

	# Normal style
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.06, 0.16, 0.95)
	normal_style.border_color = _accent_color.darkened(0.2)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.content_margin_left = 20
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal_style)

	# Hover style
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.12, 0.08, 0.22, 0.95)
	hover_style.border_color = _accent_color
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed style
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.1, 0.28, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	btn.add_theme_color_override("font_hover_color", _accent_color)

	btn.pressed.connect(callback)
	return btn

func _get_realm_display() -> String:
	"""Get readable realm + stage string like '练气初期'."""
	var realm_idx: int = clampi(PlayerData.cultivation_realm, 0, REALM_NAMES.size() - 1)
	var stage_idx: int = clampi(PlayerData.cultivation_stage, 0, STAGE_NAMES.size() - 1)
	return REALM_NAMES[realm_idx] + STAGE_NAMES[stage_idx]

func _on_restart_pressed() -> void:
	"""Restart: go to spirit root selection."""
	RunStats.reset()
	GameManager.goto_scene(SPIRIT_ROOT_SELECTION_PATH)

func _on_menu_pressed() -> void:
	"""Return to main menu."""
	GameManager.goto_scene(MAIN_MENU_PATH)
