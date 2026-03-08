extends CanvasLayer
## HUD — In-game heads-up display
##
## Shows:
## - HP bar (red)
## - Spiritual Power / 灵力 bar (blue)
## - Auto-battle indicator
## - Cultivation realm & stage text

# ─── Node References ──────────────────────────────────────────
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPBar/HPLabel
@onready var sp_bar: ProgressBar = $MarginContainer/VBoxContainer/SPBar
@onready var sp_label: Label = $MarginContainer/VBoxContainer/SPBar/SPLabel
@onready var auto_battle_label: Label = $MarginContainer/VBoxContainer/AutoBattleLabel
@onready var realm_label: Label = $MarginContainer/VBoxContainer/RealmLabel

# ─── Realm Name Maps ──────────────────────────────────────────
const REALM_NAMES: Dictionary = {
	0: "练气期",  # QI_CONDENSATION
	1: "筑基期",  # FOUNDATION_ESTABLISHMENT
	2: "结丹期",  # CORE_FORMATION
	3: "元婴期",  # NASCENT_SOUL
	4: "化神期",  # SOUL_TRANSFORMATION
	5: "炼虚期",  # VOID_REFINEMENT
	6: "合体期",  # BODY_INTEGRATION
	7: "大乘期",  # MAHAYANA
	8: "渡劫期",  # TRIBULATION_TRANSCENDENCE
}

const STAGE_NAMES: Dictionary = {
	0: "初期",  # EARLY
	1: "中期",  # MID
	2: "后期",  # LATE
	3: "巅峰",  # PEAK
}

# Room display (created dynamically)
var room_label: Label = null

func _ready() -> void:
	# Connect to CombatSystem auto-battle signal
	CombatSystem.auto_battle_toggled.connect(_on_auto_battle_toggled)

	# Connect to PlayerData signals
	PlayerData.cultivation_advanced.connect(_on_cultivation_advanced)

	# Initialize display
	_update_auto_battle_display(CombatSystem.auto_battle_enabled)
	_update_realm_display()

	# Create room counter label
	_create_room_label()

	print("[HUD] Ready")

# ─── Player Connection ────────────────────────────────────────
func connect_to_player(player: Node) -> void:
	"""Connect HUD to the player node's signals."""
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_hp_changed)
	if player.has_signal("sp_changed"):
		player.sp_changed.connect(_on_sp_changed)

	# Initialize bars with current values if available
	if player.has_method("get") or true:
		_on_hp_changed(player.current_hp, player.max_hp)
		_on_sp_changed(player.current_sp, player.max_sp)

# ─── Signal Handlers ──────────────────────────────────────────
func _on_hp_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "气血  %.0f / %.0f" % [current, maximum]

func _on_sp_changed(current: float, maximum: float) -> void:
	sp_bar.max_value = maximum
	sp_bar.value = current
	sp_label.text = "灵力  %.0f / %.0f" % [current, maximum]

func _on_auto_battle_toggled(enabled: bool) -> void:
	_update_auto_battle_display(enabled)

func _on_cultivation_advanced(_realm: int, _stage: int) -> void:
	_update_realm_display()

# ─── Display Helpers ───────────────────────────────────────────
func _update_auto_battle_display(enabled: bool) -> void:
	if auto_battle_label:
		auto_battle_label.text = "⚔ 自动战斗: %s  [Q]" % ("开" if enabled else "关")
		auto_battle_label.modulate = Color.GREEN if enabled else Color(0.6, 0.6, 0.6)

func _update_realm_display() -> void:
	if realm_label:
		var realm_name: String = REALM_NAMES.get(PlayerData.cultivation_realm, "???")
		var stage_name: String = STAGE_NAMES.get(PlayerData.cultivation_stage, "???")
		realm_label.text = "%s · %s" % [realm_name, stage_name]

# ─── Room Cleared Display ─────────────────────────────────────
func show_room_cleared() -> void:
	"""Display a room cleared notification on the HUD."""
	var label := Label.new()
	label.text = "✦ 房间已清除 ✦\n下一间 →"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER
	label.anchor_left = 0.5
	label.anchor_top = 0.4
	label.anchor_right = 0.5
	label.anchor_bottom = 0.4
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(label)
	
	# Animate
	var tween := create_tween()
	label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

# ─── Room Counter Display ─────────────────────────────────────
func _create_room_label() -> void:
	"""Create a room counter in the top-right corner."""
	room_label = Label.new()
	room_label.text = "第 1/5 间"
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_label.add_theme_font_size_override("font_size", 20)
	room_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	room_label.anchor_left = 0.85
	room_label.anchor_right = 0.98
	room_label.anchor_top = 0.02
	room_label.anchor_bottom = 0.06
	room_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(room_label)

func update_room_display(room: int, total: int) -> void:
	"""Update the room counter text."""
	if room_label:
		room_label.text = "第 %d/%d 间" % [room, total]
