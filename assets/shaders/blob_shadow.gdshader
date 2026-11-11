// Fake contact shadow: a soft dark ellipse on a quad (replaces real-time shadows on mobile).
// It goes through the same curved-world bend as the track, so it stays glued to the rails
// instead of hovering over the bent ground.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform float opacity = 0.6;

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX = curve_world(vp);
}

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;   // 0 centre .. 1 edge
	ALBEDO = vec3(0.0);
	// Dense core, soft falloff: reads as contact, not as a grey disc.
	ALPHA = (smoothstep(1.0, 0.55, d) * 0.55 + smoothstep(0.6, 0.0, d) * 0.45) * opacity;
}
