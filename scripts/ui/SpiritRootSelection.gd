extends Control
## SpiritRootSelection — 灵根选择界面
##
## Displayed after clicking "新的修仙" in MainMenu.
## Player selects one of five elemental spiritual roots before starting the game.
## All UI is built procedurally in code (no external assets).

const CARD_WIDTH := 180.0
const CARD_HEIGHT := 280.0
const CARD_GAP := 16.0

# Element data for the 5 base roots + 2 unlockable
const ROOT_DATA := [
	{
		"root": PlayerData.SpiritualRoot.METAL,
		"char": "金",
		"name": "金灵根",
		"element": "金系 · Metal",
		"bonus": "攻击力 +10%",
		"skill": "起始技能：金剑斩",
		"color": Color(0.75, 0.75, 1.0),       # #C0C0FF
		"color_hex": "#C0C0FF",
		"unlock_id": "",
	},
	{
		"root": PlayerData.SpiritualRoot.WOOD,
		"char": "木",
		"name": "木灵根",
		"element": "木系 · Wood",
		"bonus": "治疗效果 +20%",
		"skill": "起始技能：木灵愈",
		"color": Color(0.267, 0.8, 0.267),     # #44CC44
		"color_hex": "#44CC44",
		"unlock_id": "",
	},
	{
		"root": PlayerData.SpiritualRoot.WATER,
		"char": "水",
		"name": "水灵根",
		"element": "水系 · Water",
		"bonus": "防御力 +10%",
		"skill": "起始技能：寒冰剑",
		"color": Color(0.267, 0.533, 1.0),     # #4488FF
		"color_hex": "#4488FF",
		"unlock_id": "",
	},
	{
		"root": PlayerData.SpiritualRoot.FIRE,
		"char": "火",
		"name": "火灵根",
		"element": "火系 · Fire",
		"bonus": "范围伤害 +15%",
		"skill": "起始技能：火球术",
		"color": Color(1.0, 0.4, 0.2),         # #FF6633
		"color_hex": "#FF6633",
		"unlock_id": "",
	},
	{
		"root": PlayerData.SpiritualRoot.EARTH,
		"char": "土",
		"name": "土灵根",
		"element": "土系 · Earth",
		"bonus": "生命值 +20%",
		"skill": "起始技能：金剑斩",
		"color": Color(0.667, 0.533, 0.267),   # #AA8844
		"color_hex": "#AA8844",
		"unlock_id": "",
	},
	{
		"root": PlayerData.SpiritualRoot.LIGHTNING,
		"char": "雷",
		"name": "雷灵根",
		"element": "雷系 · Thunder",
		"bonus": "攻击+8% · 移速+20% · 麻痹技能",
		"skill": "起始技能：天雷掌 · 锁链雷",
		"color": Color(0.6, 0.4, 1.0),         # #9966FF
		"color_hex": "#9966FF",
		"unlock_id": "spirit_root_thunder",
	},
	{
		"root": PlayerData.SpiritualRoot.VOID,
		"char": "虚",
		"name": "虚灵根",
		"element": "虚系 · Void",
		"bonus": "攻击+12% · 移速+10% · 瞬移暗杀",
		"skill": "起始技能：虚影步 · 虚空吸髓",
		"color": Color(0.667, 0.733, 0.8),     # #AABBCC
		"color_hex": "#AABBCC",
		"unlock_id": "spirit_root_void",
	},
]

var _selected_index: int = -1
var _cards: Array[Control] = []
var _card_borders: Array[ColorRect] = []
var _card_locked: Array[bool] = []
var _confirm_btn: Button
var _back_btn: Button

# ─── Particle FX ──────────────────────────────────────────────
var _hover_particles: Array[GPUParticles2D] = []
var _burst_particles: Array[GPUParticles2D] = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()
	print("[SpiritRootSelection] Ready")

