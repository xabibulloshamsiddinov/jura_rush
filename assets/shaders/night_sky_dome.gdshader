// Night sky drawn on a dome that follows the camera (BiomeDirector): biome gradient, a star
// field, a moon and a distant skyline with a few lit windows along the horizon.
// A dome instead of a Sky resource: a custom Sky shader made frame time creep up on the test
// device (radiance work), while this is one cheap unshaded draw with no radiance at all.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 sky_top : source_color = vec4(0.01, 0.01, 0.06, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.22, 0.05, 0.38, 1.0);
uniform vec4 ground : source_color = vec4(0.05, 0.03, 0.15, 1.0);
uniform vec4 skyline_color : source_color = vec4(0.03, 0.02, 0.08, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.45, 0.85, 1.0);
uniform float stars_amount = 1.0;      // 0 = no stars
uniform float moon_amount = 1.0;       // 0 = no moon
uniform float skyline_amount = 1.0;    // 0 = no skyline
uniform vec3 moon_dir = vec3(-0.33, 0.3, -0.89);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

varying vec3 v_dir;

void vertex() {
	v_dir = VERTEX;   // dome centred on the camera: local vertex = view direction (world axes)
}

void fragment() {
	vec3 d = normalize(v_dir);
	float h = d.y;
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, smoothstep(0.0, 0.55, h));

	if (stars_amount > 0.0 && h > 0.04) {
		vec2 uv = vec2(atan(d.x, d.z), asin(h)) * 55.0;
		vec2 cell = floor(uv);
		float r = hash12(cell);
		vec2 f = fract(uv) - 0.5 - (vec2(hash12(cell + 7.1), hash12(cell + 3.3)) - 0.5) * 0.6;
		float star = step(0.975, r) * smoothstep(0.11, 0.0, length(f)) * (0.4 + 0.6 * hash12(cell + 1.9));
		col += vec3(0.85, 0.9, 1.0) * star * smoothstep(0.04, 0.35, h) * stars_amount;
	}

	if (moon_amount > 0.0) {
		float md = dot(d, normalize(moon_dir));
		float disc = smoothstep(0.99935, 0.99955, md);
		col = mix(col, vec3(0.92, 0.9, 1.0), disc * moon_amount);
		col += vec3(0.6, 0.5, 0.9) * pow(max(md, 0.0), 900.0) * 0.5 * moon_amount;
	}

	if (skyline_amount > 0.0) {
		float az = atan(d.x, d.z) * 38.0;
		float block = floor(az);
		float top = 0.012 + 0.07 * pow(hash12(vec2(block, 4.0)), 1.8);
		if (h < top && h > -0.05) {
			vec3 sil = skyline_color.rgb;
			vec2 win = vec2(fract(az) * 6.0, h * 260.0);
			float lit = step(0.86, hash12(floor(win) + block * 13.0))
					* step(0.25, fract(win.x)) * step(0.3, fract(win.y));
			sil += window_color.rgb * lit * 0.45;
			col = mix(col, sil, skyline_amount);
		}
	}

	col = mix(ground.rgb, col, smoothstep(-0.06, 0.0, h));
	ALBEDO = col;
}
