// Side decor (towers, warehouses, pylons): dark body with a procedural grid of lit windows.
// Window colours follow the biome accents, so biomes cross-fade without touching meshes.
shader_type spatial;
render_mode unshaded, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.065, 0.04, 0.13, 1.0);
uniform float window_energy = 1.35;
uniform float lit_ratio = 0.42;
// Window grid cell in metres (width, height) and the share of the cell the pane fills.
uniform vec2 window_cell = vec2(1.5, 1.9);
uniform vec2 window_fill = vec2(0.5, 0.48);
// Share of lit windows in the second accent colour (magenta in the neon biome).
uniform float accent2_ratio = 0.45;
// Share of windows that switch on / off over time, and the switching speed (0 = static).
uniform float flicker_ratio = 0.0;
uniform float flicker_speed = 0.35;

varying float v_fog;
varying float v_shade;
varying vec2 v_face_uv;
varying float v_side;
varying float v_seed;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 local = VERTEX * scale;
	// Side faces only: pick the wall plane from the normal.
	v_side = 1.0 - abs(NORMAL.y);
	v_face_uv = abs(NORMAL.x) > 0.5 ? local.zy : local.xy;
	v_seed = MODEL_MATRIX[3].x * 0.37 + scale.y;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_shade = 0.6 + 0.5 * max(dot(wn, SUN_DIR), 0.0);
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 grid = v_face_uv / window_cell;
	vec2 cell = floor(grid);
	vec2 in_cell = fract(grid);
	float rnd = hash21(cell + vec2(v_seed, v_seed * 1.7));
	float lit = step(1.0 - lit_ratio, rnd);
	float rnd2 = hash21(cell * 1.31 + vec2(v_seed * 2.3, 5.7));
	if (rnd2 < flicker_ratio) {
		// Each flickering window has its own slow on/off rhythm.
		lit = step(0.45, fract(TIME * flicker_speed * (0.5 + rnd2 * 3.0) + rnd * 11.0));
	}
	vec2 lo = (1.0 - window_fill) * 0.5;
	float mask = step(lo.x, in_cell.x) * step(in_cell.x, 1.0 - lo.x) * step(lo.y, in_cell.y) * step(in_cell.y, 1.0 - lo.y);
	// Hash of the cell decides the colour; lit windows are already rnd > 1 - lit_ratio, so rescale.
	float pick = hash21(cell * 0.73 + vec2(v_seed * 3.1, 9.2));
	vec3 win = mix(biome_accent.rgb, biome_accent2.rgb, step(1.0 - accent2_ratio, pick)) * window_energy;
	// A faint glow band along each floor line, like light spilling from the windows.
	float spill = smoothstep(0.5, 0.0, abs(in_cell.y - 0.5)) * 0.06 * v_side;
	vec3 col = albedo.rgb * COLOR.rgb * v_shade + win * lit * mask * v_side + biome_accent2.rgb * spill;
	ALBEDO = mix(col, fog_color.rgb, v_fog);
}
