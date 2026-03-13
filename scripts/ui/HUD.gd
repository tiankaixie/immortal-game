extends CanvasLayer
## HUD — In-game heads-up display
##
## Shows:
## - HP bar (red)
## - Spiritual Power / 灵力 bar (blue)
## - Auto-battle indicator
## - Cultivation realm & stage text
## - Skill panel (bottom-center, up to 4 equipped skills)

# ─── Node References ──────────────────────────────────────────
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPBar/HPLabel
@onready var sp_bar: ProgressBar = $MarginContainer/VBoxContainer/SPBar
@onready var sp_label: Label = $MarginContainer/VBoxContainer/SPBar/SPLabel
@onready var auto_battle_label: Label = $MarginContainer/VBoxContainer/AutoBattleLabel
@onready var realm_label: Label = $MarginContainer/VBoxContainer/RealmLabel

# ─── Realm Name Maps ──────────────────────────────────────────
const REALM_NAMES: Dictionary = {
	0: "练气期",  # QI_CONDENSATION
	1: "筑基期",  # FOUNDATION_ESTABLISHMENT
	2: "结丹期",  # CORE_FORMATION
	3: "元婴期",  # NASCENT_SOUL
	4: "化神期",  # SOUL_TRANSFORMATION
	5: "炼虚期",  # VOID_REFINEMENT
	6: "合体期",  # BODY_INTEGRATION
	7: "大乘期",  # MAHAYANA
	8: "渡劫期",  # TRIBULATION_TRANSCENDENCE
}

const STAGE_NAMES: Dictionary = {
	0: "初期",  # EARLY
	1: "中期",  # MID
	2: "后期",  # LATE
	3: "巅峰",  # PEAK
}

# Room display (created dynamically)
var room_label: Label = null
var room_type_label: Label = null

# Dungeon progress bar (top-center)
var dungeon_progress_container: Control = null
var dungeon_progress_bg: ColorRect = null
var dungeon_progress_fill: ColorRect = null
var dungeon_progress_label: Label = null

# Skill panel (created dynamically)
var skill_panel_container: HBoxContainer = null
var skill_tiles: Array[PanelContainer] = []

# Cooldown overlay tracking — parallel arrays indexed with skill_tiles
var cooldown_overlays: Array[ColorRect] = []
var cooldown_labels: Array[Label] = []
var cooldown_skill_ids: Array[String] = []

# Spirit stones display
var stones_label: Label = null

# Inventory UI
var inventory_ui: CanvasLayer = null
const InventoryUIScene = preload("res://scenes/ui/InventoryUI.tscn")

# Pause Menu
var pause_menu: CanvasLayer = null
const PauseMenuScene = preload("res://scenes/ui/PauseMenu.tscn")

# Drop Notification
var drop_notification: Control = null
const DropNotificationScene = preload("res://scenes/ui/DropNotification.tscn")

# Skill Unlock Notification
var skill_unlock_notification: CanvasLayer = null
const SkillUnlockNotificationScene = preload("res://scenes/ui/SkillUnlockNotification.tscn")

# ─── Active Spirit Root Theme Color ──────────────────────────
var _spirit_theme_color: Color = Color("FF3333")  # Updated in apply_spirit_root_theme()

# ─── Boss HP Bar ──────────────────────────────────────────────
var boss_bar_container: Control = null
var boss_hp_bar: ProgressBar = null
var boss_hp_label: Label = null
var boss_name_label: Label = null
var boss_phase_label: Label = null
var boss_node: Node = null
var boss_hp_tween: Tween = null

