## Proves that a window of pattern rows can be survived.
##
## Search space: (row, lane, level, wait) where level is GROUND or ROOF and wait is the number of
## rows before the next input is allowed (reaction time = min_reaction_time at the given speed).
## Every edge moves forward in rows, so the search is a simple row-by-row sweep (a BFS layered by
## row) followed by a backward sweep that keeps only states that can still reach the end.
## The model is deliberately conservative (no mid-air lane changes, no slam-cancel), so a
## "solvable" verdict always corresponds to a real path. The same search plans the test bot.
class_name SolvabilityValidator
extends RefCounted

const GROUND: int = 0
const ROOF: int = 1
const ACT_NONE: int = 0
const ACT_LEFT: int = 1
const ACT_RIGHT: int = 2
const ACT_JUMP: int = 3
const ACT_ROLL: int = 4
const END: int = -1
const LOW_BARRIER_HEIGHT: float = 1.0

## Seconds required between two inputs. Negative = GameConfig.min_reaction_time (humans);
## the test bot lowers it because it reacts instantly.
var reaction_time: float = -1.0

var _cfg: GameConfig
var _lanes: int = 3
var _rows: int = 0
var _grid: PackedInt32Array
var _blocked: PackedByteArray = PackedByteArray()
var _k: int = 2
var _wdim: int = 3
var _jump_n: int = 3
var _jump_dist: float = 0.0
var _low_ok: PackedByteArray = PackedByteArray()
var _gap_ok: PackedByteArray = PackedByteArray()
var _roll_m: int = 2
var _drop_n: int = 2
var _drop_dist: float = 0.0
## 1 when a jump / drop touches down past the centre of its landing row: the runner then
## cannot act "at" that row any more, so the next input must wait one row.
var _jump_wait_min: int = 0
var _drop_wait_min: int = 0
var _visited: PackedByteArray = PackedByteArray()
var _good: PackedByteArray = PackedByteArray()
var _out_idx: PackedInt32Array = PackedInt32Array()
var _out_act: PackedByteArray = PackedByteArray()
var _out_count: int = 0


func _init(cfg: GameConfig) -> void:
	_cfg = cfg
	_lanes = cfg.lane_count
	_out_idx.resize(16)
	_out_act.resize(16)


## Reaction rows used at a speed: round(speed * min_reaction_time / row_length), at least 1.
func reaction_rows(speed: float) -> int:
	var seconds: float = reaction_time if reaction_time >= 0.0 else _cfg.min_reaction_time
	return maxi(1, roundi(speed * seconds / _cfg.row_length()))


## Runs the search. `sources` is a flat list of (row, lane, level, wait) tuples.
## Returns true when at least one source can reach the end of the window.
func solve(grid: PackedInt32Array, total_rows: int, sources: PackedInt32Array, speed: float) -> bool:
	_grid = grid
	_rows = total_rows
	_prepare(speed)
	var size: int = _rows * _lanes * 2 * _wdim
	_visited.resize(size)
	_visited.fill(0)
	_good.resize(size)
	_good.fill(0)
	for i in range(0, sources.size(), 4):
		var row: int = sources[i]
		var lane: int = sources[i + 1]
		var level: int = sources[i + 2]
		if row < 0 or row >= _rows:
			continue
		if not _can_stand(row, lane, level):
			# A runner on a ramp or roof edge may be reported on the other level.
			level = 1 - level
			if not _can_stand(row, lane, level):
				continue
		_visited[_index(row, lane, level, mini(sources[i + 3], _k))] = 1
	# Forward sweep: every edge increases the row, so one ascending pass visits everything.
	for idx in range(size):
		if _visited[idx] == 0:
			continue
		_expand(idx)
		for j in range(_out_count):
			if _out_idx[j] != END:
				_visited[_out_idx[j]] = 1
	# Backward sweep: a state is good when it can reach the window end.
	var any_good: bool = false
	for idx in range(size - 1, -1, -1):
		if _visited[idx] == 0:
			continue
		_expand(idx)
		for j in range(_out_count):
			if _out_idx[j] == END or _good[_out_idx[j]] == 1:
				_good[idx] = 1
				any_good = true
				break
	return any_good


