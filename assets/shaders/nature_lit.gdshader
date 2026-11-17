// Lit, vertex-coloured world material: stone obstacles, caves, log bridges, torches, totem discs
// and clay pots. Receives the real sun shadow; mesh data comes from NatureMesh:
//   COLOR.rgb albedo, COLOR.a baked occlusion, UV.x sway weight, UV.y tag
//   tag 1 foliage  -> x foliage tint (biome_accent)
//   tag 2 rock     -> x rock tint (biome_accent2) + moss on faces turned up (biome lushness)
//   tag 3 glow     -> emissive (lava cracks, embers, torch heads)
//   tag 4 paint    -> warning paint (as painted; hazard stripes when `cb` is on)
//   tag 5 edge     -> rock lining a gap (as tag 2; hazard stripes when `cb` is on)
// `cb` (colour-blind palette, set on every nature material by Mats.set_colorblind) swaps the
// ochre / red warnings for yellow-black hazard stripes that every colour-vision type can read.
shader_type spatial;
render_mode skip_vertex_transform, cull_back, specular_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"
#include "res://assets/shaders/world_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Scale on the biome lushness for moss on rock tops (0 = never mossy).
uniform float moss = 1.0;
// Light of tag-3 (glow) vertices, and how strongly it flickers (0 = steady).
uniform float glow_energy = 2.2;
uniform float glow_flicker = 0.25;
// 1 = also apply the global rock tint to untagged vertices (whole-rock meshes).
uniform float tint_all = 0.0;
// 1 = colour-blind warning palette (hazard stripes on tags 4 and 5).
uniform float cb = 0.0;

const vec3 HAZARD_YELLOW = vec3(1.0, 0.72, 0.02);
const vec3 HAZARD_DARK = vec3(0.025, 0.022, 0.02);

varying float v_fog;
varying float v_wny;
varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	v_wny = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 col = albedo.rgb * COLOR.rgb;
	float tag = UV.y;
	vec3 em = emission.rgb * emission_energy;
	if (tag > 0.5 && tag < 1.5) {
		col *= foliage_tint();
	} else if ((tag > 1.5 && tag < 2.5) || tag > 4.5 || tint_all > 0.5) {
		col *= rock_tint();
		float n = vnoise(v_local.xz * 2.7 + v_local.y * 1.3);
		float up = smoothstep(0.45, 0.85, v_wny) * smoothstep(0.25, 0.55, n);
		col = mix(col, biome_accent.rgb * 0.8, up * biome_accent.a * moss);
	}
	if (tag > 2.5 && tag < 3.5) {
		float f = 1.0 - glow_flicker + glow_flicker * (0.6 + 0.4 * sin(TIME * 7.0 + v_local.x * 5.0)
				* sin(TIME * 3.1 + v_local.z * 3.0));
		em += COLOR.rgb * glow_energy * f;
		col *= 0.25;
	}
	if (tag > 3.5 && cb > 0.5) {
		// Diagonal hazard stripes (object space), a little self-lit so they read in shade too.
		float s = step(0.5, fract((v_local.x + v_local.y) * (tag > 4.5 ? 3.2 : 2.4)));
		col = mix(HAZARD_DARK, HAZARD_YELLOW, s);
		em += HAZARD_YELLOW * 0.22 * s;
	}
	ALBEDO = col;
	EMISSION = em;
	AO = hemi_ao(v_wny, COLOR.a);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	FOG = vec4(fog_color.rgb, v_fog);
}
