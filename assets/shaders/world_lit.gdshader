// Default unshaded world material with baked fake sunlight ("toy/unlit"), emission, fog, bend.
// Used by everything that is not part of the lit Jura Rush landscape (characters, creatures,
// versus mode, previews). The baked sun follows SUN_DIR, the same direction as the real light.
// Optional extras (all off by default):
//   rim_*      view-angle rim light on the silhouette (player readability)
//   pulse_*    breathing emission (warning paint)
//   fog_pierce share of the emission that stays visible inside the fog (early warning)
// The neon window panes (segment_*) are retired.
shader_type spatial;
render_mode unshaded, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// 0 = use `emission`, 1 = use the biome accent colour, 2 = use the second accent.
uniform float accent_mix = 0.0;
uniform float shade_strength = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_strength = 0.0;
uniform float rim_power = 2.5;
uniform float pulse_speed = 0.0;
uniform float pulse_amount = 0.0;
uniform float fog_pierce = 0.0;

varying float v_fog;
varying float v_shade;

void vertex() {
	vec3 wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_shade = sun_shade(wn, shade_strength);
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb * v_shade;
	vec3 em = emission.rgb;
	em = mix(em, biome_accent.rgb, clamp(accent_mix, 0.0, 1.0));
	em = mix(em, biome_accent2.rgb, clamp(accent_mix - 1.0, 0.0, 1.0));
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	em *= emission_energy * pulse;
	if (rim_strength > 0.0) {
		float facing = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
		em += rim_color.rgb * rim_strength * pow(1.0 - facing, rim_power);
	}
	// Same result as mix(base + em, fog, v_fog) when fog_pierce = 0.
	ALBEDO = mix(base, fog_color.rgb, v_fog) + em * (1.0 - v_fog * (1.0 - fog_pierce));
}
