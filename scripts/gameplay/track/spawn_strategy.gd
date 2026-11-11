## Strategy pattern: how the next chunk layout is proposed. Selected by GameConfig.spawn_strategy.
## ChunkGenerator validates every proposal, so strategies only need to be "usually" fair.
class_name SpawnStrategy
extends RefCounted


## A proposed chunk layout.
class Plan extends RefCounted:
	var id: StringName = &"empty"
	var grid: PackedInt32Array = PackedInt32Array()
	var difficulty: int = 1
	var is_rest: bool = true
	## Power-up to place in the POWERUP_SLOT cell (&"" = none, slot becomes a coin).
	var powerup_id: StringName = &""


## Proposes a layout for the given pattern difficulty (1..10). want_rest asks for a breather.
func propose(_library: PatternLibrary, _difficulty: float, _want_rest: bool, _rng: Rng,
		_cfg: GameConfig) -> Plan:
	return Plan.new()


## Creates the strategy named in the config (&"pattern" or &"random_safe").
static func create(id: StringName) -> SpawnStrategy:
	if id == &"random_safe":
		return RandomSafe.new()
	return Pattern.new()


## Picks hand-authored patterns by weight inside the difficulty window, randomly mirrored.
class Pattern extends SpawnStrategy:
	var _weights: PackedFloat32Array = PackedFloat32Array()

	func propose(library: PatternLibrary, difficulty: float, want_rest: bool, rng: Rng,
			cfg: GameConfig) -> Plan:
		var level: int = clampi(roundi(difficulty), 1, 10)
		_weights.resize(library.size())
		for i in range(library.size()):
			var def: ChunkDef = library.defs[i]
			var ok: bool = def.is_rest() == want_rest
			if not want_rest:
				ok = ok and level >= def.min_difficulty and level <= def.max_difficulty
			_weights[i] = def.weight if ok else 0.0
		var pick: int = rng.pick_weighted(_weights)
		var plan: Plan = Plan.new()
		if pick < 0:
			plan.grid = Cell.empty_grid(cfg.rows_per_chunk, cfg.lane_count)
			return plan
		var chosen: ChunkDef = library.defs[pick]
		plan.id = chosen.id
		plan.difficulty = chosen.difficulty
		plan.is_rest = chosen.is_rest()
		plan.grid = library.grids[pick]
		if rng.chance(0.5):
			plan.grid = Cell.mirror(plan.grid, cfg.lane_count)
		return plan


## Procedural layouts: a wandering safe lane with random blockers in the other lanes.
class RandomSafe extends SpawnStrategy:
	const BLOCKERS: Array[int] = [
		Cell.Type.EMPTY, Cell.Type.BARRIER_LOW, Cell.Type.BARRIER_HIGH, Cell.Type.BARRIER_FULL,
	]
	var _safe_lane: int = 1

	func propose(_library: PatternLibrary, difficulty: float, want_rest: bool, rng: Rng,
			cfg: GameConfig) -> Plan:
		var plan: Plan = Plan.new()
		plan.id = &"random_safe"
		plan.grid = Cell.empty_grid(cfg.rows_per_chunk, cfg.lane_count)
		plan.is_rest = want_rest
		plan.difficulty = clampi(roundi(difficulty), 1, 10)
		var step: int = 5 if difficulty > 6.0 else 4
		for row in range(1, cfg.rows_per_chunk - 1):
			plan.grid[row * cfg.lane_count + _safe_lane] = Cell.Type.COIN
			if want_rest or row % step != 1:
				continue
			for lane in range(cfg.lane_count):
				if lane != _safe_lane:
					plan.grid[row * cfg.lane_count + lane] = BLOCKERS[rng.range_i(0, BLOCKERS.size() - 1)]
			if row + step < cfg.rows_per_chunk:
				_safe_lane = clampi(_safe_lane + rng.range_i(-1, 1), 0, cfg.lane_count - 1)
		return plan
