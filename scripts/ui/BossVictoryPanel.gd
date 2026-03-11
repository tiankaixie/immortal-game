extends CanvasLayer
## BossVictoryPanel — Special reward screen after defeating a Boss
##
## Shows:
## - Full-screen dim overlay with "Boss Clear" theme
## - "BOSS 击败！" header in gold text
## - Loot already gained (spirit stones + equipment from boss drop)
## - 3 reward type choices: Boons (3 random) OR Lingshi (50-80) OR Rare Equipment
## - Only triggers on BossRoom (room 5), not EliteRoom
## Emits boon_chosen when selection made (or skipped)

signal boon_chosen(boon_id: String)

var loot_data: Dictionary = {}
var boon_options: Array[Dictionary] = []
var reward_lingshi: int = 0
var reward_equipment: Dictionary = {}

func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS

func show(p_loot_data: Dictionary, p_boons: Array[Dictionary]) -> void:
	"""Show the boss victory panel with loot info and reward type selection."""
	loot_data = p_loot_data
	boon_options = p_boons
	# Pre-roll alternative rewards
	reward_lingshi = randi_range(50, 80)
	_roll_reward_equipment()
	_build_ui()

func _roll_reward_equipment() -> void:
	"""Generate a rare equipment piece as reward option."""
	var slots := ["weapon", "armor", "accessory_1", "talisman"]
	var slot: String = slots[randi() % slots.size()]
	reward_equipment = EquipmentSystem.generate_equipment(slot, GameManager.current_floor, 3.0)

func _build_ui() -> void:
	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Root container
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_left = 0.05
	root.anchor_right = 0.95
	root.anchor_top = 0.03
	root.anchor_bottom = 0.97
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	# ─── Header ──────────────────────────────────────────
	var header := Label.new()
	header.text = "✦ BOSS 击败！✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 48)
	header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.15))
	root.add_child(header)

	var sparkle := Label.new()
	sparkle.text = "— 副本通关奖励 —"
	sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sparkle.add_theme_font_size_override("font_size", 20)
	sparkle.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
	root.add_child(sparkle)

	_add_spacer(root, 8)

	# ─── Loot Summary ────────────────────────────────────
	var loot_panel := _create_styled_panel(Color(0.1, 0.08, 0.15, 0.9), Color(0.6, 0.5, 0.15, 0.5))
	loot_panel.custom_minimum_size = Vector2(400, 0)
	loot_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(loot_panel)

	var loot_vbox := VBoxContainer.new()
	loot_vbox.add_theme_constant_override("separation", 4)
	loot_panel.add_child(loot_vbox)

	var loot_title := Label.new()
	loot_title.text = "— 战利品 —"
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_title.add_theme_font_size_override("font_size", 18)
	loot_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	loot_vbox.add_child(loot_title)

	var stones_amount: int = loot_data.get("spirit_stones", 0)
	var stones_label := Label.new()
	stones_label.text = "灵石: +%d" % stones_amount
	stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stones_label.add_theme_font_size_override("font_size", 16)
	stones_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	loot_vbox.add_child(stones_label)

	var equip_name: String = loot_data.get("equipment_name", "")
	var equip_quality: String = loot_data.get("equipment_quality", "")
	if equip_name != "":
		var equip_label := Label.new()
		equip_label.text = "%s  %s" % [equip_quality, equip_name]
		equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_label.add_theme_font_size_override("font_size", 16)
		equip_label.add_theme_color_override("font_color", _get_quality_color(equip_quality))
		loot_vbox.add_child(equip_label)

	_add_spacer(root, 12)

	# ─── Reward Choice Header ────────────────────────────
	var choice_header := Label.new()
	choice_header.text = "选择额外奖励（三选一）"
	choice_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_header.add_theme_font_size_override("font_size", 24)
	choice_header.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	root.add_child(choice_header)

	_add_spacer(root, 10)

	# ─── 3 Reward Cards ─────────────────────────────────
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 30)
	root.add_child(card_row)

	# Card 1: Boons (3 random)
	card_row.add_child(_create_boon_reward_card())

	# Card 2: Lingshi
	card_row.add_child(_create_lingshi_reward_card())

	# Card 3: Rare Equipment
	card_row.add_child(_create_equipment_reward_card())

	_add_spacer(root, 10)

	# ─── Skip Button ─────────────────────────────────────
	var skip_btn := Button.new()
	skip_btn.text = "跳过"
	skip_btn.custom_minimum_size = Vector2(100, 36)
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_btn.pressed.connect(_on_skip)
	root.add_child(skip_btn)

	# ─── Fade-in ─────────────────────────────────────────
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

