extends CanvasLayer
## BoonUI — Post-room boon selection screen
##
## Shows 3 random boon cards. Player clicks one to apply it.
## Emits boon_chosen(boon_id) when selection is made.

signal boon_chosen(boon_id: String)

var boon_options: Array[Dictionary] = []
var _spirit_root_color: Color = Color(0.7, 0.7, 0.9)  # Default fallback
var _fade_root: Control  # Wrapper for fade animations (CanvasLayer has no modulate)

# Spirit root color mapping (matches HUD.gd)
const SPIRIT_ROOT_COLORS: Dictionary = {
	0: Color(0.75, 0.75, 1.0),   # METAL — 银蓝
	1: Color(0.27, 0.80, 0.27),  # WOOD — 翠绿
	2: Color(0.27, 0.53, 1.0),   # WATER — 海蓝
	3: Color(1.0,  0.40, 0.20),  # FIRE — 烈橙
	4: Color(0.67, 0.53, 0.27),  # EARTH — 土黄
}

func _ready() -> void:
	layer = 18
	# Read player's spirit root color
	_spirit_root_color = SPIRIT_ROOT_COLORS.get(PlayerData.spiritual_root, Color(0.7, 0.7, 0.9))
	boon_options = BoonDatabase.get_random_boons(3)
	_build_ui()

func _build_ui() -> void:
	# Fade wrapper (CanvasLayer has no modulate, so use a Control)
	_fade_root = Control.new()
	_fade_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_root)

	# Full-screen darkened background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_root.add_child(bg)

	# Root container
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_left = 0.1
	root.anchor_right = 0.9
	root.anchor_top = 0.15
	root.anchor_bottom = 0.85
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	_fade_root.add_child(root)

	# Title
	var title := Label.new()
	title.text = "✦ 天道赐福 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择一项祝福"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	root.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	root.add_child(spacer)

	# Card container (horizontal)
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 30)
	root.add_child(card_row)

	# Create 3 boon cards
	for i in range(boon_options.size()):
		var card := _create_boon_card(boon_options[i], i)
		card_row.add_child(card)

	# Fade-in animation
	_fade_root.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_fade_root, "modulate:a", 1.0, 0.4)

func _create_boon_card(boon: Dictionary, index: int) -> PanelContainer:
	"""Create a clickable boon card."""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 360)

	# Style the panel — blend quality color with spirit root color (25%)
	var style := StyleBoxFlat.new()
	var rarity: int = boon.get("rarity", 0)
	var base_bg: Color
	var base_border: Color
	match rarity:
		0:  # Common — dark blue
			base_bg = Color(0.08, 0.08, 0.18, 0.95)
			base_border = Color(0.3, 0.3, 0.6)
		1:  # Rare — purple
			base_bg = Color(0.12, 0.05, 0.2, 0.95)
			base_border = Color(0.6, 0.3, 0.8)
		2:  # Legendary — gold
			base_bg = Color(0.15, 0.1, 0.02, 0.95)
			base_border = Color(0.9, 0.7, 0.2)
		_:
			base_bg = Color(0.08, 0.08, 0.18, 0.95)
			base_border = Color(0.3, 0.3, 0.6)
	# Mix spirit root color into background (25%) and border (20%)
	var spirit_bg := _spirit_root_color.darkened(0.7)  # Darken spirit color to keep card dark
	style.bg_color = base_bg.lerp(spirit_bg, 0.25)
	style.bg_color.a = 0.95
	style.border_color = base_border.lerp(_spirit_root_color, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Emoji icon
	var icon_label := Label.new()
	icon_label.text = boon.get("icon_emoji", "✦")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 56)
	vbox.add_child(icon_label)

	# Boon name (Chinese)
	var name_label := Label.new()
	name_label.text = boon.get("name_zh", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	vbox.add_child(name_label)

	# English name
	var en_label := Label.new()
	en_label.text = boon.get("name_en", "")
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en_label.add_theme_font_size_override("font_size", 14)
	en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(en_label)

	var sep := HSeparator.new()
	var sep_color := Color(0.3, 0.3, 0.5, 0.5).lerp(_spirit_root_color, 0.3)
	sep_color.a = 0.5
	sep.add_theme_color_override("separator", sep_color)
	vbox.add_child(sep)

	# Description
	var desc_label := Label.new()
	desc_label.text = boon.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Rarity label
	var rarity_names := ["凡品", "灵品", "仙品"]
	var rarity_colors := [Color(0.5, 0.5, 0.6), Color(0.6, 0.3, 0.8), Color(0.9, 0.7, 0.2)]
	var rarity_label := Label.new()
	rarity_label.text = rarity_names[clampi(rarity, 0, 2)]
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.add_theme_color_override("font_color", rarity_colors[clampi(rarity, 0, 2)])
	vbox.add_child(rarity_label)

	# Select button
	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_boon_selected.bind(boon["id"]))
	vbox.add_child(btn)

	return panel

func _on_boon_selected(boon_id: String) -> void:
	"""Player selected a boon — apply it and close UI."""
	AudioManager.play_sfx("level_up")
	BoonDatabase.apply_boon(boon_id)
	RunStats.boons_acquired += 1

	var boon := BoonDatabase.get_boon_by_id(boon_id)
	print("[BoonUI] Player chose: %s (%s)" % [boon.get("name_zh", boon_id), boon_id])

	# Fade out and remove
	var tween := create_tween()
	tween.tween_property(_fade_root, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_close.bind(boon_id))

func _close(boon_id: String) -> void:
	boon_chosen.emit(boon_id)
	queue_free()