func _ready() -> void:
	# Connect to CombatSystem auto-battle signal
	CombatSystem.auto_battle_toggled.connect(_on_auto_battle_toggled)

	# Connect to PlayerData signals
	PlayerData.cultivation_advanced.connect(_on_cultivation_advanced)

	# Initialize display
	_update_auto_battle_display(CombatSystem.auto_battle_enabled)
	_update_realm_display()

	# Connect to PlayerData skill/stones changes
	PlayerData.spirit_stones_changed.connect(_on_spirit_stones_changed)
	PlayerData.skill_learned.connect(_on_skill_learned)

	# Create room counter label
	_create_room_label()

	# Create dungeon progress bar at top-center
	_create_dungeon_progress_bar()

	# Create skill panel at bottom-center
	_create_skill_panel()

	# Create spirit stones display
	_create_stones_label()

	# Create drop notification overlay
	_create_drop_notification()

	# Show hard mode indicator if active
	if GameManager.hard_mode:
		_create_hard_mode_indicator()

	# Create skill unlock notification overlay
	_create_skill_unlock_notification()

	# Apply spirit root color theme
	apply_spirit_root_theme(PlayerData.spiritual_root)

	print("[HUD] Ready")

func _process(_delta: float) -> void:
	_update_cooldown_overlays()

func _update_cooldown_overlays() -> void:
	"""Update cooldown overlay height and timer text each frame."""
	for i in range(cooldown_skill_ids.size()):
		var skill_id: String = cooldown_skill_ids[i]
		var overlay: ColorRect = cooldown_overlays[i]
		var label: Label = cooldown_labels[i]
		var tile: PanelContainer = skill_tiles[i]

		var remaining: float = CombatSystem.skill_cooldowns.get(skill_id, 0.0)
		if remaining <= 0.0:
			overlay.visible = false
			label.visible = false
			continue

		# 获取技能总冷却时间
		var skill_data: Dictionary = SkillDatabase.get_skill(skill_id)
		var total_cd: float = skill_data.get("cooldown", 1.0)
		var ratio: float = clampf(remaining / total_cd, 0.0, 1.0)

		overlay.visible = true
		label.visible = true
		label.text = "%.1fs" % remaining

		# 遮罩从顶部向下缩小：高度 = tile高度 * ratio
		var tile_size: Vector2 = tile.size
		overlay.size = Vector2(tile_size.x, tile_size.y * ratio)
		overlay.position = Vector2.ZERO

# ─── Player Connection ────────────────────────────────────────
func connect_to_player(player: Node) -> void:
	"""Connect HUD to the player node's signals."""
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_hp_changed)
	if player.has_signal("sp_changed"):
		player.sp_changed.connect(_on_sp_changed)

	# Initialize bars with current values if available
	if player.has_method("get") or true:
		_on_hp_changed(player.current_hp, player.max_hp)
		_on_sp_changed(player.current_sp, player.max_sp)

# ─── Signal Handlers ──────────────────────────────────────────
func _on_hp_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "气血  %.0f / %.0f" % [current, maximum]

func _on_sp_changed(current: float, maximum: float) -> void:
	sp_bar.max_value = maximum
	sp_bar.value = current
	sp_label.text = "灵力  %.0f / %.0f" % [current, maximum]

func _on_auto_battle_toggled(enabled: bool) -> void:
	_update_auto_battle_display(enabled)

func _on_cultivation_advanced(_realm: int, _stage: int) -> void:
	_update_realm_display()

# ─── Display Helpers ───────────────────────────────────────────
func _update_auto_battle_display(enabled: bool) -> void:
	if auto_battle_label:
		auto_battle_label.text = "⚔ 自动战斗: %s  [Q]" % ("开" if enabled else "关")
		auto_battle_label.modulate = Color.GREEN if enabled else Color(0.6, 0.6, 0.6)

func _update_realm_display() -> void:
	if realm_label:
		var realm_name: String = REALM_NAMES.get(PlayerData.cultivation_realm, "???")
		var stage_name: String = STAGE_NAMES.get(PlayerData.cultivation_stage, "???")
		realm_label.text = "%s · %s" % [realm_name, stage_name]

# ─── Spirit Root Theme ─────────────────────────────────────────
const SPIRIT_ROOT_COLORS: Dictionary = {
	PlayerData.SpiritualRoot.METAL: Color("C0C0FF"),   # 银蓝
	PlayerData.SpiritualRoot.WOOD:  Color("44CC44"),   # 翠绿
	PlayerData.SpiritualRoot.WATER: Color("4488FF"),   # 海蓝
	PlayerData.SpiritualRoot.FIRE:  Color("FF6633"),   # 烈橙
	PlayerData.SpiritualRoot.EARTH: Color("AA8844"),   # 土黄
}
const DEFAULT_HP_COLOR := Color("FF3333")

func apply_spirit_root_theme(root: int) -> void:
	"""Apply element color theme to HP bar, SP bar, skill panel borders,
	   boss HP bar border, and room labels."""
	var theme_color: Color = SPIRIT_ROOT_COLORS.get(root, DEFAULT_HP_COLOR)
	_spirit_theme_color = theme_color

	# ── HP bar fill color ──
	if hp_bar:
		var hp_fill := StyleBoxFlat.new()
		hp_fill.bg_color = theme_color
		hp_fill.set_corner_radius_all(2)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)

	# ── SP bar fill color (darkened 20%) ──
	if sp_bar:
		var sp_fill := StyleBoxFlat.new()
		sp_fill.bg_color = theme_color.darkened(0.2)
		sp_fill.set_corner_radius_all(2)
		sp_bar.add_theme_stylebox_override("fill", sp_fill)

	# ── Skill panel tile borders ──
	_apply_theme_to_skill_tiles(theme_color)

	# ── Boss HP bar border (if already created) ──
	_apply_theme_to_boss_bar(theme_color)

	# ── Room labels accent ──
	_apply_theme_to_room_labels(theme_color)

	# ── Dungeon progress bar fill ──
	_apply_theme_to_dungeon_progress(theme_color)

	print("[HUD] Applied spirit root theme: %s → %s" % [root, theme_color.to_html()])

func _apply_theme_to_skill_tiles(theme_color: Color) -> void:
	"""Update existing skill tile border colors to match the spirit root theme."""
	for tile in skill_tiles:
		if not is_instance_valid(tile):
			continue
		var style: StyleBoxFlat = tile.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			# Duplicate to avoid shared resource issues
			var new_style := style.duplicate() as StyleBoxFlat
			new_style.border_color = theme_color
			tile.add_theme_stylebox_override("panel", new_style)

func _apply_theme_to_boss_bar(theme_color: Color) -> void:
	"""Tint the boss HP bar border and bg to the spirit root color."""
	if boss_hp_bar == null or not is_instance_valid(boss_hp_bar):
		return
	var bg_style := boss_hp_bar.get_theme_stylebox("background") as StyleBoxFlat
	if bg_style:
		var new_bg := bg_style.duplicate() as StyleBoxFlat
		new_bg.border_color = theme_color.darkened(0.3)
		boss_hp_bar.add_theme_stylebox_override("background", new_bg)
	# Also tint boss_bar_container background label accent
	if boss_name_label and is_instance_valid(boss_name_label):
		# Blend default gold with theme color slightly (70% gold, 30% theme)
		var blended := Color(1.0, 0.85, 0.3).lerp(theme_color, 0.3)
		boss_name_label.add_theme_color_override("font_color", blended)

func _apply_theme_to_room_labels(theme_color: Color) -> void:
	"""Tint the room counter label with the spirit root color."""
	if room_label and is_instance_valid(room_label):
		# Blend the default purple-white with theme color
		var blended := Color(0.8, 0.7, 1.0).lerp(theme_color, 0.4)
		room_label.add_theme_color_override("font_color", blended)
	# room_type_label keeps its per-type colors for readability (elite/boss/treasure),
	# but for the default "普通间" case, use a softened theme tint
	if room_type_label and is_instance_valid(room_type_label):
		var soft := theme_color.lightened(0.3)
		soft.a = 0.85
		room_type_label.add_theme_color_override("font_color", soft)
		# Override back to type-specific colors each time update_room_type_display is called

