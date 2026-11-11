## Command pattern base. Used for player input (replayable, bufferable) and shop purchases (undoable).
class_name Command
extends RefCounted

## Engine time (ms) at which the command was created; used for input buffering.
var created_msec: int = 0


func _init() -> void:
	created_msec = Time.get_ticks_msec()


## Runs the command against a target. Returns true when it took effect.
func execute(_target: Object) -> bool:
	return false


## Reverts the command. Only meaningful for commands that support rollback.
func undo(_target: Object) -> void:
	pass


## Short name for logs, replays and tests.
func label() -> StringName:
	return &"command"
