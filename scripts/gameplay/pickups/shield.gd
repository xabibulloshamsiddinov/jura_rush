## Shield: a bubble that absorbs one hit, then shatters.
class_name ShieldPowerup
extends PowerupStrategy

const HITS: int = 1


func on_activate(player: Player) -> void:
	player.shield.activate(HITS)


func on_tick(player: Player, _delta: float, _remaining: float) -> void:
	# The bubble broke before the timer ran out: end the power-up early.
	if not player.shield.active:
		player.powerups.cancel(&"shield")


func on_expire(player: Player) -> void:
	if player.shield.active:
		player.shield.deactivate()
