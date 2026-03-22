extends Node3D

const MODEL_OPTIONS := {
	"Ren (Player)": "res://assets/external/ren/blender/Ren-fixed.glb",
	"Stella": "res://assets/external/downloads/stella/blender/Stella.glb",
	"LizardMan": "res://assets/external/downloads/lizard-man-warrior/blender/LizardManWarrior1.glb",
	"Sett": "res://assets/external/downloads/sett/blender/Sett.glb",
	"Leocetus": "res://assets/external/downloads/leocetus-leader/blender/LeocetusLeader.glb",
}

var model_anchor: Node3D = null
var current_model: Node3D = null
var anim_player: AnimationPlayer = null
var current_animation: String = ""

var model_picker: OptionButton = null
var anim_picker: OptionButton = null
var play_button: Button = null
var window_button: Button = null
var time_slider: HSlider = null
var speed_slider: HSlider = null
var speed_value: Label = null
var time_label: Label = null
var start_spin: SpinBox = null
var end_spin: SpinBox = null
var info_label: RichTextLabel = null

var _ignore_ui_updates: bool = false
var _preview_window_enabled: bool = false
var _last_animation_position: float = 0.0


func _ready() -> void:
	model_anchor = $ModelAnchor
	_build_ui()
	_populate_model_picker()
	_load_selected_model()
	set_process(true)


