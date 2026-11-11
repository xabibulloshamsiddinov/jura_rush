// Chromatic aberration pulse (crash). Reads the screen, so the node is only visible while pulsing.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;

void fragment() {
	vec2 dir = (SCREEN_UV - vec2(0.5)) * amount * 0.06;
	float r = texture(screen_tex, SCREEN_UV + dir).r;
	float g = texture(screen_tex, SCREEN_UV).g;
	float b = texture(screen_tex, SCREEN_UV - dir).b;
	COLOR = vec4(r, g, b, 1.0);
}
