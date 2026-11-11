## Base class of the State pattern. Subclasses override the hooks they need.
class_name State
extends RefCounted

## Identifier this state was registered under.
var id: StringName = &""
## Owning machine (a Node, so there is no RefCounted cycle).
var machine: StateMachine = null
## The object this state drives (player, chaser, game flow...).
var host: Object = null


## Called when the machine switches into this state.
func enter(_prev: StringName) -> void:
	pass


## Called when the machine leaves this state.
func exit(_next: StringName) -> void:
	pass


## Per-frame update, driven manually by the host.
func update(_delta: float) -> void:
	pass


## Fixed-step update, driven manually by the host.
func physics_update(_delta: float) -> void:
	pass


## Offers a command to the state. Returns true when the command was consumed.
func handle(_cmd: Command) -> bool:
	return false
