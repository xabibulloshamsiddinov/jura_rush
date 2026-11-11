## Running on the ground (rails, ramp or roof). Leaves to Fall when the ground disappears.
class_name RunState
extends PlayerState


func enter(_prev: StringName) -> void:
	player.visual.set_pose(PlayerVisual.Pose.RUN)


func physics_update(_delta: float) -> void:
	if not player.on_ground and player.coyote_left <= 0.0:
		machine.transition_to(Player.FALL)
