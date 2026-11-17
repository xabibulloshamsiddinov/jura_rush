// Stylised daylight shared by the LIT world shaders (track, flora, rocks, caves, bridges,
// creatures): a soft wrapped Lambert from the sun (receives the real directional shadow through
// ATTENUATION), no specular, and ambient from the WorldEnvironment (sky tinted, set by
// BiomeDirector). Include AFTER world_common.gdshaderinc. Fog is applied through FOG in fragment().
// A shader that needs extra light terms (creature.gdshader: glints, rim) defines
// WORLD_LIGHT_CUSTOM before the include and writes its own light() around wrap_diffuse().

// How far the light wraps past the terminator (0 = plain Lambert). Higher = softer, toy-like.
const float LIGHT_WRAP = 0.45;

// The diffuse sun term of every lit world material (0..1, before LIGHT_COLOR * ATTENUATION).
// Calibrated so a sunlit flat surface shows about its albedo (sun energy 1 + ambient).
float wrap_diffuse(float ndl) {
	float w = clamp((ndl + LIGHT_WRAP) / (1.0 + LIGHT_WRAP), 0.0, 1.0);
	return w * w * (3.0 - 2.0 * w);
}

#ifndef WORLD_LIGHT_CUSTOM
void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * wrap_diffuse(dot(NORMAL, LIGHT));
}
#endif

// Hemisphere-style ambient occlusion: faces turned down get less sky light.
// world_normal_y: world-space normal y; ao: baked occlusion (vertex colour alpha).
float hemi_ao(float world_normal_y, float ao) {
	return ao * mix(0.62, 1.0, world_normal_y * 0.5 + 0.5);
}
