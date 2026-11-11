## The game-flow states used by GameState (State pattern).
##
##   Boot -> Menu -> Loading -> Countdown -> Running <-> Paused
##   Running -> Revive -> Countdown(short) -> Running
##   Running / Revive -> GameOver -> Loading (again) | Menu
##   Paused -> Countdown (resume) | Loading (restart) | Menu
class_name GameFlowStates
extends RefCounted


## Common base: typed access to the GameState autoload that hosts the machine.
class FlowState extends State:
	func flow() -> Node:
		return host as Node


## Splash / pre-warm. main.gd calls GameState.boot_finished() when loading is done.
class Boot extends FlowState:
	pass


## Main menu over the live 3D backdrop.
class Menu extends FlowState:
	func enter(_prev: StringName) -> void:
		flow().call(&"set_tree_paused", false)
		flow().call(&"set_time_scale", 1.0)


## World reset for a new run, hidden behind the loading overlay.
class Loading extends FlowState:
	const DURATION: float = 0.55
	var _left: float = 0.0

	func enter(_prev: StringName) -> void:
		flow().call(&"set_tree_paused", false)
		flow().call(&"set_time_scale", 1.0)
		_left = DURATION

	func update(delta: float) -> void:
		_left -= delta
		if _left <= 0.0:
			machine.transition_to(&"countdown")


## 3-2-1-GO. Fresh runs and resumes count from 3; revives use a short count.
class Countdown extends FlowState:
	const STEP: float = 0.75
	var remaining: int = 3
	var _left: float = 0.0
	## What this countdown precedes: &"fresh", &"resume" or &"revive".
	var kind: StringName = &"fresh"

	func enter(prev: StringName) -> void:
		kind = &"fresh"
		remaining = 3
		if prev == &"paused":
			kind = &"resume"
		elif prev == &"revive":
			kind = &"revive"
			remaining = 2
		_left = STEP
		GameEvents.countdown_tick.emit(remaining)

	func update(delta: float) -> void:
		_left -= delta
		if _left > 0.0:
			return
		_left = STEP
		remaining -= 1
		GameEvents.countdown_tick.emit(maxi(remaining, 0))
		if remaining <= 0:
			machine.transition_to(&"running")


## The run is live.
class Running extends FlowState:
	func enter(prev: StringName) -> void:
		flow().call(&"set_tree_paused", false)
		if prev == &"countdown":
			var countdown: Countdown = machine.get_state(&"countdown") as Countdown
			if countdown.kind == &"fresh":
				GameEvents.run_started.emit()


## Paused: the scene tree is frozen (UI and audio keep processing).
class Paused extends FlowState:
	func enter(_prev: StringName) -> void:
		flow().call(&"set_tree_paused", true)

	func exit(next: StringName) -> void:
		# A resume keeps the world frozen through the countdown.
		if next != &"countdown":
			flow().call(&"set_tree_paused", false)


## "Continue?" offer after a crash.
class Revive extends FlowState:
	pass


## Results screen. The score service banks the run before the state change is announced.
class GameOver extends FlowState:
	func enter(_prev: StringName) -> void:
		flow().call(&"finalize_run")
