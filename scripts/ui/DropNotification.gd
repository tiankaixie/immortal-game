extends Control
## DropNotification — Item drop notification system
##
## Shows slide-in notifications at bottom-right when items are obtained.
## Format: "获得：[品质] 物品名称"
## Max 3 visible at once, queued if more.

const MAX_VISIBLE: int = 3
const DISPLAY_DURATION: float = 2.5
const SLIDE_DURATION: float = 0.3
const FADE_DURATION: float = 0.4
const NOTIFICATION_HEIGHT: float = 40.0
const NOTIFICATION_SPACING: float = 6.0
const NOTIFICATION_WIDTH: float = 300.0
const RIGHT_MARGIN: float = 20.0
const BOTTOM_MARGIN: float = 100.0

# Quality color mapping
const QUALITY_COLORS: Dictionary = {
	"凡品": Color(0.7, 0.7, 0.7),        # Gray
	"灵品": Color(0.3, 0.8, 0.4),        # Green
	"玄品": Color(0.3, 0.5, 1.0),        # Blue
	"地品": Color(0.7, 0.3, 1.0),        # Purple
	"天品": Color(1.0, 0.7, 0.1),        # Gold
	"仙品": Color(1.0, 0.3, 0.3),        # Red
}

# Active notification labels
var active_notifications: Array[Control] = []
var notification_queue: Array[Dictionary] = []

# Track seen items for "new item" detection
var seen_item_names: Dictionary = {}

func _ready() -> void:
	# Listen for inventory changes
	PlayerData.inventory_changed.connect(_on_inventory_changed)
	# Initialize seen items from current inventory
	for item in PlayerData.inventory:
		var item_name: String = item.get("name", "")
		if item_name != "":
			seen_item_names[item_name] = true

func _on_inventory_changed() -> void:
	"""Check for new items added to inventory and show notifications."""
	# Scan inventory for items we haven't seen
	for item in PlayerData.inventory:
		var item_name: String = item.get("name", "")
		if item_name == "":
			continue
		if not seen_item_names.has(item_name):
			seen_item_names[item_name] = true
			var quality: String = item.get("quality", "凡品")
			show_drop(item_name, quality)

func show_drop(item_name: String, quality: String = "凡品") -> void:
	"""Queue a drop notification. If slots available, show immediately."""
	var data := {"name": item_name, "quality": quality}
	if active_notifications.size() < MAX_VISIBLE:
		_create_notification(data)
	else:
		notification_queue.append(data)

func _create_notification(data: Dictionary) -> void:
	"""Create and animate a notification panel."""
	var item_name: String = data["name"]
	var quality: String = data["quality"]
	var quality_color: Color = QUALITY_COLORS.get(quality, Color(0.7, 0.7, 0.7))

	# Panel container
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.15, 0.9)
	style.border_color = quality_color * 0.8
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	# Label with formatted text
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color_hex := quality_color.to_html(false)
	label.text = "获得：[color=#%s][%s] %s[/color]" % [color_hex, quality, item_name]
	label.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(label)

	# Position: bottom-right, stacked above existing notifications
	var viewport_size := get_viewport_rect().size
	var slot_index := active_notifications.size()
	var target_y := viewport_size.y - BOTTOM_MARGIN - (slot_index + 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_SPACING)
	var target_x := viewport_size.x - RIGHT_MARGIN - NOTIFICATION_WIDTH

	panel.position = Vector2(viewport_size.x + 10, target_y)  # Start off-screen right
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(panel)
	active_notifications.append(panel)

	# Animate: slide in from right
	var tween := create_tween()
	tween.tween_property(panel, "position:x", target_x, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func():
		_remove_notification(panel)
	)

func _remove_notification(panel: Control) -> void:
	"""Remove a notification and process queue."""
	var idx := active_notifications.find(panel)
	if idx >= 0:
		active_notifications.remove_at(idx)
	if is_instance_valid(panel):
		panel.queue_free()

	# Reposition remaining notifications
	_reposition_active()

	# Process queue
	if notification_queue.size() > 0 and active_notifications.size() < MAX_VISIBLE:
		var next_data := notification_queue.pop_front() as Dictionary
		_create_notification(next_data)

func _reposition_active() -> void:
	"""Smoothly reposition active notifications after one is removed."""
	var viewport_size := get_viewport_rect().size
	for i in range(active_notifications.size()):
		var panel: Control = active_notifications[i]
		if not is_instance_valid(panel):
			continue
		var target_y := viewport_size.y - BOTTOM_MARGIN - (i + 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_SPACING)
		var tween := create_tween()
		tween.tween_property(panel, "position:y", target_y, 0.2).set_ease(Tween.EASE_OUT)
