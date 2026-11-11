## Shared material cache. Every world mesh uses one of a handful of ShaderMaterials, which keeps
## draw-call state changes low and lets biomes recolour the world through global uniforms.
class_name Mats
extends RefCounted

const LIT_SHADER: Shader = preload("res://assets/shaders/world_lit.gdshader")
const GLOW_SHADER: Shader = preload("res://assets/shaders/world_glow.gdshader")
const BUILDING_SHADER: Shader = preload("res://assets/shaders/building.gdshader")
const COIN_SHADER: Shader = preload("res://assets/shaders/coin.gdshader")
const BLOB_SHADER: Shader = preload("res://assets/shaders/blob_shadow.gdshader")
const SHIELD_SHADER: Shader = preload("res://assets/shaders/shield_bubble.gdshader")
const LANE_WARNING_SHADER: Shader = preload("res://assets/shaders/lane_warning.gdshader")

static var _cache: Dictionary = {}


## Opaque curved-world material. accent_mix: 0 own glow colour, 1 biome accent, 2 second accent.
static func lit(color: Color, glow_color: Color = Color.BLACK, energy: float = 0.0,
		accent_mix: float = 0.0) -> ShaderMaterial:
	var key: String = "lit|%s|%s|%.2f|%.1f" % [color.to_html(), glow_color.to_html(), energy, accent_mix]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = LIT_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"emission", glow_color)
	mat.set_shader_parameter(&"emission_energy", energy)
	mat.set_shader_parameter(&"accent_mix", accent_mix)
	_cache[key] = mat
	return mat


## Runner material: the lit material plus a rim light so the silhouette reads against coins,
## neon and dark track (VisualTuning.PLAYER_RIM_*).
static func player_lit(color: Color, glow_color: Color = Color.BLACK, energy: float = 0.0) -> ShaderMaterial:
	var key: String = "player|%s|%s|%.2f" % [color.to_html(), glow_color.to_html(), energy]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = lit(color, glow_color, energy).duplicate() as ShaderMaterial
	if VisualTuning.FEATURE_PLAYER_RIM:
		mat.set_shader_parameter(&"rim_color", VisualTuning.PLAYER_RIM_COLOR)
		mat.set_shader_parameter(&"rim_strength", VisualTuning.PLAYER_RIM_STRENGTH)
		mat.set_shader_parameter(&"rim_power", VisualTuning.PLAYER_RIM_POWER)
	_cache[key] = mat
	return mat


## Obstacle warning stripes: pulsing emission that partly shows through the fog, so barriers
## read from further away.
static func warning(glow_color: Color, energy: float) -> ShaderMaterial:
	var key: String = "warn|%s|%.2f" % [glow_color.to_html(), energy]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = lit(Color.BLACK, glow_color, energy).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"pulse_speed", VisualTuning.WARNING_PULSE_SPEED)
	mat.set_shader_parameter(&"pulse_amount", VisualTuning.WARNING_PULSE_AMOUNT)
	mat.set_shader_parameter(&"fog_pierce", VisualTuning.WARNING_FOG_PIERCE)
	_cache[key] = mat
	return mat


## Faint animated marker painted on the rails in front of an obstacle.
static func lane_warning(color: Color) -> ShaderMaterial:
	var key: String = "lanewarn|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = LANE_WARNING_SHADER
	mat.set_shader_parameter(&"tint", color)
	mat.set_shader_parameter(&"opacity", VisualTuning.LANE_WARNING_OPACITY)
	_cache[key] = mat
	return mat


## Additive glow material (trails, rings, streaks). Pass unique = true to animate it privately.
static func glow(color: Color, energy: float = 1.5, soft_edge: float = 0.0,
		accent_mix: float = 0.0, unique: bool = false) -> ShaderMaterial:
	var key: String = "glow|%s|%.2f|%.1f|%.1f" % [color.to_html(), energy, soft_edge, accent_mix]
	if not unique and _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"energy", energy)
	mat.set_shader_parameter(&"soft_edge", soft_edge)
	mat.set_shader_parameter(&"accent_mix", accent_mix)
	if not unique:
		_cache[key] = mat
	return mat


## Decor material with procedural lit windows.
static func building() -> ShaderMaterial:
	if not _cache.has("building"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BUILDING_SHADER
		if VisualTuning.FEATURE_WINDOW_FLICKER:
			mat.set_shader_parameter(&"flicker_ratio", VisualTuning.WINDOW_FLICKER_RATIO)
			mat.set_shader_parameter(&"flicker_speed", VisualTuning.WINDOW_FLICKER_SPEED)
		_cache["building"] = mat
	return _cache["building"] as ShaderMaterial


## Spinning coin material (MultiMesh).
static func coin() -> ShaderMaterial:
	if not _cache.has("coin"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = COIN_SHADER
		mat.set_shader_parameter(&"near_fade_start", VisualTuning.COIN_NEAR_FADE_START)
		mat.set_shader_parameter(&"near_fade_end", VisualTuning.COIN_NEAR_FADE_END)
		mat.set_shader_parameter(&"max_brightness", VisualTuning.COIN_MAX_BRIGHTNESS)
		_cache["coin"] = mat
	return _cache["coin"] as ShaderMaterial


## Soft fake shadow disc.
static func blob_shadow() -> ShaderMaterial:
	if not _cache.has("blob"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BLOB_SHADER
		mat.set_shader_parameter(&"opacity", VisualTuning.SHADOW_OPACITY)
		_cache["blob"] = mat
	return _cache["blob"] as ShaderMaterial


## Shield bubble material (always unique: its hit ripple is animated).
static func shield(color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHIELD_SHADER
	mat.set_shader_parameter(&"tint", color)
	return mat