## Good (alive) states with row in [row_from, row_to], as tuples with rows shifted by -shift.
func collect_good(row_from: int, row_to: int, shift: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var per_row: int = _lanes * 2 * _wdim
	for idx in range(row_from * per_row, mini((row_to + 1) * per_row, _good.size())):
		if _good[idx] == 1:
			@warning_ignore("integer_division")
			var cell: int = idx / (2 * _wdim)
			@warning_ignore("integer_division")
			out.append(cell / _lanes - shift)
			out.append(cell % _lanes)
			@warning_ignore("integer_division")
			out.append((idx / _wdim) % 2)
			out.append(idx % _wdim)
	return out


## Action list (row, lane, action triples) of one surviving path starting from the first good
## source in `sources`. Empty when there is none. Call right after solve().
func extract_path(sources: PackedInt32Array) -> PackedInt32Array:
	var path: PackedInt32Array = PackedInt32Array()
	var idx: int = -1
	for i in range(0, sources.size(), 4):
		if sources[i] < 0 or sources[i] >= _rows:
			continue
		var candidate: int = _index(sources[i], sources[i + 1], sources[i + 2], mini(sources[i + 3], _k))
		if _good[candidate] == 1:
			idx = candidate
			break
	while idx != END and idx >= 0:
		_expand(idx)
		var next: int = -2
		var act: int = ACT_NONE
		for j in range(_out_count):
			if _out_idx[j] == END or _good[_out_idx[j]] == 1:
				next = _out_idx[j]
				act = _out_act[j]
				break
		if next == -2:
			break
		if act != ACT_NONE:
			@warning_ignore("integer_division")
			var cell: int = idx / (2 * _wdim)
			@warning_ignore("integer_division")
			path.append(cell / _lanes)
			path.append(cell % _lanes)
			path.append(act)
		idx = next
	return path


func _prepare(speed: float) -> void:
	var f: float = _cfg.speed_fraction(speed)
	var rl: float = _cfg.row_length()
	_k = reaction_rows(speed)
	_wdim = _k + 1
	_jump_dist = _cfg.jump_time_at(f) * speed
	_jump_n = maxi(1, roundi(_jump_dist / rl))
	_jump_wait_min = 1 if _jump_dist > rl * float(_jump_n) else 0
	_low_ok.resize(_jump_n + 1)
	_gap_ok.resize(_jump_n + 1)
	for k in range(_jump_n + 1):
		var h0: float = _cfg.jump_height_at_time((rl * k - 0.5) / speed, f)
		var h1: float = _cfg.jump_height_at_time((rl * k + 0.5) / speed, f)
		_low_ok[k] = 1 if minf(h0, h1) > LOW_BARRIER_HEIGHT + 0.1 else 0
		_gap_ok[k] = 1 if rl * k + rl * 0.5 + 0.2 <= _jump_dist else 0
	var roll_dist: float = _cfg.roll_time_at(f) * speed
	_roll_m = maxi(1, int(floor((roll_dist - 0.5) / rl)))
	var g: float = _cfg.jump_gravity(f) * _cfg.gravity_down_multiplier
	_drop_dist = rl * 0.5 + sqrt(2.0 * _cfg.train_height / g) * speed
	_drop_n = maxi(1, roundi(_drop_dist / rl))
	_drop_wait_min = 1 if _drop_dist > rl * float(_drop_n) else 0
	# Oncoming trains sweep the rows in front of them: mark those as blocked.
	var vf: float = _cfg.moving_train_speed_factor
	var sweep: int = int(ceil(_cfg.moving_train_activation * vf / (1.0 + vf) / rl)) + 1
	_blocked.resize(_rows * _lanes)
	_blocked.fill(0)
	for r in range(_rows):
		for l in range(_lanes):
			if (_grid[r * _lanes + l] & Cell.TYPE_MASK) == Cell.Type.TRAIN_MOVING:
				for rr in range(maxi(r - sweep, 0), r + 1):
					_blocked[rr * _lanes + l] = 1


func _index(row: int, lane: int, level: int, wait: int) -> int:
	return ((row * _lanes + lane) * 2 + level) * _wdim + wait


## Cell type at a position; rows past the window are treated as EMPTY (re-validated later).
func _type(row: int, lane: int) -> int:
	if row >= _rows:
		return Cell.Type.EMPTY
	return _grid[row * _lanes + lane] & Cell.TYPE_MASK


func _is_blocked(row: int, lane: int) -> bool:
	return row < _rows and _blocked[row * _lanes + lane] == 1


func _open(row: int, lane: int) -> bool:
	return not _is_blocked(row, lane) and Cell.is_open(_type(row, lane))


func _can_stand(row: int, lane: int, level: int) -> bool:
	var t: int = _type(row, lane)
	if level == ROOF:
		return Cell.is_roof_train(t) or t == Cell.Type.RAMP_UP
	return _open(row, lane)


func _push(row: int, lane: int, level: int, wait: int, act: int) -> void:
	if _out_count >= _out_idx.size():
		return
	_out_idx[_out_count] = END if row >= _rows else _index(row, lane, level, clampi(wait, 0, _k))
	_out_act[_out_count] = act
	_out_count += 1


## Fills _out_idx / _out_act with every state reachable in one step from state `idx`.
func _expand(idx: int) -> void:
	_out_count = 0
	var wait: int = idx % _wdim
	@warning_ignore("integer_division")
	var level: int = (idx / _wdim) % 2
	@warning_ignore("integer_division")
	var cell: int = idx / (2 * _wdim)
	@warning_ignore("integer_division")
	var row: int = cell / _lanes
	var lane: int = cell % _lanes
	var nr: int = row + 1
	var next_type: int = _type(nr, lane)
	var w1: int = maxi(wait - 1, 0)
	# Keep running straight.
	if level == GROUND:
		if not _is_blocked(nr, lane):
			if next_type == Cell.Type.RAMP_UP:
				_push(nr, lane, ROOF, w1, ACT_NONE)
			elif Cell.is_open(next_type):
				_push(nr, lane, GROUND, w1, ACT_NONE)
	elif Cell.is_roof_train(next_type) or next_type == Cell.Type.RAMP_UP:
		_push(nr, lane, ROOF, w1, ACT_NONE)
	else:
		_try_drop(row, lane, 1, wait, ACT_NONE)
	if wait > 0 or _type(row, lane) == Cell.Type.RAMP_UP:
		return
	# Lane changes.
	for dir: int in [-1, 1]:
		var nl: int = lane + dir
		if nl < 0 or nl >= _lanes:
			continue
		var act: int = ACT_LEFT if dir < 0 else ACT_RIGHT
		if level == GROUND:
			if _open(row, nl) and _open(nr, nl):
				_push(nr, nl, GROUND, _k - 1, act)
		elif Cell.is_roof_train(_type(row, nl)) and Cell.is_roof_train(_type(nr, nl)):
			_push(nr, nl, ROOF, _k - 1, act)
		else:
			_try_drop(row, nl, 0, _k, act)
	if level == GROUND:
		_try_jump(row, lane)
		_try_roll(row, lane)


func _try_jump(row: int, lane: int) -> void:
	for k in range(1, _jump_n):
		if _is_blocked(row + k, lane):
			return
		var t: int = _type(row + k, lane)
		if Cell.is_open(t):
			continue
		if t == Cell.Type.BARRIER_LOW and _low_ok[k] == 1:
			continue
		if t == Cell.Type.GAP and _gap_ok[k] == 1:
			continue
		return
	if _open(row + _jump_n, lane):
		_push(row + _jump_n, lane, GROUND, maxi(_k - _jump_n, _jump_wait_min), ACT_JUMP)


func _try_roll(row: int, lane: int) -> void:
	for k in range(1, _roll_m + 1):
		if _is_blocked(row + k, lane):
			return
		var t: int = _type(row + k, lane)
		if not (Cell.is_open(t) or t == Cell.Type.BARRIER_HIGH):
			return
	_push(row + _roll_m, lane, GROUND, _k - _roll_m, ACT_ROLL)


## Falling off a roof (walking off its end, or stepping sideways into an open lane).
func _try_drop(row: int, lane: int, first_k: int, wait: int, act: int) -> void:
	var rl: float = _cfg.row_length()
	for k in range(first_k, _drop_n):
		if _is_blocked(row + k, lane):
			return
		var t: int = _type(row + k, lane)
		if Cell.is_open(t):
			continue
		if t == Cell.Type.BARRIER_LOW and k == 1:
			continue
		if t == Cell.Type.GAP and rl * k + rl * 0.5 + 0.2 <= _drop_dist:
			continue
		return
	if _open(row + _drop_n, lane):
		_push(row + _drop_n, lane, GROUND, maxi(wait - _drop_n, _drop_wait_min), act)
