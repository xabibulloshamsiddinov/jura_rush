// Torch flames (crossed quads, UV.y 0 = base .. 1 = tip) and the warm light pools they throw on
// the floor (UV.x >= 2). Additive, flickers in the shader (no scripts). COLOR.r = flicker seed.
// One of the few true emissives of Jura Rush, so it is allowed to bloom a little.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 flame_core : source_color = vec4(1.0, 0.88, 0.5, 1.0);
uniform vec4 flame_edge : source_color = vec4(1.0, 0.36, 0.05, 1.0);
uniform float energy = 2.4;
uniform vec4 pool_color : source_color = vec4(1.0, 0.5, 0.16, 1.0);
uniform float pool_energy = 0.38;

varying float v_fog;
varying float v_seed;

void vertex() {
	v_seed = COLOR.r * 17.0;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
}

void fragment() {
	float flicker = 0.82 + 0.18 * sin(TIME * 13.0 + v_seed) * sin(TIME * 7.3 + v_seed * 2.1);
	vec3 col;
	if (UV.x >= 1.5) {
		vec2 q = UV - vec2(2.5, 0.5);
		float r = length(q) * 2.0;
		float a = pow(max(1.0 - r, 0.0), 2.0);
		col = pool_color.rgb * a * pool_energy * (0.9 + 0.1 * flicker);
	} else {
		float y = UV.y;
		float x = (UV.x - 0.5) * 2.0;
		float sway = sin(TIME * 9.0 + v_seed + y * 5.0) * 0.16 * y + sin(TIME * 4.3 + v_seed) * 0.06 * y;
		float w = sin(3.14159 * pow(clamp(y * 0.95 + 0.03, 0.0, 1.0), 0.62)) * (1.0 - 0.35 * y);
		float d = abs(x + sway) / max(w, 0.001);
		float body = 1.0 - smoothstep(0.55, 1.0, d);
		float core = 1.0 - smoothstep(0.0, 0.7, d + y * 0.75);
		body *= smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.82 + 0.1 * flicker, 1.0, y));
		col = mix(flame_edge.rgb, flame_core.rgb, core) * body * energy * flicker;
	}
	ALBEDO = col * (1.0 - v_fog);
}
