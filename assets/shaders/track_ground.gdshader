// The stone-path track (one mesh shared by every chunk, TrackVisuals.track_mesh): three flagstone
// lanes, earth and grass between and beside them, border stones, pebbles and grass tufts, rolling
// terrain further out. Biome look PER CHUNK through instance uniforms, so a biome change travels
// with the world: a chunk blends style_a at its near edge (z = 0) into style_b at its far edge.
// Per-style palettes are uniform arrays filled by TrackVisuals from the BiomeDefs.
//   UV.y tag: 0 ground, 1 path stone surface, 2 border stones / pebbles, 3 grass tufts.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, specular_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"
#include "res://assets/shaders/world_light.gdshaderinc"

// Linear colours, one per style (decor_set index 0..3).
uniform vec4 pal_grass[4];
uniform vec4 pal_grass_dark[4];
uniform vec4 pal_earth[4];
uniform vec4 pal_stone[4];
uniform vec4 pal_crevice[4];
// x lushness (grass cover, moss), y swamp water, z lava cracks, w dry-mud cracks.
uniform vec4 pal_params[4];
uniform vec4 lava_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 water_deep : source_color = vec4(0.05, 0.17, 0.17, 1.0);
uniform vec4 water_shallow : source_color = vec4(0.12, 0.26, 0.2, 1.0);
uniform vec4 lily_color : source_color = vec4(0.3, 0.55, 0.2, 1.0);
// Path geometry (metres): lane pitch, half width of a flagstone path, flagstone cells per chunk.
uniform float lane_pitch = 2.0;
uniform float path_half = 0.85;
uniform float stone_cells_z = 72.0;
uniform float stone_cell_x = 0.43;
uniform float chunk_length = 30.0;
uniform float sway_amount = 0.05;

instance uniform float style_a = 0.0;
instance uniform float style_b = 0.0;

varying vec3 v_local;
varying float v_fog;
varying float v_wny;

