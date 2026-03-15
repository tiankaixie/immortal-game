extends Area3D
## Merchant NPC — Dungeon mid-run trader
##
## Appears in shop rooms between combat rooms.
## Player presses E or walks into interaction range to open the shop UI.
## Uses TradeSystem.generate_dungeon_merchant_stock() for inventory.

# ─── Config ───────────────────────────────────────────────────
const INTERACTION_KEY := "interact"  # Input action name (fallback to raw E)
const SHOP_UI_PATH := "res://scripts/ui/MerchantUI.gd"

# ─── State ────────────────────────────────────────────────────
var player_in_range: bool = false
var shop_open: bool = false
var merchant_stock: Array[Dictionary] = []

# Visual elements (created in _ready)
var mesh_instance: MeshInstance3D = null
var label_3d: Label3D = null
var prompt_label: Label3D = null

# ─── Signals ──────────────────────────────────────────────────
signal shop_opened()
signal shop_closed()

func _ready() -> void:
	# Generate stock based on current floor
	var floor_level: int = GameManager.current_floor if GameManager.current_floor > 0 else 1
	merchant_stock = TradeSystem.generate_dungeon_merchant_stock(floor_level)

	_create_visual()
	_setup_collision()
	print("[Merchant] Ready — %d items in stock" % merchant_stock.size())

func _create_visual() -> void:
	"""Create a simple capsule mesh + name label for the merchant."""
	# Body mesh — a capsule placeholder
	mesh_instance = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0, 0.8, 0)

	# Give the merchant a distinctive gold-ish material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.35)
	mat.metallic = 0.3
	mat.roughness = 0.6
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	# Name label floating above head
	label_3d = Label3D.new()
	label_3d.text = "行商·灵宝阁"
	label_3d.font_size = 48
	label_3d.position = Vector3(0, 2.0, 0)
	label_3d.modulate = Color(1.0, 0.9, 0.5)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	add_child(label_3d)

	# Interaction prompt (hidden until player is near)
	prompt_label = Label3D.new()
	prompt_label.text = "[E] 交易"
	prompt_label.font_size = 36
	prompt_label.position = Vector3(0, 1.5, 0)
	prompt_label.modulate = Color(0.8, 1.0, 0.8, 0.0)  # Start invisible
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.no_depth_test = true
	add_child(prompt_label)

func _setup_collision() -> void:
	"""Create a sphere collision shape for the interaction area."""
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0  # Interaction range
	shape.shape = sphere
	add_child(shape)

	# Connect body entered/exited signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		# Fade in prompt
		var tween := create_tween()
		tween.tween_property(prompt_label, "modulate:a", 1.0, 0.2)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		# Fade out prompt
		var tween := create_tween()
		tween.tween_property(prompt_label, "modulate:a", 0.0, 0.2)
		# Close shop if open
		if shop_open:
			_close_shop()

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or shop_open:
		return

	# Check for interact key (E) — use action + physical_keycode fallback for IME compat
	if event.is_action_pressed("interact"):
		_open_shop()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key == KEY_E:
			_open_shop()
			get_viewport().set_input_as_handled()

func _open_shop() -> void:
	"""Open the merchant shop UI."""
	shop_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var ui_script := load(SHOP_UI_PATH)
	if ui_script == null:
		push_error("[Merchant] Failed to load MerchantUI script")
		shop_open = false
		return

	var ui := CanvasLayer.new()
	ui.name = "MerchantUI"
	ui.layer = 20
	ui.set_script(ui_script)
	ui.set_meta("merchant_stock", merchant_stock)
	add_child(ui)

	if ui.has_signal("closed"):
		ui.closed.connect(_on_shop_ui_closed)
	if ui.has_signal("item_purchased"):
		ui.item_purchased.connect(_on_item_purchased)

	shop_opened.emit()

func _on_shop_ui_closed() -> void:
	_close_shop()

func _close_shop() -> void:
	shop_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var ui := get_node_or_null("MerchantUI")
	if ui:
		ui.queue_free()

	shop_closed.emit()

func _on_item_purchased(item_index: int) -> void:
	"""Remove purchased item from stock."""
	if item_index >= 0 and item_index < merchant_stock.size():
		merchant_stock.remove_at(item_index)
