extends Node3D
## SkillVFX — Reusable particle effect for skill impacts
##
## Instantiate at hit position, configure element, auto-frees after playing.
## Uses GPUParticles3D with element-based color variations.

@onready var particles: GPUParticles3D = $GPUParticles3D

# Element color palettes: [base_color, secondary_color]
const ELEMENT_COLORS: Dictionary = {
	"fire": [Color(1.0, 0.3, 0.05), Color(1.0, 0.7, 0.1)],
	"water": [Color(0.2, 0.5, 1.0), Color(0.6, 0.85, 1.0)],
	"lightning": [Color(1.0, 1.0, 0.3), Color(1.0, 1.0, 1.0)],
	"thunder_palm": [Color(1.0, 0.95, 0.3), Color(1.0, 1.0, 1.0)],
	"chain_lightning": [Color(0.3, 0.6, 1.0), Color(0.8, 0.9, 1.0)],
	"metal": [Color(0.85, 0.85, 0.8), Color(1.0, 0.95, 0.7)],
	"wood": [Color(0.2, 0.8, 0.3), Color(0.5, 1.0, 0.4)],
	"earth": [Color(0.7, 0.5, 0.2), Color(0.9, 0.75, 0.4)],
	"void": [Color(0.5, 0.0, 0.9), Color(0.7, 0.3, 1.0)],
}

const DEFAULT_COLORS: Array = [Color(0.7, 0.4, 1.0), Color(1.0, 1.0, 1.0)]

var element: String = ""
var lifetime: float = 0.6

func _ready() -> void:
	_configure_particles()
	particles.emitting = true
	# Auto-free after particles finish
	var timer := get_tree().create_timer(lifetime + 0.3)
	timer.timeout.connect(queue_free)

func setup(vfx_element: String, vfx_position: Vector3) -> void:
	"""Configure element and world position before adding to tree."""
	element = vfx_element
	global_position = vfx_position

func _configure_particles() -> void:
	"""Set up particle material based on element."""
	if particles == null:
		return

	var colors: Array = ELEMENT_COLORS.get(element, DEFAULT_COLORS)
	var base_color: Color = colors[0]
	var secondary_color: Color = colors[1]

	# Create process material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.05
	mat.scale_max = 0.15

	# Color gradient
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(secondary_color, 1.0))
	gradient.add_point(0.3, Color(base_color, 0.9))
	gradient.add_point(1.0, Color(base_color, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	# Element-specific tweaks
	var particle_amount: int = 24
	match element:
		"fire":
			mat.initial_velocity_min = 1.5
			mat.initial_velocity_max = 4.0
			mat.gravity = Vector3(0, 1.0, 0)  # Fire rises
			mat.scale_min = 0.08
			mat.scale_max = 0.2
		"water":
			mat.initial_velocity_min = 1.0
			mat.initial_velocity_max = 3.5
			mat.gravity = Vector3(0, -4.0, 0)
			mat.spread = 120.0
		"lightning":
			mat.initial_velocity_min = 4.0
			mat.initial_velocity_max = 8.0
			mat.gravity = Vector3.ZERO
			mat.damping_min = 5.0
			mat.damping_max = 8.0
			mat.scale_min = 0.03
			mat.scale_max = 0.1
			lifetime = 0.35
		"thunder_palm":
			# 天雷掌：黄白色闪电爆发，高 explosiveness，电弧/电击感
			mat.direction = Vector3(0, 0.5, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 12.0
			mat.gravity = Vector3.ZERO
			mat.damping_min = 6.0
			mat.damping_max = 10.0
			mat.scale_min = 0.02
			mat.scale_max = 0.12
			lifetime = 0.4
			particle_amount = 60
			# Override gradient: bright yellow → white → fade out
			var tp_gradient := Gradient.new()
			tp_gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))  # white flash
			tp_gradient.add_point(0.2, Color(1.0, 0.95, 0.3, 1.0))  # bright yellow
			tp_gradient.add_point(0.6, Color(1.0, 0.85, 0.1, 0.7))  # golden
			tp_gradient.add_point(1.0, Color(1.0, 0.9, 0.5, 0.0))   # fade out
			var tp_grad_tex := GradientTexture1D.new()
			tp_grad_tex.gradient = tp_gradient
			mat.color_ramp = tp_grad_tex
		"chain_lightning":
			# 锁链雷：蓝白色分支感粒子，模拟链式电弧跳跃
			mat.direction = Vector3(0, 0.3, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 6.0
			mat.initial_velocity_max = 14.0
			mat.gravity = Vector3(0, 0.5, 0)
			mat.damping_min = 4.0
			mat.damping_max = 7.0
			mat.scale_min = 0.015
			mat.scale_max = 0.08
			lifetime = 0.5
			particle_amount = 80
			# Override gradient: electric blue → white → fade
			var cl_gradient := Gradient.new()
			cl_gradient.add_point(0.0, Color(0.9, 0.95, 1.0, 1.0))  # white flash
			cl_gradient.add_point(0.15, Color(0.3, 0.6, 1.0, 1.0))  # electric blue
			cl_gradient.add_point(0.5, Color(0.4, 0.7, 1.0, 0.8))   # blue glow
			cl_gradient.add_point(1.0, Color(0.2, 0.4, 0.9, 0.0))   # fade out
			var cl_grad_tex := GradientTexture1D.new()
			cl_grad_tex.gradient = cl_gradient
			mat.color_ramp = cl_grad_tex
		"void":
			# 虚空系：紫色暗能量粒子
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 5.0
			mat.gravity = Vector3(0, 1.0, 0)
			mat.damping_min = 3.0
			mat.damping_max = 5.0
			mat.scale_min = 0.04
			mat.scale_max = 0.15
			lifetime = 0.5

	particles.process_material = mat
	particles.amount = particle_amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95 if element in ["thunder_palm", "chain_lightning"] else 0.9

	# Simple mesh for particles (small sphere)
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = base_color
	mesh_mat.emission_enabled = true
	mesh_mat.emission = base_color
	mesh_mat.emission_energy_multiplier = 5.0 if element in ["thunder_palm", "chain_lightning"] else 3.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if element in ["thunder_palm", "chain_lightning", "void"] else BaseMaterial3D.BLEND_MODE_MIX
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh
