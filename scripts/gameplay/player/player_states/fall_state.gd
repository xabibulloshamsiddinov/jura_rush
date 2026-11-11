## Falling (after a jump apex, off a roof end, or after the jetpack). Landing is detected by
## Player._update_vertical, which switches to Run or Roll.
class_name FallState
extends PlayerState


func enter(_prev: StringName) -> void:
	player.on_ground = false
	player.visual.set_pose(PlayerVisual.Pose.FALL)


func physics_update(_delta: float) -> void:
	if player.on_ground:
		machine.transition_to(Player.RUN)
