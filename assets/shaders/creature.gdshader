// Creatures (T-Rex chaser, sauropod herds, triceratops, rock ramps). LIT like the rest of the
// Jura Rush landscape (world_light.gdshaderinc): the biome's sun colour with the same soft wrap,
// the sky-tinted WorldEnvironment ambient with the same hemisphere occlusion, and the real sun
// shadows (quality Medium / High): a brachiosaurus standing in a cave or under a tree is shaded
// exactly like the stones beside it, and the animals cast their own shadows on the path. On top:
// a specular glint on glossy parts (eyes, teeth, horns) and a thin sunlit rim on the silhouette.
// Shares the curved-world bend (CURVE_WORLD: also correct in the shadow pass) and the distance fog.
//
// Vertex data written by OrganicMesh:
//   COLOR        albedo pattern in sRGB (countershading, stripes, dapples)
//   UV2.x        eye mask (blinks to lid_color)        UV2.y  gloss (specular glint)
//   CUSTOM0.x    neck sway weight   .y tail-tip sway   .z jaw chew   .w flank breathing
// The idle animation is pure vertex math on TIME (no CPU work), varied per instance by `phase`.
// Rigged creatures (Skeleton3D) leave the masks at 0 and animate with bones instead.
// Near the camera the surface dissolves with an ordered dither instead of clipping the lens.
shader_type spatial;
render_mode skip_vertex_transform, cull_back;
#include "res://assets/shaders/world_common.gdshaderinc"
#define WORLD_LIGHT_CUSTOM
#include "res://assets/shaders/world_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float rim_strength = 0.12;
uniform vec3 rim_color : source_color = vec3(1.0, 0.96, 0.86);
uniform float spec_power = 36.0;
// Idle animation (all off by default).
uniform vec3 neck_sway = vec3(0.0);   // x / y amplitude (m), speed (rad/s)
uniform vec2 tail_sway = vec2(0.0);   // amplitude (m), speed
uniform vec2 chew = vec2(0.0);        // amplitude (m), speed
uniform vec2 breathe = vec2(0.0);     // relative amplitude, speed
uniform float blink_rate = 0.0;       // blinks per second (0 = eyes always open)
uniform vec3 lid_color : source_color = vec3(0.45, 0.4, 0.3);
// Dither-dissolve distances from the camera (metres).
uniform float near_fade_start = 2.4;
uniform float near_fade_end = 1.0;
// Shadow casters are shrunk this far along their normals (metres): no self-shadow acne on the
// smooth organic bodies, while the ground shadow keeps its shape.
uniform float shadow_shrink = 0.07;
instance uniform float phase = 0.0;

varying float v_wny;
varying float v_fog;
varying float v_eye;
varying float v_gloss;
varying float v_dist;
// Gloss handed from fragment() to light().
varying float v_glint;

void vertex() {
	vec3 v = VERTEX;
	vec4 m = CUSTOM0;
	float t = TIME;
	float p = phase * 6.2831;
	float wn = m.x * m.x * (3.0 - 2.0 * m.x);
	v.x += wn * neck_sway.x * sin(t * neck_sway.z + p);
	v.y += wn * neck_sway.y * sin(t * neck_sway.z * 0.71 + p * 1.7);
	float wt = m.y * m.y;
	v.x += wt * tail_sway.x * sin(t * tail_sway.y + p * 1.3 - m.y * 2.2);
	float c = 0.5 + 0.5 * sin(t * chew.y + p * 2.3);
	v.y -= m.z * chew.x * c;
	v.z -= m.z * chew.x * 0.4 * c;
	v.x *= 1.0 + m.w * breathe.x * sin(t * breathe.y + p * 0.9);
	bool shadow_pass = is_ortho_pass(PROJECTION_MATRIX);
	if (shadow_pass) {
		v -= NORMAL * shadow_shrink;
	}
	v_wny = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	v_eye = UV2.x;
	v_gloss = UV2.y;
	vec3 vp = (MODELVIEW_MATRIX * vec4(v, 1.0)).xyz;
	v_fog = fog_amount(vp);
	// Camera distance for the near dissolve; huge in the (orthographic) shadow pass, so the
	// shadow never dissolves with the body.
	v_dist = shadow_pass ? 1e4 : length(vp);
	VERTEX = CURVE_WORLD(vp);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Ordered dissolve near the lens (interleaved gradient noise threshold).
	float fade = smoothstep(near_fade_end, near_fade_start, v_dist);
	if (fade < 0.999) {
		float th = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (fade <= th) {
			discard;
		}
	}
	// Vertex colours are authored in sRGB like every other colour in the project.
	vec3 base = pow(COLOR.rgb, vec3(2.2)) * tint.rgb;
	if (blink_rate > 0.0) {
		float b = step(0.955, fract(TIME * blink_rate + phase * 3.17));
		base = mix(base, lid_color, clamp(v_eye, 0.0, 1.0) * b);
	}
	v_glint = v_gloss;
	ALBEDO = base;
	AO = hemi_ao(v_wny, 1.0);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	FOG = vec4(fog_color.rgb, v_fog);
}

void light() {
	float w = wrap_diffuse(dot(NORMAL, LIGHT));
	vec3 sun = LIGHT_COLOR * ATTENUATION;
	DIFFUSE_LIGHT += sun * w;
	float spec = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), spec_power) * v_glint;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength * (0.4 + 0.6 * w);
	SPECULAR_LIGHT += sun * (spec * 0.9) + sun * rim_color * rim;
}
