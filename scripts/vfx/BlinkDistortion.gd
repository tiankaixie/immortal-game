extends CanvasLayer
## BlinkDistortion — Short-lived screen distortion for void_blink
##
## Creates a fullscreen ColorRect with a canvas_item shader that produces
## a brief chromatic aberration / space-warp pulse effect (0.3s).
## Auto-frees after the effect completes.

const EFFECT_DURATION: float = 0.3

func _ready() -> void:
	layer = 80  # Above game, below UI
	_create_distortion_overlay()

func _create_distortion_overlay() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float time_offset = 0.0;

void fragment() {
	float t = intensity;
	// Radial distance from center
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - center;
	float dist = length(dir);

	// Chromatic aberration: offset R and B channels
	float aberration = 0.012 * t * (1.0 - dist);
	vec2 offset_r = dir * aberration;
	vec2 offset_b = -dir * aberration;

	float r = texture(SCREEN_TEXTURE, uv + offset_r).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv + offset_b).b;

	// Purple-tinted vignette pulse
	float vignette = smoothstep(0.2, 0.8, dist) * t * 0.4;
	vec3 purple_tint = vec3(0.3, 0.0, 0.5) * vignette;

	COLOR = vec4(vec3(r, g, b) + purple_tint, t * 0.6);
}
"""

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("intensity", 1.0)
	rect.material = shader_mat

	add_child(rect)

	# Animate intensity from 1.0 → 0.0 over EFFECT_DURATION
	var tween := create_tween()
	tween.tween_method(func(val: float):
		shader_mat.set_shader_parameter("intensity", val)
	, 1.0, 0.0, EFFECT_DURATION)
	tween.tween_callback(queue_free)
