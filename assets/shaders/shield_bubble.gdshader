// Shell Shield bubble around the runner: a translucent jade shell with soft tortoise-shell plates
// (a hex lattice), a fresnel rim and a bright ripple on hits. Alpha-blended: the old additive cyan
// bubble washed out to white over the daylight world and read as a neon leftover.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.32, 0.76, 0.7, 1.0);
// Seams between the shell plates.
uniform vec4 seam_color : source_color = vec4(0.16, 0.3, 0.22, 1.0);
uniform float hit = 0.0;
uniform float strength = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	// Hex plates: the nearest of two offset lattices, distance to the cell edge (0.5 = seam).
	vec2 uv = UV * vec2(16.0, 9.0) + vec2(TIME * 0.12, 0.0);
	vec2 r = vec2(1.0, 1.7320508);
	vec2 a = mod(uv, r) - r * 0.5;
	vec2 b = mod(uv - r * 0.5, r) - r * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 p = abs(g);
	float d = max(dot(p, vec2(0.5, 0.8660254)), p.x);
	float seam = smoothstep(0.4, 0.49, d);
	float ripple = hit * (0.5 + 0.5 * sin(UV.y * 40.0 - TIME * 30.0));
	vec3 col = mix(tint.rgb * 1.15, seam_color.rgb, seam * 0.7);
	col = mix(col, vec3(1.0, 0.97, 0.88), clamp(hit * 0.7 + fres * 0.25, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp((0.06 + fres * 0.6 + seam * 0.2 * (0.35 + 0.65 * fres) + ripple * 0.45) * strength, 0.0, 0.85);
}
