## Rising part of a jump. Launch velocity and gravity come from GameConfig so the apex is
## exactly jump_height and the air time jump_time (scaled slightly with speed).
class_name JumpState
extends PlayerState


func enter(_prev: StringName) -> void:
	var cfg: GameConfig = GameConfig.current()
	player.set_rolling(false)
	player.on_ground = false
	player.coyote_left = 0.0
	player.slam_pending = false
	player.vertical_speed = cfg.jump_velocity(player.speed_fraction())
	player.visual.set_pose(PlayerVisual.Pose.JUMP)
	player.events.player_jumped.emit()


func physics_update(_delta: float) -> void:
	if player.vertical_speed <= 0.0 and not player.on_ground:
		machine.transition_to(Player.FALL)
