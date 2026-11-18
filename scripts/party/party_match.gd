## One multiplayer round: a split screen of 1-3 PartyViews (one complete GameWorld each, side by
## side), every runner on the same seeded track, a shared round clock and lives.
##
## Round flow
##   intro (menu pose, START_DELAY) -> countdown 3-2-1-GO (camera swings into the run) -> running
##   crash: the world slows down for a beat, the death camera shows it, a life is lost;
##          lives left -> short respawn count -> running again (protected for a moment)
##          no lives  -> out (that strip shows its final score)
##   end:   the clock runs out or everybody is out -> results, best score first
##   phone lost mid-run: that world freezes until the phone comes back, then a short count.
##
## Talks to PartyMode through signals; it never touches the UI or the network itself.
class_name PartyMatch
extends Node

signal countdown(n: int)
## kind: crash, out, respawn, frozen, resumed, stumble, finish
signal runner_event(slot: int, kind: StringName)
signal finished(results: Array[Dictionary])

const ROUND_TIME: float = 180.0
const LIVES: int = 3
const START_DELAY: float = 0.9
const COUNTDOWN_STEP: float = 1.0
const CRASH_TIME: float = 1.7
const RESPAWN_TIME: float = 1.6
const RESUME_TIME: float = 1.5
const END_DELAY: float = 2.2

enum Phase { INTRO, COUNTDOWN, RUNNING, ENDING, DONE }


class Runner extends RefCounted:
	var member: PartyRoster.Member = null
	var view: PartyView = null
	var lives: int = PartyMatch.LIVES
	## running, crashed, respawn, out, finished
	var state: StringName = &"intro"
	var timer: float = 0.0
	var frozen: bool = false
	var result: Dictionary = {}
	## Bot slips: seconds of "not paying attention" left, and until the next one.
	var bot_idle: float = 0.0
	var bot_next: float = 12.0

	func score() -> int:
		return int(view.world.score.score) if view != null and view.world != null else 0

	func distance() -> int:
		return int(view.world.track.distance_travelled) if view != null and view.world != null else 0


var runners: Array[Runner] = []
var phase: Phase = Phase.INTRO
var time_left: float = ROUND_TIME
var run_seed: int = 0
var biome: int = 0
## Override for tests (seconds).
static var round_time_override: float = 0.0

var _layer: CanvasLayer = null
var _row: HBoxContainer = null
var _phase_time: float = 0.0
var _count: int = 3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _results: Array[Dictionary] = []


## Builds the split screen for the members (in slot order).
func setup(members: Array[PartyRoster.Member], p_seed: int, p_biome: int) -> void:
	run_seed = p_seed
	biome = p_biome
	_rng.seed = p_seed
	time_left = round_time_override if round_time_override > 0.0 else ROUND_TIME
	for m: PartyRoster.Member in members:
		var r: Runner = Runner.new()
		r.member = m
		r.bot_next = _rng.randf_range(8.0, 20.0)
		runners.append(r)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_layer = CanvasLayer.new()
	_layer.layer = 1
	add_child(_layer)
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.07, 0.04, 0.02)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(back)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_row)
	for i in range(runners.size()):
		var r: Runner = runners[i]
		var view: PartyView = PartyView.new()
		view.name = "View%d" % r.member.slot
		view.setup(r.member.slot, run_seed, biome, r.member.character, &"", i == 0)
		_row.add_child(view)
		r.view = view
		view.world.bot.enabled = r.member.kind == PartyRoster.Kind.BOT
		view.bus.player_crashed.connect(_on_crash.bind(r))
		view.bus.player_stumbled.connect(func(_k: StringName) -> void: runner_event.emit(r.member.slot, &"stumble"))
		view.set_flow(&"menu")
	phase = Phase.INTRO
	_phase_time = 0.0


func _exit_tree() -> void:
	for r: Runner in runners:
		if r.view != null and is_instance_valid(r.view):
			r.view.dispose()


