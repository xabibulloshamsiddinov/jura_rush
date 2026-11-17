// Shared by every world material: curved-world vertex bend + distance fog + small helpers.
// Bend and fog values are GLOBAL shader parameters (Project Settings > Shader Globals),
// animated at runtime by BiomeDirector / TrackManager through RenderingServer.
//
// Biome globals (Jura Rush):
//   fog_color       horizon haze of the current biome (rgb). Alpha unused (1).
//   biome_accent    FOLIAGE tint (rgb); alpha = lushness 0..1 (moss on rocks, grass in crevices).
//   biome_accent2   ROCK tint (rgb);    alpha = heat 0..1 (lava glow: 1 in Volcano Ridge).
// Tints are absolute colours; foliage_tint() / rock_tint() turn them into multipliers that are
// 1.0 for the Fern Valley reference palette.
global uniform float bend_x;
global uniform float bend_y;
global uniform float fog_start;
global uniform float fog_end;
global uniform vec4 fog_color : source_color;
global uniform vec4 biome_accent : source_color;
global uniform vec4 biome_accent2 : source_color;
// World z of the run camera: GameConfig.cam_back, pushed by TrackManager (one source of truth; the
// project default 6.5 only matters before the first run). The world is a treadmill, so the camera
// that matters always sits here; the directional shadow pass bends around it.
global uniform float run_cam_z;

// Sun direction (world space, pointing TOWARD the sun): warm key light from the upper right,
// slightly behind the camera. BiomeDirector aims its DirectionalLight3D along -SUN_DIR, so the
// baked shading of unshaded materials and the real light / shadows agree.
const vec3 SUN_DIR = vec3(0.7027, 0.6826, 0.2008);

// Reference palette the biome tints are measured against, in LINEAR space (the globals are
// source_color, so shaders see them linear): Fern Valley grass sRGB (0.34, 0.60, 0.22) and path
// stone sRGB (0.63, 0.59, 0.53).
const vec3 REF_FOLIAGE = vec3(0.0946, 0.3186, 0.0397);
const vec3 REF_ROCK = vec3(0.3547, 0.3070, 0.2428);

// Bends a VIEW-space position: drops with distance (hides the horizon) and drifts sideways.
// y -= (d * bend_y)^2, x += sign(bend_x) * (d * bend_x)^2
// Correct for the camera pass. Shadow casters should use CURVE_WORLD() below instead.
vec3 curve_world(vec3 view_pos) {
	float d = view_pos.z;
	float by = d * bend_y;
	float bx = d * bend_x;
	view_pos.y -= by * by;
	view_pos.x += sign(bend_x) * bx * bx;
	return view_pos;
}

// True in an orthographic pass (the directional light's shadow pass); the camera is perspective.
bool is_ortho_pass(mat4 proj) {
	return proj[3][3] > 0.5;
}

// Shadow-safe bend. Camera pass: exactly curve_world(). Directional shadow pass (orthographic):
// the same drop / drift applied in WORLD space by the distance in front of the run camera, so
// casters bend like the receivers they shade and shadows land where they should (bending in the
// light's own view space would push every caster metres away). Measured: without this, the
// curved cave let full sunlight onto its inner wall.
// inv_view / view / proj: INV_VIEW_MATRIX / VIEW_MATRIX / PROJECTION_MATRIX of the current pass.
// Use the CURVE_WORLD(vp) macro from vertex().
vec3 curve_world_ex(vec3 view_pos, mat4 inv_view, mat4 view, mat4 proj) {
	if (!is_ortho_pass(proj)) {
		return curve_world(view_pos);
	}
	vec3 world = (inv_view * vec4(view_pos, 1.0)).xyz;
	float d = run_cam_z - world.z;
	float by = d * bend_y;
	float bx = d * bend_x;
	world.y -= by * by;
	world.x += sign(bend_x) * bx * bx;
	return (view * vec4(world, 1.0)).xyz;
}
#define CURVE_WORLD(vp) curve_world_ex(vp, INV_VIEW_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX)

// Depth (metres) of a point in front of the camera that matters: the view depth in the camera
// pass, the distance from the run camera in the shadow pass. view_pos / world_pos: the point.
float pass_depth(vec3 view_pos, vec3 world_pos, mat4 proj) {
	return is_ortho_pass(proj) ? run_cam_z - world_pos.z : -view_pos.z;
}

// 0 = no fog, 1 = fully fogged. Depth based so it is stable while strafing.
float fog_amount(vec3 view_pos) {
	return smoothstep(fog_start, fog_end, -view_pos.z);
}

// Baked "toy" sunlight for unshaded materials: 1 - strength in shade, up to ~1 + 0.25 strength
// on faces turned to the sun (the original world_lit formula, now with the Jura Rush sun).
float sun_shade(vec3 world_normal, float strength) {
	return 1.0 - strength + strength * max(dot(world_normal, SUN_DIR), 0.0) * 1.25;
}

// Biome tints as multipliers (1.0 in Fern Valley).
vec3 foliage_tint() {
	return biome_accent.rgb / REF_FOLIAGE;
}
vec3 rock_tint() {
	return biome_accent2.rgb / REF_ROCK;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Sine-free hash (stable on mobile GPUs at large inputs).
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Smooth value noise in [0, 1].
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Value noise whose lattice repeats every `period` cells along y. Chunk-local patterns that must
// join seamlessly at chunk seams sample it at p.y * k with chunk_length * k == period, and offset
// only along x.
float pnoise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float y0 = mod(i.y, period);
	float y1 = mod(i.y + 1.0, period);
	float a = hash12(vec2(i.x, y0));
	float b = hash12(vec2(i.x + 1.0, y0));
	float c = hash12(vec2(i.x, y1));
	float d = hash12(vec2(i.x + 1.0, y1));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Three-octave fractal noise in [0, 1].
float fbm3(vec2 p) {
	float v = vnoise(p) * 0.5;
	v += vnoise(p * 2.03 + 17.1) * 0.3;
	v += vnoise(p * 4.11 + 41.7) * 0.2;
	return v;
}
