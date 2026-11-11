## Owns the look of the world: WorldEnvironment (sky, glow, tonemap), the sun light and the
## biome colours. Every biome_length metres it cross-fades to the next BiomeDef by lerping
## global shader parameters, and tells the track which decor set newly recycled chunks use
## (chunks already on screen are never changed, so nothing pops).
class_name BiomeDirector
extends Node3D

const FADE_TIME: float = 3.5

var track: TrackManager = null
var index: int = 0

var _cfg: GameConfig = GameConfig.current()
var _environment: Environment = null
var _sky_material: ProceduralSkyMaterial = null
var _light: DirectionalLight3D = null
var _from: BiomeDef = null
var _to: BiomeDef = null
var _fade: float = 1.0
var _offset: int = 0


func _ready() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = 0.0
	_sky_material.sky_curve = 0.25
	var sky: Sky = Sky.new()
	sky.sky_material = _sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.5, 0.55, 0.7)
	_environment.ambient_light_energy = 0.6
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_white = 4.0
	_environment.glow_intensity = 0.9
	_environment.glow_bloom = 0.08
	_environment.glow_hdr_threshold = 0.95
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.08
	_environment.adjustment_saturation = 1.15
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = _environment
	add_child(world_env)
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_light.light_energy = 0.9
	_light.shadow_enabled = false
	add_child(_light)
	_from = ContentDB.BIOMES[0]
	_to = _from
	_apply(1.0)
	_apply_quality()
	GameEvents.settings_changed.connect(_on_settings_changed)


## Back to the first biome (new run). The daily challenge may start elsewhere via offset.
func reset(start_offset: int = 0) -> void:
	_offset = start_offset
	index = start_offset % ContentDB.BIOMES.size()
	_from = ContentDB.BIOMES[index]
	_to = _from
	_fade = 1.0
	_apply(1.0)
	if track != null:
		track.decor_set = _to.decor_set


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
		track.decor_set = _to.decor_set
		GameEvents.biome_changed.emit(_to.id, Tr.t(_to.name_key))
	if _fade < 1.0:
		_fade = minf(_fade + delta / FADE_TIME, 1.0)
		_apply(smoothstep(0.0, 1.0, _fade))


func _apply(t: float) -> void:
	var fog: Color = _from.fog.lerp(_to.fog, t)
	var accent: Color = _from.accent.lerp(_to.accent, t)
	var accent2: Color = _from.accent2.lerp(_to.accent2, t)
	if SettingsManager.get_bool("colorblind"):
		# Colour-blind safe pair: blue + yellow stay distinct for all common CVD types.
		accent = Color(0.25, 0.6, 1.0)
		accent2 = Color(1.0, 0.85, 0.1)
	RenderingServer.global_shader_parameter_set(&"fog_color", fog)
	RenderingServer.global_shader_parameter_set(&"biome_accent", accent)
	RenderingServer.global_shader_parameter_set(&"biome_accent2", accent2)
	var horizon: Color = _from.sky_horizon.lerp(_to.sky_horizon, t)
	_sky_material.sky_top_color = _from.sky_top.lerp(_to.sky_top, t)
	_sky_material.sky_horizon_color = horizon.lerp(fog, 0.6)
	_sky_material.ground_horizon_color = fog
	_sky_material.ground_bottom_color = fog
	_light.light_color = _from.light.lerp(_to.light, t)
	_environment.ambient_light_color = _light.light_color.darkened(0.3)


func _apply_quality() -> void:
	_environment.glow_enabled = SettingsManager.quality() > 0
	_environment.adjustment_enabled = SettingsManager.quality() > 0


func _on_settings_changed() -> void:
	_apply_quality()
	_apply(smoothstep(0.0, 1.0, _fade))