# ─── Dungeon Progress Bar ──────────────────────────────────────
func _create_dungeon_progress_bar() -> void:
	"""Create a thin progress bar at top-center showing dungeon room progression."""
	dungeon_progress_container = Control.new()
	dungeon_progress_container.name = "DungeonProgressBar"
	dungeon_progress_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dungeon_progress_container.anchor_left = 0.5
	dungeon_progress_container.anchor_right = 0.5
	dungeon_progress_container.anchor_top = 0.0
	dungeon_progress_container.anchor_bottom = 0.0
	dungeon_progress_container.offset_left = -300
	dungeon_progress_container.offset_right = 300
	dungeon_progress_container.offset_top = 6
	dungeon_progress_container.offset_bottom = 26  # 8px bar + label space
	dungeon_progress_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(dungeon_progress_container)

	# Background track (semi-transparent dark)
	dungeon_progress_bg = ColorRect.new()
	dungeon_progress_bg.color = Color(0.1, 0.08, 0.15, 0.5)
	dungeon_progress_bg.position = Vector2(0, 0)
	dungeon_progress_bg.size = Vector2(600, 8)
	dungeon_progress_container.add_child(dungeon_progress_bg)

	# Fill bar (spirit root color, starts at 1/5)
	dungeon_progress_fill = ColorRect.new()
	dungeon_progress_fill.color = _spirit_theme_color
	dungeon_progress_fill.position = Vector2(0, 0)
	dungeon_progress_fill.size = Vector2(120, 8)  # 1/5 of 600
	dungeon_progress_container.add_child(dungeon_progress_fill)

	# Small label below the bar
	dungeon_progress_label = Label.new()
	dungeon_progress_label.text = "1 / 5"
	dungeon_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dungeon_progress_label.position = Vector2(0, 9)
	dungeon_progress_label.size = Vector2(600, 14)
	dungeon_progress_label.add_theme_font_size_override("font_size", 11)
	dungeon_progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.7))
	dungeon_progress_container.add_child(dungeon_progress_label)

