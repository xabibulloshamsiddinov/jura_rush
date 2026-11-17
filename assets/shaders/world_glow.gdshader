// Double-sided glow material for trails, streaks, rings and light pools. Premultiplied blending:
// `additive` = 1 adds light (the old blend_add look), 0 is a soft alpha blend that still reads on
// a bright daylight background (dust and leaf trails, dusty shock rings).
shader_type spatial;
render_mode unshaded, skip_vertex_transform, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float energy = 1.5;
// 1 = fade toward the mesh UV edges (soft ribbons / discs).
uniform float soft_edge = 0.0;
uniform float accent_mix = 0.0;
uniform float additive = 1.0;

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
	float a = clamp(albedo.a * COLOR.a * edge * (1.0 - v_fog), 0.0, 1.0);
	// Additive keeps the HDR energy; the alpha blend shows the plain colour.
	vec3 c = col * COLOR.rgb * mix(min(energy, 1.0), energy, additive);
	ALBEDO = c * a;
	ALPHA = a * (1.0 - additive);
}
