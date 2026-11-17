## The endless world: a TREADMILL with CHUNK RECYCLING.
## The player never moves forward. All chunks slide toward the camera (+Z) at world_speed; a chunk
## whose far edge passes recycle_threshold behind the player is cleared, refilled and re-placed
## at the far end (z = last.z - chunk_length), beyond the fog. Positions are re-snapped to the
## head chunk every frame, so no drift or gaps can accumulate and coordinates stay small forever.
class_name TrackManager
extends Node3D

## Ordered near -> far. chunks[0] is the one closest to (or behind) the camera.
var chunks: Array[TrackChunk] = []
var world_speed: float = 0.0
## Speed the world eases toward (set by GameWorld from the DifficultyDirector).
var target_speed: float = 0.0
## Extra factor on top of target_speed (dash power-up).
var speed_multiplier: float = 1.0
## Sum of speed * delta since the last reset, in metres.
var distance_travelled: float = 0.0
var generator: ChunkGenerator = null
var library: PatternLibrary = null
## Optional: supplies pattern difficulty and arrival-speed predictions.
var director: DifficultyDirector = null
## Decor set (biome style index) used for chunks recycled from now on (set by BiomeDirector).
var decor_set: int = 0
## Dev flag (--feature=tunnel|bridge): makes that feature come round again and again.
static var dev_feature: TrackVisuals.Feature = TrackVisuals.Feature.NONE
## Total chunks recycled since the last reset.
var recycled_count: int = 0
## Largest gap between neighbouring chunks ever measured (soak test).
var max_gap_seen: float = 0.0

var _cfg: GameConfig = GameConfig.current()
var _builder: ChunkBuilder = null
var _length: float = 30.0
var _chunk_count: int = 0
## Tunnel / bridge run in progress: kind and chunks still to place.
var _feature_kind: TrackVisuals.Feature = TrackVisuals.Feature.NONE
var _feature_left: int = 0
## The chunk being filled starts / ends a feature run (caps: cave mouth, river banks).
var _feature_first: bool = false
var _feature_last: bool = false
## Plain chunks still to place before the dev feature may start again.
var _dev_gap: int = 0
## Biome style of the last chunk placed (the next one blends its ground from it).
var _last_style: int = -1
var _last_emitted_speed: float = -1.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _bend_scale: float = 1.0


func _ready() -> void:
	_length = _cfg.chunk_length
	library = PatternLibrary.new(_cfg)
	for problem: String in library.errors:
		Log.warn(&"patterns", problem)
	generator = ChunkGenerator.new(_cfg, library)
	_builder = ChunkBuilder.new(_cfg)
	_noise.seed = 7
	_noise.frequency = 1.0
	reset(0, true)


## Rebuilds the whole track for a new run (or the menu backdrop when empty_only is true).
func reset(run_seed: int, empty_only: bool) -> void:
	for chunk in chunks:
		remove_child(chunk)
		Factories.Chunks.recycle(chunk)
	chunks.clear()
	_chunk_count = SettingsManager.chunk_count()
	generator.reset(run_seed)
	generator.forced_empty = empty_only
	distance_travelled = 0.0
	recycled_count = 0
	max_gap_seen = 0.0
	world_speed = 0.0
	speed_multiplier = 1.0
	_apply_fog()
	_feature_left = 0
	_dev_gap = 0
	_last_style = decor_set
	for i in range(_chunk_count):
		var chunk: TrackChunk = Factories.Chunks.create()
		add_child(chunk)
		chunk.position = Vector3(0.0, 0.0, _length - float(i) * _length)
		chunks.append(chunk)
		# The chunk behind the player and the two ahead stay empty: a clean runway.
		var was_forced: bool = generator.forced_empty
		if i < 3:
			generator.forced_empty = true
		_fill(chunk)
		generator.forced_empty = was_forced


## Moves the world by one step: ease speed, slide chunks, recycle, tick moving obstacles.
func advance(delta: float) -> void:
	world_speed = MathUtils.damp(world_speed, target_speed * speed_multiplier,
			1.0 / maxf(_cfg.speed_smoothing, 0.01), delta)
	if absf(world_speed - _last_emitted_speed) > 0.1:
		_last_emitted_speed = world_speed
		GameEvents.speed_changed.emit(world_speed)
	var step: float = world_speed * delta
	distance_travelled += step
	chunks[0].position.z += step
	while chunks[0].position.z - _length > _cfg.recycle_threshold:
		_recycle_head()
	_snap()
	_hide_passed_obstacles()
	for chunk in chunks:
		if not chunk.tickers.is_empty():
			chunk.tick(delta, world_speed)
	var bend: float = _noise.get_noise_1d(distance_travelled * 0.004) * _cfg.bend_strength_x * _bend_scale
	RenderingServer.global_shader_parameter_set(&"bend_x", bend)


## Stops the world instantly (crash, countdown).
func halt() -> void:
	world_speed = 0.0
	target_speed = 0.0


## Scales the sideways world bend (0 for the menu showcase).
func set_bend_scale(value: float) -> void:
	_bend_scale = value


## Ground height for a lane at world z. 0 = rails, >0 = roof or ramp, very negative = pit.
func get_ground_height(lane: int, z: float) -> float:
	var chunk: TrackChunk = chunk_at(z)
	if chunk == null:
		return 0.0
	return chunk.ground_height(lane, z - chunk.position.z)


## The chunk covering world z (null outside the track).
func chunk_at(z: float) -> TrackChunk:
	var index: int = int(floor((chunks[0].position.z - z) / _length))
	if index < 0 or index >= chunks.size():
		return null
	return chunks[index]


