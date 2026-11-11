## Dash: a short invincible sprint that smashes obstacles and bridges gaps.
class_name DashPowerup
extends PowerupStrategy

const SAFE_TIME_AFTER: float = 1.2


func on_activate(player: Player) -> void:
	player.dashing = true
	player.track.speed_multiplier = GameConfig.current().dash_speed_multiplier
	player.trail.burst()


func on_expire(player: Player) -> void:
	player.dashing = false
	player.track.speed_multiplier = 1.0
	player.grant_invulnerability(SAFE_TIME_AFTER)
