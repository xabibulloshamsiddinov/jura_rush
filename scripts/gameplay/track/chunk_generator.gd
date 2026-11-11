## Decides what the next recycled chunk contains: asks the spawn strategy for a layout, proves it
## solvable against the previous chunk, applies roller-coaster pacing (tension budget + rest
## chunks) and places power-ups with a distance cooldown. Fully deterministic for a given seed.
class_name ChunkGenerator
extends RefCounted

## Chunks at the very start of a run that are always breathers.
const WARMUP_CHUNKS: int = 1

var library: PatternLibrary
var validator: SolvabilityValidator
var strategy: SpawnStrategy
var rng: Rng = Rng.new()
## Rises with hard patterns, falls with rest patterns.
var tension: float = 0.0
## Rest chunks still owed after a hard pattern.
var rest_queue: int = 0
## Proposals rejected by the validator this run.
var failures: int = 0
var chunks_generated: int = 0
var last_pattern_id: StringName = &""
## When true only empty chunks are produced (menu backdrop, tutorial).
var forced_empty: bool = false

var _cfg: GameConfig
var _prev_grid: PackedInt32Array
var _sources: PackedInt32Array
var _distance_since_powerup: float = 0.0
var _forced_id: StringName = &""
var _powerup_weights: PackedFloat32Array = PackedFloat32Array()


func _init(cfg: GameConfig, p_library: PatternLibrary) -> void:
	_cfg = cfg
	library = p_library
	validator = SolvabilityValidator.new(cfg)
	strategy = SpawnStrategy.create(cfg.spawn_strategy)
	for def: PowerupDef in ContentDB.POWERUPS:
		_powerup_weights.append(def.weight)
	reset(0)


## Restarts generation for a new run.
func reset(run_seed: int) -> void:
	rng.reseed(run_seed)
	tension = 0.0
	rest_queue = 0
	failures = 0
	chunks_generated = 0
	last_pattern_id = &""
	_forced_id = &""
	_distance_since_powerup = _cfg.powerup_min_gap * 0.5
	_prev_grid = Cell.empty_grid(_cfg.rows_per_chunk, _cfg.lane_count)
	_sources = library.start_sources()


## Debug cheat: the next generated chunk uses this pattern id (if it validates).
func force_next(id: StringName) -> void:
	_forced_id = id


## Produces the validated plan for the next chunk.
## difficulty: pattern difficulty 1..10. arrival_speed: world speed expected when it is reached.
func next_plan(difficulty: float, arrival_speed: float) -> SpawnStrategy.Plan:
	chunks_generated += 1
	var plan: SpawnStrategy.Plan = null
	if not forced_empty:
		var want_rest: bool = chunks_generated <= WARMUP_CHUNKS or rest_queue > 0 \
				or tension >= _cfg.tension_limit
		for attempt in range(_cfg.max_validation_tries):
			var candidate: SpawnStrategy.Plan = _propose(difficulty, want_rest)
			if _validate(candidate.grid, arrival_speed):
				plan = candidate
				break
			failures += 1
			GameEvents.validator_failed.emit(candidate.id)
	if plan == null:
		plan = SpawnStrategy.Plan.new()
		plan.grid = Cell.empty_grid(_cfg.rows_per_chunk, _cfg.lane_count)
		if not _validate(plan.grid, arrival_speed):
			# Cannot happen with an empty chunk, but never leave the chain broken.
			_prev_grid = plan.grid
			_sources = library.start_sources()
	_apply_pacing(plan, difficulty)
	_place_powerup(plan)
	last_pattern_id = plan.id
	return plan


func _propose(difficulty: float, want_rest: bool) -> SpawnStrategy.Plan:
	if _forced_id != &"":
		var index: int = library.index_of(_forced_id)
		_forced_id = &""
		if index >= 0:
			var forced: SpawnStrategy.Plan = SpawnStrategy.Plan.new()
			forced.id = library.defs[index].id
			forced.grid = library.grids[index]
			forced.difficulty = library.defs[index].difficulty
			forced.is_rest = library.defs[index].is_rest()
			return forced
	return strategy.propose(library, difficulty, want_rest, rng, _cfg)


## Validates prev + candidate. On success the candidate becomes the new "previous" chunk and
## the alive states in its first rows become the sources for the next validation.
func _validate(grid: PackedInt32Array, speed: float) -> bool:
	var rows: int = _cfg.rows_per_chunk
	var window: PackedInt32Array = _prev_grid.duplicate()
	window.append_array(grid)
	if not validator.solve(window, rows * 2, _sources, speed):
		return false
	@warning_ignore("integer_division")
	var next_sources: PackedInt32Array = validator.collect_good(rows, rows + rows / 2 - 1, rows)
	if next_sources.is_empty():
		return false
	_prev_grid = grid
	_sources = next_sources
	return true


## Tension budget: hard patterns add their difficulty, rest patterns relieve it. A hard pattern
## also queues max(1, round(difficulty / 4)) rest chunks so breathers grow with speed.
func _apply_pacing(plan: SpawnStrategy.Plan, difficulty: float) -> void:
	if plan.is_rest:
		tension = maxf(tension - _cfg.tension_rest_relief, 0.0)
		rest_queue = maxi(rest_queue - 1, 0)
		return
	tension += float(plan.difficulty)
	if plan.difficulty >= _cfg.hard_pattern_threshold:
		rest_queue = maxi(1, roundi(difficulty / 4.0))


func _place_powerup(plan: SpawnStrategy.Plan) -> void:
	_distance_since_powerup += _cfg.chunk_length
	var ready: bool = _distance_since_powerup >= _cfg.powerup_min_gap
	var slot: int = plan.grid.find(Cell.Type.POWERUP_SLOT)
	if slot < 0 and ready and plan.is_rest and not forced_empty and rng.chance(_cfg.powerup_chance):
		slot = plan.grid.find(Cell.Type.COIN)
		if slot >= 0:
			plan.grid = plan.grid.duplicate()
			plan.grid[slot] = Cell.Type.POWERUP_SLOT
	if slot >= 0 and ready:
		var pick: int = rng.pick_weighted(_powerup_weights)
		plan.powerup_id = ContentDB.POWERUPS[maxi(pick, 0)].id
		_distance_since_powerup = 0.0
