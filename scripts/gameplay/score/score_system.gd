## Run scoring: distance, coins, near misses, combo meter and multipliers. Talks to the rest of
## the game only through GameEvents; registered as the &"score" service so the flow can ask it
## to finalise a run.
class_name ScoreSystem
extends Node

const SCORE_EMIT_INTERVAL: float = 0.1

var track: TrackManager = null
var score: float = 0.0
var run_coins: int = 0
var run_keys: int = 0
var near_misses: int = 0
var combo: int = 1
## Extra multiplier from the score-booster consumable.
var booster_bonus: int = 0
var run_active: bool = false
var run_time: float = 0.0

var _cfg: GameConfig = GameConfig.current()
var _last_distance: float = 0.0
var _powerup_multiplier: int = 1
var _near_chain: int = 0
var _coin_chain: int = 0
var _combo_left: float = 0.0
var _emit_left: float = 0.0
var _last_emitted_score: int = -1
var _last_emitted_metres: int = -1


func _ready() -> void:
	Services.provide(&"score", self)
	GameEvents.coin_collected.connect(_on_coin)
	GameEvents.near_miss.connect(_on_near_miss)
	GameEvents.mystery_box_opened.connect(_on_box)
	GameEvents.powerup_activated.connect(func(id: StringName, _d: float) -> void:
		if id == &"multiplier":
			_set_powerup_multiplier(2))
	GameEvents.powerup_expired.connect(func(id: StringName) -> void:
		if id == &"multiplier":
			_set_powerup_multiplier(1))
	GameEvents.player_stumbled.connect(func(_k: StringName) -> void: _break_combo())


## Clears everything for a new run.
func reset() -> void:
	score = 0.0
	run_coins = 0
	run_keys = 0
	near_misses = 0
	booster_bonus = 0
	run_time = 0.0
	run_active = true
	_last_distance = 0.0
	_powerup_multiplier = 1
	_near_chain = 0
	_coin_chain = 0
	_combo_left = 0.0
	combo = 1
	_last_emitted_score = -1
	_last_emitted_metres = -1
	GameEvents.score_changed.emit(0)
	GameEvents.coins_changed.emit(0)
	GameEvents.combo_changed.emit(1)
	GameEvents.multiplier_changed.emit(total_multiplier())


## Multiplier applied to everything: account (missions) + booster, times the x2 power-up.
func total_multiplier() -> int:
	return (SaveSystem.account_multiplier() + booster_bonus) * _powerup_multiplier


## Adds distance score and runs the combo timer. Call every step while the run is live.
func tick(delta: float) -> void:
	if not run_active:
		return
	run_time += delta
	var travelled: float = track.distance_travelled - _last_distance
	_last_distance = track.distance_travelled
	score += ScoreCalculator.points(travelled * _cfg.score_per_meter, 1, _powerup_multiplier,
			SaveSystem.account_multiplier() + booster_bonus)
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_break_combo()
	_emit_left -= delta
	if _emit_left <= 0.0:
		_emit_left = SCORE_EMIT_INTERVAL
		_emit_score()


## Ends the run: banks coins / keys / best score and returns the result dictionary.
func finalize_run() -> Dictionary:
	if not run_active:
		return {}
	run_active = false
	var final_score: int = int(score)
	var best: int = int(SaveSystem.data.get("best_score", 0))
	var result: Dictionary = {
		"score": final_score,
		"coins": run_coins,
		"keys": run_keys,
		"distance": int(track.distance_travelled),
		"near_misses": near_misses,
		"best": maxi(best, final_score),
		"new_best": final_score > best and final_score > 0,
		"duration": run_time,
	}
	SaveSystem.data["best_score"] = maxi(best, final_score)
	SaveSystem.data["total_distance"] = float(SaveSystem.data.get("total_distance", 0.0)) \
			+ track.distance_travelled
	SaveSystem.add_coins(run_coins)
	if run_keys > 0:
		SaveSystem.add_keys(run_keys)
	GameEvents.run_ended.emit(result)
	SaveSystem.save_game()
	return result


func _on_coin(value: int, _world_pos: Vector3) -> void:
	if not run_active:
		return
	run_coins += value
	_coin_chain += 1
	_touch_combo()
	score += ScoreCalculator.points(float(value * _cfg.score_per_coin), combo, _powerup_multiplier,
			SaveSystem.account_multiplier() + booster_bonus)
	GameEvents.coins_changed.emit(run_coins)


func _on_near_miss(lane: int) -> void:
	if not run_active:
		return
	near_misses += 1
	_near_chain += 1
	_touch_combo()
	var gained: float = ScoreCalculator.points(float(_cfg.near_miss_points), combo,
			_powerup_multiplier, SaveSystem.account_multiplier() + booster_bonus)
	score += gained
	GameEvents.floating_text.emit("+%d %s" % [int(gained), Tr.t(&"hud.near")],
			Vector3(_cfg.lane_x(lane), 2.2, -1.0), Color(1.0, 0.9, 0.2))


func _on_box(reward: StringName, amount: int) -> void:
	if not run_active:
		return
	if reward == &"coins":
		run_coins += amount
		GameEvents.coins_changed.emit(run_coins)
	elif reward == &"keys":
		run_keys += amount


func _touch_combo() -> void:
	_combo_left = _cfg.combo_window
	var level: int = ScoreCalculator.combo_level(_near_chain, _coin_chain, _cfg.combo_max)
	if level != combo:
		combo = level
		GameEvents.combo_changed.emit(combo)


func _break_combo() -> void:
	_near_chain = 0
	_coin_chain = 0
	_combo_left = 0.0
	if combo != 1:
		combo = 1
		GameEvents.combo_changed.emit(1)


func _set_powerup_multiplier(value: int) -> void:
	_powerup_multiplier = value
	GameEvents.multiplier_changed.emit(total_multiplier())


func _emit_score() -> void:
	var whole: int = int(score)
	if whole != _last_emitted_score:
		_last_emitted_score = whole
		GameEvents.score_changed.emit(whole)
	var metres: int = int(track.distance_travelled)
	if metres != _last_emitted_metres:
		_last_emitted_metres = metres
		GameEvents.distance_changed.emit(metres)
