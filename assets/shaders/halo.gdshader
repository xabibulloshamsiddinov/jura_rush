// Soft camera-facing glow disc (power-up totem halo). A 1 x 1 quad billboarded in view space
// around its node origin, so it follows the curved world with the object it surrounds.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.25, 1.0);
uniform float energy = 0.8;
uniform float size = 1.9;
uniform float pulse = 0.15;

varying float v_fog;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 vp = centre + vec3(VERTEX.xy * size, 0.0);
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = pow(max(1.0 - r, 0.0), 2.2);
	float p = 1.0 - pulse + pulse * sin(TIME * 3.0);
	ALBEDO = tint.rgb * a * energy * p * (1.0 - v_fog);
}
