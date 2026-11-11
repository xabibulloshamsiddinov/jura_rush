// Coins: drawn through MultiMesh and spun entirely in the vertex shader (no per-coin scripts).
// Coins close to the camera shrink to nothing (near_fade_*), so one can never fill the screen,
// and the colour is capped (max_brightness) below the glow threshold so yellow stays yellow.
shader_type spatial;
render_mode unshaded, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0, 0.78, 0.08, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float spin_speed = 4.0;
// Distance from the camera (metres) where shrinking starts / where the coin is gone.
uniform float near_fade_start = 4.5;
uniform float near_fade_end = 2.0;
uniform float max_brightness = 1.05;

varying float v_fog;
varying float v_shade;

void vertex() {
	// The instance basis stands the disc upright; spinning about local Z turns it about world Y.
	float a = TIME * spin_speed + float(INSTANCE_ID) * 0.45;
	float c = cos(a);
	float s = sin(a);
	mat3 rot = mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
	// Scale about the coin centre by its distance to the camera (scale, not alpha: stays opaque,
	// no sorting, no overdraw).
	float centre_depth = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	float keep = smoothstep(near_fade_end, near_fade_start, centre_depth);
	vec3 v = rot * VERTEX * keep;
	vec3 n = rot * NORMAL;
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(n, 0.0)).xyz);
	v_shade = 0.6 + 0.55 * abs(vn.z);
	vec3 vp = (MODELVIEW_MATRIX * vec4(v, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
	NORMAL = vn;
}

void fragment() {
	vec3 col = mix(albedo.rgb, rim.rgb, 0.6 * smoothstep(0.95, 1.15, v_shade)) * v_shade;
	// Cap the brightest channel, keeping the hue.
	float peak = max(col.r, max(col.g, col.b));
	col *= min(1.0, max_brightness / max(peak, 0.0001));
	ALBEDO = mix(col, fog_color.rgb, v_fog);
}
