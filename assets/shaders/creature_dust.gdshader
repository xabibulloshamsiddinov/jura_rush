// Soft dust puffs kicked up by creatures (MultiMesh of camera-facing quads; per-instance colour
// and alpha come from the MultiMesh colours). Bends and fogs like every world material.
shader_type spatial;
render_mode unshaded, skip_vertex_transform, blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec3 shade_color : source_color = vec3(0.78, 0.72, 0.64);

varying float v_fog;
varying vec2 v_uv;

void vertex() {
	vec3 center = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 vp = center + vec3(VERTEX.xy * size, 0.0);
	v_fog = fog_amount(vp);
	v_uv = UV;
	VERTEX = curve_world(vp);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 d = v_uv * 2.0 - 1.0;
	float r = dot(d, d);
	float soft = 1.0 - smoothstep(0.15, 1.0, r);
	// Lit from above: the top of each puff is brighter.
	vec3 col = pow(COLOR.rgb, vec3(2.2)) * mix(shade_color, vec3(1.08), 1.0 - smoothstep(-0.6, 0.6, d.y));
	ALBEDO = mix(col, fog_color.rgb, v_fog);
	ALPHA = COLOR.a * soft * (1.0 - v_fog);
}
