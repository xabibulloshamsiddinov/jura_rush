// Coins: drawn through MultiMesh and spun entirely in the vertex shader (no per-coin scripts).
shader_type spatial;
render_mode unshaded, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0, 0.8, 0.1, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.95, 0.6, 1.0);
uniform float spin_speed = 4.0;

varying float v_fog;
varying float v_shade;

void vertex() {
	// The instance basis stands the disc upright; spinning about local Z turns it about world Y.
	float a = TIME * spin_speed + float(INSTANCE_ID) * 0.45;
	float c = cos(a);
	float s = sin(a);
	mat3 rot = mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
	vec3 v = rot * VERTEX;
	vec3 n = rot * NORMAL;
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(n, 0.0)).xyz);
	v_shade = 0.55 + 0.75 * abs(vn.z);
	vec3 vp = (MODELVIEW_MATRIX * vec4(v, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
	NORMAL = vn;
}

void fragment() {
	vec3 col = mix(albedo.rgb, rim.rgb, smoothstep(0.9, 1.3, v_shade)) * v_shade * 1.3;
	ALBEDO = mix(col, fog_color.rgb, v_fog);
}
