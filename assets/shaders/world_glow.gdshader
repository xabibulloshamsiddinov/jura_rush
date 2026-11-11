// Additive, double-sided glow material for trails, streaks, rings and light cones.
shader_type spatial;
render_mode unshaded, skip_vertex_transform, blend_add, cull_disabled, depth_draw_never;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float energy = 1.5;
// 1 = fade toward the mesh UV edges (soft ribbons / discs).
uniform float soft_edge = 0.0;
uniform float accent_mix = 0.0;

varying float v_fog;

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = mix(albedo.rgb, biome_accent.rgb, clamp(accent_mix, 0.0, 1.0));
	float edge = mix(1.0, 1.0 - abs(UV.y * 2.0 - 1.0), soft_edge);
	ALBEDO = col * COLOR.rgb * energy;
	ALPHA = albedo.a * COLOR.a * edge * (1.0 - v_fog);
}
