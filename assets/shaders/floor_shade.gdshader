// Multiplied shade over the floor inside caves: darkens the shared stone-path track (which does
// not know it is underground) without touching obstacles, eggs or the runner standing on it.
// Fades with the fog so far caves do not punch dark holes into the haze.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 shade : source_color = vec4(0.5, 0.45, 0.42, 1.0);

varying float v_fog;

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
}

void fragment() {
	ALBEDO = mix(shade.rgb, vec3(1.0), v_fog);
}
