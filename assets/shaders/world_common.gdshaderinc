// Shared by every world material: curved-world vertex bend + distance fog.
// Bend and fog values are GLOBAL shader parameters (Project Settings > Shader Globals),
// animated at runtime by BiomeDirector / TrackManager through RenderingServer.
global uniform float bend_x;
global uniform float bend_y;
global uniform float fog_start;
global uniform float fog_end;
global uniform vec4 fog_color : source_color;
global uniform vec4 biome_accent : source_color;
global uniform vec4 biome_accent2 : source_color;

// Fixed fake sun direction (world space) for the cheap baked-in shading.
const vec3 SUN_DIR = vec3(0.3287, 0.7513, 0.5723);

// Bends a VIEW-space position: drops with distance (hides the horizon) and drifts sideways.
// y -= (d * bend_y)^2, x += sign(bend_x) * (d * bend_x)^2
vec3 curve_world(vec3 view_pos) {
	float d = view_pos.z;
	float by = d * bend_y;
	float bx = d * bend_x;
	view_pos.y -= by * by;
	view_pos.x += sign(bend_x) * bx * bx;
	return view_pos;
}

// 0 = no fog, 1 = fully fogged. Depth based so it is stable while strafing.
float fog_amount(vec3 view_pos) {
	return smoothstep(fog_start, fog_end, -view_pos.z);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
