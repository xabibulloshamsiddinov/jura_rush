## Owns the look of the world: WorldEnvironment (tonemap, ambient, glow), the sun light with its
## shadows, the day sky dome and the biome colours. Every biome_length metres it cross-fades to the
## next BiomeDef by lerping global shader parameters and the sky, and tells the track which style
## newly recycled chunks use (their decor and ground; chunks already on screen are never changed,
## so nothing pops, and the ground blends from one style into the next along the first new chunk).
##
## Globals set here (see world_common.gdshaderinc):
##   fog_color      horizon haze
##   biome_accent   foliage tint, alpha = lushness (moss on rocks)
##   biome_accent2  rock tint,    alpha = heat (lava glow in gaps)
class_name BiomeDirector
extends Node3D

const FADE_TIME: float = 3.5
## Toward the sun, world space. MUST match SUN_DIR in world_common.gdshaderinc (the baked shading
## of unshaded materials uses that constant, the lit world uses this light).
const SUN_DIR: Vector3 = Vector3(0.7027, 0.6826, 0.2008)
## Where the sun disc is drawn on the dome: upper right of the run view, on the same side as the
## key light (the light itself sits higher, so shadows stay short and readable).
const SUN_DISC_DIR: Vector3 = Vector3(0.2, 0.15, -0.968)
## Volcano azimuth on the dome (radians, 0 = straight down the track, + = right).
const VOLCANO_AZIMUTH: float = -0.2
## Dome radius: inside the camera far plane (400 m), beyond every world object.
const DOME_RADIUS: float = 330.0

## Dev flag (--biome=N): added to every reset offset, so a run starts in biome N.
static var dev_offset: int = 0
## Dev flag (--no-shadows): sun shadows off at every quality (performance comparison).
static var dev_no_shadows: bool = false
## Fog start multiplier of the current biome mix (1 / BiomeDef.fog_density_scale); read by
## TrackManager when it sets the fog distances.
static var fog_start_scale: float = 1.0

var track: TrackManager = null
var index: int = 0

var _cfg: GameConfig = GameConfig.current()
var _environment: Environment = null
## Day sky dome; null when VisualTuning.FEATURE_SKY_DOME is off.
var _sky: ShaderMaterial = null
var _dome: MeshInstance3D = null
var _light: DirectionalLight3D = null
var _from: BiomeDef = null
var _to: BiomeDef = null
var _fade: float = 1.0
var _offset: int = 0


func _ready() -> void:
	if VisualTuning.FEATURE_SKY_DOME:
		_sky = ShaderMaterial.new()
		_sky.shader = preload("res://assets/shaders/sky_dome.gdshader")
		_sky.set_shader_parameter(&"sun_dir", SUN_DISC_DIR.normalized())
		_sky.set_shader_parameter(&"pterosaurs", VisualTuning.SKY_PTEROSAURS)
		_sky.set_shader_parameter(&"volcano_az", VOLCANO_AZIMUTH)
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = DOME_RADIUS
		sphere.height = DOME_RADIUS * 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		_dome = MeshInstance3D.new()
		_dome.mesh = sphere
		_dome.material_override = _sky
		_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dome.top_level = true
		_dome.extra_cull_margin = 16384.0
		add_child(_dome)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = VisualTuning.AMBIENT_ENERGY
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = VisualTuning.TONEMAP_MODE
	_environment.tonemap_exposure = VisualTuning.TONEMAP_EXPOSURE
	# All glow numbers live in VisualTuning so they can be tweaked in one place.
	_environment.tonemap_white = VisualTuning.TONEMAP_WHITE
	_environment.glow_intensity = VisualTuning.GLOW_INTENSITY
	_environment.glow_strength = VisualTuning.GLOW_STRENGTH
	_environment.glow_bloom = VisualTuning.GLOW_BLOOM
	_environment.glow_hdr_threshold = VisualTuning.GLOW_HDR_THRESHOLD
	_environment.glow_hdr_scale = VisualTuning.GLOW_HDR_SCALE
	_environment.glow_blend_mode = VisualTuning.GLOW_BLEND_MODE
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = VisualTuning.ADJUST_CONTRAST
	_environment.adjustment_saturation = VisualTuning.ADJUST_SATURATION
	_environment.adjustment_brightness = VisualTuning.ADJUST_BRIGHTNESS
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = _environment
	add_child(world_env)
	_light = DirectionalLight3D.new()
	_light.basis = Basis.looking_at(-SUN_DIR, Vector3.UP)
	_light.light_energy = VisualTuning.SUN_ENERGY
	_light.light_specular = 0.0
	_light.shadow_opacity = VisualTuning.SUN_SHADOW_OPACITY
	_light.shadow_bias = 0.03
	_light.shadow_normal_bias = 1.0
	_light.shadow_blur = 1.2
	_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_light.directional_shadow_split_1 = 0.32
	_light.directional_shadow_fade_start = 0.75
	add_child(_light)
	_from = ContentDB.BIOMES[0]
	_to = _from
	_apply(1.0)
	_apply_quality()
	Mats.set_colorblind(SettingsManager.get_bool("colorblind"))
	GameEvents.settings_changed.connect(_on_settings_changed)


## Back to the first biome (new run). The daily challenge may start elsewhere via offset.
func reset(start_offset: int = 0) -> void:
	_offset = start_offset + dev_offset
	index = _offset % ContentDB.BIOMES.size()
	_from = ContentDB.BIOMES[index]
	_to = _from
	_fade = 1.0
	if track != null:
		track.decor_set = BiomeStyle.of(_to)
	_apply(1.0)


## Debug cheat: jump to the next biome now.
func skip() -> void:
	_offset += 1


## Checks distance and advances the cross-fade.
func tick(delta: float) -> void:
	var wanted: int = (int(track.distance_travelled / _cfg.biome_length) + _offset) % ContentDB.BIOMES.size()
	if wanted != index:
		index = wanted
		_from = _to
		_to = ContentDB.BIOMES[index]
		_fade = 0.0
		track.decor_set = BiomeStyle.of(_to)
		GameEvents.biome_changed.emit(_to.id, Tr.t(_to.name_key))
	if _fade < 1.0:
		_fade = minf(_fade + delta / FADE_TIME, 1.0)
		_apply(smoothstep(0.0, 1.0, _fade))


func _apply(t: float) -> void:
	var fog: Color = _from.fog.lerp(_to.fog, t)
	fog.a = 1.0
	var foliage: Color = _from.accent.lerp(_to.accent, t)
	var rock: Color = _from.accent2.lerp(_to.accent2, t)
	RenderingServer.global_shader_parameter_set(&"fog_color", fog)
	RenderingServer.global_shader_parameter_set(&"biome_accent", foliage)
	RenderingServer.global_shader_parameter_set(&"biome_accent2", rock)
	var top: Color = _from.sky_top.lerp(_to.sky_top, t)
	var horizon: Color = _from.sky_horizon.lerp(_to.sky_horizon, t)
	var sun: Color = _from.light.lerp(_to.light, t)
	_light.light_color = sun
	# Sky-tinted ambient: the zenith blue warmed by the horizon haze (keeps grey stone warm).
	var ambient: Color = top.lerp(horizon, 0.58).lerp(Color.WHITE, 0.2)
	_environment.ambient_light_color = ambient
	_environment.background_color = fog
	var style_a: int = BiomeStyle.of(_from)
	var style_b: int = BiomeStyle.of(_to)
	if _sky != null:
		_sky.set_shader_parameter(&"sky_top", top)
		_sky.set_shader_parameter(&"sky_horizon", horizon)
		_sky.set_shader_parameter(&"ground", fog)
		_sky.set_shader_parameter(&"sun_color", sun)
		_sky.set_shader_parameter(&"cloud_shade", top.lerp(horizon, 0.5).lerp(Color(0.75, 0.78, 0.86), 0.5))
		_sky.set_shader_parameter(&"far_tint", BiomeStyle.SKY_FAR[style_a].lerp(BiomeStyle.SKY_FAR[style_b], t))
		_sky.set_shader_parameter(&"near_tint", BiomeStyle.SKY_NEAR[style_a].lerp(BiomeStyle.SKY_NEAR[style_b], t))
		_sky.set_shader_parameter(&"cloud_amount",
				lerpf(BiomeStyle.CLOUDS[style_a], BiomeStyle.CLOUDS[style_b], t) * VisualTuning.SKY_CLOUDS)
		_sky.set_shader_parameter(&"style_a", float(style_a))
		_sky.set_shader_parameter(&"style_b", float(style_b))
		_sky.set_shader_parameter(&"style_mix", t if style_a != style_b else 0.0)
	else:
		_environment.background_color = horizon.lerp(top, 0.4)
	fog_start_scale = lerpf(1.0 / maxf(_from.fog_density_scale, 0.1), 1.0 / maxf(_to.fog_density_scale, 0.1), t)
	if track != null:
		track.refresh_fog()


func _apply_quality() -> void:
	var q: int = SettingsManager.quality()
	_environment.glow_enabled = q > 0
	_environment.adjustment_enabled = q > 0
	var shadows: bool = VisualTuning.FEATURE_SUN_SHADOWS and q > 0 and not dev_no_shadows
	_light.shadow_enabled = shadows
	if shadows:
		_light.directional_shadow_max_distance = VisualTuning.SUN_SHADOW_DISTANCE[q]
		_light.directional_shadow_blend_splits = q >= 2
		RenderingServer.directional_shadow_atlas_set_size(2048 if q >= 2 else 1024, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW if q >= 2 else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)


func _on_settings_changed() -> void:
	_apply_quality()
	# Colour-blind palette: high-contrast warnings (lane chevrons, lethal paint, gap edges).
	Mats.set_colorblind(SettingsManager.get_bool("colorblind"))
	_apply(smoothstep(0.0, 1.0, _fade))


## Keeps the sky dome centred on whichever camera is rendering.
func _process(_delta: float) -> void:
	if _dome == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		_dome.global_position = camera.global_position
