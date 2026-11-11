## Generic finite state machine. The host adds states, then forwards update / physics_update / handle.
## It never processes on its own, so it also works outside the scene tree (unit tests).
class_name StateMachine
extends Node

signal transitioned(from: StringName, to: StringName)

var current: State = null
var current_id: StringName = &""
var previous_id: StringName = &""
## Seconds spent in the current state.
var time_in_state: float = 0.0

var _states: Dictionary = {}
## Optional whitelist: from-id -> Array of allowed to-ids. Empty means "anything goes".
var _allowed: Dictionary = {}


## Registers a state under an id.
func add_state(id: StringName, state: State, host: Object) -> void:
	state.id = id
	state.machine = self
	state.host = host
	_states[id] = state


## Restricts transitions out of `from` to the listed targets.
func allow(from: StringName, targets: Array[StringName]) -> void:
	_allowed[from] = targets


## Enters the first state without calling exit on anything.
func start(id: StringName) -> void:
	current = _states[id] as State
	current_id = id
	time_in_state = 0.0
	current.enter(&"")
	transitioned.emit(&"", id)


## Switches state. Returns false when the target is unknown or not allowed.
func transition_to(id: StringName, allow_reenter: bool = false) -> bool:
	if not _states.has(id):
		return false
	if id == current_id and not allow_reenter:
		return false
	if _allowed.has(current_id):
		var targets: Array = _allowed[current_id]
		if not targets.has(id):
			return false
	var from: StringName = current_id
	if current != null:
		current.exit(id)
	previous_id = from
	current = _states[id] as State
	current_id = id
	time_in_state = 0.0
	current.enter(from)
	transitioned.emit(from, id)
	return true


## True when the machine is in the given state.
func is_in(id: StringName) -> bool:
	return current_id == id


## Returns a registered state (or null).
func get_state(id: StringName) -> State:
	return _states.get(id) as State


## Forwards a frame update to the active state.
func update(delta: float) -> void:
	if current != null:
		current.update(delta)


## Forwards a fixed-step update to the active state.
func physics_update(delta: float) -> void:
	time_in_state += delta
	if current != null:
		current.physics_update(delta)


## Offers a command to the active state.
func handle(cmd: Command) -> bool:
	if current == null:
		return false
	return current.handle(cmd)
