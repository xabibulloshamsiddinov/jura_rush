## Rolling: the collider shrinks to roll_height for roll_time (scaled with speed).
## A jump command cancels the roll; a second roll command is buffered until this one ends.
class_name RollState
extends PlayerState

var _left: float = 0.0


func enter(_prev: StringName) -> void:
	var cfg: GameConfig = GameConfig.current()
	_left = cfg.roll_time_at(player.speed_fraction())
	player.set_rolling(true)
	player.visual.set_pose(PlayerVisual.Pose.ROLL)
	GameEvents.player_rolled.emit()


func exit(_next: StringName) -> void:
	player.set_rolling(false)


func handle(cmd: Command) -> bool:
	if cmd is InputCommand.Roll:
		return false
	return cmd.execute(player)


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition_to(Player.RUN if player.on_ground else Player.FALL)
