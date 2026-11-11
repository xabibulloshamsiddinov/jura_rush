## Strategy pattern for power-up behaviour. PowerupController owns timing and stacking; a
## strategy only says what happens on activate / every tick / on expire.
class_name PowerupStrategy
extends RefCounted


## Called once when the power-up starts (not when it is refreshed).
func on_activate(_player: Player) -> void:
	pass


## Called every physics frame while active.
func on_tick(_player: Player, _delta: float, _remaining: float) -> void:
	pass


## Called once when the power-up ends or is cancelled.
func on_expire(_player: Player) -> void:
	pass


## Creates the strategy for a power-up id.
static func create(id: StringName) -> PowerupStrategy:
	match id:
		&"magnet":
			return MagnetPowerup.new()
		&"shield":
			return ShieldPowerup.new()
		&"jetpack":
			return JetpackPowerup.new()
		&"multiplier":
			return MultiplierPowerup.new()
		&"dash":
			return DashPowerup.new()
	return PowerupStrategy.new()
