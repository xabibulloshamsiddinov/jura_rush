// Fake contact shadow: a soft dark disc on a quad (replaces real-time shadows on mobile).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float opacity = 0.55;

void fragment() {
	float d = distance(UV, vec2(0.5));
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(0.5, 0.15, d) * opacity;
}
