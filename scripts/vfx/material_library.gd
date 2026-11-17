## Shared material cache. Every world mesh uses one of a handful of ShaderMaterials, which keeps
## draw-call state changes low and lets biomes recolour the world through global uniforms.
## Jura Rush: the stone-path track, flora, rocks, caves and bridges use LIT shaders (real sun,
## shadows at quality > 0); world_lit stays unshaded with baked sun for everything else.
class_name Mats
extends RefCounted

const LIT_SHADER: Shader = preload("res://assets/shaders/world_lit.gdshader")
const GLOW_SHADER: Shader = preload("res://assets/shaders/world_glow.gdshader")
## Decor / flora shader (the file keeps its old name; windows are retired).
const BUILDING_SHADER: Shader = preload("res://assets/shaders/building.gdshader")
## Egg shader (the file keeps its old name: coins are eggs now).
const COIN_SHADER: Shader = preload("res://assets/shaders/coin.gdshader")
const BLOB_SHADER: Shader = preload("res://assets/shaders/blob_shadow.gdshader")
const SHIELD_SHADER: Shader = preload("res://assets/shaders/shield_bubble.gdshader")
const LANE_WARNING_SHADER: Shader = preload("res://assets/shaders/lane_warning.gdshader")
const NATURE_SHADER: Shader = preload("res://assets/shaders/nature_lit.gdshader")
const TRACK_SHADER: Shader = preload("res://assets/shaders/track_ground.gdshader")
const FLAME_SHADER: Shader = preload("res://assets/shaders/flame.gdshader")
const CHASM_SHADER: Shader = preload("res://assets/shaders/chasm.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")
const FLOOR_SHADE_SHADER: Shader = preload("res://assets/shaders/floor_shade.gdshader")

static var _cache: Dictionary = {}
## Colour-blind warning palette in use (Settings > Colour-blind palette): lane warnings turn into
## yellow chevrons with a dark outline, warning paint and gap edge stones into yellow / black
## hazard stripes. Applied to every cached lane-warning and nature material by set_colorblind().
static var colorblind: bool = false


## Switches the colour-blind warning palette on every material that shows warnings (BiomeDirector
## calls it at start-up and whenever the settings change). Cheap: one uniform per material.
static func set_colorblind(on: bool) -> void:
	colorblind = on
	for mat: Variant in _cache.values():
		var sm: ShaderMaterial = mat as ShaderMaterial
		if sm != null and (sm.shader == LANE_WARNING_SHADER or sm.shader == NATURE_SHADER):
			sm.set_shader_parameter(&"cb", 1.0 if on else 0.0)


## Opaque curved-world material (unshaded, baked sun). accent_mix: 0 own glow colour, 1 biome
## accent (foliage tint), 2 second accent (rock tint).
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


## Former train-window material. The window panes are retired with the neon look; kept so old
## callers still get a plain lit material (the emission is dropped).
static func lit_segmented(color: Color, _glow_color: Color, _energy: float, _segment_len: float,
		_segment_fill: float, accent_mix: float = 0.0) -> ShaderMaterial:
	return lit(color, Color.BLACK, 0.0, accent_mix)


## Painted ochre warning marks (no neon): the colour is painted on, with an optional gentle pulse.
## Kept for callers of the old pulsing-stripe API.
static func warning(glow_color: Color, energy: float) -> ShaderMaterial:
	var key: String = "warn|%s|%.2f" % [glow_color.to_html(), energy]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = lit(glow_color, glow_color, minf(energy, 1.0) * VisualTuning.WARNING_GLOW).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"pulse_speed", VisualTuning.WARNING_PULSE_SPEED)
	mat.set_shader_parameter(&"pulse_amount", VisualTuning.WARNING_PULSE_AMOUNT)
	mat.set_shader_parameter(&"fog_pierce", VisualTuning.WARNING_FOG_PIERCE)
	_cache[key] = mat
	return mat


