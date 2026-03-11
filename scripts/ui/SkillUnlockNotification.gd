extends CanvasLayer
## SkillUnlockNotification — Shows a gold notification when the player learns a new skill
##
## Displays at top-center: "✦ 习得技能：[技能名]" with element color glow
## Slide-down animation, stays 2.5s, slides back up
## Queues multiple notifications for sequential display

var notification_queue: Array[Dictionary] = []
var is_showing: bool = false
var current_panel: PanelContainer = null

func _ready() -> void:
	layer = 25

func show_skill_notification(skill_id: String) -> void:
	"""Queue a skill unlock notification for display."""
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	notification_queue.append(skill)
	if not is_showing:
		_show_next()

func _show_next() -> void:
	if notification_queue.is_empty():
		is_showing = false
		return

	is_showing = true
	var skill: Dictionary = notification_queue.pop_front()
	_display_notification(skill)

func _display_notification(skill: Dictionary) -> void:
	var panel := PanelContainer.new()
	current_panel = panel

	# Style: dark panel with element-colored glow border
	var element: String = skill.get("element", "")
	var elem_color := _get_element_color(element)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.1, 0.92)
	style.border_color = elem_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	# Glow via shadow
	style.shadow_color = Color(elem_color.r, elem_color.g, elem_color.b, 0.4)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Main text
	var title := Label.new()
	title.text = "✦ 习得技能：%s" % skill.get("name_zh", "???")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# Sub info: SP cost + element
	var sp_cost: float = skill.get("sp_cost", 0)
	var elem_name := _get_element_name(element)
	var info := Label.new()
	info.text = "灵力消耗 %.0f  |  %s系" % [sp_cost, elem_name]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", elem_color)
	vbox.add_child(info)

	# Position at top-center, offscreen initially
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = -80
	add_child(panel)

	# Slide down animation
	var tween := create_tween()
	tween.tween_property(panel, "offset_top", 20.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(2.5)
	# Slide back up
	tween.tween_property(panel, "offset_top", -80.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_on_notification_done.bind(panel))

func _on_notification_done(panel: PanelContainer) -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	current_panel = null
	_show_next()

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