## Removes obstacles in a world z range (revive: clears the road around the player).
func clear_obstacles_between(z_from: float, z_to: float) -> void:
	for chunk in chunks:
		if chunk.position.z < z_from or chunk.position.z - _length > z_to:
			continue
		chunk.clear_obstacles_between(z_from - chunk.position.z, z_to - chunk.position.z)


## Re-reads fog distances (after a quality change).
func refresh_fog() -> void:
	_apply_fog()


func _recycle_head() -> void:
	var chunk: TrackChunk = chunks.pop_front() as TrackChunk
	remove_child(chunk)
	Factories.Chunks.recycle(chunk)
	chunk = Factories.Chunks.create()
	add_child(chunk)
	chunk.position.z = chunks[chunks.size() - 1].position.z - _length
	chunks.append(chunk)
	# Spawn-safe window: a recycled chunk must appear beyond the fog, never inside the view.
	assert(chunk.position.z <= _cfg.cam_back - _cfg.effective_fog_end(_chunk_count),
			"chunk recycled inside the visible range")
	_fill(chunk)
	recycled_count += 1


## Re-snaps every chunk to its predecessor and records the worst gap seen.
func _snap() -> void:
	var head_z: float = chunks[0].position.z
	for i in range(1, chunks.size()):
		chunks[i].position.z = head_z - float(i) * _length
		var gap: float = absf((chunks[i - 1].position.z - _length) - chunks[i].position.z)
		if gap > max_gap_seen:
			max_gap_seen = gap


func _fill(chunk: TrackChunk) -> void:
	var eta: float = _cfg.spawn_distance(_chunk_count) / maxf(world_speed, _cfg.start_speed)
	var difficulty: float = 1.0
	var arrival_speed: float = _cfg.start_speed
	if director != null:
		difficulty = director.pattern_difficulty(eta)
		arrival_speed = director.predict_speed(eta)
	var plan: SpawnStrategy.Plan = generator.next_plan(difficulty, arrival_speed)
	chunk.prev_style = _last_style
	_builder.begin(chunk, plan, arrival_speed).add_obstacles().add_coins().add_pickups() \
			.add_decor(decor_set, generator.rng.range_i(0, 1 << 20), SettingsManager.decor_density()) \
			.build()
	_last_style = decor_set
	var kind: TrackVisuals.Feature = _next_feature()
	chunk.set_feature(kind, _feature_first, _feature_last)


func _apply_fog() -> void:
	var fog_end: float = _cfg.effective_fog_end(_chunk_count)
	RenderingServer.global_shader_parameter_set(&"fog_end", fog_end)
	# VisualTuning.FOG_START pushes the fog out so obstacles read earlier; never past half the
	# fog range, or the far fade would get too abrupt. Misty biomes pull it in
	# (BiomeDirector.fog_start_scale, from BiomeDef.fog_density_scale).
	var fog_start: float = maxf(_cfg.fog_start, VisualTuning.FOG_START) * BiomeDirector.fog_start_scale
	RenderingServer.global_shader_parameter_set(&"fog_start", minf(fog_start, fog_end * 0.5))
	RenderingServer.global_shader_parameter_set(&"bend_y", _cfg.bend_strength_y)
	# The shadow-pass bend (world_common CURVE_WORLD) pivots on the run camera's z.
	RenderingServer.global_shader_parameter_set(&"run_cam_z", _cfg.cam_back)


## Hides obstacles the runner has fully passed. They would otherwise stay on screen between the
## camera (cam_back metres behind) and the player until their chunk is recycled. Only the two
## nearest chunks can hold such obstacles. on_acquire() makes them visible again on reuse.
## The test uses the far end of the VISUAL (box far edge minus ObstacleBase.far_overhang), so
## parts drawn beyond the collision box (sauropod necks and tails) never vanish in view.
func _hide_passed_obstacles() -> void:
	for i in range(mini(2, chunks.size())):
		var chunk: TrackChunk = chunks[i]
		for o in chunk.obstacles:
			if o.visible and chunk.position.z + o.position.z - o.length * 0.5 - o.far_overhang \
					> VisualTuning.HIDE_PASSED_OBSTACLES_Z:
				o.visible = false


## Occasional cave or bridge runs of a few chunks (VisualTuning.TRACK_FEATURE_*). Uses its own
## RNG so the obstacle generator (and its tests / daily seed) is not affected. Also records
## whether the chunk starts / ends its run (_feature_first / _feature_last, for the caps).
var _feature_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _next_feature() -> TrackVisuals.Feature:
	_feature_first = false
	_feature_last = false
	if not VisualTuning.FEATURE_TUNNELS_BRIDGES:
		return TrackVisuals.Feature.NONE
	if _feature_left > 0:
		_feature_left -= 1
		_feature_last = _feature_left == 0
		return _feature_kind
	if dev_feature != TrackVisuals.Feature.NONE:
		# Dev flag: three feature chunks, two plain ones, repeat (first runway chunks stay plain).
		if _dev_gap > 0 or chunks.size() < 4:
			_dev_gap = maxi(_dev_gap - 1, 0)
			return TrackVisuals.Feature.NONE
		_feature_kind = dev_feature
		_feature_left = 2
		_dev_gap = 2
		_feature_first = true
		return _feature_kind
	if distance_travelled > 60.0 and _feature_rng.randf() < VisualTuning.TRACK_FEATURE_CHANCE:
		_feature_kind = TrackVisuals.Feature.TUNNEL if _feature_rng.randf() < 0.5 else TrackVisuals.Feature.BRIDGE
		_feature_left = _feature_rng.randi_range(VisualTuning.TRACK_FEATURE_MIN_CHUNKS,
				VisualTuning.TRACK_FEATURE_MAX_CHUNKS) - 1
		_feature_first = true
		_feature_last = _feature_left == 0
		return _feature_kind
	return TrackVisuals.Feature.NONE
