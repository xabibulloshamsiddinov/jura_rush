// Shield power-up bubble: fresnel rim + scrolling hex-like lattice + hit ripple.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform float hit = 0.0;
uniform float strength = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec2 uv = UV * vec2(18.0, 10.0) + vec2(TIME * 0.6, TIME * 0.25);
	float lattice = abs(sin(uv.x) * sin(uv.y + sin(uv.x * 0.5) * 1.5));
	lattice = smoothstep(0.75, 1.0, 1.0 - lattice) * 0.35;
	float ripple = hit * (0.5 + 0.5 * sin(UV.y * 40.0 - TIME * 30.0));
	ALBEDO = tint.rgb * (1.0 + hit * 2.0);
	ALPHA = clamp((fres + lattice + ripple) * strength, 0.0, 1.0);
}
