// Stylised day sky on a dome that follows the camera (BiomeDirector): zenith -> horizon haze
// gradient, a sun disc with halo, soft toon clouds, far mountain silhouettes per biome style
// (rolling forested hills, mesas, misty tree lines, jagged peaks with a smoking volcano) and a few
// pterosaurs gliding far away. One cheap unshaded draw, no radiance work (a custom Sky shader made
// the frame time creep up on the test device).
// Azimuth 0 = straight down the track (-Z), positive = right. h = sin(elevation).
// The land (silhouettes, volcano, horizon haze, ground) sits on the CURVED world's visual horizon,
// not on the eye-level one: the bend (bend_y) drops the track out of sight below eye level, about
// 2 * bend_y * sqrt(camera height) (the crest of the bent ground, ~95 m ahead in the run). With
// the land on the eye-level horizon, the gap between the two showed as a flat fog-coloured slab
// with a jagged top at the end of the track; now the hazy hills rise straight from the far path.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

global uniform float bend_y;

uniform vec4 sky_top : source_color = vec4(0.3, 0.58, 0.9, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.93, 0.86, 0.7, 1.0);
uniform vec4 ground : source_color = vec4(0.86, 0.85, 0.74, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.72, 0.78, 0.88, 1.0);
uniform vec4 far_tint : source_color = vec4(0.45, 0.58, 0.6, 1.0);
uniform vec4 near_tint : source_color = vec4(0.24, 0.42, 0.3, 1.0);
uniform vec4 lava_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 bird_color : source_color = vec4(0.22, 0.18, 0.2, 1.0);
// Decorative sun position (direction). The key light comes from the same side (upper right).
uniform vec3 sun_dir = vec3(0.21, 0.14, -0.97);
uniform float cloud_amount = 0.5;
uniform float style_a = 0.0;
uniform float style_b = 0.0;
uniform float style_mix = 0.0;
uniform float pterosaurs = 1.0;
uniform float volcano_az = -0.2;

varying vec3 v_dir;

void vertex() {
	v_dir = VERTEX;   // dome centred on the camera: local vertex = view direction (world axes)
}

float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), u);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm1(float x) {
	return noise1(x) * 0.55 + noise1(x * 2.1 + 3.7) * 0.3 + noise1(x * 4.3 + 9.1) * 0.15;
}

// Volcano cone height (0 outside it).
float volcano(float az) {
	float dx = abs(az - volcano_az);
	float cone = 0.165 - dx * 0.62 - 0.012 * noise1(az * 60.0);
	cone = min(cone, 0.128 + 0.004 * noise1(az * 90.0));
	return max(cone, 0.0);
}

// Ridge height of the far (layer 0) and near (layer 1) silhouettes for one biome style.
vec2 ridges(int s, float az) {
	if (s == 1) {
		// Red Canyon: flat-topped mesas and buttes.
		float n = fbm1(az * 1.7 + 4.0);
		float far = 0.02 + smoothstep(0.42, 0.455, n) * 0.06 + smoothstep(0.6, 0.63, n) * 0.035;
		far -= 0.004 * noise1(az * 70.0);
		float m = fbm1(az * 3.1 + 11.0);
		float near = 0.008 + smoothstep(0.5, 0.53, m) * 0.04 + 0.006 * noise1(az * 40.0);
		return vec2(far, near);
	} else if (s == 2) {
		// Misty Swamp: low hills and a lumpy tree line.
		float far = 0.025 + 0.03 * fbm1(az * 2.0 + 1.0);
		float k = az * 55.0 + noise1(az * 9.0) * 2.0;
		float bump = sqrt(max(1.0 - pow(fract(k) * 2.0 - 1.0, 2.0), 0.0));
		float near = 0.014 + 0.01 * fbm1(az * 6.0) + bump * (0.006 + 0.008 * hash1(floor(k)));
		return vec2(far, near);
	} else if (s == 3) {
		// Volcano Ridge: jagged peaks and the volcano.
		float n = noise1(az * 3.0 + 2.0) * 0.6 + noise1(az * 7.0) * 0.4;
		float jag = 1.0 - abs(n * 2.0 - 1.0);
		float far = 0.03 + 0.09 * jag * jag + 0.012 * noise1(az * 40.0);
		far = max(far, volcano(az));
		float m = noise1(az * 6.0 + 5.0);
		float near = 0.006 + 0.035 * pow(1.0 - abs(m * 2.0 - 1.0), 2.0) + 0.006 * noise1(az * 55.0);
		return vec2(far, near);
	}
	// Fern Valley: soft blue mountains, forested hills with conifer spikes.
	float far = 0.03 + 0.085 * smoothstep(0.2, 0.9, fbm1(az * 2.3 + 6.0));
	float k = az * 120.0;
	float tree = (1.0 - abs(fract(k) * 2.0 - 1.0)) * (0.004 + 0.006 * hash1(floor(k)));
	float near = 0.012 + 0.03 * fbm1(az * 4.5 + 2.0) + tree;
	return vec2(far, near);
}

