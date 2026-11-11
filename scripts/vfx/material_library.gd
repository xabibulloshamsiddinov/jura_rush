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
		_cache["building"] = mat
	return _cache["building"] as ShaderMaterial


## Spinning coin material (MultiMesh).
static func coin() -> ShaderMaterial:
	if not _cache.has("coin"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = COIN_SHADER
		_cache["coin"] = mat
	return _cache["coin"] as ShaderMaterial


## Soft fake shadow disc.
static func blob_shadow() -> ShaderMaterial:
	if not _cache.has("blob"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BLOB_SHADER
		_cache["blob"] = mat
	return _cache["blob"] as ShaderMaterial


## Shield bubble material (always unique: its hit ripple is animated).
static func shield(color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHIELD_SHADER
	mat.set_shader_parameter(&"tint", color)
	return mat
