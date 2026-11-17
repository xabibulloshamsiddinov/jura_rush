## Creature materials: one shader (assets/shaders/creature.gdshader) and a few cached presets.
## Each species uses ONE material (patterns live in vertex colours) plus the shared dust puffs,
## so a whole herd shares a single ShaderMaterial. The idle-animation strengths live here.
class_name CreatureMats
extends RefCounted

const SHADER: Shader = preload("res://assets/shaders/creature.gdshader")
const DUST_SHADER: Shader = preload("res://assets/shaders/creature_dust.gdshader")

## Linear albedo multiplier per species (see skin()).
const SKIN_TINT: Dictionary = {
	&"trex": Color(0.86, 0.86, 0.84),
	&"brachio": Color(0.7, 0.68, 0.64),
	&"trike": Color(0.86, 0.84, 0.8),
	&"rock": Color(0.9, 0.9, 0.9),
}

## Near-camera dissolve of the sauropods (start, end; metres from the camera).
const BRACHIO_FADE: Vector2 = Vector2(4.2, 2.0)

static var _cache: Dictionary = {}


## Skin material for a species: &"trex", &"brachio", &"trike" or &"rock" (static props).
static func skin(species: StringName) -> ShaderMaterial:
	if _cache.has(species):
		return _cache[species] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	# The skin is lit by the real sun like the landscape: `tint` (linear) calibrates the painted
	# vertex colours to the albedo range of the Jura Rush world (pastel hides would glow).
	mat.set_shader_parameter(&"tint", SKIN_TINT.get(species, Color.WHITE))
	match species:
		&"trex":
			mat.set_shader_parameter(&"blink_rate", 0.2)
			mat.set_shader_parameter(&"lid_color", Color(0.36, 0.33, 0.17))
			mat.set_shader_parameter(&"rim_strength", 0.16)
		&"brachio":
			# Neck sways a few cm, the tail tip a little more; chewing and breathing are subtle so
			# the walkable back stays where the collision says it is.
			mat.set_shader_parameter(&"neck_sway", Vector3(0.16, 0.07, 0.75))
			mat.set_shader_parameter(&"tail_sway", Vector2(0.16, 1.5))
			mat.set_shader_parameter(&"chew", Vector2(0.035, 7.5))
			mat.set_shader_parameter(&"breathe", Vector2(0.025, 1.4))
			mat.set_shader_parameter(&"blink_rate", 0.22)
			mat.set_shader_parameter(&"lid_color", Color(0.4, 0.52, 0.48))
			# Necks arching over the free lane and flanks beside the camera dissolve a little
			# earlier than the other creatures, so a passing herd never fills the screen.
			mat.set_shader_parameter(&"near_fade_start", BRACHIO_FADE.x)
			mat.set_shader_parameter(&"near_fade_end", BRACHIO_FADE.y)
		&"trike":
			mat.set_shader_parameter(&"blink_rate", 0.25)
			mat.set_shader_parameter(&"lid_color", Color(0.62, 0.42, 0.25))
			mat.set_shader_parameter(&"rim_strength", 0.14)
		_:
			mat.set_shader_parameter(&"rim_strength", 0.06)
	_cache[species] = mat
	return mat


## Soft dust puff material (MultiMesh colours carry tint and alpha).
static func dust() -> ShaderMaterial:
	if not _cache.has(&"dust"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = DUST_SHADER
		_cache[&"dust"] = mat
	return _cache[&"dust"] as ShaderMaterial