func runner_for(slot: int) -> Runner:
	for r: Runner in runners:
		if r.member.slot == slot:
			return r
	return null


## A controller action for a slot: &"left", &"right", &"jump", &"roll".
func push_input(slot: int, action: StringName) -> void:
	var r: Runner = runner_for(slot)
	if r == null or r.state != &"running" or r.frozen or phase != Phase.RUNNING:
		return
	var player: Player = r.view.world.player
	match action:
		&"left":
			player.push_command(InputCommand.Lane.new(-1))
		&"right":
			player.push_command(InputCommand.Lane.new(1))
		&"jump":
			player.push_command(InputCommand.Jump.new())
		&"roll":
			player.push_command(InputCommand.Roll.new())


## Phone connection lost / back: the runner's world stops until it returns.
func set_frozen(slot: int, value: bool) -> void:
	var r: Runner = runner_for(slot)
	if r == null or r.frozen == value or r.state == &"out" or r.state == &"finished":
		return
	r.frozen = value
	if value:
		r.view.world.local_time_scale = 0.0
		runner_event.emit(slot, &"frozen")
		return
	r.view.world.local_time_scale = 1.0
	runner_event.emit(slot, &"resumed")
	if r.state == &"running" and phase == Phase.RUNNING:
		# A short count before the world moves again, and a moment of protection after it.
		r.state = &"respawn"
		r.timer = RESUME_TIME
		r.view.set_flow(&"countdown")


## Place (1-based) of a slot by the live score; equal scores share a place.
func place_of(slot: int) -> int:
	var me: Runner = runner_for(slot)
	if me == null:
		return 0
	var place: int = 1
	for r: Runner in runners:
		if r != me and _final_score(r) > _final_score(me):
			place += 1
	return place


func _final_score(r: Runner) -> int:
	return int(r.result.get("score", r.score())) if not r.result.is_empty() else r.score()


## Live numbers for a slot (phone status line, HUD).
func snapshot(slot: int) -> Dictionary:
	var r: Runner = runner_for(slot)
	if r == null:
		return {}
	return {
		"score": r.score(),
		"eggs": r.view.world.score.run_coins,
		"lives": r.lives,
		"place": place_of(slot),
		"players": runners.size(),
		"time": ceili(maxf(time_left, 0.0)),
		"out": r.state == &"out",
		"state": String(r.state),
		"frozen": r.frozen,
	}


func results() -> Array[Dictionary]:
	return _results


func _process(delta: float) -> void:
	_phase_time += delta
	match phase:
		Phase.INTRO:
			if _phase_time >= START_DELAY:
				for r: Runner in runners:
					r.view.set_flow(&"loading")
					r.view.set_flow(&"countdown")
				phase = Phase.COUNTDOWN
				_phase_time = 0.0
				_count = 3
				countdown.emit(_count)
		Phase.COUNTDOWN:
			if _phase_time >= COUNTDOWN_STEP:
				_phase_time -= COUNTDOWN_STEP
				_count -= 1
				countdown.emit(_count)
				if _count <= 0:
					_go()
		Phase.RUNNING:
			time_left -= delta
			for r: Runner in runners:
				_tick_runner(r, delta)
			if time_left <= 0.0 or _everybody_out():
				_end_round()
		Phase.ENDING:
			if _phase_time >= END_DELAY:
				phase = Phase.DONE
				finished.emit(_results)


func _go() -> void:
	phase = Phase.RUNNING
	_phase_time = 0.0
	for r: Runner in runners:
		r.state = &"running"
		r.view.set_flow(&"running")


