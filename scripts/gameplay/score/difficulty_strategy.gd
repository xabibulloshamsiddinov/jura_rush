## Strategy pattern for difficulty. A strategy answers two questions:
##   speed_fraction(run_time) -> 0..1   how far along the speed ramp the run is
##   pattern_bias(skill)      -> +/-    how much harder/easier patterns should be than the ramp
## Selected by GameConfig.difficulty_strategy: &"linear", &"curve" or &"adaptive".
class_name DifficultyStrategy
extends RefCounted


## Speed ramp position for a run time in seconds.
func speed_fraction(_run_time: float, _cfg: GameConfig) -> float:
	return 0.0


## Pattern difficulty offset for a skill estimate in -1..1.
func pattern_bias(_skill: float, _cfg: GameConfig) -> float:
	return 0.0


## Creates a strategy by id.
static func create(id: StringName) -> DifficultyStrategy:
	match id:
		&"linear":
			return Linear.new()
		&"curve":
			return CurveBased.new()
	return Adaptive.new()


## Straight line from 0 to 1 over speed_ramp_time.
class Linear extends DifficultyStrategy:
	func speed_fraction(run_time: float, cfg: GameConfig) -> float:
		return clampf(run_time / cfg.speed_ramp_time, 0.0, 1.0)


## Follows config/difficulty_curve.tres (fast early ramp, gentle finish).
class CurveBased extends DifficultyStrategy:
	func speed_fraction(run_time: float, cfg: GameConfig) -> float:
		var t: float = clampf(run_time / cfg.speed_ramp_time, 0.0, 1.0)
		return clampf(cfg.difficulty_curve.sample_baked(t), 0.0, 1.0)


## Curve-based speed, plus patterns that lean easier for struggling players and harder for
## clean ones: bias = skill * adaptive_range.
class Adaptive extends CurveBased:
	func pattern_bias(skill: float, cfg: GameConfig) -> float:
		return clampf(skill, -1.0, 1.0) * cfg.adaptive_range
