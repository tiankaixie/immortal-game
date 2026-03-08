extends CanvasLayer
## InventoryUI — Backpack and equipment overlay
##
## Shows inventory items and equipped gear.
## Press Tab to toggle. Click equippable items to wear them.
## Style: dark purple / gold border, consistent with MerchantUI.

# ─── Signals ──────────────────────────────────────────────────
signal closed()

# ─── Constants ────────────────────────────────────────────────
const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "accessory_1", "accessory_2", "talisman"]
const SLOT_NAMES_ZH: Dictionary = {
	"weapon": "法器",
	"armor": "法袍",
	"accessory_1": "灵佩",
	"accessory_2": "灵戒",
	"talisman": "护身符",
}

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

# ─── State ────────────────────────────────────────────────────
var inventory_vbox: VBoxContainer = null
var equip_vbox: VBoxContainer = null

func _ready() -> void:
	_build_ui()
	PlayerData.inventory_changed.connect(_refresh)
	PlayerData.equipment_changed.connect(func(_slot): _refresh())

func _build_ui() -> void:
	"""Construct the inventory UI programmatically."""
	# Dark background overlay
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Main panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -260
	panel.offset_bottom = 260
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
	panel_style.border_color = Color(0.7, 0.55, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(outer_vbox)

	# Title
	var title := Label.new()
	title.text = "✦ 储物袋 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer_vbox.add_child(title)

	# Two-column layout: equipment (left) | inventory (right)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(columns)

	# ── Left column: equipped items ──
	var left_panel := _create_section_panel("已装备")
	columns.add_child(left_panel)
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(260, 0)
	left_panel.add_child(left_scroll)
	equip_vbox = VBoxContainer.new()
	equip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_vbox.add_theme_constant_override("separation", 6)
	left_scroll.add_child(equip_vbox)

	# ── Right column: inventory ──
	var right_panel := _create_section_panel("背包")
	columns.add_child(right_panel)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size = Vector2(340, 0)
	right_panel.add_child(right_scroll)
	inventory_vbox = VBoxContainer.new()
	inventory_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_vbox.add_theme_constant_override("separation", 4)
	right_scroll.add_child(inventory_vbox)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "关闭  [Tab]"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close)
	outer_vbox.add_child(close_btn)

	# Populate
	_refresh()

	# Fade in
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func _create_section_panel(header_text: String) -> VBoxContainer:
	"""Create a labeled section container."""
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	var header := Label.new()
	header.text = "── %s ──" % header_text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	vbox.add_child(header)
	return vbox

func _refresh() -> void:
	"""Rebuild both equipment and inventory displays."""
	_refresh_equipment()
	_refresh_inventory()

func _refresh_equipment() -> void:
	"""Show all 5 equipment slots."""
	if equip_vbox == null:
		return
	for child in equip_vbox.get_children():
		child.queue_free()
	await get_tree().process_frame

	for slot in EQUIP_SLOTS:
		var item = PlayerData.equipped_items.get(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Slot name
		var slot_label := Label.new()
		slot_label.text = SLOT_NAMES_ZH.get(slot, slot)
		slot_label.custom_minimum_size = Vector2(60, 0)
		slot_label.add_theme_font_size_override("font_size", 14)
		slot_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.8))
		row.add_child(slot_label)

		if item != null and item is Dictionary and not item.is_empty():
			var name_label := Label.new()
			name_label.text = item.get("name", "???")
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 14)
			var rarity: int = item.get("rarity", 0)
			name_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
			row.add_child(name_label)

			# Unequip button
			var unequip_btn := Button.new()
			unequip_btn.text = "卸下"
			unequip_btn.custom_minimum_size = Vector2(50, 26)
			unequip_btn.add_theme_font_size_override("font_size", 12)
			unequip_btn.pressed.connect(_on_unequip.bind(slot))
			row.add_child(unequip_btn)
		else:
			var empty_label := Label.new()
			empty_label.text = "— 空 —"
			empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_label.add_theme_font_size_override("font_size", 14)
			empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			row.add_child(empty_label)

		equip_vbox.add_child(row)

func _refresh_inventory() -> void:
	"""Show all items in player inventory."""
	if inventory_vbox == null:
		return
	for child in inventory_vbox.get_children():
		child.queue_free()
	await get_tree().process_frame

	if PlayerData.inventory.size() == 0:
		var empty := Label.new()
		empty.text = "储物袋空空如也"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		inventory_vbox.add_child(empty)
		return

	for i in range(PlayerData.inventory.size()):
		var item: Dictionary = PlayerData.inventory[i]
		var row := _create_inventory_row(item, i)
		inventory_vbox.add_child(row)

func _create_inventory_row(item: Dictionary, index: int) -> HBoxContainer:
	"""Create a row for an inventory item."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Item name with rarity color
	var rarity: int = item.get("rarity", 0)
	var name_label := Label.new()
	var rarity_tag: String = RARITY_NAMES.get(rarity, "")
	name_label.text = "%s" % item.get("name", "???")
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	row.add_child(name_label)

	# Description
	var desc_label := Label.new()
	var desc: String = item.get("description", item.get("desc", ""))
	if desc.length() > 24:
		desc = desc.substr(0, 24) + "…"
	desc_label.text = desc
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	row.add_child(desc_label)

	# Equip button (only for items with a slot field)
	var slot: String = item.get("slot", "")
	if slot != "" and slot in EQUIP_SLOTS:
		var equip_btn := Button.new()
		equip_btn.text = "装备"
		equip_btn.custom_minimum_size = Vector2(50, 26)
		equip_btn.add_theme_font_size_override("font_size", 12)
		equip_btn.pressed.connect(_on_equip.bind(index))
		row.add_child(equip_btn)

	return row

# ─── Equip / Unequip ─────────────────────────────────────────
func _on_equip(inventory_index: int) -> void:
	"""Equip an item from inventory."""
	if inventory_index < 0 or inventory_index >= PlayerData.inventory.size():
		return
	var item: Dictionary = PlayerData.inventory[inventory_index]
	var slot: String = item.get("slot", "")
	if slot == "" or slot not in EQUIP_SLOTS:
		return

	# Swap: move currently equipped item back to inventory
	var old_item = PlayerData.equipped_items.get(slot)
	if old_item != null and old_item is Dictionary and not old_item.is_empty():
		PlayerData.inventory.append(old_item)

	# Remove from inventory and equip
	PlayerData.inventory.remove_at(inventory_index)
	PlayerData.equipped_items[slot] = item
	PlayerData.equipment_changed.emit(slot)
	PlayerData.inventory_changed.emit()
	print("[InventoryUI] Equipped: %s → %s" % [item.get("name", "?"), slot])

func _on_unequip(slot: String) -> void:
	"""Unequip an item back to inventory."""
	var item = PlayerData.equipped_items.get(slot)
	if item == null or not (item is Dictionary) or item.is_empty():
		return
	if PlayerData.inventory.size() >= PlayerData.max_inventory_size:
		print("[InventoryUI] Inventory full, cannot unequip")
		return
	PlayerData.inventory.append(item)
	PlayerData.equipped_items[slot] = null
	PlayerData.equipment_changed.emit(slot)
	PlayerData.inventory_changed.emit()
	print("[InventoryUI] Unequipped: %s from %s" % [item.get("name", "?"), slot])

# ─── Input ────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()

func _on_close() -> void:
	"""Close inventory with fade-out."""
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)
