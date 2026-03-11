extends CanvasLayer
## BossVictoryPanel — Special reward screen after defeating a Boss
##
## Shows:
## - Full-screen dim overlay (darker than normal boon UI)
## - "BOSS 击败！" header in gold/red gradient text with sparkle
## - Loot gained (spirit stones + equipment)
## - 4 boon cards (higher rarity chance) instead of normal 3
## - Skip button in bottom-right
## Emits boon_chosen when selection made (or skipped)

signal boon_chosen(boon_id: String)

var loot_data: Dictionary = {}
var boon_options: Array[Dictionary] = []

func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS

func show(p_loot_data: Dictionary, p_boons: Array[Dictionary]) -> void:
	"""Show the boss victory panel with loot info and boon selection."""
	loot_data = p_loot_data
	boon_options = p_boons
	_build_ui()

func _build_ui() -> void:
	# Dark overlay (darker than normal boon UI)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Root scroll container
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_left = 0.05
	root.anchor_right = 0.95
	root.anchor_top = 0.05
	root.anchor_bottom = 0.95
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	# ─── Header: BOSS 击败！ ─────────────────────────────
	var header := Label.new()
	header.text = "BOSS 击败！"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 52)
	header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.15))
	root.add_child(header)

	# Sparkle subtitle
	var sparkle := Label.new()
	sparkle.text = "✦ ✦ ✦"
	sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sparkle.add_theme_font_size_override("font_size", 28)
	sparkle.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	root.add_child(sparkle)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	root.add_child(spacer1)

	# ─── Loot Section ────────────────────────────────────
	var loot_panel := PanelContainer.new()
	var loot_style := StyleBoxFlat.new()
	loot_style.bg_color = Color(0.1, 0.08, 0.15, 0.9)
	loot_style.border_color = Color(0.8, 0.65, 0.15, 0.6)
	loot_style.set_border_width_all(1)
	loot_style.set_corner_radius_all(8)
	loot_style.set_content_margin_all(16)
	loot_panel.add_theme_stylebox_override("panel", loot_style)
	loot_panel.custom_minimum_size = Vector2(400, 0)
	loot_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(loot_panel)

	var loot_vbox := VBoxContainer.new()
	loot_vbox.add_theme_constant_override("separation", 6)
	loot_panel.add_child(loot_vbox)

	var loot_title := Label.new()
	loot_title.text = "— 战利品 —"
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_title.add_theme_font_size_override("font_size", 20)
	loot_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	loot_vbox.add_child(loot_title)

	# Spirit stones
	var stones_amount: int = loot_data.get("spirit_stones", 0)
	var stones_label := Label.new()
	stones_label.text = "灵石: +%d" % stones_amount
	stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stones_label.add_theme_font_size_override("font_size", 18)
	stones_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	loot_vbox.add_child(stones_label)

	# Equipment item
	var equip_name: String = loot_data.get("equipment_name", "")
	var equip_quality: String = loot_data.get("equipment_quality", "")
	if equip_name != "":
		var equip_label := Label.new()
		equip_label.text = "%s  %s" % [equip_quality, equip_name]
		equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_label.add_theme_font_size_override("font_size", 18)
		equip_label.add_theme_color_override("font_color", _get_quality_color(equip_quality))
		loot_vbox.add_child(equip_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	root.add_child(spacer2)

	# ─── Boon Selection ──────────────────────────────────
	var boon_header := Label.new()
	boon_header.text = "选择额外祝福"
	boon_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boon_header.add_theme_font_size_override("font_size", 24)
	boon_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	root.add_child(boon_header)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	root.add_child(spacer3)

	# Card row (4 cards)
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 20)
	root.add_child(card_row)

	for i in range(boon_options.size()):
		var card := _create_boon_card(boon_options[i])
		card_row.add_child(card)

	var spacer4 := Control.new()
	spacer4.custom_minimum_size = Vector2(0, 15)
	root.add_child(spacer4)

	# ─── Skip Button (bottom-right, small, grayed) ───────
	var skip_anchor := Control.new()
	skip_anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_anchor.anchor_left = 1.0
	skip_anchor.anchor_right = 1.0
	skip_anchor.anchor_top = 1.0
	skip_anchor.anchor_bottom = 1.0
	skip_anchor.offset_left = -140
	skip_anchor.offset_top = -50
	skip_anchor.offset_right = -20
	skip_anchor.offset_bottom = -15
	skip_anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(skip_anchor)

	var skip_btn := Button.new()
	skip_btn.text = "跳过"
	skip_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	skip_btn.pressed.connect(_on_skip)
	skip_anchor.add_child(skip_btn)

	# ─── Fade-in animation ───────────────────────────────
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _create_boon_card(boon: Dictionary) -> PanelContainer:
	"""Create a boon card (same style as BoonUI but slightly smaller for 4-across)."""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 320)

	var style := StyleBoxFlat.new()
	var rarity: int = boon.get("rarity", 0)
	match rarity:
		0:
			style.bg_color = Color(0.08, 0.08, 0.18, 0.95)
			style.border_color = Color(0.3, 0.3, 0.6)
		1:
			style.bg_color = Color(0.12, 0.05, 0.2, 0.95)
			style.border_color = Color(0.6, 0.3, 0.8)
		2:
			style.bg_color = Color(0.15, 0.1, 0.02, 0.95)
			style.border_color = Color(0.9, 0.7, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Emoji icon
	var icon_label := Label.new()
	icon_label.text = boon.get("icon_emoji", "✦")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon_label)

	# Name
	var name_label := Label.new()
	name_label.text = boon.get("name_zh", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	vbox.add_child(name_label)

	# English name
	var en_label := Label.new()
	en_label.text = boon.get("name_en", "")
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en_label.add_theme_font_size_override("font_size", 12)
	en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(en_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.3, 0.5, 0.5))
	vbox.add_child(sep)

	# Description
	var desc_label := Label.new()
	desc_label.text = boon.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Rarity
	var rarity_names := ["凡品", "灵品", "仙品"]
	var rarity_colors := [Color(0.5, 0.5, 0.6), Color(0.6, 0.3, 0.8), Color(0.9, 0.7, 0.2)]
	var rarity_label := Label.new()
	rarity_label.text = rarity_names[clampi(rarity, 0, 2)]
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 13)
	rarity_label.add_theme_color_override("font_color", rarity_colors[clampi(rarity, 0, 2)])
	vbox.add_child(rarity_label)

	# Select button
	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(100, 36)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_boon_selected.bind(boon["id"]))
	vbox.add_child(btn)

	return panel

func _on_boon_selected(boon_id: String) -> void:
	AudioManager.play_sfx("level_up")
	BoonDatabase.apply_boon(boon_id)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_close.bind(boon_id))

func _on_skip() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_close.bind(""))

func _close(boon_id: String) -> void:
	boon_chosen.emit(boon_id)
	queue_free()

func _get_quality_color(quality: String) -> Color:
	match quality:
		"凡品": return Color(0.7, 0.7, 0.7)
		"灵品": return Color(0.3, 0.8, 0.4)
		"宝品": return Color(0.3, 0.5, 1.0)
		"地品": return Color(0.7, 0.3, 1.0)
		"天品": return Color(1.0, 0.7, 0.1)
		"仙品": return Color(1.0, 0.3, 0.3)
		_: return Color(0.8, 0.8, 0.8)
