## Parses the pattern DSL into ChunkDef resources, analyses them (required actions, safe lanes,
## highest solvable difficulty) and serves lookups to the spawn strategies.
class_name PatternLibrary
extends RefCounted

var defs: Array[ChunkDef] = []
## Parsed grids, same order as defs.
var grids: Array[PackedInt32Array] = []
## Problems found while loading (shown in the debug overlay and by the tests).
var errors: PackedStringArray = PackedStringArray()

var _cfg: GameConfig
var _by_id: Dictionary = {}


func _init(cfg: GameConfig) -> void:
	_cfg = cfg
	_parse_text(PatternData.TEXT)
	for extra: ChunkDef in cfg.extra_chunk_defs:
		if extra != null:
			_add(extra)
	_analyse_all()


## Number of patterns.
func size() -> int:
	return defs.size()


## Index of a pattern id, or -1.
func index_of(id: StringName) -> int:
	return int(_by_id.get(id, -1))


## Pattern definition by id (null when unknown).
func find(id: StringName) -> ChunkDef:
	var i: int = index_of(id)
	return defs[i] if i >= 0 else null


## World speed that corresponds to a pattern difficulty (1 -> start_speed, 10 -> max_speed).
func speed_for_difficulty(difficulty: float) -> float:
	return lerpf(_cfg.start_speed, _cfg.max_speed, clampf((difficulty - 1.0) / 9.0, 0.0, 1.0))


## Checks a pattern on its own (after an empty chunk) at a difficulty.
func is_solvable_alone(index: int, difficulty: int, validator: SolvabilityValidator) -> bool:
	var rows: int = _cfg.rows_per_chunk
	var window: PackedInt32Array = Cell.empty_grid(rows, _cfg.lane_count)
	window.append_array(grids[index])
	return validator.solve(window, rows * 2, start_sources(), speed_for_difficulty(float(difficulty)))


## Sources for a clean start: every lane, on the ground, free to act, at row 0.
func start_sources() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for lane in range(_cfg.lane_count):
		out.append_array(PackedInt32Array([0, lane, SolvabilityValidator.GROUND, 0]))
	return out


func _parse_text(text: String) -> void:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts: PackedStringArray = line.split(";")
		if parts.size() != 6:
			errors.append("bad field count: %s" % line)
			continue
		var def: ChunkDef = ChunkDef.new()
		def.id = StringName(parts[0].strip_edges())
		def.difficulty = int(parts[1])
		var span: PackedStringArray = parts[2].split("-")
		def.min_difficulty = int(span[0])
		def.max_difficulty = int(span[1]) if span.size() > 1 else 10
		def.weight = float(parts[3])
		for tag: String in parts[4].split(",", false):
			def.tags.append(StringName(tag.strip_edges()))
		def.rows = parts[5].strip_edges().split(" ", false)
		_add(def)


func _add(def: ChunkDef) -> void:
	if def.rows.size() != _cfg.rows_per_chunk:
		errors.append("%s: expected %d rows, got %d" % [def.id, _cfg.rows_per_chunk, def.rows.size()])
		return
	var grid: PackedInt32Array = Cell.parse_rows(def.rows, _cfg.lane_count)
	if grid.is_empty():
		errors.append("%s: malformed rows" % def.id)
		return
	if _by_id.has(def.id):
		errors.append("%s: duplicate id" % def.id)
		return
	_by_id[def.id] = defs.size()
	defs.append(def)
	grids.append(grid)


func _analyse_all() -> void:
	var validator: SolvabilityValidator = SolvabilityValidator.new(_cfg)
	for i in range(defs.size()):
		var def: ChunkDef = defs[i]
		_analyse_content(def, grids[i])
		# Lower max_difficulty until the pattern is solvable on its own at that speed.
		var top: int = def.max_difficulty
		while top >= def.min_difficulty and not is_solvable_alone(i, top, validator):
			top -= 1
		if top < def.min_difficulty:
			errors.append("%s: not solvable at its minimum difficulty %d" % [def.id, def.min_difficulty])
			def.weight = 0.0
		elif not is_solvable_alone(i, def.min_difficulty, validator):
			errors.append("%s: not solvable at difficulty %d" % [def.id, def.min_difficulty])
			def.weight = 0.0
		def.max_difficulty = maxi(top, def.min_difficulty)


func _analyse_content(def: ChunkDef, grid: PackedInt32Array) -> void:
	var lanes: int = _cfg.lane_count
	def.required_actions.clear()
	def.safe_lanes.clear()
	var lane_clear: Array[bool] = []
	lane_clear.resize(lanes)
	lane_clear.fill(true)
	for idx in range(grid.size()):
		var t: int = grid[idx] & Cell.TYPE_MASK
		var action: StringName = &""
		if t == Cell.Type.BARRIER_LOW or t == Cell.Type.GAP:
			action = &"jump"
		elif t == Cell.Type.BARRIER_HIGH:
			action = &"roll"
		elif Cell.is_solid(t):
			action = &"lane"
		elif t == Cell.Type.RAMP_UP:
			action = &"roof"
		if action != &"":
			lane_clear[idx % lanes] = false
			if not def.required_actions.has(action):
				def.required_actions.append(action)
	for lane in range(lanes):
		if lane_clear[lane]:
			def.safe_lanes.append(lane)
