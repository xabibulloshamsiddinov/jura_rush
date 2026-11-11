## Jetpack flight: rise to jetpack_height and hover above every obstacle. Only lane changes
## are accepted; jump / roll are swallowed.
class_name JetpackState
extends PlayerState


func enter(_prev: StringName) -> void:
	player.flying = true
	player.on_ground = false
	player.slam_pending = false
	player.vertical_speed = 0.0
	player.set_rolling(false)
	player.visual.set_pose(PlayerVisual.Pose.FLY)


func exit(_next: StringName) -> void:
	player.flying = false
	player.vertical_speed = 0.0


func handle(cmd: Command) -> bool:
	if cmd is InputCommand.Lane:
		return cmd.execute(player)
	return true


func physics_update(delta: float) -> void:
	var cfg: GameConfig = GameConfig.current()
	var bob: float = sin(machine.time_in_state * 3.0) * 0.15
	player.feet_y = MathUtils.damp(player.feet_y, cfg.jetpack_height + bob, 0.25, delta)