func update_dungeon_progress(current: int, total: int) -> void:
	"""Update the dungeon progress bar with smooth tween animation."""
	if dungeon_progress_fill == null or dungeon_progress_bg == null:
		return

	var bar_width: float = dungeon_progress_bg.size.x
	var target_width: float = bar_width * (float(current) / float(total))

	# Tween the fill width smoothly
	var tween := create_tween()
	tween.tween_property(dungeon_progress_fill, "size:x", target_width, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Update label
	if dungeon_progress_label:
		dungeon_progress_label.text = "%d / %d" % [current, total]

	# Brief glow effect on the fill color
	var original_color: Color = _spirit_theme_color
	var bright_color: Color = original_color.lightened(0.4)
	dungeon_progress_fill.color = bright_color
	var color_tween := create_tween()
	color_tween.tween_property(dungeon_progress_fill, "color", original_color, 0.6)

func _apply_theme_to_dungeon_progress(theme_color: Color) -> void:
	"""Update dungeon progress bar fill color to match spirit root theme."""
	if dungeon_progress_fill and is_instance_valid(dungeon_progress_fill):
		dungeon_progress_fill.color = theme_color

# ─── Room Cleared Display ─────────────────────────────────────
func show_room_cleared() -> void:
	"""Display a room cleared notification on the HUD."""
	var label := Label.new()
	label.text = "✦ 房间已清除 ✦\n下一间 →"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER
	label.anchor_left = 0.5
	label.anchor_top = 0.4
	label.anchor_right = 0.5
	label.anchor_bottom = 0.4
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(label)
	
	# Animate
	var tween := create_tween()
	label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

# ─── Room Counter Display ─────────────────────────────────────
func _create_room_label() -> void:
	"""Create a room type label and room counter in the top-right corner."""
	# Room type label (above counter)
	room_type_label = Label.new()
	room_type_label.text = "普通间"
	room_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_type_label.add_theme_font_size_override("font_size", 16)
	room_type_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	room_type_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	room_type_label.anchor_left = 0.85
	room_type_label.anchor_right = 0.98
	room_type_label.anchor_top = 0.015
	room_type_label.anchor_bottom = 0.04
	room_type_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(room_type_label)

	# Room counter (below type label)
	room_label = Label.new()
	room_label.text = "第 1/5 间"
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_label.add_theme_font_size_override("font_size", 20)
	room_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	room_label.anchor_left = 0.85
	room_label.anchor_right = 0.98
	room_label.anchor_top = 0.04
	room_label.anchor_bottom = 0.075
	room_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(room_label)

func update_room_display(room: int, total: int) -> void:
	"""Update the room counter text."""
	if room_label:
		room_label.text = "第 %d/%d 间" % [room, total]

func update_room_type_display(room_type_name: String) -> void:
	"""Update the room type label text and color.
	   Special room types keep distinct colors; normal rooms use spirit root tint."""
	if room_type_label:
		room_type_label.text = "— %s —" % room_type_name
		# Color coding: special rooms override theme; normal room uses theme tint
		match room_type_name:
			"精英间":
				room_type_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			"宝藏间":
				room_type_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			"BOSS间":
				room_type_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			_:
				# Normal/Ambush rooms: spirit root color, softened
				var soft := _spirit_theme_color.lightened(0.3)
				soft.a = 0.85
				room_type_label.add_theme_color_override("font_color", soft)

# ─── Spirit Stones Display ────────────────────────────────────
func _create_stones_label() -> void:
	"""Create a spirit stones counter below the room label."""
	stones_label = Label.new()
	stones_label.text = "灵石: %d" % PlayerData.spirit_stones
	stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stones_label.add_theme_font_size_override("font_size", 18)
	stones_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	stones_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stones_label.anchor_left = 0.85
	stones_label.anchor_right = 0.98
	stones_label.anchor_top = 0.075
	stones_label.anchor_bottom = 0.11
	stones_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(stones_label)

func _on_spirit_stones_changed(new_total: int) -> void:
	if stones_label:
		stones_label.text = "灵石: %d" % new_total

# ─── Drop Notification ────────────────────────────────────────
func _create_drop_notification() -> void:
	"""Create the drop notification overlay."""
	drop_notification = DropNotificationScene.instantiate()
	add_child(drop_notification)

func _create_skill_unlock_notification() -> void:
	"""Create the skill unlock notification overlay."""
	skill_unlock_notification = SkillUnlockNotificationScene.instantiate()
	get_tree().root.call_deferred("add_child", skill_unlock_notification)

# ─── Hard Mode Indicator ──────────────────────────────────────
func _create_hard_mode_indicator() -> void:
	"""Show a red '劫难' indicator at the top-right of the HUD."""
	var label := Label.new()
	label.name = "HardModeIndicator"
	label.text = "⚡ 劫难"
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -120
	label.offset_right = -10
	label.offset_top = 10
	label.offset_bottom = 40
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	add_child(label)

# ─── Skill Panel ─────────────────────────────────────────────
func _create_skill_panel() -> void:
	"""Create a panel at the bottom-center showing up to 4 equipped skills."""
	# Anchor container at bottom-center
	var anchor := Control.new()
	anchor.name = "SkillPanelAnchor"
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.anchor_left = 0.5
	anchor.anchor_right = 0.5
	anchor.anchor_top = 1.0
	anchor.anchor_bottom = 1.0
	anchor.offset_top = -80
	anchor.offset_bottom = -10
	anchor.offset_left = -260
	anchor.offset_right = 260
	anchor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(anchor)

	skill_panel_container = HBoxContainer.new()
	skill_panel_container.name = "SkillPanel"
	skill_panel_container.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_panel_container.add_theme_constant_override("separation", 8)
	skill_panel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.add_child(skill_panel_container)

	refresh_skill_panel()

func refresh_skill_panel() -> void:
	"""Rebuild skill tiles from PlayerData.equipped_skills."""
	if skill_panel_container == null:
		return

	# Clear existing tiles and cooldown tracking
	for tile in skill_tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	skill_tiles.clear()
	cooldown_overlays.clear()
	cooldown_labels.clear()
	cooldown_skill_ids.clear()

	# Build tiles for each equipped skill (up to 4)
	var skills_to_show: Array[String] = []
	for sid in PlayerData.equipped_skills:
		skills_to_show.append(sid)
	if skills_to_show.size() == 0:
		# Fallback: show unlocked skills if nothing explicitly equipped
		for sid in PlayerData.unlocked_skills:
			if skills_to_show.size() >= 4:
				break
			skills_to_show.append(sid)

	var hotkey_index := 1
	for skill_id in skills_to_show:
		if hotkey_index > 4:
			break
		var skill_data: Dictionary = SkillDatabase.get_skill(skill_id)
		if skill_data.is_empty():
			hotkey_index += 1
			continue
		var tile := _create_skill_tile(skill_data, hotkey_index)
		skill_panel_container.add_child(tile)
		skill_tiles.append(tile)
		cooldown_skill_ids.append(skill_id)
		hotkey_index += 1

	# Re-apply spirit root theme to new tiles
	var theme_color: Color = SPIRIT_ROOT_COLORS.get(PlayerData.spiritual_root, DEFAULT_HP_COLOR)
	_apply_theme_to_skill_tiles(theme_color)

func _create_skill_tile(skill: Dictionary, hotkey: int) -> PanelContainer:
	"""Create a single skill tile showing icon placeholder, name, SP cost, and hotkey."""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 60)

	# Style the panel background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.2, 0.85)
	style.border_color = _get_element_color(skill.get("element", ""))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Top row: hotkey badge + skill name
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)

	var hotkey_label := Label.new()
	hotkey_label.text = "[%d]" % hotkey
	hotkey_label.add_theme_font_size_override("font_size", 11)
	hotkey_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	top.add_child(hotkey_label)

	var name_label := Label.new()
	name_label.text = skill.get("name_zh", "???")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	# Bottom row: SP cost + element
	var bottom := Label.new()
	var sp_cost: float = skill.get("sp_cost", 0)
	var element: String = skill.get("element", "")
	bottom.text = "灵力 %.0f  |  %s" % [sp_cost, _get_element_name(element)]
	bottom.add_theme_font_size_override("font_size", 11)
	bottom.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	vbox.add_child(bottom)

	# ── 冷却遮罩 (cooldown overlay) ──
	var cd_overlay := ColorRect.new()
	cd_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.visible = false
	panel.add_child(cd_overlay)
	cooldown_overlays.append(cd_overlay)

	var cd_label := Label.new()
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_label.add_theme_font_size_override("font_size", 16)
	cd_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.visible = false
	panel.add_child(cd_label)
	cooldown_labels.append(cd_label)

	return panel