# ─── Reward Card: Boons ──────────────────────────────────────
func _create_boon_reward_card() -> PanelContainer:
	var panel := _create_reward_card_base(
		Color(0.08, 0.06, 0.2, 0.95),
		Color(0.4, 0.3, 0.8),
		"🔮",
		"天赋祝福",
		"获得 3 个随机祝福\n（从当前祝福池中抽取）"
	)

	# Add boon preview names
	var vbox: VBoxContainer = panel.get_child(0)
	var preview := Label.new()
	var preview_text := ""
	for i in range(mini(3, boon_options.size())):
		if i > 0:
			preview_text += "\n"
		preview_text += "· %s" % boon_options[i].get("name_zh", "???")
	preview.text = preview_text
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_theme_font_size_override("font_size", 13)
	preview.add_theme_color_override("font_color", Color(0.6, 0.55, 0.85))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Insert before the button (last child)
	vbox.add_child(preview)
	vbox.move_child(preview, vbox.get_child_count() - 2)

	return panel

# ─── Reward Card: Lingshi ────────────────────────────────────
func _create_lingshi_reward_card() -> PanelContainer:
	return _create_reward_card_base(
		Color(0.15, 0.12, 0.02, 0.95),
		Color(0.9, 0.7, 0.2),
		"💎",
		"灵石宝藏",
		"获得 %d 灵石\n（立即入账）" % reward_lingshi,
		"lingshi"
	)

# ─── Reward Card: Equipment ──────────────────────────────────
func _create_equipment_reward_card() -> PanelContainer:
	var rarity_names := {0: "凡品", 1: "灵品", 2: "宝品", 3: "地品", 4: "天品", 5: "仙品"}
	var rarity_val: int = reward_equipment.get("rarity", 0)
	var rarity_name: String = rarity_names.get(rarity_val, "凡品")
	var equip_name: String = reward_equipment.get("name", "神秘装备")
	var slot_name: String = reward_equipment.get("slot", "weapon")

	var slot_names := {"weapon": "武器", "armor": "护甲", "accessory_1": "饰品", "talisman": "符箓"}
	var slot_zh: String = slot_names.get(slot_name, "装备")

	return _create_reward_card_base(
		Color(0.12, 0.05, 0.08, 0.95),
		Color(0.8, 0.3, 0.5),
		"⚔️",
		"稀有装备",
		"%s [%s]\n%s" % [equip_name, slot_zh, rarity_name],
		"equipment"
	)

# ─── Shared Card Builder ─────────────────────────────────────
func _create_reward_card_base(bg_color: Color, border_color: Color, icon: String, title: String, desc: String, reward_type: String = "boons") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 380)

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Icon
	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 56)
	vbox.add_child(icon_label)

	# Title
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.3, 0.5, 0.4))
	vbox.add_child(sep)

	# Description
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Select button
	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(120, 42)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_reward_chosen.bind(reward_type))
	vbox.add_child(btn)

	return panel

# ─── Reward Application ──────────────────────────────────────
func _on_reward_chosen(reward_type: String) -> void:
	AudioManager.play_sfx("level_up")

	match reward_type:
		"boons":
			# Apply up to 3 boons
			for i in range(mini(3, boon_options.size())):
				BoonDatabase.apply_boon(boon_options[i]["id"])
		"lingshi":
			PlayerData.add_spirit_stones(reward_lingshi)
		"equipment":
			PlayerData.inventory.append(reward_equipment)

	_fade_and_close("")

func _on_skip() -> void:
	_fade_and_close("")

func _fade_and_close(boon_id: String) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_close.bind(boon_id))

func _close(boon_id: String) -> void:
	boon_chosen.emit(boon_id)
	queue_free()

# ─── Helpers ──────────────────────────────────────────────────
func _add_spacer(parent: Control, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _create_styled_panel(bg_color: Color, border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _get_quality_color(quality: String) -> Color:
	match quality:
		"凡品": return Color(0.7, 0.7, 0.7)
		"灵品": return Color(0.3, 0.8, 0.4)
		"宝品": return Color(0.3, 0.5, 1.0)
		"地品": return Color(0.7, 0.3, 1.0)
		"天品": return Color(1.0, 0.7, 0.1)
		"仙品": return Color(1.0, 0.3, 0.3)
		_: return Color(0.8, 0.8, 0.8)
