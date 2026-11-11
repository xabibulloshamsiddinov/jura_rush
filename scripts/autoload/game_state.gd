## Global game-flow state machine. The ONLY place that changes flow state, pauses the scene tree
## or touches Engine.time_scale. Screens and gameplay ask for transitions through GameEvents
## request_* signals; everyone learns about changes through GameEvents.state_changed.
extends Node

const BOOT: StringName = &"boot"
const MENU: StringName = &"menu"
const LOADING: StringName = &"loading"
const COUNTDOWN: StringName = &"countdown"
const RUNNING: StringName = &"running"
const PAUSED: StringName = &"paused"
const REVIVE: StringName = &"revive"
const GAME_OVER: StringName = &"game_over"

var machine: StateMachine = null
## Seed of the current run (reproducible; the daily challenge derives it from the date).
var run_seed: int = 0
var is_daily: bool = false
var revive_count: int = 0
## True while the first-run tutorial is teaching gestures (track stays empty).
var tutorial_active: bool = false
## Result of the last finished run (see ScoreSystem.finalize_run).
var last_result: Dictionary = {}

var _cfg: GameConfig = GameConfig.current()
var _crashing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	machine = StateMachine.new()
	add_child(machine)
	machine.add_state(BOOT, GameFlowStates.Boot.new(), self)
	machine.add_state(MENU, GameFlowStates.Menu.new(), self)
	machine.add_state(LOADING, GameFlowStates.Loading.new(), self)
	machine.add_state(COUNTDOWN, GameFlowStates.Countdown.new(), self)
	machine.add_state(RUNNING, GameFlowStates.Running.new(), self)
	machine.add_state(PAUSED, GameFlowStates.Paused.new(), self)
	machine.add_state(REVIVE, GameFlowStates.Revive.new(), self)
	machine.add_state(GAME_OVER, GameFlowStates.GameOver.new(), self)
	machine.allow(BOOT, [MENU])
	machine.allow(MENU, [LOADING])
	machine.allow(LOADING, [COUNTDOWN])
	machine.allow(COUNTDOWN, [RUNNING, MENU])
	machine.allow(RUNNING, [PAUSED, REVIVE, GAME_OVER])
	machine.allow(PAUSED, [COUNTDOWN, LOADING, MENU])
	machine.allow(REVIVE, [COUNTDOWN, GAME_OVER])
	machine.allow(GAME_OVER, [LOADING, MENU])
	machine.transitioned.connect(func(from: StringName, to: StringName) -> void:
		GameEvents.state_changed.emit(from, to))
	machine.start(BOOT)
	GameEvents.request_play.connect(_on_request_play)
	GameEvents.request_pause.connect(_on_request_pause)
	GameEvents.request_resume.connect(func() -> void: machine.transition_to(COUNTDOWN))
	GameEvents.request_restart.connect(_on_request_restart)
	GameEvents.request_menu.connect(_on_request_menu)
	GameEvents.request_revive.connect(_on_request_revive)
	GameEvents.request_decline_revive.connect(func() -> void:
		if machine.is_in(REVIVE):
			machine.transition_to(GAME_OVER))
	GameEvents.player_crashed.connect(_on_player_crashed)
	GameEvents.tutorial_finished.connect(_on_tutorial_finished)


func _process(delta: float) -> void:
	machine.update(delta)


func _notification(what: int) -> void:
	# Phone call / app switch / lock screen: pause a live run.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if machine != null and machine.is_in(RUNNING) and not OS.has_feature("editor"):
			_on_request_pause()


## Current flow state id.
func current() -> StringName:
	return machine.current_id


## True while the run is live (world moving, input accepted).
func is_running() -> bool:
	return machine.current_id == RUNNING


## Called by main.gd when boot loading has finished.
func boot_finished() -> void:
	machine.transition_to(MENU)


## Keys needed for the next revive: revive_cost_keys + 1 per revive already used this run.
func revive_cost() -> int:
	return _cfg.revive_cost_keys + revive_count


## True when another revive may be offered this run.
func can_revive() -> bool:
	return revive_count < _cfg.max_revives


