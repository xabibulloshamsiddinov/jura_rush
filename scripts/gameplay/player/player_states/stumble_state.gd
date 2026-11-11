## Short flinch after a non-lethal hit. Input stays live so the player can recover instantly;
## invincibility frames and the stumble window are handled by Player / Health.
class_name StumbleState
extends PlayerState

const DURATION: float = 0.4

var _left: float = 0.0


func enter(_prev: StringName) -> void:
	_left = DURATION
	player.set_rolling(false)
	player.visual.set_pose(PlayerVisual.Pose.STUMBLE)


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition_to(Player.RUN if player.on_ground else Player.FALL)