func _get_element_color(element: String) -> Color:
	"""Return a border color based on the skill's element."""
	match element:
		"fire": return Color(0.9, 0.3, 0.1)
		"water": return Color(0.2, 0.5, 0.9)
		"metal": return Color(0.8, 0.8, 0.7)
		"wood": return Color(0.3, 0.8, 0.3)
		"earth": return Color(0.7, 0.55, 0.3)
		"lightning": return Color(0.7, 0.5, 1.0)
		_: return Color(0.5, 0.5, 0.5)

func _get_element_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"metal": return "金"
		"wood": return "木"
		"earth": return "土"
		"lightning": return "雷"
		_: return "无"

func _on_skill_learned(skill_id: String) -> void:
	refresh_skill_panel()
	# Show skill unlock notification
	if skill_unlock_notification and skill_unlock_notification.has_method("show_skill_notification"):
		skill_unlock_notification.show_skill_notification(skill_id)

# ─── Inventory Toggle ─────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()

func _toggle_inventory() -> void:
	"""Open or close the inventory UI."""
	if inventory_ui != null and is_instance_valid(inventory_ui):
		# Already open — close it
		if inventory_ui.has_method("_on_close"):
			inventory_ui._on_close()
		inventory_ui = null
		return

	inventory_ui = InventoryUIScene.instantiate()
	inventory_ui.closed.connect(func(): inventory_ui = null)
	get_tree().root.add_child(inventory_ui)