void vertex() {
	v_local = VERTEX;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (UV.y > 2.5) {
		float t = TIME * 2.1 + VERTEX.x * 0.9 + VERTEX.z * 0.35;
		wp.x += (sin(t) + 0.4 * sin(t * 2.3)) * sway_amount * UV.x;
		wp.z += 0.5 * sin(t * 0.7 + 1.0) * sway_amount * UV.x;
	}
	v_wny = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	vec3 vp = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

// Distance (m) from the nearest flagstone path edge; negative inside a path.
float path_edge_dist(float x) {
	float lane = clamp(floor(x / lane_pitch + 0.5), -1.0, 1.0);
	return abs(x - lane * lane_pitch) - path_half;
}

// Cellular noise (F1, F2 - F1, nearest cell id, vector to the nearest feature point) on a grid
// that repeats every `period_y` cells along y (seamless chunk joins).
void cells(vec2 g, float period_y, out float f1, out float edge, out vec2 id, out vec2 to_center) {
	vec2 ip = floor(g);
	vec2 fp = fract(g);
	float d1 = 9.0;
	float d2 = 9.0;
	id = ip;
	to_center = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = vec2(float(i), float(j));
			vec2 cid = ip + c;
			cid.y = mod(cid.y, period_y);
			vec2 o = 0.15 + 0.7 * hash22(cid + 3.7);
			vec2 r = c + o - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = cid;
				to_center = r;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	f1 = sqrt(d1);
	edge = sqrt(d2) - f1;
}

// Flagstone path colour for one style; n_world returns the bevelled stone normal.
vec3 path_color(int s, vec2 p, float aa, out vec3 n_world) {
	vec2 g = vec2(p.x / stone_cell_x, p.y * stone_cells_z / chunk_length);
	float f1;
	float e;
	vec2 id;
	vec2 tc;
	cells(g, stone_cells_z, f1, e, id, tc);
	float h1 = hash12(id + 11.3);
	float h2 = hash12(id + 27.9);
	vec3 stone = pal_stone[s].rgb * (0.9 + 0.2 * h1);
	stone *= vec3(1.0 + 0.07 * (h2 - 0.5), 1.0, 1.0 - 0.07 * (h2 - 0.5));
	stone *= 0.95 + 0.1 * pnoise(vec2(p.x * 13.0 + id.x * 3.1 + id.y * 1.7, p.y * 13.0), 390.0);
	// Worn line down the middle of each lane.
	float dx = abs(path_edge_dist(p.x) + path_half);
	stone *= 1.0 + 0.07 * (1.0 - smoothstep(0.15, 0.6, dx));
	vec4 par = pal_params[s];
	vec3 crev = pal_crevice[s].rgb;
	crev = mix(crev, pal_grass_dark[s].rgb * 0.75, par.x * 0.55 * step(0.45, hash12(id + 4.2)));
	float cw = 0.075;
	float k = smoothstep(cw * 0.45, cw + aa, e);
	float far_fade = 1.0 - smoothstep(0.1, 0.35, aa);
	vec3 col = mix(crev, stone, mix(1.0, k, far_fade * 0.95 + 0.05));
	// Rounded stone edges: tilt the normal away from the stone centre near the crevice.
	float bev = (1.0 - smoothstep(0.0, 0.22, e)) * far_fade;
	vec2 out_dir = -normalize(tc + 1e-4);
	n_world = normalize(vec3(out_dir.x * bev * 0.9, 1.0, out_dir.y * bev * 0.9));
	// Darker rim where the path meets the earth.
	col *= 1.0 - 0.22 * smoothstep(path_half - 0.1, path_half + 0.05, dx);
	return col;
}

// Ground colour (earth, grass, water, lava) for one style. em returns emission.
vec3 ground_color(int s, vec2 p, float fres, out vec3 em) {
	em = vec3(0.0);
	vec4 par = pal_params[s];
	float n1 = pnoise(vec2(p.x * 0.1 + 3.1, p.y * 0.1), 3.0) * 0.65
			+ pnoise(vec2(p.x * 0.3 + 7.7, p.y * 0.3), 9.0) * 0.35;
	float n2 = pnoise(vec2(p.x * 0.8667 + 5.3, p.y * 0.8667), 26.0);
	float n3 = pnoise(vec2(p.x * 3.7 + 1.9, p.y * 3.7), 111.0);
	vec3 grass = mix(pal_grass_dark[s].rgb, pal_grass[s].rgb, smoothstep(0.32, 0.72, n1));
	grass *= 0.9 + 0.2 * n3;
	vec3 earth = pal_earth[s].rgb * (0.86 + 0.24 * n3) * (0.93 + 0.14 * n2);
	float lush = par.x;
	float cover = smoothstep(0.92 - lush * 0.95, 1.08 - lush * 0.95, n1 * 0.7 + n2 * 0.3 + 0.05);
	float ed = path_edge_dist(p.x);
	float bare = 1.0 - smoothstep(0.02, 0.12 + 0.16 * n2, ed);
	vec3 col = mix(earth, grass, cover * (1.0 - bare));
	float ax = abs(p.x);
	// Tiny flowers in lush meadows.
	if (lush > 0.5 && ax > 3.3) {
		vec2 fc = floor(p * 2.6);
		fc.y = mod(fc.y, 78.0);
		float fh = hash12(fc + 91.0);
		vec2 fo = fract(p * 2.6) - (0.25 + 0.5 * hash22(fc + 7.0));
		float dot_mask = (1.0 - smoothstep(0.05, 0.09, length(fo))) * step(fh, 0.07 * lush) * cover;
		vec3 flower = mix(vec3(1.0, 0.92, 0.55), vec3(0.98, 0.98, 0.95), step(0.035, fh));
		col = mix(col, flower, dot_mask);
	}
	// Dry mud / sandstone cracks.
	if (par.w > 0.01 && ax > 3.0) {
		float f1;
		float e;
		vec2 id;
		vec2 tc;
		cells(p * vec2(0.9, 0.9), 27.0, f1, e, id, tc);
		col *= 1.0 - par.w * 0.35 * (1.0 - smoothstep(0.0, 0.07, e)) * (1.0 - cover);
	}
	// Swamp water strips beside the path, with lily pads.
	if (par.y > 0.01) {
		float wn = pnoise(vec2(p.x * 0.2667 + 2.0, p.y * 0.2667), 8.0);
		float inner = 3.9 + wn * 0.8;
		float outer = 9.0 + wn * 3.0;
		float w = smoothstep(inner, inner + 0.35, ax) * (1.0 - smoothstep(outer, outer + 0.6, ax)) * par.y;
		float shore = smoothstep(inner - 0.5, inner, ax) * (1.0 - smoothstep(outer + 0.6, outer + 1.4, ax));
		col = mix(col, col * 0.62, shore * par.y * (1.0 - w));
		float wv = pnoise(vec2(p.x * 0.6 + TIME * 0.05, p.y * 0.6), 18.0);
		// Shallow and murky toward the banks, deep teal in the middle of the strip.
		float mid_w = smoothstep(inner, inner + 2.2, ax) * (1.0 - smoothstep(outer - 2.0, outer, ax));
		vec3 water = mix(water_shallow.rgb, water_deep.rgb, mid_w) * (0.85 + 0.3 * wv);
		float ripple = smoothstep(0.72, 0.95, pnoise(vec2(p.x * 0.7 + TIME * 0.2, p.y * 2.6), 78.0));
		vec2 lc = floor(p * 0.9);
		lc.y = mod(lc.y, 27.0);
		vec2 lo = fract(p * 0.9) - (0.3 + 0.4 * hash22(lc + 5.0));
		float lr = 0.16 + 0.12 * hash12(lc + 9.0);
		float notch = step(0.06, abs(atan(lo.y, lo.x) - 1.0));
		float pad = (1.0 - smoothstep(lr - 0.02, lr, length(lo))) * step(hash12(lc + 2.0), 0.42) * notch;
		vec3 wcol = mix(water, lily_color.rgb * (0.85 + 0.3 * hash12(lc)), pad);
		// Sky reflection grows toward grazing angles; ripples catch the light.
		em += (fog_color.rgb * (0.02 + 0.08 * fres) + vec3(0.05) * ripple) * (1.0 - pad) * w;
		col = mix(col, wcol, w);
	}
	// Lava cracks (Volcano Ridge) away from the path.
	if (par.z > 0.01 && ax > 3.4) {
		float f1;
		float e;
		vec2 id;
		vec2 tc;
		// Wobbly, broken cracks: warp the cell grid, vary the width, and let only some stretches
		// glow (a honeycomb of even lines reads as tiles, not as cooling lava).
		vec2 warp = vec2(pnoise(vec2(p.x * 0.8 + 4.0, p.y * 0.8), 24.0),
				pnoise(vec2(p.x * 0.8 + 19.0, p.y * 0.8), 24.0)) - 0.5;
		cells(p * 0.5 + warp * 0.7, 15.0, f1, e, id, tc);
		float zone = smoothstep(3.8, 6.0, ax) * smoothstep(0.42, 0.62, pnoise(vec2(p.x * 0.1333 + 9.0, p.y * 0.1333), 4.0));
		float live = smoothstep(0.38, 0.62, pnoise(vec2(p.x * 0.5 + 3.0, p.y * 0.5), 15.0));
		float width = 0.025 + 0.05 * pnoise(vec2(p.x * 1.7 + 8.0, p.y * 1.7), 51.0);
		float crack = (1.0 - smoothstep(0.0, width, e)) * zone * live;
		float crust = (1.0 - smoothstep(0.0, 0.3, e)) * zone;
		col *= 1.0 - 0.45 * crust * par.z;
		float pulse = 0.7 + 0.3 * sin(TIME * 1.7 + hash12(id) * 6.28);
		em += lava_color.rgb * crack * par.z * 2.2 * pulse;
		col = mix(col, lava_color.rgb * 0.3, crack * par.z);
	}
	return col;
}

void fragment() {
	int sa = int(style_a + 0.5);
	int sb = int(style_b + 0.5);
	float blend = sa == sb ? 0.0 : smoothstep(-1.0, -chunk_length + 1.0, v_local.z);
	vec2 p = v_local.xz;
	float tag = UV.y;
	vec3 col;
	vec3 em = vec3(0.0);
	vec3 n_world = vec3(0.0, 1.0, 0.0);
	bool use_normal = false;
	if (tag < 0.5) {
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		col = ground_color(sa, p, fres, em);
		if (blend > 0.001) {
			vec3 em_b;
			vec3 col_b = ground_color(sb, p, fres, em_b);
			col = mix(col, col_b, blend);
			em = mix(em, em_b, blend);
		}
	} else if (tag < 1.5) {
		float aa = fwidth(p.y) * stone_cells_z / chunk_length;
		col = path_color(sa, p, aa, n_world);
		if (blend > 0.001) {
			vec3 nb;
			col = mix(col, path_color(sb, p, aa, nb), blend);
		}
		use_normal = true;
	} else if (tag < 2.5) {
		vec3 stone_a = pal_stone[sa].rgb / REF_ROCK;
		vec3 stone_b = pal_stone[sb].rgb / REF_ROCK;
		col = COLOR.rgb * mix(stone_a, stone_b, blend);
		float lush = mix(pal_params[sa].x, pal_params[sb].x, blend);
		float up = smoothstep(0.55, 0.95, v_wny) * smoothstep(0.4, 0.6, pnoise(p * 6.0, 180.0));
		col = mix(col, mix(pal_grass_dark[sa].rgb, pal_grass_dark[sb].rgb, blend), up * lush * 0.7);
	} else {
		vec3 grass_a = pal_grass[sa].rgb / REF_FOLIAGE;
		vec3 grass_b = pal_grass[sb].rgb / REF_FOLIAGE;
		col = COLOR.rgb * mix(grass_a, grass_b, blend);
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
	}
	if (use_normal) {
		NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	}
	ALBEDO = col;
	EMISSION = em;
	AO = hemi_ao(v_wny, COLOR.a);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	FOG = vec4(fog_color.rgb, v_fog);
}
