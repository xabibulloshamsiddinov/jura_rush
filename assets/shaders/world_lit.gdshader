// Default world material: unshaded with baked fake sunlight ("toon/unlit"), emission, fog, bend.
shader_type spatial;
render_mode unshaded, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// 0 = use `emission`, 1 = use the biome accent colour, 2 = use the second accent.
uniform float accent_mix = 0.0;
uniform float shade_strength = 0.5;

varying float v_fog;
varying float v_shade;

void vertex() {
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_shade = 1.0 - shade_strength + shade_strength * max(dot(wn, SUN_DIR), 0.0) * 1.25;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb * v_shade;
	vec3 em = emission.rgb;
	em = mix(em, biome_accent.rgb, clamp(accent_mix, 0.0, 1.0));
	em = mix(em, biome_accent2.rgb, clamp(accent_mix - 1.0, 0.0, 1.0));
	ALBEDO = mix(base + em * emission_energy, fog_color.rgb, v_fog);
}
