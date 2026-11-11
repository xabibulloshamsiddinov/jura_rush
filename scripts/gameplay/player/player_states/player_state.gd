## Base of all player states. By default a state lets every command try to execute.
class_name PlayerState
extends State

## Typed access to the host.
var player: Player:
	get:
		return host as Player


func handle(cmd: Command) -> bool:
	return cmd.execute(player)
