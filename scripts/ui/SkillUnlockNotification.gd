extends CanvasLayer
## SkillUnlockNotification — Shows a notification when the player learns a new skill
##
## Displays at right side: slides in from offscreen right, stays 3s, fades out
## Max 2 notifications visible at once; extras are queued
## Shows skill name, element color, and brief description
## Triggered by PlayerData.skill_learned or PlayerData.realm_changed signals

const MAX_VISIBLE: int = 2
const DISPLAY_DURATION: float = 3.0
const SLIDE_IN_DURATION: float = 0.35
const FADE_OUT_DURATION: float = 0.3
const NOTIFICATION_WIDTH: float = 320.0
const NOTIFICATION_SPACING: float = 10.0

var notification_queue: Array[Dictionary] = []
var active_notifications: Array[PanelContainer] = []

func _ready() -> void:
	layer = 25

	# Connect to realm_changed if available
	if PlayerData.has_signal("realm_changed"):
		PlayerData.realm_changed.connect(_on_realm_changed)

func show_skill_notification(skill_id: String) -> void:
	"""Queue a skill unlock notification for display."""
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	notification_queue.append(skill)
	_try_show_next()

func _on_realm_changed(realm: int, stage: int) -> void:
	"""When realm changes, check if new skills should be unlocked and notified."""
	# This signal is connected externally; the actual skill learning triggers
	# show_skill_notification via HUD._on_skill_learned
	pass

func _try_show_next() -> void:
	"""Show next queued notification if there's room."""
	while active_notifications.size() < MAX_VISIBLE and not notification_queue.is_empty():
		var skill: Dictionary = notification_queue.pop_front()
		_display_notification(skill)

func _display_notification(skill: Dictionary) -> void:
	var panel := PanelContainer.new()

	# Style: dark panel with element-colored glow border
	var element: String = skill.get("element", "")
	var elem_color := _get_element_color(element)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.1, 0.92)
	style.border_color = elem_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(elem_color.r, elem_color.g, elem_color.b, 0.4)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Skill name line
	var title := Label.new()
	title.text = "✦ 习得技能：%s" % skill.get("name_zh", "???")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# Description line
	var desc_text: String = skill.get("description", "")
	if desc_text.length() > 0:
		var desc := Label.new()
		desc.text = desc_text
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(NOTIFICATION_WIDTH - 50, 0)
		vbox.add_child(desc)

	# Element + SP cost info
	var sp_cost: float = skill.get("sp_cost", 0)
	var elem_name := _get_element_name(element)
	var info := Label.new()
	info.text = "灵力消耗 %.0f  |  %s系" % [sp_cost, elem_name]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", elem_color)
	vbox.add_child(info)

	# Position: right side, stacked based on active count
	var slot_index := active_notifications.size()
	var y_offset := 80.0 + slot_index * (70.0 + NOTIFICATION_SPACING)

	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(NOTIFICATION_WIDTH, 0)

	# Start offscreen to the right
	panel.offset_right = NOTIFICATION_WIDTH + 20
	panel.offset_left = 20
	panel.offset_top = y_offset

	add_child(panel)
	active_notifications.append(panel)

	# Slide in from right
	var target_right := -15.0
	var target_left := -(NOTIFICATION_WIDTH + 15.0)

	var tween := create_tween()
	tween.tween_property(panel, "offset_right", target_right, SLIDE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(panel, "offset_left", target_left, SLIDE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(DISPLAY_DURATION)
	# Fade out
	tween.tween_property(panel, "modulate:a", 0.0, FADE_OUT_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_notification_done.bind(panel))

func _on_notification_done(panel: PanelContainer) -> void:
	if panel in active_notifications:
		active_notifications.erase(panel)
	if is_instance_valid(panel):
		panel.queue_free()

	# Reposition remaining active notifications
	_reposition_active()

	# Try to show queued notifications
	_try_show_next()

func _reposition_active() -> void:
	"""Smoothly reposition remaining notifications to close gaps."""
	for i in range(active_notifications.size()):
		var panel: PanelContainer = active_notifications[i]
		if not is_instance_valid(panel):
			continue
		var target_y := 80.0 + i * (70.0 + NOTIFICATION_SPACING)
		var tween := create_tween()
		tween.tween_property(panel, "offset_top", target_y, 0.2).set_ease(Tween.EASE_OUT)

func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(0.9, 0.3, 0.1)
		"water": return Color(0.2, 0.5, 0.9)
		"metal": return Color(0.8, 0.8, 0.7)
		"wood": return Color(0.3, 0.8, 0.3)
		"earth": return Color(0.7, 0.55, 0.3)
		"lightning": return Color(0.7, 0.5, 1.0)
		_: return Color(0.7, 0.7, 0.7)

func _get_element_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"metal": return "金"
		"wood": return "木"
		"earth": return "土"
		"lightning": return "雷"
		_: return "无"
