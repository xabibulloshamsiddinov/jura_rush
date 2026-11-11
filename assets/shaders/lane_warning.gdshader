// Faint warning painted on the rails in front of a barrier: chevrons that slide toward the
// player and fade in near the obstacle. Additive, no depth write, follows the curved world + fog.
// The plane's UV.y runs from the obstacle side (0) to the player side (1).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.25, 1.0);
uniform float opacity = 0.32;
uniform float chevrons = 4.0;
uniform float speed = 1.6;

// The marker fades out before it reaches the runner (world z = 0, forward = -Z): it warns about
// what is ahead and never paints the ground under or behind the player.
uniform float player_clear_start = -6.0;
uniform float player_clear_end = -2.5;

varying float v_fog;
varying float v_world_z;

void vertex() {
	v_world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;                       // 0 centre .. 1 edge
	float band = fract(UV.y * chevrons + x * 0.45 - TIME * speed);
	float chevron = smoothstep(0.0, 0.12, band) * (1.0 - smoothstep(0.32, 0.46, band));
	float edge = smoothstep(1.0, 0.82, x);                  // soft lane edges
	float along = (1.0 - UV.y) * smoothstep(0.0, 0.15, UV.y) + 0.15; // strongest near the obstacle
	float clear = 1.0 - smoothstep(player_clear_start, player_clear_end, v_world_z);
	float a = (chevron * 0.85 + 0.15) * edge * along * clear * opacity * (1.0 - v_fog);
	ALBEDO = tint.rgb * a;
}
