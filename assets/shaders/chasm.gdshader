// Gap / chasm in a lane, drawn on a flat plane at ground level with interior mapping: every
// pixel traces the view ray into a virtual box (lane width x gap length x `depth`) and shows the
// rock wall or floor it hits, so the lane looks cut open without touching the shared track mesh.
// Walls are banded rock that darkens with depth; the floor glows with lava (strongest in Volcano
// Ridge: heat = biome_accent2.a). The plane mesh is 1 x 1 on XZ, scaled by the node.
shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_back, shadows_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 wall_color : source_color = vec4(0.5, 0.41, 0.33, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.045, 0.035, 1.0);
uniform vec4 lava_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float depth = 7.5;
// Lava glow outside hot biomes (0..1); heat adds the rest.
uniform float lava_base = 0.3;
uniform float lava_energy = 2.4;

varying vec3 v_pos;
varying vec3 v_cam;
varying vec3 v_half;
varying float v_fog;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), 1.0, length(MODEL_MATRIX[2].xyz));
	v_half = vec3(scale.x * 0.5, depth, scale.z * 0.5);
	v_pos = VERTEX * scale;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	v_cam = (inverse(MODEL_MATRIX) * vec4(cam, 1.0)).xyz * scale;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	vec3 ro = vec3(v_pos.x, 0.0, v_pos.z);
	vec3 rd = normalize(ro - v_cam);
	rd.y = min(rd.y, -0.02);
	float tx = ((rd.x > 0.0 ? v_half.x : -v_half.x) - ro.x) / (abs(rd.x) > 1e-4 ? rd.x : 1e-4);
	float tz = ((rd.z > 0.0 ? v_half.z : -v_half.z) - ro.z) / (abs(rd.z) > 1e-4 ? rd.z : 1e-4);
	float ty = (-v_half.y - ro.y) / rd.y;
	tx = tx < 0.0 ? 1e6 : tx;
	tz = tz < 0.0 ? 1e6 : tz;
	float t = min(min(tx, tz), ty);
	vec3 hit = ro + rd * t;
	float d01 = clamp(-hit.y / v_half.y, 0.0, 1.0);
	float heat = clamp(lava_base + biome_accent2.a, 0.0, 1.0);
	vec3 col;
	vec3 glow = lava_color.rgb * heat;
	if (t >= ty - 0.001) {
		// Floor: cracked crust over lava.
		vec2 fp = hit.xz * 1.7;
		float n = fbm3(fp + vec2(TIME * 0.15, 0.0));
		float lava = smoothstep(0.35, 0.7, n);
		col = mix(deep_color.rgb, glow * lava_energy, lava * (0.6 + 0.4 * sin(TIME * 1.8 + n * 6.0)));
	} else {
		// Wall: horizontal strata, darker with depth, lit from below by the lava.
		float along = tx < tz ? hit.z : hit.x;
		float strata = vnoise(vec2(along * 1.3, hit.y * 3.2)) * 0.6 + vnoise(vec2(along * 4.0, hit.y * 9.0)) * 0.4;
		vec3 rock = wall_color.rgb * rock_tint() * (0.72 + 0.4 * strata);
		// Light dies fast below the rim (the camera mostly sees the upper far wall at a grazing
		// angle, so a slow falloff would read as a pale slab instead of a hole).
		float depth_m = -hit.y;
		float dark = exp(-depth_m * 1.6) * 0.42;
		col = mix(deep_color.rgb, rock, dark);
		// A thin sunlit lip right under the edge.
		col = mix(col, rock * 0.9, smoothstep(-0.07, -0.02, hit.y));
		// Lava light climbing the walls from below.
		col += glow * (pow(d01, 2.5) * 1.1 + exp(-(v_half.y - depth_m) * 0.45) * 0.25 * heat);
	}
	// Hot haze in the pit: grows with the length of the ray inside it, so even a grazing view
	// (which only reaches the upper far wall) glows warm - strongly in Volcano Ridge.
	col += glow * (1.0 - exp(-t * 0.22)) * (0.25 + 0.55 * heat);
	ALBEDO = mix(col, fog_color.rgb, v_fog);
}
