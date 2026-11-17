// Toy-like character material for the procedural caveman and his pterosaur (CavemanMesh).
// LIT with the same daylight model as the world and the creatures (world_light.gdshaderinc): the
// biome's real sun (direction, colour, shadows: under a tree or in a cave he darkens exactly like a
// brachiosaurus beside him) with the soft wrap, eased a little toward toon bands, and the sky-tinted
// WorldEnvironment ambient with hemisphere occlusion. On top, readability terms that keep him the
// clearest thing on screen: a sun-coloured fill from the camera side and a sunlit rim (both shadowed
// like the sun), plus a faint constant sky rim so his silhouette survives in deep shade.
// The shop preview and the labs light him with their own sun and environment.
// Bends and fogs with the world (CURVE_WORLD, also correct in a shadow pass). He casts no real
// shadow: the blob contact shadow (Player) reads jump height better and is there at every quality.
//
// Vertex colour channels (written by CavemanMesh):
//   COLOR.r  palette slot / 15        (skin, fur, hair, leather, bone, eyes, accent ...)
//   COLOR.g  baked ambient occlusion  (1 = open, lower in creases: under the brow, armpits)
//   COLOR.b  fur pattern mask         (1 = leopard spots / stripes / leaves on this surface)
//   COLOR.a  gloss                    (eye glints, bone sheen)
//   UV2.x    flutter weight, UV2.y flutter phase (ragged hem, hair tips, feathers)
shader_type spatial;
render_mode skip_vertex_transform, cull_back;
#include "res://assets/shaders/world_common.gdshaderinc"
#define WORLD_LIGHT_CUSTOM
#include "res://assets/shaders/world_light.gdshaderinc"

// 0 skin, 1 fur, 2 hair, 3 leather, 4 bone, 5 eye white, 6 pupil, 7 accent, 8 fur marks,
// 9 stone, 10 dark (mouth), 11 blush.
uniform vec4 palette[12] : source_color;
// 0 plain, 1 leopard rosettes, 2 tiger stripes, 3 overlapping leaves, 4 soft patches.
uniform int pattern_kind = 1;
uniform float pattern_scale = 1.0;
// 0 = the world's plain wrap_diffuse, 1 = a hard two-tone step.
uniform float toon = 0.45;
// Sun-coloured fill from the camera side (0..1 of the sun): his face reads in the menu (sun
// behind him) and his back reads in the run, while caves and tree shade still darken him.
uniform float view_fill = 0.24;
// Sunlit rim on the silhouette (VisualTuning.PLAYER_RIM_*).
uniform vec4 rim_color : source_color = vec4(1.0, 0.9, 0.72, 1.0);
uniform float rim_strength = 0.45;
uniform float rim_power = 2.8;
// Constant sky rim (emission), the only term that survives full shade.
uniform vec4 sky_rim_color : source_color = vec4(0.62, 0.74, 0.95, 1.0);
uniform float sky_rim = 0.1;
uniform float flutter_speed = 11.0;
uniform float flutter_amount = 0.018;

varying vec3 v_local;
varying float v_wny;
varying float v_fog;
// Gloss handed from fragment() to light().
varying float v_glint;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Nearest feature point of a jittered 3D grid: x = distance, y = cell id hash.
vec2 voronoi(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 h = hash33(cell + o);
				vec3 d = o + 0.15 + h * 0.7 - f;
				float dd = dot(d, d);
				if (dd < best) {
					best = dd;
					id = hash13(cell + o + 17.0);
				}
			}
		}
	}
	return vec2(sqrt(best), id);
}