func _build_ui() -> void:
	# ── Background ──
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Title ──
	var title := Label.new()
	title.text = "选 择 灵 根"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40.0
	title.offset_bottom = 100.0
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1.0))
	add_child(title)

	# ── Subtitle ──
	var subtitle := Label.new()
	subtitle.text = "你的修仙之路由此开始"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 95.0
	subtitle.offset_bottom = 130.0
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.8))
	add_child(subtitle)

	# ── Cards container ──
	var total_width: float = ROOT_DATA.size() * CARD_WIDTH + (ROOT_DATA.size() - 1) * CARD_GAP
	var cards_container := Control.new()
	cards_container.set_anchors_preset(Control.PRESET_CENTER)
	cards_container.offset_left = -total_width / 2.0
	cards_container.offset_top = -CARD_HEIGHT / 2.0 - 20.0
	cards_container.offset_right = total_width / 2.0
	cards_container.offset_bottom = CARD_HEIGHT / 2.0 - 20.0
	add_child(cards_container)

	for i in range(ROOT_DATA.size()):
		var data: Dictionary = ROOT_DATA[i]
		var is_locked := false
		var unlock_id: String = data.get("unlock_id", "")
		if unlock_id != "" and not UnlockSystem.is_unlocked(unlock_id):
			is_locked = true
		_card_locked.append(is_locked)

		var card := _create_card(i, is_locked)
		card.position = Vector2(i * (CARD_WIDTH + CARD_GAP), 0)
		cards_container.add_child(card)
		_cards.append(card)

		# Create hover + burst particles for each card
		var elem_color: Color = data["color"]
		if is_locked:
			elem_color = Color(0.3, 0.3, 0.3)
		var card_center := card.position + Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)

		var hover_p := _create_element_particles(elem_color, 20, 1.0, false)
		hover_p.position = card_center
		hover_p.emitting = false
		cards_container.add_child(hover_p)
		_hover_particles.append(hover_p)

		var burst_p := _create_element_particles(elem_color, 60, 0.8, true)
		burst_p.position = card_center
		burst_p.emitting = false
		cards_container.add_child(burst_p)
		_burst_particles.append(burst_p)

	# ── Bottom buttons container ──
	var btn_container := HBoxContainer.new()
	btn_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_container.offset_top = -80.0
	btn_container.offset_bottom = -30.0
	btn_container.offset_left = -200.0
	btn_container.offset_right = 200.0
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 30)
	add_child(btn_container)

	# Back button
	_back_btn = Button.new()
	_back_btn.text = "返回"
	_back_btn.custom_minimum_size = Vector2(120, 45)
	_back_btn.add_theme_font_size_override("font_size", 20)
	_back_btn.pressed.connect(_on_back)
	btn_container.add_child(_back_btn)

	# Random button
	var random_btn := Button.new()
	random_btn.text = "随机"
	random_btn.custom_minimum_size = Vector2(120, 45)
	random_btn.add_theme_font_size_override("font_size", 20)
	random_btn.pressed.connect(_on_random)
	btn_container.add_child(random_btn)

	# Confirm button (hidden until selection)
	_confirm_btn = Button.new()
	_confirm_btn.text = "确认"
	_confirm_btn.custom_minimum_size = Vector2(140, 45)
	_confirm_btn.add_theme_font_size_override("font_size", 22)
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm)
	# Gold-ish styling via modulate
	_confirm_btn.modulate = Color(1.0, 0.9, 0.5, 1.0)
	btn_container.add_child(_confirm_btn)

