## One fixed-length segment of the endless track. Chunks are never freed: when one scrolls past
## the recycle line it is cleared, refilled by ChunkBuilder and re-placed at the far end.
## Local space: z = 0 is the near edge (toward the camera), z = -length the far edge.
class_name TrackChunk
extends Node3D

var obstacles: Array[ObstacleBase] = []
## Subset of obstacles that need tick() (moving obstacles, blinking lights).
var tickers: Array[ObstacleBase] = []
## Subset of obstacles that change the ground height (roofs, ramps, gaps).
var ground_shapers: Array[ObstacleBase] = []
var pickups: Array[PickupBase] = []
var coins: CoinField = null
var grid: PackedInt32Array = PackedInt32Array()
var pattern_id: StringName = &"empty"
var length: float = 30.0
## Biome style of the chunk before this one (set by TrackManager before the chunk is built): the
## ground blends from it at the near edge into this chunk's style at the far edge.
var prev_style: int = -1
## Biome style (BiomeDef.decor_set) the chunk was last decorated with.
var style: int = 0

## The stone-path track mesh (hidden on bridges, which bring their own deck).
var _track: MeshInstance3D = null
## Decor MultiMeshes, one per FloraLibrary slot.
var _decor: Array[MultiMeshInstance3D] = []
## Tunnel / bridge geometry (shared meshes), hidden on normal chunks.
var _feature: MeshInstance3D = null
## Feature caps: cave mouth / near river bank on the first chunk of a run, mountain back / far
## bank on the last one.
var _cap_start: MeshInstance3D = null
var _cap_end: MeshInstance3D = null
var feature: TrackVisuals.Feature = TrackVisuals.Feature.NONE
var _cfg: GameConfig = GameConfig.current()


func _init() -> void:
	length = _cfg.chunk_length
	_track = MeshInstance3D.new()
	_track.mesh = TrackVisuals.track_mesh(_cfg)
	_track.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_track.extra_cull_margin = 60.0
	add_child(_track)
	for slot in range(FloraLibrary.SLOT_COUNT):
		var decor: MultiMeshInstance3D = MultiMeshInstance3D.new()
		decor.multimesh = TrackVisuals.new_decor_slot(slot)
		decor.material_override = Mats.flora()
		decor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if FloraLibrary.SLOT_CASTS_SHADOW[slot] \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor.custom_aabb = AABB(Vector3(-75.0, -12.0, -length - 12.0), Vector3(150.0, 60.0, length + 24.0))
		decor.extra_cull_margin = 60.0
		add_child(decor)
		_decor.append(decor)
	coins = CoinField.new()
	add_child(coins)
	_feature = MeshInstance3D.new()
	# Double-sided: the cave is a closed tube for the sun; its inner roof must block light too.
	_feature.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_feature.extra_cull_margin = 60.0
	_feature.visible = false
	add_child(_feature)
	_cap_start = MeshInstance3D.new()
	_cap_end = MeshInstance3D.new()
	for cap: MeshInstance3D in [_cap_start, _cap_end]:
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cap.extra_cull_margin = 60.0
		cap.visible = false
		add_child(cap)


## Pool hook.
func on_acquire() -> void:
	visible = true


## Pool hook: hand all contents back to their pools.
func on_release() -> void:
	clear()


## Releases every obstacle, pickup and coin.
func clear() -> void:
	for o in obstacles:
		PoolManager.release(o.def.id, o)
	obstacles.clear()
	tickers.clear()
	ground_shapers.clear()
	for p in pickups:
		PoolManager.release(p.pool_id, p)
	pickups.clear()
	coins.clear()
	pattern_id = &"empty"


## Attaches a configured obstacle.
func add_obstacle(o: ObstacleBase) -> void:
	add_child(o)
	obstacles.append(o)
	if o.needs_tick:
		tickers.append(o)
	if o.shapes_ground:
		ground_shapers.append(o)


## Attaches a pickup at a local position.
func add_pickup(p: PickupBase, local_pos: Vector3) -> void:
	add_child(p)
	p.position = local_pos
	pickups.append(p)


## Removes obstacles whose centre lies in a local z range (used when reviving).
func clear_obstacles_between(z_from: float, z_to: float) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var o: ObstacleBase = obstacles[i]
		if o.position.z + o.length * 0.5 >= z_from and o.position.z - o.length * 0.5 <= z_to:
			tickers.erase(o)
			ground_shapers.erase(o)
			obstacles.remove_at(i)
			PoolManager.release(o.def.id, o)


## Ground height for a lane at a local z. 0 = path, >0 = roof or ramp, very negative = pit.
func ground_height(lane: int, local_z: float) -> float:
	var height: float = 0.0
	for o in ground_shapers:
		if o.lane != lane or o.disabled:
			continue
		var dz: float = local_z - o.position.z
		if absf(dz) > o.length * 0.5:
			continue
		var h: float = o.ground_height_at(dz)
		if h > height or (h < 0.0 and height <= 0.0):
			height = h
	return height


## Advances moving / blinking obstacles.
func tick(delta: float, world_speed: float) -> void:
	for o in tickers:
		if not o.disabled:
			o.tick(delta, world_speed, position.z)


## Regenerates the side decor and the ground style (called only when the chunk is recycled, never
## while visible). decor_set = the biome style index (BiomeDef.decor_set).
func set_decor(decor_set: int, decor_seed: int, per_side: int) -> void:
	style = clampi(decor_set, 0, BiomeStyle.COUNT - 1)
	var from: int = style if prev_style < 0 else clampi(prev_style, 0, BiomeStyle.COUNT - 1)
	_track.set_instance_shader_parameter(&"style_a", float(from))
	_track.set_instance_shader_parameter(&"style_b", float(style))
	for slot in range(_decor.size()):
		TrackVisuals.fill_decor_slot(_decor[slot].multimesh, slot, style, decor_seed, per_side, _cfg)


## Turns this chunk into a cave or bridge section (or back to open track). Called on recycle.
## first / last: the chunk starts / ends a run of that feature (caps: cave mouth, river banks).
func set_feature(kind: TrackVisuals.Feature, first: bool = false, last: bool = false) -> void:
	feature = kind
	_cap_start.visible = false
	_cap_end.visible = false
	match kind:
		TrackVisuals.Feature.TUNNEL:
			_feature.mesh = TrackVisuals.tunnel_mesh(_cfg)
			if first:
				_cap_start.mesh = TrackFeatures.cave_mouth_mesh(_cfg)
				_cap_start.visible = true
			if last:
				_cap_end.mesh = TrackFeatures.cave_end_mesh(_cfg)
				_cap_end.visible = true
		TrackVisuals.Feature.BRIDGE:
			_feature.mesh = TrackVisuals.bridge_mesh(_cfg)
			if first:
				_cap_start.mesh = TrackFeatures.bridge_near_mesh(_cfg)
				_cap_start.visible = true
			if last:
				_cap_end.mesh = TrackFeatures.bridge_far_mesh(_cfg)
				_cap_end.visible = true
	_feature.visible = kind != TrackVisuals.Feature.NONE
	# Caves cover the side decor; bridges open the view over the river (and bring their own deck).
	for decor in _decor:
		decor.visible = kind == TrackVisuals.Feature.NONE
	_track.visible = kind != TrackVisuals.Feature.BRIDGE
