## Automated test player. Every time the runner crosses a row centre it re-plans a surviving path
## with the SolvabilityValidator over all chunks ahead and issues the first due action as a
## normal InputCommand. Used by the soak test to prove generated tracks are really playable.
class_name BotController
extends Node

var enabled: bool = false
## Commands issued since the last reset (for reports).
var actions_issued: int = 0
## Times the planner found no path from the bot's actual state.
var plan_failures: int = 0
## Last few decisions, newest last (diagnostics).
var history: PackedStringArray = PackedStringArray()

var _track: TrackManager = null
var _player: Player = null
var _cfg: GameConfig = GameConfig.current()
var _validator: SolvabilityValidator = null
var _window: PackedInt32Array = PackedInt32Array()
var _source: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _last_row: int = -1000
var _last_head: TrackChunk = null


## Wires the bot to the world.
func setup(track: TrackManager, player: Player) -> void:
	_track = track
	_player = player
	_validator = SolvabilityValidator.new(_cfg)
	# 0.2 s: just longer than one lane change at any speed, far quicker than a human (0.45 s).
	_validator.reaction_time = 0.2


## Forgets planning state (new run).
func reset() -> void:
	_last_row = -1000
	_last_head = null
	actions_issued = 0
	plan_failures = 0


## Plans and acts. Call once per physics step before the track advances.
func tick() -> void:
	if not enabled or _player.is_dead or _track.world_speed < 2.0:
		return
	var rl: float = _cfg.row_length()
	var head: TrackChunk = _track.chunks[0]
	# Row whose centre the runner has most recently crossed, counted from the head chunk.
	var row: int = int(floor(head.position.z / rl - 0.5))
	if head == _last_head and row == _last_row:
		return
	_last_head = head
	_last_row = row
	if row < 0 or _player.flying or _player.is_changing_lane():
		return
	# Airborne: only lane changes can be issued (they work mid-air), so plan as if landed.
	var airborne: bool = not _player.on_ground
	var rows_per_chunk: int = _cfg.rows_per_chunk
	_window.clear()
	for chunk in _track.chunks:
		if chunk.grid.size() == rows_per_chunk * _cfg.lane_count:
			_window.append_array(chunk.grid)
		else:
			_window.append_array(Cell.empty_grid(rows_per_chunk, _cfg.lane_count))
	_source[0] = row
	_source[1] = _player.lane
	var on_roof: bool = _player.feet_y > 1.0 and not airborne
	_source[2] = SolvabilityValidator.ROOF if on_roof else SolvabilityValidator.GROUND
	_source[3] = 0
	var total_rows: int = rows_per_chunk * _track.chunks.size()
	var speed: float = maxf(_track.world_speed, _cfg.start_speed)
	if not _validator.solve(_window, total_rows, _source, speed):
		plan_failures += 1
		_note("NOPLAN r%d l%d lv%d v%.1f %s>%s" % [row, _player.lane, _source[2], speed,
				_track.chunks[1].pattern_id, _track.chunks[2].pattern_id])
		return
	var path: PackedInt32Array = _validator.extract_path(_source)
	if path.size() < 3 or path[0] != row:
		return
	if airborne and path[2] != SolvabilityValidator.ACT_LEFT and path[2] != SolvabilityValidator.ACT_RIGHT:
		return
	match path[2]:
		SolvabilityValidator.ACT_LEFT:
			_player.push_command(InputCommand.Lane.new(-1))
		SolvabilityValidator.ACT_RIGHT:
			_player.push_command(InputCommand.Lane.new(1))
		SolvabilityValidator.ACT_JUMP:
			_player.push_command(InputCommand.Jump.new())
		SolvabilityValidator.ACT_ROLL:
			_player.push_command(InputCommand.Roll.new())
	actions_issued += 1
	_note("a%d r%d l%d" % [path[2], row, _player.lane])


func _note(text: String) -> void:
	history.append(text)
	if history.size() > 5:
		history.remove_at(0)