// Pterosaur silhouette mask in local coordinates (x along the span, y up), facing `dir`.
float pterosaur(vec2 q, float flap, float dir) {
	float ax = abs(q.x);
	if (ax > 1.05 || q.y < -0.5 || q.y > 0.5) {
		return 0.0;
	}
	float yc = (0.22 * sin(3.14159 * min(ax, 1.0)) - 0.12 * ax) * (0.55 + 0.45 * flap);
	float th = 0.17 * pow(max(1.0 - ax, 0.0), 0.7) + 0.015;
	float wing = 1.0 - smoothstep(th * 0.5, th * 0.5 + 0.04, abs(q.y - yc + th * 0.15));
	float body = 1.0 - smoothstep(0.9, 1.15, length(vec2(q.x / 0.11, (q.y + 0.01) / 0.08)));
	// Pickaxe head: a beak forward, a crest back.
	vec2 hq = vec2(q.x * dir, q.y - 0.05);
	float beak = step(0.0, hq.x) * step(hq.x, 0.36) * step(abs(hq.y + hq.x * 0.1), 0.03 * (1.0 - hq.x / 0.36) + 0.006);
	float crest = step(hq.x, 0.0) * step(-0.26, hq.x) * step(abs(hq.y - 0.06 + hq.x * 0.25), 0.025 * (1.0 + hq.x / 0.26) + 0.005);
	return clamp(max(max(wing, body), max(beak, crest)), 0.0, 1.0);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float h = d.y;
	float az = atan(d.x, -d.z);
	float aa = max(fwidth(h), 0.0005);
	// Height above the curved world's visual horizon (the dome is centred on the camera).
	float dip = 2.0 * max(bend_y, 0.0) * sqrt(max(NODE_POSITION_WORLD.y, 0.5));
	float hl = h + dip;

	// Sky gradient: warm haze at the horizon, clear blue overhead.
	// The run camera only sees up to h ~ 0.35, so the blue has to arrive early.
	float g = pow(smoothstep(-0.02, 0.4, h), 0.6);
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, g);

	// Sun halo and disc.
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_color.rgb * (pow(sd, 6.0) * 0.22 + pow(sd, 48.0) * 0.35);
	float disc = smoothstep(0.99935, 0.99955, sd);
	col = mix(col, vec3(1.0, 0.98, 0.9) * 1.25, disc);

	// Soft toon clouds on a flat layer.
	if (cloud_amount > 0.0 && h > 0.015) {
		// Puffy cumulus with clear blue between them: large shapes, a high threshold.
		vec2 uv = d.xz / (h + 0.07) * 0.34 + vec2(TIME * 0.006, TIME * 0.0025);
		float dens = noise2(uv * 1.3) * 0.55 + noise2(uv * 2.9 + 7.1) * 0.3 + noise2(uv * 6.2 + 3.3) * 0.15;
		float thr = 0.74 - cloud_amount * 0.14;
		float c = smoothstep(thr, thr + 0.05, dens) * smoothstep(0.015, 0.1, h);
		vec2 toward = normalize(sun_dir.xz + 1e-4) * 0.06;
		float dens2 = noise2((uv - toward) * 1.3) * 0.55 + noise2((uv - toward) * 2.9 + 7.1) * 0.3
				+ noise2((uv - toward) * 6.2 + 3.3) * 0.15;
		float lit = smoothstep(-0.05, 0.08, dens - dens2 + 0.03);
		vec3 cc = mix(cloud_shade.rgb, cloud_light.rgb, lit);
		cc = mix(cc, sky_horizon.rgb, smoothstep(0.25, 0.02, h) * 0.45);
		col = mix(col, cc, c * 0.92);
	}

	// Pterosaurs gliding far away.
	if (pterosaurs > 0.0 && h > 0.02 && h < 0.32) {
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float period = 34.0 + fi * 13.0;
			float t = fract(TIME / period + fi * 0.41);
			float dir = i == 1 ? -1.0 : 1.0;
			float paz = mix(-0.6, 0.6, t) * dir + 0.08 * sin(TIME * 0.2 + fi * 2.0);
			float ph = 0.085 + 0.045 * fi + 0.015 * sin(TIME * 0.33 + fi * 1.7);
			float size = 0.012 - fi * 0.0025;
			vec2 q = vec2((az - paz) * cos(asin(h)), h - ph) / size;
			float flap = clamp(sin(TIME * 5.0 + fi * 2.0) * step(0.55, sin(TIME * 0.45 + fi * 1.9)), -1.0, 1.0);
			float m = pterosaur(q, 0.5 + 0.5 * flap, dir);
			col = mix(col, mix(bird_color.rgb, sky_horizon.rgb, 0.15 + fi * 0.15), m);
		}
	}

	// Far silhouettes: two hazy layers, styles cross-fading.
	int sa = int(style_a + 0.5);
	int sb = int(style_b + 0.5);
	vec2 r = ridges(sa, az);
	if (style_mix > 0.001) {
		r = mix(r, ridges(sb, az), style_mix);
	}
	float far_m = 1.0 - smoothstep(r.x - aa, r.x + aa, hl);
	float near_m = 1.0 - smoothstep(r.y - aa, r.y + aa, hl);
	vec3 far_col = mix(far_tint.rgb, sky_horizon.rgb, 0.35 + 0.4 * smoothstep(0.1, -0.02, hl));
	far_col *= 0.94 + 0.12 * smoothstep(r.x - 0.03, r.x, hl);
	col = mix(col, far_col, far_m);
	// Volcano: smoke plume, glowing crater and lava streaks.
	float vol = mix(sa == 3 ? 1.0 : 0.0, sb == 3 ? 1.0 : 0.0, style_mix);
	if (vol > 0.01) {
		float top = 0.128;
		float above = hl - top;
		if (above > -0.01 && above < 0.25) {
			float cx = volcano_az + above * 0.55 + 0.01 * sin(TIME * 0.3 + above * 20.0);
			float w = 0.012 + above * 0.38;
			float px = (az - cx) / w;
			float puff = noise2(vec2(px * 1.5, above * 18.0 - TIME * 0.35))
					* 0.6 + noise2(vec2(px * 3.0 + 4.0, above * 36.0 - TIME * 0.6)) * 0.4;
			float smoke = (1.0 - smoothstep(0.6, 1.0, abs(px))) * smoothstep(-0.01, 0.01, above)
					* smoothstep(0.25, 0.05, above) * smoothstep(0.25, 0.55, puff);
			vec3 smoke_col = mix(vec3(0.33, 0.29, 0.28), sky_horizon.rgb, 0.25 + above * 2.0);
			col = mix(col, smoke_col, smoke * 0.85 * vol * (1.0 - far_m * step(hl, top)));
		}
		float cone = volcano(az);
		if (cone > 0.0 && hl < cone) {
			float rim = smoothstep(top - 0.018, top, hl) * step(abs(az - volcano_az), 0.06);
			float k = (az - volcano_az) * 36.0 + noise1(hl * 30.0) * 1.5;
			float streak = (1.0 - smoothstep(0.0, 0.12, abs(fract(k) - 0.5))) * step(hash1(floor(k)), 0.35)
					* smoothstep(0.03, top, hl);
			col += lava_color.rgb * (rim * 1.4 + streak * 0.8) * vol;
		}
	}
	vec3 near_col = mix(near_tint.rgb, sky_horizon.rgb, 0.25 + 0.35 * smoothstep(0.05, -0.03, hl));
	col = mix(col, near_col, near_m);

	// Horizon haze band and the ground below (fog colour, matches the fogged world).
	col = mix(col, ground.rgb, smoothstep(0.03, -0.02, hl) * 0.85);
	col = mix(ground.rgb, col, smoothstep(-0.07, -0.01, hl));
	ALBEDO = col;
}
