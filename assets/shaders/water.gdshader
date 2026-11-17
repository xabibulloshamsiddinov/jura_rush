// River under the log bridges: stylised teal water flowing across the track, with drifting foam
// streaks, a sky reflection toward grazing angles and sun glints. Lit, so the bridge shadow falls
// on it. UV = chunk-local (x, z) in metres (periodic along z for seamless chunk joins).
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, specular_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"
#include "res://assets/shaders/world_light.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.12, 0.36, 0.42, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.58, 0.6, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 0.96, 0.95, 1.0);
uniform float flow_speed = 0.9;

varying float v_fog;

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	vec2 p = UV;
	float flow = TIME * flow_speed;
	float n = pnoise(vec2(p.x * 0.18 - flow * 0.35, p.y * 0.4), 12.0);
	vec3 col = mix(deep.rgb, shallow.rgb, n);
	float streak = pnoise(vec2(p.x * 0.5 - flow, p.y * 1.6), 48.0);
	float foam_m = smoothstep(0.72, 0.84, streak) * (0.6 + 0.4 * n);
	col = mix(col, foam.rgb, foam_m * 0.75);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sky = fog_color.rgb;
	float glint = smoothstep(0.86, 0.96, pnoise(vec2(p.x * 2.4 - flow * 2.0, p.y * 2.4), 72.0)) * 0.6;
	ALBEDO = col * 0.85;
	EMISSION = sky * (0.12 + 0.5 * fres) + vec3(1.0, 0.95, 0.85) * glint * 0.4;
	ROUGHNESS = 1.0;
	FOG = vec4(fog_color.rgb, v_fog);
}