## Single entry point for pausing the scene tree (used by the flow states).
func set_tree_paused(value: bool) -> void:
	get_tree().paused = value


## Single entry point for Engine.time_scale.
func set_time_scale(value: float) -> void:
	Engine.time_scale = value


## Debug cheat: toggles slow motion.
func toggle_slow_motion() -> void:
	set_time_scale(0.35 if Engine.time_scale > 0.9 else 1.0)


## Asks the score service to bank the run (called by the GameOver state on entry).
func finalize_run() -> void:
	var score: Object = Services.locate(&"score")
	if score == null:
		return
	var result: Dictionary = score.call(&"finalize_run")
	if result.is_empty():
		return
	if is_daily:
		_apply_daily(result)
	last_result = result


func _start_run(daily: bool) -> void:
	is_daily = daily
	run_seed = Rng.daily_seed() if daily else Rng.random_seed()
	revive_count = 0
	_crashing = false
	tutorial_active = not daily and not bool(SaveSystem.data.get("tutorial_done", false))
	machine.transition_to(LOADING, true)


func _on_request_play(daily: bool) -> void:
	if machine.is_in(MENU) or machine.is_in(GAME_OVER):
		_start_run(daily)


func _on_request_restart() -> void:
	if machine.is_in(PAUSED):
		finalize_run()
		_start_run(is_daily)
	elif machine.is_in(GAME_OVER):
		_start_run(is_daily)


func _on_request_pause() -> void:
	if machine.is_in(RUNNING) and not _crashing:
		machine.transition_to(PAUSED)


func _on_request_menu() -> void:
	if machine.is_in(PAUSED) or machine.is_in(COUNTDOWN):
		finalize_run()
	machine.transition_to(MENU)


func _on_request_revive(method: StringName) -> void:
	if not machine.is_in(REVIVE) or not can_revive():
		return
	if method == &"keys":
		if not SaveSystem.spend(&"keys", revive_cost()):
			GameEvents.ui_feedback.emit(&"error")
			return
		_do_revive()
	else:
		var ads: Object = Services.locate(&"ads")
		ads.call(&"show_rewarded_ad", &"revive", func(success: bool) -> void:
			if success and machine.is_in(REVIVE):
				_do_revive())


func _do_revive() -> void:
	revive_count += 1
	_crashing = false
	machine.transition_to(COUNTDOWN)


## Crash sequence: hit-stop (near freeze), a beat of slow motion, then the revive offer.
func _on_player_crashed(_kind: StringName) -> void:
	if not machine.is_in(RUNNING) or _crashing:
		return
	_crashing = true
	set_time_scale(0.05)
	await get_tree().create_timer(_cfg.hit_stop_time, true, false, true).timeout
	set_time_scale(0.3)
	await get_tree().create_timer(0.65, true, false, true).timeout
	set_time_scale(1.0)
	if not machine.is_in(RUNNING):
		return
	machine.transition_to(REVIVE if can_revive() else GAME_OVER)


func _on_tutorial_finished() -> void:
	tutorial_active = false
	SaveSystem.data["tutorial_done"] = true
	SaveSystem.mark_dirty()


## Daily challenge bookkeeping: one reward per calendar day, streak grows on consecutive days.
func _apply_daily(result: Dictionary) -> void:
	var today: String = Rng.today_text()
	if str(SaveSystem.data.get("last_daily_date", "")) == today:
		return
	var yesterday: String = Time.get_date_string_from_unix_time(
			int(Time.get_unix_time_from_system()) - 86400)
	var streak: int = int(SaveSystem.data.get("daily_streak", 0))
	streak = streak + 1 if str(SaveSystem.data.get("last_daily_date", "")) == yesterday else 1
	var reward: int = mini(_cfg.daily_reward_base * streak, _cfg.daily_reward_base * 7)
	SaveSystem.data["daily_streak"] = streak
	SaveSystem.data["last_daily_date"] = today
	SaveSystem.add_coins(reward)
	result["daily_reward"] = reward
	result["daily_streak"] = streak
	SaveSystem.save_game()
