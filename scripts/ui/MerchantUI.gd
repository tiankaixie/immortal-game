extends CanvasLayer
## MerchantUI — Shop overlay for the dungeon merchant
##
## Displays merchant stock as a list of buyable items.
## Player clicks "购买" to buy; spirit stones are deducted via PlayerData.
## Press Escape or click "关闭" to close.

# ─── Signals ──────────────────────────────────────────────────
signal closed()
signal item_purchased(item_index: int)

# ─── Tooltip ─────────────────────────────────────────────────
const ItemTooltipScene := preload("res://scenes/ui/ItemTooltip.tscn")
var _tooltip: PanelContainer = null

# ─── State ────────────────────────────────────────────────────
var stock: Array[Dictionary] = []
var item_rows: Array[HBoxContainer] = []
var stones_label: Label = null
var content_vbox: VBoxContainer = null

func _ready() -> void:
	# Retrieve stock from meta (set by Merchant.gd before adding to tree)
	var meta_stock = get_meta("merchant_stock")
	if meta_stock is Array:
		for item in meta_stock:
			stock.append(item)

	_build_ui()

func _build_ui() -> void:
	"""Construct the full shop UI programmatically."""
	# Dark background overlay
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Main panel centered on screen
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -220
	panel.offset_bottom = 220
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
	title.text = "✦ 灵宝阁 · 行商 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer_vbox.add_child(title)

	# Spirit stones display
	stones_label = Label.new()
	stones_label.text = "灵石: %d" % PlayerData.spirit_stones
	stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stones_label.add_theme_font_size_override("font_size", 16)
	stones_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	outer_vbox.add_child(stones_label)

	# Separator
	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# Scrollable item list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	outer_vbox.add_child(scroll)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(content_vbox)

	# Populate item rows
	_populate_items()

	# Close button
	var close_btn := Button.new()
	close_btn.text = "关闭  [Esc]"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close)
	outer_vbox.add_child(close_btn)

	# Fade in
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func _populate_items() -> void:
	"""Create a row for each item in stock."""
	# Clear existing rows
	for row in item_rows:
		if is_instance_valid(row):
			row.queue_free()
	item_rows.clear()

	if stock.size() == 0:
		var empty_label := Label.new()
		empty_label.text = "商人已无货物"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content_vbox.add_child(empty_label)
		return

	for i in range(stock.size()):
		var item: Dictionary = stock[i]
		var row := _create_item_row(item, i)
		content_vbox.add_child(row)
		item_rows.append(row)

func _create_item_row(item: Dictionary, index: int) -> HBoxContainer:
	"""Create a single item row: name | description | price | buy button."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Item name
	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	row.add_child(name_label)

	# Description (truncated)
	var desc_label := Label.new()
	var desc: String = item.get("description", item.get("desc", ""))
	if desc.length() > 20:
		desc = desc.substr(0, 20) + "…"
	desc_label.text = desc
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	row.add_child(desc_label)

	# Price
	var price: int = item.get("price", 0)
	var price_label := Label.new()
	price_label.text = "%d 灵石" % price
	price_label.custom_minimum_size = Vector2(80, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_font_size_override("font_size", 14)
	var can_afford := PlayerData.spirit_stones >= price
	price_label.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.4) if can_afford else Color(0.8, 0.3, 0.3))
	row.add_child(price_label)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(60, 30)
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.disabled = not can_afford
	buy_btn.pressed.connect(_on_buy_pressed.bind(index))
	row.add_child(buy_btn)

	# Tooltip hover
	row.mouse_entered.connect(_on_item_hover.bind(item))
	row.mouse_exited.connect(_on_item_unhover)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	return row

# ─── Tooltip ──────────────────────────────────────────────────
func _on_item_hover(item: Dictionary) -> void:
	"""Show tooltip for hovered item."""
	_on_item_unhover()
	_tooltip = ItemTooltipScene.instantiate()
	add_child(_tooltip)
	_tooltip.show_item(item)
	_tooltip.show_comparison(item)
	_tooltip.update_position(get_viewport().get_mouse_position())

func _on_item_unhover() -> void:
	"""Hide the tooltip."""
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.hide_comparison()
		_tooltip.queue_free()
		_tooltip = null

func _process(_delta: float) -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.update_position(get_viewport().get_mouse_position())

func _on_buy_pressed(index: int) -> void:
	"""Handle buying an item."""
	if index < 0 or index >= stock.size():
		return

	var item: Dictionary = stock[index]
	var price: int = item.get("price", 0)

	if not PlayerData.spend_spirit_stones(price):
		print("[MerchantUI] Not enough spirit stones")
		return

	# Add to player inventory
	PlayerData.inventory.append(item)
	PlayerData.inventory_changed.emit()

	# Remove from stock
	stock.remove_at(index)
	item_purchased.emit(index)

	# Refresh display
	_refresh_after_purchase()

	AudioManager.play_sfx("purchase")
	print("[MerchantUI] Purchased: %s for %d stones" % [item.get("name", "?"), price])

func _refresh_after_purchase() -> void:
	"""Rebuild item list and update stones display."""
	if stones_label:
		stones_label.text = "灵石: %d" % PlayerData.spirit_stones

	# Clear and repopulate
	for child in content_vbox.get_children():
		child.queue_free()
	item_rows.clear()

	# Wait a frame for queue_free to process, then repopulate
	await get_tree().process_frame
	_populate_items()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()

func _on_close() -> void:
	"""Close the shop UI with fade-out."""
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)
