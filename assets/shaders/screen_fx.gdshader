// Full-screen overlay: subtle warm speed lines at the edges, vignette and a soft colour flash.
// No screen read.
shader_type canvas_item;

uniform float speed_lines = 0.0;
uniform float vignette = 0.24;
uniform vec4 line_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash = 0.0;
uniform vec4 edge_color : source_color = vec4(0.85, 0.2, 0.08, 1.0);
uniform float edge = 0.0;

float hash11(float p) {
	return fract(sin(p * 91.345) * 47453.5453);
}

void fragment() {
	vec2 p = UV - vec2(0.5, 0.45);
	float r = length(p * vec2(1.0, 1.25));
	float a = atan(p.y, p.x);
	float slice = floor(a * 28.0);
	float rnd = hash11(slice);
	float streak = step(0.72, rnd) * step(fract(r * 2.5 - TIME * (3.0 + rnd * 4.0) + rnd), 0.35);
	float lines = streak * smoothstep(0.38, 0.75, r) * speed_lines;
	float vig = smoothstep(0.35, 0.95, r);
	vec3 col = line_color.rgb * lines;
	float alpha = lines * 0.35;
	col = mix(col, vec3(0.1, 0.07, 0.04), vig * vignette * (1.0 - lines));
	alpha = max(alpha, vig * vignette);
	col = mix(col, edge_color.rgb, vig * edge);
	alpha = max(alpha, vig * edge);
	col = mix(col, flash_color.rgb, flash);
	alpha = max(alpha, flash);
	COLOR = vec4(col, alpha);
}
