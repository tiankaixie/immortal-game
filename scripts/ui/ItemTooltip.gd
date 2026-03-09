extends PanelContainer
## ItemTooltip — 物品悬浮提示框
##
## Shows item details on hover: name, rarity, slot, affixes, refinement, etc.
## Follows mouse position and stays within screen bounds.
## Style: dark purple background with gold border.

# ─── Constants ────────────────────────────────────────────────
const RARITY_COLORS: Dictionary = {
	0: Color.WHITE,         # MORTAL 凡品
	1: Color.GREEN,         # SPIRIT 灵品
	2: Color.DODGER_BLUE,   # TREASURE 宝品
	3: Color.MEDIUM_PURPLE, # EARTH 地品
	4: Color.GOLD,          # HEAVEN 天品
	5: Color.CRIMSON,       # IMMORTAL 仙品
}

const RARITY_NAMES: Dictionary = {
	0: "凡品", 1: "灵品", 2: "宝品", 3: "地品", 4: "天品", 5: "仙品",
}

const SLOT_NAMES_ZH: Dictionary = {
	"weapon": "法器",
	"armor": "法袍",
	"accessory_1": "灵佩",
	"accessory_2": "灵戒",
	"talisman": "护身符",
}

## Stat display names (Chinese)
const STAT_NAMES_ZH: Dictionary = {
	"hp": "生命",
	"attack": "攻击",
	"defense": "防御",
	"speed": "速度",
	"luck": "幸运",
	"spirit_power": "灵力",
	"crit_rate": "暴击率",
	"crit_damage": "暴击伤害",
}

const MOUSE_OFFSET := Vector2(16, 16)
const TOOLTIP_MAX_WIDTH: float = 280.0

# ─── State ────────────────────────────────────────────────────
var vbox: VBoxContainer = null

func _ready() -> void:
	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
	style.border_color = Color(0.7, 0.55, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(200, 0)
	size = Vector2.ZERO

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# Fade in
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

func show_item(item: Dictionary) -> void:
	"""Populate tooltip content from item data."""
	_clear()

	var rarity: int = item.get("rarity", 0)
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	# Item name (colored by rarity)
	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Rarity tier + slot type
	var info_parts: Array[String] = []
	var rarity_name: String = RARITY_NAMES.get(rarity, "")
	if rarity_name != "":
		info_parts.append(rarity_name)
	var slot: String = item.get("slot", "")
	var slot_name: String = SLOT_NAMES_ZH.get(slot, "")
	if slot_name != "":
		info_parts.append(slot_name)

	if info_parts.size() > 0:
		var info_label := Label.new()
		info_label.text = " · ".join(info_parts)
		info_label.add_theme_font_size_override("font_size", 13)
		info_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.8))
		info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(info_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.25, 0.5, 0.6))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Affixes
	var affixes: Array = item.get("affixes", [])
	for affix in affixes:
		var affix_label := Label.new()
		var stat_key: String = affix.get("stat", affix.get("id", ""))
		var stat_name: String = _get_stat_name(stat_key, affix.get("name", ""))
		var value = affix.get("value", 0)
		var affix_type: String = affix.get("type", "flat")

		if affix_type == "percent":
			affix_label.text = "%s +%s%%" % [stat_name, _format_number(value * 100)]
		else:
			affix_label.text = "%s +%s" % [stat_name, _format_number(value)]

		affix_label.add_theme_font_size_override("font_size", 13)
		affix_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		affix_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(affix_label)

	# Refinement level
	var refinement: int = item.get("refinement_level", 0)
	if refinement > 0:
		var ref_label := Label.new()
		ref_label.text = "精炼 +%d" % refinement
		ref_label.add_theme_font_size_override("font_size", 13)
		ref_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		ref_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(ref_label)

	# Soul-bound indicator
	var soul_bound: bool = item.get("soul_bound", false)
	if soul_bound:
		var sb_label := Label.new()
		sb_label.text = "已绑定"
		sb_label.add_theme_font_size_override("font_size", 12)
		sb_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		sb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sb_label)

	# Description
	var desc: String = item.get("description", item.get("desc", ""))
	if desc != "":
		var sep2 := HSeparator.new()
		sep2.add_theme_color_override("separator", Color(0.3, 0.25, 0.5, 0.4))
		sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sep2)

		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(TOOLTIP_MAX_WIDTH - 24, 0)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

func update_position(mouse_pos: Vector2) -> void:
	"""Position the tooltip near the mouse, clamped to screen bounds."""
	var viewport_size := get_viewport_rect().size
	var tooltip_size := size

	var pos := mouse_pos + MOUSE_OFFSET

	# Flip horizontally if near right edge
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - MOUSE_OFFSET.x

	# Flip vertically if near bottom edge
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - MOUSE_OFFSET.y

	# Clamp to screen
	pos.x = clampf(pos.x, 0, viewport_size.x - tooltip_size.x)
	pos.y = clampf(pos.y, 0, viewport_size.y - tooltip_size.y)

	position = pos

func _clear() -> void:
	"""Remove all content children."""
	for child in vbox.get_children():
		child.queue_free()

func _get_stat_name(stat_key: String, fallback_name: String) -> String:
	"""Look up Chinese stat name from key."""
	# Try direct match
	if STAT_NAMES_ZH.has(stat_key):
		return STAT_NAMES_ZH[stat_key]
	# Try stripping _flat/_pct suffixes
	var base_key := stat_key.replace("_flat", "").replace("_pct", "")
	if STAT_NAMES_ZH.has(base_key):
		return STAT_NAMES_ZH[base_key]
	# Fallback to affix name or raw key
	return fallback_name if fallback_name != "" else stat_key

func _format_number(value: float) -> String:
	"""Format a number: show as int if whole, otherwise 1 decimal."""
	if is_equal_approx(value, roundf(value)):
		return str(int(value))
	return "%.1f" % value
