// Eggs (the collectible; this file keeps the old coin name): drawn through MultiMesh and animated
// entirely in the vertex shader (no per-egg scripts): a slow turn plus a gentle wobble and bob.
// Speckled cream shell with a soft sun highlight and a warm rim so eggs pop against foliage and
// stone. Eggs close to the camera shrink to nothing (near_fade_*), so one can never fill the
// screen, and the colour is capped (max_brightness) below the bloom threshold except for a tiny
// glint. Eggs cast a small real shadow (the shadow pass bends and shrinks them like the camera).
shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_back;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 shell : source_color = vec4(0.96, 0.92, 0.8, 1.0);
uniform vec4 speckle_a : source_color = vec4(0.36, 0.6, 0.56, 1.0);
uniform vec4 speckle_b : source_color = vec4(0.5, 0.33, 0.2, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.8, 0.45, 1.0);
uniform float turn_speed = 1.3;
uniform float wobble = 0.22;
// Distance from the camera (metres) where shrinking starts / where the egg is gone.
uniform float near_fade_start = 4.5;
uniform float near_fade_end = 2.0;
uniform float max_brightness = 1.05;

varying float v_fog;
varying float v_shade;
varying float v_rim;
varying float v_spec;
varying vec3 v_obj;
varying float v_seed;

void vertex() {
	float seed = float(INSTANCE_ID) * 0.61;
	v_seed = seed;
	float a = TIME * turn_speed + seed * 2.3;
	float tilt = sin(TIME * 2.6 + seed * 3.0) * wobble;
	float c = cos(a);
	float s = sin(a);
	mat3 spin = mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
	float ct = cos(tilt);
	float st = sin(tilt);
	mat3 rock = mat3(vec3(ct, st, 0.0), vec3(-st, ct, 0.0), vec3(0.0, 0.0, 1.0));
	mat3 rot = rock * spin;
	v_obj = VERTEX;
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Shrink near the MAIN camera (also in the shadow pass, so the shadow shrinks with the egg).
	vec3 centre_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float keep = smoothstep(near_fade_end, near_fade_start, pass_depth(centre_view, centre, PROJECTION_MATRIX));
	vec3 v = rot * VERTEX * keep + vec3(0.0, sin(TIME * 2.2 + seed * 5.0) * 0.045, 0.0);
	vec3 wn = normalize(mat3(MODEL_MATRIX) * (rot * NORMAL));
	v_shade = 0.62 + 0.5 * max(dot(wn, SUN_DIR), 0.0);
	vec3 vp = (MODELVIEW_MATRIX * vec4(v, 1.0)).xyz;
	vec3 vn = normalize(mat3(MODELVIEW_MATRIX) * (rot * NORMAL));
	v_rim = pow(1.0 - clamp(dot(vn, normalize(-vp)), 0.0, 1.0), 2.2);
	vec3 half_v = normalize(normalize(-vp) + mat3(VIEW_MATRIX) * SUN_DIR);
	v_spec = pow(max(dot(vn, half_v), 0.0), 24.0);
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = vn;
}

void fragment() {
	// Speckles in object space (they turn with the egg).
	vec2 p = vec2(atan(v_obj.x, v_obj.z) * 2.2, v_obj.y * 14.0) + v_seed * 7.0;
	float n1 = vnoise(p * 2.2);
	float n2 = vnoise(p * 4.7 + 13.0);
	float dots_a = smoothstep(0.78, 0.86, n1);
	float dots_b = smoothstep(0.8, 0.9, n2) * (1.0 - dots_a);
	vec3 col = shell.rgb;
	col = mix(col, speckle_a.rgb, dots_a * 0.85);
	col = mix(col, speckle_b.rgb, dots_b * 0.8);
	col *= v_shade;
	col += rim.rgb * v_rim * 0.55;
	// Cap the brightest channel, keeping the hue; then a small soft highlight that may glow.
	float peak = max(col.r, max(col.g, col.b));
	col *= min(1.0, max_brightness / max(peak, 0.0001));
	col += vec3(1.0, 0.97, 0.9) * smoothstep(0.35, 0.9, v_spec) * 0.55;
	ALBEDO = mix(col, fog_color.rgb, v_fog);
}