func _create_card(index: int, is_locked: bool = false) -> Control:
	var data: Dictionary = ROOT_DATA[index]
	var elem_color: Color = data["color"]
	var locked_gray := Color(0.35, 0.35, 0.4)

	# Root container for the card
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Border (glow effect for selected)
	var border := ColorRect.new()
	border.color = Color(0.15, 0.15, 0.2, 0.6) if is_locked else Color(0.2, 0.15, 0.3, 0.6)
	border.position = Vector2(-3, -3)
	border.size = Vector2(CARD_WIDTH + 6, CARD_HEIGHT + 6)
	card.add_child(border)
	_card_borders.append(border)

	# Card background
	var card_bg := ColorRect.new()
	card_bg.color = Color(0.08, 0.08, 0.1, 0.95) if is_locked else Color(0.1, 0.08, 0.15, 0.95)
	card_bg.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_child(card_bg)

	# Top accent line
	var accent := ColorRect.new()
	accent.color = locked_gray if is_locked else elem_color
	accent.size = Vector2(CARD_WIDTH, 3)
	card.add_child(accent)

	if is_locked:
		# ── Locked card layout ──
		# Lock icon
		var lock_label := Label.new()
		lock_label.text = "🔒"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.position = Vector2(0, 30)
		lock_label.size = Vector2(CARD_WIDTH, 60)
		lock_label.add_theme_font_size_override("font_size", 48)
		card.add_child(lock_label)

		# Root name (grayed)
		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, 100)
		name_label.size = Vector2(CARD_WIDTH, 30)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", locked_gray)
		card.add_child(name_label)

		# Divider
		var divider := ColorRect.new()
		divider.color = Color(0.3, 0.3, 0.35, 0.3)
		divider.position = Vector2(20, 140)
		divider.size = Vector2(CARD_WIDTH - 40, 1)
		card.add_child(divider)

		# Unlock condition text
		var unlock_id: String = data.get("unlock_id", "")
		var condition_text := "未知条件"
		var definition := UnlockSystem.get_definition(unlock_id)
		if not definition.is_empty():
			condition_text = definition.get("condition_text", condition_text)

		var cond_label := Label.new()
		cond_label.text = "解锁条件:\n" + condition_text
		cond_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cond_label.position = Vector2(5, 155)
		cond_label.size = Vector2(CARD_WIDTH - 10, 80)
		cond_label.add_theme_font_size_override("font_size", 14)
		cond_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 0.8))
		cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(cond_label)
	else:
		# ── Normal unlocked card layout ──
		# Element character (large)
		var char_label := Label.new()
		char_label.text = data["char"]
		char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		char_label.position = Vector2(0, 20)
		char_label.size = Vector2(CARD_WIDTH, 80)
		char_label.add_theme_font_size_override("font_size", 64)
		char_label.add_theme_color_override("font_color", elem_color)
		card.add_child(char_label)

		# Root name
		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, 105)
		name_label.size = Vector2(CARD_WIDTH, 30)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		card.add_child(name_label)

		# Element name
		var elem_label := Label.new()
		elem_label.text = data["element"]
		elem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elem_label.position = Vector2(0, 135)
		elem_label.size = Vector2(CARD_WIDTH, 24)
		elem_label.add_theme_font_size_override("font_size", 14)
		elem_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 0.8))
		card.add_child(elem_label)

		# Divider
		var divider := ColorRect.new()
		divider.color = elem_color * Color(1, 1, 1, 0.3)
		divider.position = Vector2(20, 168)
		divider.size = Vector2(CARD_WIDTH - 40, 1)
		card.add_child(divider)

		# Bonus description
		var bonus_label := Label.new()
		bonus_label.text = data["bonus"]
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_label.position = Vector2(0, 180)
		bonus_label.size = Vector2(CARD_WIDTH, 30)
		bonus_label.add_theme_font_size_override("font_size", 16)
		bonus_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		card.add_child(bonus_label)

		# Starting skill
		var skill_label := Label.new()
		skill_label.text = data["skill"]
		skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_label.position = Vector2(0, 215)
		skill_label.size = Vector2(CARD_WIDTH, 30)
		skill_label.add_theme_font_size_override("font_size", 14)
		skill_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
		card.add_child(skill_label)

	# Connect mouse events
	card.gui_input.connect(_on_card_input.bind(index))
	card.mouse_entered.connect(_on_card_hover.bind(index, true))
	card.mouse_exited.connect(_on_card_hover.bind(index, false))

	return card

