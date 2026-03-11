extends Control
## SpiritRootSelection — 灵根选择界面
##
## Displayed after clicking "新的修仙" in MainMenu.
## Player selects one of five elemental spiritual roots before starting the game.
## All UI is built procedurally in code (no external assets).

const CARD_WIDTH := 200.0
const CARD_HEIGHT := 280.0
const CARD_GAP := 20.0

# Element data for the 5 base roots
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
	},
]

var _selected_index: int = -1
var _cards: Array[Control] = []
var _card_borders: Array[ColorRect] = []
var _confirm_btn: Button
var _back_btn: Button

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
		var card := _create_card(i)
		card.position = Vector2(i * (CARD_WIDTH + CARD_GAP), 0)
		cards_container.add_child(card)
		_cards.append(card)

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

func _create_card(index: int) -> Control:
	var data: Dictionary = ROOT_DATA[index]
	var elem_color: Color = data["color"]

	# Root container for the card
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Border (glow effect for selected)
	var border := ColorRect.new()
	border.color = Color(0.2, 0.15, 0.3, 0.6)
	border.position = Vector2(-3, -3)
	border.size = Vector2(CARD_WIDTH + 6, CARD_HEIGHT + 6)
	card.add_child(border)
	_card_borders.append(border)

	# Card background
	var card_bg := ColorRect.new()
	card_bg.color = Color(0.1, 0.08, 0.15, 0.95)
	card_bg.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_child(card_bg)

	# Top accent line
	var accent := ColorRect.new()
	accent.color = elem_color
	accent.size = Vector2(CARD_WIDTH, 3)
	card.add_child(accent)

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
	else:
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		if index != _selected_index:
			_card_borders[index].color = Color(0.2, 0.15, 0.3, 0.6)

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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

	print("[SpiritRootSelection] Selected: %s" % data["name"])

func _on_random() -> void:
	var rand_index := randi() % ROOT_DATA.size()
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
