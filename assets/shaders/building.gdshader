// Side decor (Jura Rush flora and terrain: tree ferns, cycads, araucarias, horsetails, swamp and
// dead trees, boulders, mesas, basalt cliffs), drawn through the per-chunk decor MultiMeshes.
// The old procedural windows / flicker are retired. Lit (receives the sun shadow), double-sided
// for fronds, with wind sway in the vertex shader (UV.x = sway weight from NatureMesh).
// Colours are baked into the vertex colours per biome; the instance colour adds variety.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, specular_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"
#include "res://assets/shaders/world_light.gdshaderinc"

// Wind: sway distance (metres at sway weight 1 and instance scale 1) and speed.
uniform float sway_amount = 0.14;
uniform float wind_speed = 1.35;
// Light of tag-3 vertices (lava cracks in Volcano Ridge).
uniform float glow_energy = 2.0;

varying float v_fog;
varying float v_wny;
varying float v_phase;

void vertex() {
	// Instance origin relative to its chunk (the chunk slides every frame; a world-space phase
	// would speed the sway up with the run speed).
	vec3 origin = MODEL_MATRIX[3].xyz - NODE_POSITION_WORLD;
	float inst_scale = length(MODEL_MATRIX[1].xyz);
	v_phase = origin.x * 0.31 + origin.z * 0.17;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wind_speed + v_phase;
	float gust = 0.75 + 0.25 * sin(TIME * 0.37 + origin.z * 0.05);
	vec3 wind = vec3(sin(t) + 0.35 * sin(t * 2.7 + 1.3), 0.0, 0.45 * sin(t * 0.83 + 2.1));
	wp += wind * (sway_amount * UV.x * inst_scale * gust);
	v_wny = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	vec3 vp = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 col = COLOR.rgb;
	vec3 em = vec3(0.0);
	if (UV.y > 2.5) {
		em = COLOR.rgb * glow_energy * (0.75 + 0.25 * sin(TIME * 2.3 + v_phase * 3.0));
		col *= 0.2;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = col;
	EMISSION = em;
	AO = hemi_ao(v_wny, COLOR.a);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	FOG = vec4(fog_color.rgb, v_fog);
}
