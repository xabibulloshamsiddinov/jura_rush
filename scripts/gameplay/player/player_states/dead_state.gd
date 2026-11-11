## Dead: all input is swallowed and the body plays its fall-over tween until revive or reset.
class_name DeadState
extends PlayerState


func enter(_prev: StringName) -> void:
	player.set_rolling(false)
	player.flying = false
	player.dashing = false
	player.visual.set_pose(PlayerVisual.Pose.DEAD)


func handle(_cmd: Command) -> bool:
	return true