func _tick_runner(r: Runner, delta: float) -> void:
	if r.frozen:
		return
	match r.state:
		&"crashed":
			r.timer -= delta
			if r.timer <= 0.0:
				if r.lives > 0:
					r.state = &"respawn"
					r.timer = RESPAWN_TIME
					r.view.set_flow(&"countdown")
					runner_event.emit(r.member.slot, &"respawn")
				else:
					_finish_runner(r, &"out")
		&"respawn":
			r.timer -= delta
			if r.timer <= 0.0:
				r.state = &"running"
				r.view.set_flow(&"running")
				r.view.world.player.grant_invulnerability(1.2)
		&"running":
			if r.member.kind == PartyRoster.Kind.BOT:
				_tick_bot(r, delta)


## Bots play with the test planner, but now and then stop paying attention for a moment.
func _tick_bot(r: Runner, delta: float) -> void:
	var bot: BotController = r.view.world.bot
	if r.bot_idle > 0.0:
		r.bot_idle -= delta
		if r.bot_idle <= 0.0:
			bot.enabled = true
		return
	r.bot_next -= delta
	if r.bot_next <= 0.0:
		r.bot_next = _rng.randf_range(10.0, 26.0)
		r.bot_idle = _rng.randf_range(0.6, 1.4)
		bot.enabled = false


func _on_crash(_kind: StringName, r: Runner) -> void:
	if r.state != &"running" or phase != Phase.RUNNING:
		return
	r.lives -= 1
	r.state = &"crashed"
	r.timer = CRASH_TIME
	r.view.set_flow(&"revive")
	runner_event.emit(r.member.slot, &"crash")
	_slow_motion(r)


## Per-world hit-stop and slow motion (the other players keep full speed).
func _slow_motion(r: Runner) -> void:
	var world: GameWorld = r.view.world
	world.local_time_scale = 0.05
	await get_tree().create_timer(0.08, false, false, true).timeout
	if not is_instance_valid(world) or r.frozen:
		return
	world.local_time_scale = 0.3
	await get_tree().create_timer(0.6, false, false, true).timeout
	if is_instance_valid(world) and not r.frozen:
		world.local_time_scale = 1.0


func _finish_runner(r: Runner, kind: StringName) -> void:
	if r.state == &"out" or r.state == &"finished":
		return
	var world: GameWorld = r.view.world
	var banked: Dictionary = world.score.finalize_run()
	r.result = {
		"slot": r.member.slot,
		"name": r.member.name,
		"character": String(r.member.character),
		"color": r.member.color(),
		"score": int(banked.get("score", r.score())),
		"distance": int(banked.get("distance", r.distance())),
		"eggs": int(banked.get("coins", 0)),
		"near_misses": int(banked.get("near_misses", 0)),
		"lives": maxi(r.lives, 0),
		"survived": kind == &"finished",
	}
	r.state = kind
	# Out of lives (death camera already showing) or time up (the world stops, camera swings round).
	r.view.set_flow(&"game_over")
	runner_event.emit(r.member.slot, kind)


func _everybody_out() -> bool:
	for r: Runner in runners:
		if r.state != &"out":
			return false
	return true


func _end_round() -> void:
	time_left = maxf(time_left, 0.0)
	for r: Runner in runners:
		if r.frozen:
			r.frozen = false
			r.view.world.local_time_scale = 1.0
		_finish_runner(r, &"finished")
	_results.clear()
	for r: Runner in _ranked():
		var entry: Dictionary = r.result.duplicate()
		entry["place"] = place_of(r.member.slot)
		_results.append(entry)
	phase = Phase.ENDING
	_phase_time = 0.0


## Runners best first: score, then distance, then slot.
func _ranked() -> Array[Runner]:
	var order: Array[Runner] = runners.duplicate()
	order.sort_custom(func(a: Runner, b: Runner) -> bool:
		var sa: int = int(a.result.get("score", a.score())) if not a.result.is_empty() else a.score()
		var sb: int = int(b.result.get("score", b.score())) if not b.result.is_empty() else b.score()
		if sa != sb:
			return sa > sb
		if a.distance() != b.distance():
			return a.distance() > b.distance()
		return a.member.slot < b.member.slot)
	return order