func _on_card_hover(index: int, entering: bool) -> void:
	var card := _cards[index]
	var tween := create_tween()
	if entering:
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)
		if index != _selected_index:
			_card_borders[index].color = Color(0.4, 0.3, 0.6, 0.8)
		# Start hover particles
		if index < _hover_particles.size():
			_hover_particles[index].emitting = true
	else:
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		if index != _selected_index:
			_card_borders[index].color = Color(0.2, 0.15, 0.3, 0.6)
		# Stop hover particles
		if index < _hover_particles.size():
			_hover_particles[index].emitting = false

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index < _card_locked.size() and _card_locked[index]:
			return  # Can't select locked cards
		_select_card(index)

func _select_card(index: int) -> void:
	# Deselect previous
	if _selected_index >= 0:
		_card_borders[_selected_index].color = Color(0.2, 0.15, 0.3, 0.6)

	_selected_index = index
	var data: Dictionary = ROOT_DATA[index]

	# Highlight selected card border with element color
	_card_borders[index].color = data["color"]

	# Show confirm button
	_confirm_btn.visible = true
	_confirm_btn.text = "确认 · %s" % data["name"]

	# Trigger burst particles on selection
	if index < _burst_particles.size():
		_burst_particles[index].restart()
		_burst_particles[index].emitting = true

	print("[SpiritRootSelection] Selected: %s" % data["name"])

func _on_random() -> void:
	# Only pick from unlocked cards
	var available: Array[int] = []
	for i in range(ROOT_DATA.size()):
		if i < _card_locked.size() and not _card_locked[i]:
			available.append(i)
	if available.is_empty():
		return
	var rand_index := available[randi() % available.size()]
	_select_card(rand_index)

func _on_back() -> void:
	GameManager.goto_scene("res://scenes/ui/MainMenu.tscn")

func _on_confirm() -> void:
	if _selected_index < 0:
		return

	var data: Dictionary = ROOT_DATA[_selected_index]
	var root: PlayerData.SpiritualRoot = data["root"]

	# Reset PlayerData for new game
	PlayerData.spiritual_root = root
	PlayerData.cultivation_realm = PlayerData.CultivationRealm.QI_CONDENSATION
	PlayerData.cultivation_stage = PlayerData.CultivationStage.EARLY
	PlayerData.cultivation_xp = 0.0
	PlayerData.spirit_stones = 0
	PlayerData.sp = PlayerData.sp_max
	PlayerData.inventory.clear()
	PlayerData.equipped_items = {
		"weapon": null,
		"armor": null,
		"accessory_1": null,
		"accessory_2": null,
		"talisman": null,
	}

	# Give starter skills based on selected root
	var starters := SkillDatabase.get_starter_skills(root)
	PlayerData.unlocked_skills = starters
	PlayerData.equipped_skills = starters

	print("[SpiritRootSelection] Confirmed: %s — starting game" % data["name"])
	GameManager.goto_scene("res://scenes/Main.tscn")

# ─── Particle FX Helpers ─────────────────────────────────────
func _create_element_particles(elem_color: Color, amount: int, lifetime: float, one_shot: bool) -> GPUParticles2D:
	"""Create a GPUParticles2D node with element-colored particles and additive blending."""
	var particles := GPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 0.9 if one_shot else 0.05
	particles.z_index = 10

	# Additive glow material
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = canvas_mat

	# Process material for particle behavior
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 80.0 if one_shot else 40.0
	mat.gravity = Vector3(0, 20, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 40.0 if one_shot else 25.0

	# Scale
	mat.scale_min = 2.0
	mat.scale_max = 5.0

	# Color gradient: element color → faded
	var color_ramp := Gradient.new()
	var bright := elem_color
	bright.a = 1.0
	var mid := elem_color
	mid.a = 0.7
	var faded := elem_color
	faded.a = 0.0
	color_ramp.set_offset(0, 0.0)
	color_ramp.set_color(0, bright)
	color_ramp.add_point(0.5, mid)
	color_ramp.set_offset(2, 1.0)
	color_ramp.set_color(2, faded)

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = color_ramp
	mat.color_ramp = gradient_tex

	# Damping to slow particles
	mat.damping_min = 10.0
	mat.damping_max = 30.0

	particles.process_material = mat

	return particles
