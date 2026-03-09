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
const COMPARE_PANEL_WIDTH: float = 220.0

# ─── State ────────────────────────────────────────────────────
var vbox: VBoxContainer = null
var compare_panel: PanelContainer = null

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

func show_comparison(item: Dictionary) -> void:
	"""Show a comparison panel next to the tooltip if item has an equipment slot."""
	# Clean up any existing comparison panel
	if compare_panel != null and is_instance_valid(compare_panel):
		compare_panel.queue_free()
		compare_panel = null

	var slot: String = item.get("slot", "")
	if slot == "":
		return  # Not equippable, no comparison needed

	# Get the currently equipped item in this slot
	var equipped_item = PlayerData.equipped_items.get(slot)

	# Build comparison panel
	compare_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.95)
	style.border_color = Color(0.5, 0.4, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	compare_panel.add_theme_stylebox_override("panel", style)
	compare_panel.custom_minimum_size = Vector2(COMPARE_PANEL_WIDTH, 0)
	compare_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 3)
	cvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compare_panel.add_child(cvbox)

	# Header: "当前装备" with slot name
	var header := Label.new()
	var slot_name: String = SLOT_NAMES_ZH.get(slot, slot)
	header.text = "当前%s" % slot_name
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cvbox.add_child(header)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.25, 0.5, 0.6))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cvbox.add_child(sep)

	if equipped_item == null or not (equipped_item is Dictionary) or equipped_item.is_empty():
		# Nothing equipped
		var empty_label := Label.new()
		empty_label.text = "未装备"
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvbox.add_child(empty_label)
	else:
		# Show equipped item name
		var eq_name := Label.new()
		var eq_rarity: int = equipped_item.get("rarity", 0)
		eq_name.text = equipped_item.get("name", "???")
		eq_name.add_theme_font_size_override("font_size", 14)
		eq_name.add_theme_color_override("font_color", RARITY_COLORS.get(eq_rarity, Color.WHITE))
		eq_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvbox.add_child(eq_name)

		# Build stat comparison
		var hovered_stats := _collect_affix_stats(item)
		var equipped_stats := _collect_affix_stats(equipped_item)
		var all_stat_keys: Array[String] = []
		for k in hovered_stats:
			if k not in all_stat_keys:
				all_stat_keys.append(k)
		for k in equipped_stats:
			if k not in all_stat_keys:
				all_stat_keys.append(k)

		var sep2 := HSeparator.new()
		sep2.add_theme_color_override("separator", Color(0.3, 0.25, 0.5, 0.4))
		sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvbox.add_child(sep2)

		for stat_key in all_stat_keys:
			var hovered_val: float = hovered_stats.get(stat_key, 0.0)
			var equipped_val: float = equipped_stats.get(stat_key, 0.0)
			var diff: float = hovered_val - equipped_val
			var stat_name: String = _get_stat_name(stat_key, stat_key)

			var row := Label.new()
			row.add_theme_font_size_override("font_size", 12)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE

			if is_equal_approx(diff, 0.0):
				row.text = "%s: %s → %s" % [stat_name, _format_number(equipped_val), _format_number(hovered_val)]
				row.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			elif diff > 0:
				row.text = "%s: %s → %s ▲%s" % [stat_name, _format_number(equipped_val), _format_number(hovered_val), _format_number(diff)]
				row.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			else:
				row.text = "%s: %s → %s ▼%s" % [stat_name, _format_number(equipped_val), _format_number(hovered_val), _format_number(absf(diff))]
				row.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

			cvbox.add_child(row)

	# Add to parent (same parent as tooltip)
	if get_parent() != null:
		get_parent().add_child(compare_panel)

	# Fade in
	compare_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(compare_panel, "modulate:a", 1.0, 0.1)

func _collect_affix_stats(item: Dictionary) -> Dictionary:
	"""Collect all affix stats from an item into a flat {stat_key: value} dict."""
	var stats: Dictionary = {}
	var affixes: Array = item.get("affixes", [])
	for affix in affixes:
		var stat_key: String = affix.get("stat", affix.get("id", ""))
		var value: float = affix.get("value", 0.0)
		var affix_type: String = affix.get("type", "flat")
		# Use a display key that includes type to avoid collisions
		var key: String = stat_key + ("_pct" if affix_type == "percent" else "")
		stats[key] = stats.get(key, 0.0) + value
	return stats

func hide_comparison() -> void:
	"""Remove the comparison panel."""
	if compare_panel != null and is_instance_valid(compare_panel):
		compare_panel.queue_free()
		compare_panel = null

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

	# Position comparison panel to the right (or left) of tooltip
	if compare_panel != null and is_instance_valid(compare_panel):
		var cp_pos := Vector2(pos.x + tooltip_size.x + 8, pos.y)
		# Flip to left if no space on right
		if cp_pos.x + compare_panel.size.x > viewport_size.x:
			cp_pos.x = pos.x - compare_panel.size.x - 8
		# Clamp vertically
		cp_pos.y = clampf(cp_pos.y, 0, viewport_size.y - compare_panel.size.y)
		compare_panel.position = cp_pos

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
