## One fixed-length segment of the endless track. Chunks are never freed: when one scrolls past
## the recycle line it is cleared, refilled by ChunkBuilder and re-placed at the far end.
## Local space: z = 0 is the near edge (toward the camera), z = -length the far edge.
class_name TrackChunk
extends Node3D

var obstacles: Array[ObstacleBase] = []
## Subset of obstacles that need tick() (moving trains, blinking lights).
var tickers: Array[ObstacleBase] = []
## Subset of obstacles that change the ground height (roofs, ramps, gaps).
var ground_shapers: Array[ObstacleBase] = []
var pickups: Array[PickupBase] = []
var coins: CoinField = null
var grid: PackedInt32Array = PackedInt32Array()
var pattern_id: StringName = &"empty"
var length: float = 30.0

var _decor: MultiMeshInstance3D = null
var _cfg: GameConfig = GameConfig.current()


func _init() -> void:
	length = _cfg.chunk_length
	var track: MeshInstance3D = MeshInstance3D.new()
	track.mesh = TrackVisuals.track_mesh(_cfg)
	track.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	track.extra_cull_margin = 60.0
	add_child(track)
	_decor = MultiMeshInstance3D.new()
	_decor.multimesh = TrackVisuals.new_decor_multimesh()
	_decor.material_override = Mats.building()
	_decor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor.custom_aabb = AABB(Vector3(-40.0, -40.0, -length - 5.0), Vector3(80.0, 100.0, length + 10.0))
	_decor.extra_cull_margin = 60.0
	add_child(_decor)
	coins = CoinField.new()
	add_child(coins)


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


## Ground height for a lane at a local z. 0 = rails, >0 = roof or ramp, very negative = pit.
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


## Regenerates the side buildings (called only when the chunk is recycled, never while visible).
func set_decor(decor_set: int, decor_seed: int, per_side: int) -> void:
	TrackVisuals.fill_decor(_decor.multimesh, decor_set, decor_seed, per_side, _cfg)
