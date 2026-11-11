## Jetpack: fly above everything along an automatic trail of sky coins.
class_name JetpackPowerup
extends PowerupStrategy


func on_activate(player: Player) -> void:
	player.start_jetpack()


func on_expire(player: Player) -> void:
	player.stop_jetpack()
