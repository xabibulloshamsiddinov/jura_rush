## Builder pattern: assembles a chunk from a validated plan, one step at a time
## (obstacles -> coins -> pickups -> decor). All nodes come from the factories / pools.
class_name ChunkBuilder
extends RefCounted

const COIN_Y: float = 0.9
const OBSTACLE_IDS: Dictionary = {
	Cell.Type.TRAIN_LONG: &"train_long",
	Cell.Type.TRAIN_SHORT: &"train_short",
	Cell.Type.TRAIN_MOVING: &"train_moving",
	Cell.Type.BARRIER_LOW: &"barrier_low",
	Cell.Type.BARRIER_HIGH: &"barrier_high",
	Cell.Type.BARRIER_FULL: &"barrier_full",
	Cell.Type.RAMP_UP: &"ramp",
	Cell.Type.GAP: &"gap",
	Cell.Type.DECOR: &"hazard_light",
}

var _cfg: GameConfig
var _chunk: TrackChunk = null
var _plan: SpawnStrategy.Plan = null
var _speed: float = 14.0
var _rows: int = 10
var _lanes: int = 3
var _rl: float = 3.0


func _init(cfg: GameConfig) -> void:
	_cfg = cfg
	_rows = cfg.rows_per_chunk
	_lanes = cfg.lane_count
	_rl = cfg.row_length()


## Starts building `plan` into a cleared chunk. arrival_speed shapes the coin arcs.
func begin(chunk: TrackChunk, plan: SpawnStrategy.Plan, arrival_speed: float) -> ChunkBuilder:
	_chunk = chunk
	_plan = plan
	_speed = arrival_speed
	_chunk.clear()
	_chunk.grid = plan.grid
	_chunk.pattern_id = plan.id
	return self


## Step 1: obstacles. Vertical runs of trains, ramps and gaps merge into one node each.
func add_obstacles() -> ChunkBuilder:
	var grid: PackedInt32Array = _plan.grid
	for lane in range(_lanes):
		var row: int = 0
		while row < _rows:
			var t: int = grid[row * _lanes + lane] & Cell.TYPE_MASK
			if not OBSTACLE_IDS.has(t):
				row += 1
				continue
			var run: int = 1
			if Cell.is_roof_train(t) or t == Cell.Type.TRAIN_MOVING or t == Cell.Type.RAMP_UP \
					or t == Cell.Type.GAP:
				run = Cell.run_length(grid, _lanes, row, lane)
			var id: StringName = OBSTACLE_IDS[t]
			var z_center: float = -(float(row) + float(run) * 0.5) * _rl
			var node: ObstacleBase = Factories.Obstacles.create(id, lane, _cfg.lane_x(lane),
					z_center, float(run) * _rl)
			if node != null:
				_chunk.add_obstacle(node)
			row += run
	return self


## Step 2: coins (ground lines, roof lines, jump arcs, diagonals).
func add_coins() -> ChunkBuilder:
	var grid: PackedInt32Array = _plan.grid
	var field: CoinField = _chunk.coins
	var f: float = _cfg.speed_fraction(_speed)
	var arc_span: float = clampf(_cfg.jump_time_at(f) * _speed * 0.8, 5.0, _rl * 4.0)
	for row in range(_rows):
		var z_near: float = -float(row) * _rl
		var z_far: float = z_near - _rl
		var z_mid: float = (z_near + z_far) * 0.5
		for lane in range(_lanes):
			var cell: int = grid[row * _lanes + lane]
			var t: int = cell & Cell.TYPE_MASK
			var x: float = _cfg.lane_x(lane)
			if t == Cell.Type.COIN or (t == Cell.Type.POWERUP_SLOT and _plan.powerup_id == &""):
				CoinLayout.line(field, x, COIN_Y, z_near, z_far, 2)
			elif t == Cell.Type.COIN_ARC or (cell & Cell.FLAG_ARC) != 0:
				CoinLayout.arc(field, x, COIN_Y, z_mid, arc_span, _cfg.jump_height * 0.8, 5)
			elif t == Cell.Type.COIN_DIAG_RIGHT and lane + 1 < _lanes:
				CoinLayout.diagonal(field, x, _cfg.lane_x(lane + 1), COIN_Y, z_near, z_far, 3)
			elif t == Cell.Type.COIN_DIAG_LEFT and lane > 0:
				CoinLayout.diagonal(field, x, _cfg.lane_x(lane - 1), COIN_Y, z_near, z_far, 3)
			elif (cell & Cell.FLAG_COINS) != 0:
				if Cell.is_roof_train(t):
					CoinLayout.line(field, x, _cfg.train_height + COIN_Y, z_near, z_far, 2)
				else:
					CoinLayout.line(field, x, 0.5, z_near, z_far, 2)
	return self


## Step 3: power-up item and mystery boxes.
func add_pickups() -> ChunkBuilder:
	var grid: PackedInt32Array = _plan.grid
	for idx in range(grid.size()):
		var t: int = grid[idx] & Cell.TYPE_MASK
		if t != Cell.Type.POWERUP_SLOT and t != Cell.Type.MYSTERY_BOX:
			continue
		@warning_ignore("integer_division")
		var row: int = idx / _lanes
		var pos: Vector3 = Vector3(_cfg.lane_x(idx % _lanes), 1.15, -(float(row) + 0.5) * _rl)
		if t == Cell.Type.MYSTERY_BOX:
			_chunk.add_pickup(Factories.Pickups.create_box(), pos)
		elif _plan.powerup_id != &"":
			var item: PowerupPickup = Factories.Pickups.create_powerup(_plan.powerup_id)
			if item != null:
				_chunk.add_pickup(item, pos)
	return self


## Step 4: side decor for the biome the chunk is recycled into.
func add_decor(decor_set: int, decor_seed: int, per_side: int) -> ChunkBuilder:
	_chunk.set_decor(decor_set, decor_seed, per_side)
	return self


## Finishes and returns the chunk.
func build() -> TrackChunk:
	var result: TrackChunk = _chunk
	_chunk = null
	_plan = null
	return result