## Ochre chevrons painted on the stone path in front of an obstacle (Jura Rush: earthy paint,
## alpha-blended, not additive neon). The colour passed in is warmed toward VisualTuning.
## LANE_WARNING_COLOR so every warning reads as the same family.
static func lane_warning(color: Color) -> ShaderMaterial:
	var key: String = "lanewarn|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = LANE_WARNING_SHADER
	var tint: Color = VisualTuning.LANE_WARNING_COLOR.lerp(Color(color.r, color.g, color.b), 0.45)
	mat.set_shader_parameter(&"tint", tint)
	mat.set_shader_parameter(&"opacity", VisualTuning.LANE_WARNING_OPACITY)
	mat.set_shader_parameter(&"cb", 1.0 if colorblind else 0.0)
	_cache[key] = mat
	return mat


## Glow material (trails, rings, streaks) on premultiplied blending: `additive` 1 adds light (the
## old look), 0 is a soft alpha blend that also reads on a bright daylight background.
## Pass unique = true to animate it privately.
## Soft-edged unique ribbons (motion trails) default to the soft blend
## (VisualTuning.TRAIL_ADDITIVE): daylight makes additive ribbons wash out to white.
static func glow(color: Color, energy: float = 1.5, soft_edge: float = 0.0,
		accent_mix: float = 0.0, unique: bool = false, additive: float = -1.0) -> ShaderMaterial:
	var add: float = additive
	if add < 0.0:
		add = VisualTuning.TRAIL_ADDITIVE if (unique and soft_edge >= 1.0) else 1.0
	var key: String = "glow|%s|%.2f|%.1f|%.1f|%.2f" % [color.to_html(), energy, soft_edge, accent_mix, add]
	if not unique and _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"energy", energy)
	mat.set_shader_parameter(&"soft_edge", soft_edge)
	mat.set_shader_parameter(&"accent_mix", accent_mix)
	mat.set_shader_parameter(&"additive", add)
	if not unique:
		_cache[key] = mat
	return mat


## Decor material (flora and terrain, wind sway, lit). Same as building().
static func flora() -> ShaderMaterial:
	if not _cache.has("building"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BUILDING_SHADER
		mat.set_shader_parameter(&"sway_amount", VisualTuning.WIND_SWAY)
		mat.set_shader_parameter(&"wind_speed", VisualTuning.WIND_SPEED)
		_cache["building"] = mat
	return _cache["building"] as ShaderMaterial


## Old name of flora() (the side decor used to be buildings).
static func building() -> ShaderMaterial:
	return flora()


## Lit, vertex-coloured nature material (rocks, caves, bridges, torches, totems, pots).
## color multiplies the vertex colours; glow_color / energy add emission.
static func nature(color: Color = Color.WHITE, glow_color: Color = Color.BLACK, energy: float = 0.0,
		moss: float = 1.0) -> ShaderMaterial:
	var key: String = "nature|%s|%s|%.2f|%.2f" % [color.to_html(), glow_color.to_html(), energy, moss]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = NATURE_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"emission", glow_color)
	mat.set_shader_parameter(&"emission_energy", energy)
	mat.set_shader_parameter(&"moss", moss)
	mat.set_shader_parameter(&"cb", 1.0 if colorblind else 0.0)
	_cache[key] = mat
	return mat


## The stone-path track material, with the per-style palettes from the BiomeDefs.
static func track_ground(cfg: GameConfig) -> ShaderMaterial:
	if _cache.has("track"):
		return _cache["track"] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TRACK_SHADER
	var grass: PackedColorArray = PackedColorArray()
	var grass_dark: PackedColorArray = PackedColorArray()
	var earth: PackedColorArray = PackedColorArray()
	var stone: PackedColorArray = PackedColorArray()
	var crevice: PackedColorArray = PackedColorArray()
	var params: PackedColorArray = PackedColorArray()
	for s in range(BiomeStyle.COUNT):
		grass.append(BiomeStyle.foliage(s).srgb_to_linear())
		grass_dark.append(BiomeStyle.GRASS_DARK[s].srgb_to_linear())
		earth.append(BiomeStyle.EARTH[s].srgb_to_linear())
		stone.append(BiomeStyle.rock(s).srgb_to_linear())
		crevice.append(BiomeStyle.CREVICE[s].srgb_to_linear())
		var p: Vector4 = BiomeStyle.ground_params(s)
		params.append(Color(p.x, p.y, p.z, p.w))
	mat.set_shader_parameter(&"pal_grass", grass)
	mat.set_shader_parameter(&"pal_grass_dark", grass_dark)
	mat.set_shader_parameter(&"pal_earth", earth)
	mat.set_shader_parameter(&"pal_stone", stone)
	mat.set_shader_parameter(&"pal_crevice", crevice)
	mat.set_shader_parameter(&"pal_params", params)
	mat.set_shader_parameter(&"lane_pitch", cfg.lane_width)
	mat.set_shader_parameter(&"path_half", TrackVisuals.PATH_HALF)
	mat.set_shader_parameter(&"chunk_length", cfg.chunk_length)
	mat.set_shader_parameter(&"stone_cells_z", roundf(cfg.chunk_length / 0.42))
	mat.set_shader_parameter(&"sway_amount", VisualTuning.WIND_SWAY * 0.4)
	_cache["track"] = mat
	return mat


## Torch flames and their light pools (additive, flickering).
static func flame() -> ShaderMaterial:
	if not _cache.has("flame"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = FLAME_SHADER
		_cache["flame"] = mat
	return _cache["flame"] as ShaderMaterial


## Chasm interior (gaps).
static func chasm(wall: Color) -> ShaderMaterial:
	var key: String = "chasm|%s" % wall.to_html()
	if not _cache.has(key):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = CHASM_SHADER
		mat.set_shader_parameter(&"wall_color", wall)
		_cache[key] = mat
	return _cache[key] as ShaderMaterial


## Multiplied floor shade inside caves.
static func floor_shade(shade: Color) -> ShaderMaterial:
	var key: String = "floorshade|%s" % shade.to_html()
	if not _cache.has(key):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = FLOOR_SHADE_SHADER
		mat.set_shader_parameter(&"shade", shade)
		_cache[key] = mat
	return _cache[key] as ShaderMaterial


## River water under the bridges.
static func water() -> ShaderMaterial:
	if not _cache.has("water"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = WATER_SHADER
		_cache["water"] = mat
	return _cache["water"] as ShaderMaterial


## Egg material (MultiMesh; wobble, speckles, near-camera shrink). Old name of egg().
static func coin() -> ShaderMaterial:
	if not _cache.has("coin"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = COIN_SHADER
		mat.set_shader_parameter(&"near_fade_start", VisualTuning.COIN_NEAR_FADE_START)
		mat.set_shader_parameter(&"near_fade_end", VisualTuning.COIN_NEAR_FADE_END)
		mat.set_shader_parameter(&"max_brightness", VisualTuning.COIN_MAX_BRIGHTNESS)
		mat.set_shader_parameter(&"shell", VisualTuning.EGG_SHELL_COLOR)
		_cache["coin"] = mat
	return _cache["coin"] as ShaderMaterial


## The egg material (same as coin()).
static func egg() -> ShaderMaterial:
	return coin()


## Soft fake shadow disc.
static func blob_shadow() -> ShaderMaterial:
	if not _cache.has("blob"):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BLOB_SHADER
		mat.set_shader_parameter(&"opacity", VisualTuning.SHADOW_OPACITY)
		_cache["blob"] = mat
	return _cache["blob"] as ShaderMaterial


## Shield bubble material (always unique: its hit ripple is animated). `color` is the Shell Shield
## power-up's own colour (PowerupDef.color; its totem and HUD timer use it too).
static func shield(color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHIELD_SHADER
	mat.set_shader_parameter(&"tint", color)
	return mat