// Mixes the fur colour (slot 1) with the mark colour (slot 8) in the skin's pattern.
vec3 fur_pattern(vec3 base, vec3 p) {
	vec3 mark = palette[8].rgb;
	vec3 q = p * pattern_scale;
	float aa = 0.06;
	if (pattern_kind == 1) {
		// Leopard: broken rosettes with a slightly darker centre, plus a few solid spots.
		vec2 v = voronoi(q * 11.0 + value_noise(q * 20.0) * 0.35);
		float r_out = 0.30 + 0.08 * v.y;
		float ring = smoothstep(r_out + aa, r_out - aa, v.x);
		float r_in = 0.17 + 0.05 * v.y;
		float hole = smoothstep(r_in - aa, r_in + aa, v.x);
		float solid = step(0.62, v.y);
		float m = ring * mix(hole, 1.0, solid * 0.85);
		// Break the rings into a few blobs like real rosettes.
		m *= smoothstep(0.25, 0.55, value_noise(q * 26.0 + v.y * 7.0) + solid * 0.4);
		vec3 centre = mix(base, base * vec3(0.86, 0.78, 0.70), ring * (1.0 - hole) * (1.0 - solid));
		return mix(centre, mark, m);
	} else if (pattern_kind == 2) {
		// Tiger-like stripes: wavy bands across the body that taper off.
		float n = value_noise(q * vec3(6.0, 2.0, 6.0)) * 2.2;
		float s = sin(q.y * 34.0 + n * 3.0 + atan(q.z, q.x) * 1.5);
		float width = 0.55 + 0.25 * value_noise(q * 9.0);
		float m = smoothstep(width - 0.08, width + 0.08, s);
		return mix(base, mark, m);
	} else if (pattern_kind == 3) {
		// Overlapping leaves: scale rows, each leaf shaded from its tip, darker midrib.
		vec2 c = vec2(atan(q.z, q.x) * 1.5, q.y * 7.5);
		c.x += floor(c.y) * 0.5;
		vec2 cell = floor(c * vec2(4.0, 1.0));
		vec2 f = fract(c * vec2(4.0, 1.0)) - vec2(0.5, 0.5);
		float tone = hash13(vec3(cell, 3.0));
		float leaf = 1.0 - smoothstep(0.30, 0.52, length(f * vec2(1.0, 0.85)));
		vec3 col = mix(base, mark, step(0.55, tone) * 0.75);
		col *= mix(0.78, 1.08, clamp(f.y + 0.6, 0.0, 1.0));
		float rib = (1.0 - smoothstep(0.03, 0.07, abs(f.x))) * leaf;
		col = mix(col, mark * 0.7, rib * 0.6);
		return col;
	} else if (pattern_kind == 4) {
		// Soft irregular patches (black fur with grey tufts, sandy fur with brown blotches).
		float n = value_noise(q * 7.0) * 0.65 + value_noise(q * 15.0) * 0.35;
		float m = smoothstep(0.52, 0.62, n);
		return mix(base, mark, m);
	}
	return base;
}

void vertex() {
	v_local = VERTEX;
	if (UV2.x > 0.0) {
		float ph = UV2.y + TIME * flutter_speed;
		VERTEX += vec3(sin(ph), sin(ph * 1.7 + 1.3) * 0.4, cos(ph * 1.3)) * UV2.x * flutter_amount;
	}
	v_wny = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	int slot = clamp(int(COLOR.r * 15.0 + 0.5), 0, 11);
	vec3 base = palette[slot].rgb;
	if (COLOR.b > 0.5) {
		base = fur_pattern(base, v_local);
		// Fine fur grain so big fur areas never look like plastic.
		base *= 0.93 + 0.12 * value_noise(v_local * 70.0);
	}
	ALBEDO = base;
	// Baked creases plus the world's hemisphere occlusion; creases also dim the sun a little.
	AO = hemi_ao(v_wny, COLOR.g);
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = 1.0;
	v_glint = COLOR.a;
	float facing = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float fuzz = COLOR.b > 0.5 ? 1.35 : 1.0;
	EMISSION = sky_rim_color.rgb * (pow(1.0 - facing, 3.0) * sky_rim * fuzz) * (0.35 + base);
	FOG = vec4(fog_color.rgb, v_fog);
}

void light() {
	vec3 sun = LIGHT_COLOR * ATTENUATION;
	float w = wrap_diffuse(dot(NORMAL, LIGHT));
	w = mix(w, smoothstep(0.3, 0.6, w), toon);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	DIFFUSE_LIGHT += sun * (w + view_fill * facing);
	// The rim takes the surface colour (like the fur catching the light), so it never whitewashes.
	float rim = pow(1.0 - facing, rim_power) * rim_strength * (0.35 + 0.65 * w);
	float spec = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 36.0) * v_glint * 0.9;
	SPECULAR_LIGHT += sun * (rim_color.rgb * (0.3 + ALBEDO) * rim + vec3(spec));
}
