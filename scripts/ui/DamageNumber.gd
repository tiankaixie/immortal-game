extends Node3D
## DamageNumber — 3D浮动伤害数字
##
## 在受击位置生成，向上飘动并淡出。
## 暴击：金色大字 + "暴击!" 前缀
## 普通伤害：白/红色
## 治疗：绿色 + "+" 前缀

# ─── 配置 ─────────────────────────────────────────────────────
const FLOAT_SPEED: float = 1.5       # 上飘速度
const LIFETIME: float = 1.0          # 存在时间（秒）
const SPREAD_RANGE: float = 0.3      # 水平随机偏移

var label_3d: Label3D = null
var elapsed: float = 0.0
var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	# 添加随机水平偏移，避免数字重叠
	velocity = Vector3(
		randf_range(-SPREAD_RANGE, SPREAD_RANGE),
		FLOAT_SPEED,
		randf_range(-SPREAD_RANGE, SPREAD_RANGE)
	)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return

	# 上飘
	global_position += velocity * delta

	# 淡出
	if label_3d:
		var alpha: float = 1.0 - (elapsed / LIFETIME)
		label_3d.modulate.a = alpha

	# 逐渐减速
	velocity.y *= 0.98

func setup(damage_amount: float, is_critical: bool, is_heal: bool = false) -> void:
	"""初始化伤害数字的文本和样式。"""
	label_3d = Label3D.new()
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.fixed_size = false
	label_3d.pixel_size = 0.01

	if is_heal:
		# 治疗：绿色
		label_3d.text = "+%.0f" % damage_amount
		label_3d.modulate = Color(0.3, 1.0, 0.3)
		label_3d.font_size = 48
	elif is_critical:
		# 暴击：金色大字
		label_3d.text = "暴击! %.0f" % damage_amount
		label_3d.modulate = Color(1.0, 0.85, 0.2)
		label_3d.font_size = 64
		label_3d.outline_size = 8
		label_3d.outline_modulate = Color(0.6, 0.2, 0.0)
	else:
		# 普通伤害：白红色
		label_3d.text = "%.0f" % damage_amount
		label_3d.modulate = Color(1.0, 0.4, 0.3)
		label_3d.font_size = 42

	label_3d.outline_size = max(label_3d.outline_size, 4)
	label_3d.outline_modulate = Color(0, 0, 0, 0.8) if not is_critical else label_3d.outline_modulate
	add_child(label_3d)
