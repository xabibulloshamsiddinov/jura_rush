// Warning painted on the stone path in front of a barrier: ochre chevrons (cave-paint style) that
// slide gently toward the player and fade in near the obstacle. Alpha-blended earthy paint (not
// additive neon), no depth write, follows the curved world + fog.
// The plane's UV.y runs from the obstacle side (0) to the player side (1).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;
#include "res://assets/shaders/world_common.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.9, 0.48, 0.14, 1.0);
uniform float opacity = 0.55;
uniform float chevrons = 3.0;
uniform float speed = 0.9;
// 1 = colour-blind palette (Mats.set_colorblind): bright yellow chevrons with a dark outline,
// nearly opaque, readable for every colour-vision type on stone, grass and in caves.
uniform float cb = 0.0;

// The marker fades out before it reaches the runner (world z = 0, forward = -Z): it warns about
// what is ahead and never paints the ground under or behind the player.
uniform float player_clear_start = -6.0;
uniform float player_clear_end = -2.5;

varying float v_fog;
varying float v_world_z;

// The plane is placed 1.5 cm up by ObstacleBase; lift it over the flagstone path surface.
uniform float lift = 0.04;

void vertex() {
	VERTEX.y += lift;
	v_world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = fog_amount(vp);
	VERTEX = curve_world(vp);
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;                       // 0 centre .. 1 edge
	float band = fract(UV.y * chevrons + x * 0.55 - TIME * speed);
	// Brushed edge: the paint stroke is a little ragged.
	float rag = (hash12(floor(UV * vec2(24.0, 60.0))) - 0.5) * 0.06;
	float chevron = smoothstep(0.0, 0.07, band + rag) * (1.0 - smoothstep(0.3, 0.38, band + rag));
	float edge = smoothstep(0.95, 0.75, x);                 // soft lane edges
	float along = (1.0 - UV.y) * smoothstep(0.0, 0.12, UV.y) + 0.1; // strongest near the obstacle
	float clear = 1.0 - smoothstep(player_clear_start, player_clear_end, v_world_z);
	vec3 col = tint.rgb;
	float strength = opacity;
	if (cb > 0.5) {
		// Dark outline: the same chevron, widened by 0.07 of a band on both sides.
		float b2 = fract(band + rag + 0.07);
		float outline = smoothstep(0.0, 0.03, b2) * (1.0 - smoothstep(0.5, 0.53, b2));
		col = mix(vec3(0.03, 0.025, 0.02), vec3(1.0, 0.75, 0.02), chevron);
		chevron = max(chevron, outline);
		strength = 0.95;
		along = max(along, 0.5);
	}
	float a = chevron * edge * clamp(along * 1.4, 0.0, 1.0) * clear * strength * (1.0 - v_fog);
	ALBEDO = mix(col, fog_color.rgb, v_fog);
	ALPHA = clamp(a, 0.0, 1.0);
}