func _process(_delta: float) -> void:
	if anim_player == null or current_animation == "":
		return

	var animation := anim_player.get_animation(current_animation)
	if animation == null:
		return

	var current_pos := anim_player.current_animation_position
	if _preview_window_enabled and anim_player.is_playing():
		var start_time := float(start_spin.value)
		var end_time := float(end_spin.value)
		var wrapped := _last_animation_position > current_pos + 0.01
		if end_time > start_time and (current_pos < start_time - 0.01 or current_pos >= end_time - 0.01 or wrapped):
			anim_player.seek(start_time, true)
			current_pos = start_time

	_ignore_ui_updates = true
	time_slider.max_value = animation.length
	time_slider.value = current_pos
	time_label.text = "Time %.2f / %.2f" % [current_pos, animation.length]
	_ignore_ui_updates = false
	_last_animation_position = current_pos


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 456.0
	panel.offset_bottom = 416.0
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Animation Preview"
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "切模型、切动画、拖时间轴，直接指出哪一段像 Idle / Run / Attack。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	layout.add_child(_make_label("Model"))
	model_picker = OptionButton.new()
	model_picker.item_selected.connect(_on_model_selected)
	layout.add_child(model_picker)

	layout.add_child(_make_label("Animation"))
	anim_picker = OptionButton.new()
	anim_picker.item_selected.connect(_on_animation_selected)
	layout.add_child(anim_picker)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	layout.add_child(buttons)

	play_button = Button.new()
	play_button.text = "Pause"
	play_button.pressed.connect(_on_play_toggled)
	buttons.add_child(play_button)

	window_button = Button.new()
	window_button.text = "Window Off"
	window_button.pressed.connect(_on_window_toggled)
	buttons.add_child(window_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Range"
	reset_button.pressed.connect(_reset_range_to_animation)
	buttons.add_child(reset_button)

	layout.add_child(_make_label("Speed"))
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	layout.add_child(speed_row)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.1
	speed_slider.max_value = 2.0
	speed_slider.step = 0.05
	speed_slider.value = 1.0
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(speed_slider)

	speed_value = Label.new()
	speed_value.text = "1.00x"
	speed_row.add_child(speed_value)

	layout.add_child(_make_label("Timeline"))
	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 1.0
	time_slider.step = 0.01
	time_slider.value_changed.connect(_on_time_scrubbed)
	layout.add_child(time_slider)

	time_label = Label.new()
	time_label.text = "Time 0.00 / 0.00"
	layout.add_child(time_label)

	var range_row := HBoxContainer.new()
	range_row.add_theme_constant_override("separation", 8)
	layout.add_child(range_row)

	var start_box := VBoxContainer.new()
	range_row.add_child(start_box)
	start_box.add_child(_make_label("Start"))
	start_spin = SpinBox.new()
	start_spin.min_value = 0.0
	start_spin.step = 0.01
	start_spin.value_changed.connect(_on_range_changed)
	start_box.add_child(start_spin)

	var end_box := VBoxContainer.new()
	range_row.add_child(end_box)
	end_box.add_child(_make_label("End"))
	end_spin = SpinBox.new()
	end_spin.min_value = 0.0
	end_spin.step = 0.01
	end_spin.value_changed.connect(_on_range_changed)
	end_box.add_child(end_spin)

	info_label = RichTextLabel.new()
	info_label.custom_minimum_size = Vector2(0.0, 120.0)
	info_label.fit_content = true
	info_label.scroll_active = true
	layout.add_child(info_label)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _populate_model_picker() -> void:
	for label in MODEL_OPTIONS.keys():
		model_picker.add_item(label)


func _on_model_selected(_index: int) -> void:
	_load_selected_model()


func _load_selected_model() -> void:
	var model_label := model_picker.get_item_text(model_picker.selected)
	var path: String = MODEL_OPTIONS.get(model_label, "")
	if path == "":
		return

	if current_model != null:
		current_model.queue_free()
		current_model = null
		anim_player = null
		current_animation = ""

	current_model = _instantiate_model(path)
	if current_model == null:
		_set_info_text("[b]Load failed[/b]\n%s" % path)
		return

	model_anchor.add_child(current_model)
	anim_player = _find_animation_player(current_model)
	_populate_animation_picker(path)


func _instantiate_model(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			return scene.instantiate() as Node3D

	var abs_path := ProjectSettings.globalize_path(path)
	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var err := gltf_doc.append_from_file(abs_path, gltf_state)
	if err != OK:
		return null
	return gltf_doc.generate_scene(gltf_state) as Node3D


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _populate_animation_picker(path: String) -> void:
	anim_picker.clear()
	if anim_player == null:
		_set_info_text("[b]No AnimationPlayer[/b]\n%s" % path)
		return

	var anim_list := anim_player.get_animation_list()
	for anim_name in anim_list:
		anim_picker.add_item(anim_name)

	if anim_list.is_empty():
		_set_info_text("[b]No animations found[/b]\n%s" % path)
		return

	anim_picker.select(0)
	_set_info_text("[b]Model[/b] %s\n[b]Animations[/b]\n%s" % [
		path,
		"\n".join(anim_list),
	])
	_on_animation_selected(0)


func _on_animation_selected(index: int) -> void:
	if anim_player == null:
		return
	current_animation = anim_picker.get_item_text(index)
	var animation := anim_player.get_animation(current_animation)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE

	_ignore_ui_updates = true
	time_slider.max_value = animation.length
	time_slider.value = 0.0
	start_spin.max_value = animation.length
	end_spin.max_value = animation.length
	start_spin.value = 0.0
	end_spin.value = animation.length
	time_label.text = "Time 0.00 / %.2f" % animation.length
	_ignore_ui_updates = false

	anim_player.play(current_animation, 0.05, speed_slider.value)
	anim_player.seek(0.0, true)
	play_button.text = "Pause"
	_last_animation_position = 0.0


func _on_play_toggled() -> void:
	if anim_player == null or current_animation == "":
		return

	if anim_player.is_playing():
		anim_player.pause()
		play_button.text = "Play"
	else:
		anim_player.play(current_animation, 0.05, speed_slider.value)
		anim_player.seek(time_slider.value, true)
		play_button.text = "Pause"


func _on_window_toggled() -> void:
	_preview_window_enabled = not _preview_window_enabled
	window_button.text = "Window On" if _preview_window_enabled else "Window Off"
	if _preview_window_enabled and anim_player != null:
		anim_player.seek(start_spin.value, true)
		_last_animation_position = start_spin.value


func _on_speed_changed(value: float) -> void:
	speed_value.text = "%.2fx" % value
	if anim_player != null and current_animation != "":
		var pos := anim_player.current_animation_position
		anim_player.play(current_animation, 0.05, value)
		anim_player.seek(pos, true)
		_last_animation_position = pos


func _on_time_scrubbed(value: float) -> void:
	if _ignore_ui_updates or anim_player == null or current_animation == "":
		return
	anim_player.seek(value, true)
	time_label.text = "Time %.2f / %.2f" % [value, time_slider.max_value]
	_last_animation_position = value


func _on_range_changed(_value: float) -> void:
	if _ignore_ui_updates:
		return
	if end_spin.value < start_spin.value:
		end_spin.value = start_spin.value
	if _preview_window_enabled and anim_player != null:
		anim_player.seek(start_spin.value, true)
		_last_animation_position = start_spin.value


func _reset_range_to_animation() -> void:
	if anim_player == null or current_animation == "":
		return
	var animation := anim_player.get_animation(current_animation)
	if animation == null:
		return
	start_spin.value = 0.0
	end_spin.value = animation.length
	if _preview_window_enabled:
		anim_player.seek(0.0, true)
		_last_animation_position = 0.0


func _set_info_text(text: String) -> void:
	info_label.clear()
	info_label.append_text(text)
