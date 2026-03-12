extends Control
## DeathScreen — Shown when the player dies (HP <= 0)
##
## Displays run statistics, realm info, and offers restart/menu options.
## All UI is generated in code — no external assets required.

const SPIRIT_ROOT_SELECTION_PATH: String = "res://scenes/ui/SpiritRootSelection.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

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
}

var _accent_color: Color = Color(0.75, 0.75, 1.0)

func _ready() -> void:
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Get accent color from spirit root
	_accent_color = SPIRIT_ROOT_COLORS.get(PlayerData.spiritual_root, Color(0.75, 0.75, 1.0))

	_build_ui()

func _build_ui() -> void:
	# Make this a full-rect control
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# ─── Full-screen dark background ───
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.10, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ─── Root VBox (centered) ───
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_left = 0.15
	root.anchor_right = 0.85
	root.anchor_top = 0.05
	root.anchor_bottom = 0.95
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	add_child(root)

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

	# Stats rows
	var realm_name := _get_realm_display()
	_add_stat_row(vbox, "修为境界", realm_name)
	_add_stat_row(vbox, "坚持层数", "%d 间" % RunStats.rooms_cleared)
	_add_stat_row(vbox, "击杀敌人", "%d 个妖物" % RunStats.enemies_killed)
	_add_stat_row(vbox, "灵石收集", "%d 灵石" % RunStats.spirit_stones_collected)
	_add_stat_row(vbox, "使用技能", "%d 次" % RunStats.skills_used)
	_add_stat_row(vbox, "获得祝福", "%d 个" % RunStats.boons_acquired)
	_add_stat_row(vbox, "总伤害量", "%d 点" % RunStats.damage_dealt_total)

	# Duration
	var elapsed := Time.get_unix_time_from_system() - RunStats.run_start_time
	if elapsed < 0:
		elapsed = 0
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	_add_stat_row(vbox, "历劫时长", "%d 分 %02d 秒" % [minutes, seconds])

	return panel

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	"""Add a label-value row to the stats panel."""
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