# ─── Boss HP Bar ──────────────────────────────────────────────
func register_boss(boss: Node) -> void:
	"""Register a boss enemy and show the boss HP bar at top-center."""
	boss_node = boss
	_create_boss_hp_bar()

	# Connect boss signals
	if boss.has_signal("hp_changed"):
		boss.hp_changed.connect(_on_boss_hp_changed)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase_changed)

	# Initialize with current values
	if boss.get("max_hp") != null:
		_on_boss_hp_changed(boss.current_hp, boss.max_hp)

	# Set boss name dynamically
	if boss_name_label and boss.get("enemy_name") != null:
		boss_name_label.text = boss.enemy_name

	boss_bar_container.visible = true
	boss_bar_container.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(boss_bar_container, "modulate:a", 1.0, 0.5)
	print("[HUD] Boss HP bar registered: %s" % boss.get("enemy_name", "Boss"))

func _create_boss_hp_bar() -> void:
	"""Build the boss HP bar UI at top-center of screen."""
	if boss_bar_container != null and is_instance_valid(boss_bar_container):
		boss_bar_container.queue_free()

	boss_bar_container = Control.new()
	boss_bar_container.name = "BossHPBar"
	boss_bar_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar_container.anchor_left = 0.5
	boss_bar_container.anchor_right = 0.5
	boss_bar_container.anchor_top = 0.0
	boss_bar_container.anchor_bottom = 0.0
	boss_bar_container.offset_left = -300
	boss_bar_container.offset_right = 300
	boss_bar_container.offset_top = 15
	boss_bar_container.offset_bottom = 90
	boss_bar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_bar_container.visible = false
	add_child(boss_bar_container)

	# Boss name label
	boss_name_label = Label.new()
	boss_name_label.text = "Boss"  # Will be updated in register_boss
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	boss_name_label.position = Vector2(0, 0)
	boss_name_label.size = Vector2(600, 28)
	boss_bar_container.add_child(boss_name_label)

	# Phase label (hidden initially)
	boss_phase_label = Label.new()
	boss_phase_label.text = ""
	boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_label.add_theme_font_size_override("font_size", 16)
	boss_phase_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	boss_phase_label.position = Vector2(0, 26)
	boss_phase_label.size = Vector2(600, 22)
	boss_phase_label.visible = false
	boss_bar_container.add_child(boss_phase_label)

	# HP bar background (dark)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.08, 0.05, 0.8)
	bar_bg.position = Vector2(0, 48)
	bar_bg.size = Vector2(600, 22)
	boss_bar_container.add_child(bar_bg)

	# HP ProgressBar
	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.position = Vector2(0, 48)
	boss_hp_bar.size = Vector2(600, 22)
	boss_hp_bar.max_value = 100.0
	boss_hp_bar.value = 100.0
	boss_hp_bar.show_percentage = false

	# Style: gold bar
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.75, 0.15)
	fill_style.set_corner_radius_all(3)
	boss_hp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.1, 0.05, 0.9)
	bg_style.set_corner_radius_all(3)
	bg_style.border_color = Color(0.6, 0.5, 0.2, 0.6)
	bg_style.set_border_width_all(1)
	boss_hp_bar.add_theme_stylebox_override("background", bg_style)

	boss_bar_container.add_child(boss_hp_bar)

	# HP text label (overlaid on bar)
	boss_hp_label = Label.new()
	boss_hp_label.text = ""
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_hp_label.position = Vector2(0, 48)
	boss_hp_label.size = Vector2(600, 22)
	boss_hp_label.add_theme_font_size_override("font_size", 14)
	boss_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	boss_bar_container.add_child(boss_hp_label)

	# Apply current spirit root theme to newly-created bar
	_apply_theme_to_boss_bar(_spirit_theme_color)

