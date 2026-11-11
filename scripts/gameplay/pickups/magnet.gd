## Magnet: coins inside magnet_radius fly to the player (PickupSystem does the pulling).
class_name MagnetPowerup
extends PowerupStrategy


func on_activate(player: Player) -> void:
	player.magnet.active = true


func on_expire(player: Player) -> void:
	player.magnet.active = false
