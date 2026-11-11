## Base class of non-coin pickups (power-ups, mystery boxes). Template Method: collect() does the
## bookkeeping and calls the _on_collect() hook. Detection is a distance test in PickupSystem.
class_name PickupBase
extends Node3D

## Pool this node returns to.
var pool_id: StringName = &""
var collected: bool = false
## Horizontal pick-up radius in metres.
var radius: float = 1.0

var _spin: Node3D = null


## Pool hook: reset state.
func on_acquire() -> void:
	collected = false
	visible = true


## Pool hook.
func on_release() -> void:
	pass


## Called by PickupSystem when the player touches the pickup.
func collect(player: Player) -> void:
	if collected:
		return
	collected = true
	visible = false
	_on_collect(player)


## Idle animation (spin + bob).
func tick(delta: float) -> void:
	if _spin != null:
		_spin.rotate_y(delta * 2.5)


## Hook: what the pickup does.
func _on_collect(_player: Player) -> void:
	pass
