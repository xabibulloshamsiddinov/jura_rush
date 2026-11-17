## Bot soak test (run with: godot --headless --path . -- --bot-soak=600).
## The validator-driven bot plays at 10x speed for N simulated seconds, restarting after
## every death. Reports deaths, validator rejects, chunk gaps and pool growth, then quits with
## exit code 0 (no deaths, no gaps, no leaks) or 1.
class_name BotSoak
extends Node

const TIME_SCALE: float = 10.0

var _world: GameWorld = null
var _seconds: float = 0.0
var _simulated: float = 0.0
var _deaths: int = 0
var _runs: int = 0
var _death_log: PackedStringArray = PackedStringArray()
var _nodes_at_mark: int = -1
var _created_at_mark: int = 0
var _max_gap: float = 0.0
var _rejects: int = 0
var _distance: float = 0.0


func _init(world: GameWorld, seconds: float) -> void:
	_world = world
	_seconds = seconds
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	Engine.max_fps = 0
	Engine.max_physics_steps_per_frame = 64
	# time_scale multiplies every delta. GameWorld steps in _process and splits each (scaled) frame
	# into sub-steps of at most 1/60 s, so the simulation keeps its tuned step size; the physics
	# rate is raised by the same factor only so this node's own clock (_simulated) keeps pace.
	Engine.physics_ticks_per_second = int(60.0 * TIME_SCALE)
	_world.bot.enabled = true
	GameEvents.player_crashed.connect(_on_crash)
	GameEvents.state_changed.connect(_on_state_changed)
	GameEvents.validator_failed.connect(func(_id: StringName) -> void: _rejects += 1)
	GameEvents.request_play.emit(false)


func _physics_process(delta: float) -> void:
	if not GameState.is_running():
		return
	if Engine.time_scale == 1.0:
		GameState.set_time_scale(TIME_SCALE)
	_simulated += delta if Engine.time_scale >= TIME_SCALE else 0.0
	_max_gap = maxf(_max_gap, _world.track.max_gap_seen)
	if _nodes_at_mark < 0 and _simulated > _seconds * 0.3:
		_nodes_at_mark = 1
		_created_at_mark = PoolManager.total_created()
	if _simulated >= _seconds:
		_finish()


func _on_crash(kind: StringName) -> void:
	_deaths += 1
	var chunk: TrackChunk = _world.track.chunk_at(0.0)
	var p: Player = _world.player
	var rl: float = GameConfig.current().row_length()
	var culprit: String = ""
	for c in _world.track.chunks:
		for o in c.obstacles:
			var cz: float = c.position.z + o.position.z
			if o.ghost and absf(cz) < o.length * 0.5 + 1.5:
				culprit += " [%s lane %d z %.1f..%.1f]" % [o.def.id, o.lane, cz - o.length * 0.5, cz + o.length * 0.5]
	_death_log.append("%s in '%s' row %.1f at %.0f m, speed %.1f, lane %d (from %d, x %.2f), y %.2f vy %.1f, state %s, ground %s, bot %s,%s" % [kind,
			chunk.pattern_id if chunk != null else &"?", (chunk.position.z / rl) if chunk != null else -1.0,
			_world.track.distance_travelled, _world.track.world_speed, p.lane, p.previous_lane,
			p.position.x, p.feet_y, p.vertical_speed, p.machine.previous_id, p.on_ground,
			" ".join(_world.bot.history), culprit])


func _on_state_changed(_from: StringName, to: StringName) -> void:
	match to:
		&"revive":
			GameEvents.request_decline_revive.emit.call_deferred()
		&"game_over":
			_runs += 1
			_distance += float(GameState.last_result.get("distance", 0))
			GameEvents.request_play.emit.call_deferred(false)


func _finish() -> void:
	set_physics_process(false)
	GameState.set_time_scale(1.0)
	Engine.physics_ticks_per_second = 60
	# Leak check: once warmed up, pools must stop creating nodes. A leak (items never
	# returned) would force them to keep growing for the whole run.
	var growth: int = PoolManager.total_created() - _created_at_mark
	print("=== BOT SOAK REPORT ===")
	print("simulated %.0f s, runs finished %d, distance %.0f m (+%.0f m current run)" % [
			_simulated, _runs, _distance, _world.track.distance_travelled])
	print("deaths %d, plan failures %d, validator rejects %d" % [_deaths,
			_world.bot.plan_failures, _rejects])
	print("max chunk gap %.5f m, pool growth after warm-up %d, in use %d / %d" % [_max_gap, growth,
			PoolManager.total_in_use(), PoolManager.total_created()])
	print(PoolManager.stats_text())
	for line: String in _death_log:
		print("  death: " + line)
	var ok: bool = _max_gap <= 0.01 and growth <= 6 and _deaths == 0
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