func _on_boss_hp_changed(current: float, maximum: float) -> void:
	"""Update boss HP bar with smooth tween animation."""
	if boss_hp_bar == null:
		return

	boss_hp_bar.max_value = maximum
	boss_hp_label.text = "%.0f / %.0f" % [current, maximum]

	# Smooth tween for HP decrease
	if boss_hp_tween and boss_hp_tween.is_valid():
		boss_hp_tween.kill()
	boss_hp_tween = create_tween()
	boss_hp_tween.tween_property(boss_hp_bar, "value", current, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Color transition: gold → orange → red as HP drops
	var hp_pct := current / maximum if maximum > 0.0 else 0.0
	var bar_color: Color
	if hp_pct > 0.6:
		bar_color = Color(0.9, 0.75, 0.15)  # Gold
	elif hp_pct > 0.3:
		bar_color = Color(0.9, 0.45, 0.1).lerp(Color(0.9, 0.75, 0.15), (hp_pct - 0.3) / 0.3)  # Orange blend
	else:
		bar_color = Color(0.85, 0.15, 0.1).lerp(Color(0.9, 0.45, 0.1), hp_pct / 0.3)  # Red blend

	var fill_style := boss_hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = bar_color

func _on_boss_defeated() -> void:
	"""Fade out the boss HP bar over 2 seconds after defeat."""
	if boss_bar_container == null or not is_instance_valid(boss_bar_container):
		return

	var tween := create_tween()
	tween.tween_property(boss_bar_container, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func():
		if boss_bar_container and is_instance_valid(boss_bar_container):
			boss_bar_container.visible = false
	)
	boss_node = null

func _on_boss_phase_changed(phase: int) -> void:
	"""Show phase change indicator when boss enters a new phase."""
	if boss_phase_label == null:
		return

	# Determine phase text based on boss type
	var phase_text := ""
	var name_color := Color(1.0, 0.3, 0.2)

	if boss_node and boss_node.get("enemy_name") == "天劫":
		# Tribulation Boss phases
		match phase:
			2:
				phase_text = "【二阶·雷链天罚】"
				name_color = Color(1.0, 0.9, 0.4)  # Gold
			3:
				phase_text = "【三阶·劫雷降世】"
				name_color = Color(1.0, 1.0, 0.8)  # White-gold
	else:
		# Default boss (苍龙天魔) phases
		match phase:
			2:
				phase_text = "【二阶·龙魂觉醒】"
				name_color = Color(1.0, 0.3, 0.2)

	if phase_text.is_empty():
		return

	boss_phase_label.text = phase_text
	boss_phase_label.visible = true

	# Flash effect
	boss_phase_label.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(boss_phase_label, "modulate:a", 1.0, 0.3)
	tween.tween_property(boss_phase_label, "modulate:a", 0.5, 0.3)
	tween.tween_property(boss_phase_label, "modulate:a", 1.0, 0.3)

	# Update boss name color
	if boss_name_label:
		boss_name_label.add_theme_color_override("font_color", name_color)

# ─── Pause Menu Toggle ───────────────────────────────────────
func _toggle_pause_menu() -> void:
	"""Open or close the pause menu."""
	if pause_menu != null and is_instance_valid(pause_menu):
		if pause_menu.has_method("resume"):
			pause_menu.resume()
		pause_menu = null
		return

	pause_menu = PauseMenuScene.instantiate()
	pause_menu.closed.connect(func(): pause_menu = null)
	get_tree().root.add_child(pause_menu)
