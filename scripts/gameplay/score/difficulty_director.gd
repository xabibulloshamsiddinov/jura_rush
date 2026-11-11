## Difficulty Director. Turns run time into a target speed, watches how the player is doing and
## nudges pattern difficulty within bounds.
##
##   speed      = lerp(start_speed, max_speed, strategy.speed_fraction(run_time))
##   skill      = clamp(time_since_hit / 30 + 0.1 * near_recent - 0.6 * hits_recent, -1, 1)
##   difficulty = clamp(1 + 9 * speed_fraction + strategy.pattern_bias(skill), 1, 10)
##
## near_recent / hits_recent are event counters that decay with a 20 s half-life.
class_name DifficultyDirector
extends Node

const HALF_LIFE: float = 20.0

var run_time: float = 0.0
var time_since_hit: float = 0.0
var near_recent: float = 0.0
var hits_recent: float = 0.0
var strategy: DifficultyStrategy = null

var _cfg: GameConfig = GameConfig.current()


func _ready() -> void:
	strategy = DifficultyStrategy.create(_cfg.difficulty_strategy)
	GameEvents.near_miss.connect(func(_lane: int) -> void: near_recent += 1.0)
	GameEvents.player_stumbled.connect(func(_kind: StringName) -> void: _on_hit())
	GameEvents.player_crashed.connect(func(_kind: StringName) -> void: _on_hit())


## Restarts the director for a new run.
func reset() -> void:
	run_time = 0.0
	time_since_hit = 0.0
	near_recent = 0.0
	hits_recent = 0.0
	strategy = DifficultyStrategy.create(_cfg.difficulty_strategy)


## Advances the run clock (only while the run is live).
func tick(delta: float) -> void:
	run_time += delta
	time_since_hit += delta
	var decay: float = pow(0.5, delta / HALF_LIFE)
	near_recent *= decay
	hits_recent *= decay


## Speed ramp position right now (0..1).
func speed_fraction() -> float:
	return strategy.speed_fraction(run_time, _cfg)


## Speed the world should be moving at right now.
func target_speed() -> float:
	return lerpf(_cfg.start_speed, _cfg.max_speed, speed_fraction())


## Speed expected `seconds_ahead` from now (used to validate chunks for their arrival time).
func predict_speed(seconds_ahead: float) -> float:
	return lerpf(_cfg.start_speed, _cfg.max_speed,
			strategy.speed_fraction(run_time + seconds_ahead, _cfg))


## Player skill estimate in -1..1 (see header formula).
func skill() -> float:
	return clampf(time_since_hit / 30.0 + 0.1 * near_recent - 0.6 * hits_recent, -1.0, 1.0)


## Pattern difficulty 1..10 for the next chunk.
func pattern_difficulty(seconds_ahead: float = 0.0) -> float:
	var f: float = strategy.speed_fraction(run_time + seconds_ahead, _cfg)
	return clampf(1.0 + 9.0 * f + strategy.pattern_bias(skill(), _cfg), 1.0, 10.0)


func _on_hit() -> void:
	hits_recent += 1.0
	time_since_hit = 0.0
