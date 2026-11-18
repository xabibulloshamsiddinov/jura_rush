## Run scoring: distance, coins, near misses, combo meter and multipliers. Talks to the rest of
## the game only through its world's event bus; registered as the &"score" service (single-player
## world only) so the flow can ask it to finalise a run.
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
## False in multiplayer: no account multiplier, nothing is banked in the save, no service.
var persist: bool = true

var _cfg: GameConfig = GameConfig.current()
var _last_distance: float = 0.0
var _powerup_multiplier: int = 1
var _near_chain: int = 0
var _coin_chain: int = 0
var _combo_left: float = 0.0
var _emit_left: float = 0.0
var _last_emitted_score: int = -1
var _last_emitted_metres: int = -1
var _bus: EventBus = GameEvents


func _ready() -> void:
	_bus = EventScope.of(self)
	if persist:
		Services.provide(&"score", self)
	_bus.coin_collected.connect(_on_coin)
	_bus.near_miss.connect(_on_near_miss)
	_bus.mystery_box_opened.connect(_on_box)
	_bus.powerup_activated.connect(func(id: StringName, _d: float) -> void:
		if id == &"multiplier":
			_set_powerup_multiplier(2))
	_bus.powerup_expired.connect(func(id: StringName) -> void:
		if id == &"multiplier":
			_set_powerup_multiplier(1))
	_bus.player_stumbled.connect(func(_k: StringName) -> void: _break_combo())


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
	_bus.score_changed.emit(0)
	_bus.coins_changed.emit(0)
	_bus.combo_changed.emit(1)
	_bus.multiplier_changed.emit(total_multiplier())


## Multiplier applied to everything: account (missions) + booster, times the x2 power-up.
func total_multiplier() -> int:
	return _base_multiplier() * _powerup_multiplier


## Account (missions) multiplier plus the booster; 1 + booster for runs that are not banked.
func _base_multiplier() -> int:
	return (SaveSystem.account_multiplier() if persist else 1) + booster_bonus


## Adds distance score and runs the combo timer. Call every step while the run is live.
func tick(delta: float) -> void:
	if not run_active:
		return
	run_time += delta
	var travelled: float = track.distance_travelled - _last_distance
	_last_distance = track.distance_travelled
	score += ScoreCalculator.points(travelled * _cfg.score_per_meter, 1, _powerup_multiplier,
			_base_multiplier())
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
	var best: int = int(SaveSystem.data.get("best_score", 0)) if persist else 0
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
	if not persist:
		_bus.run_ended.emit(result)
		return result
	SaveSystem.data["best_score"] = maxi(best, final_score)
	SaveSystem.data["total_distance"] = float(SaveSystem.data.get("total_distance", 0.0)) \
			+ track.distance_travelled
	SaveSystem.add_coins(run_coins)
	if run_keys > 0:
		SaveSystem.add_keys(run_keys)
	_bus.run_ended.emit(result)
	SaveSystem.save_game()
	return result


func _on_coin(value: int, _world_pos: Vector3) -> void:
	if not run_active:
		return
	run_coins += value
	_coin_chain += 1
	_touch_combo()
	score += ScoreCalculator.points(float(value * _cfg.score_per_coin), combo, _powerup_multiplier,
			_base_multiplier())
	_bus.coins_changed.emit(run_coins)


func _on_near_miss(lane: int) -> void:
	if not run_active:
		return
	near_misses += 1
	_near_chain += 1
	_touch_combo()
	var gained: float = ScoreCalculator.points(float(_cfg.near_miss_points), combo,
			_powerup_multiplier, _base_multiplier())
	score += gained
	_bus.floating_text.emit("+%d %s" % [int(gained), Tr.t(&"hud.near")],
			Vector3(_cfg.lane_x(lane), 2.2, -1.0), Color(1.0, 0.9, 0.2))


func _on_box(reward: StringName, amount: int) -> void:
	if not run_active:
		return
	if reward == &"coins":
		run_coins += amount
		_bus.coins_changed.emit(run_coins)
	elif reward == &"keys":
		run_keys += amount


func _touch_combo() -> void:
	_combo_left = _cfg.combo_window
	var level: int = ScoreCalculator.combo_level(_near_chain, _coin_chain, _cfg.combo_max)
	if level != combo:
		combo = level
		_bus.combo_changed.emit(combo)


func _break_combo() -> void:
	_near_chain = 0
	_coin_chain = 0
	_combo_left = 0.0
	if combo != 1:
		combo = 1
		_bus.combo_changed.emit(1)


func _set_powerup_multiplier(value: int) -> void:
	_powerup_multiplier = value
	_bus.multiplier_changed.emit(total_multiplier())


func _emit_score() -> void:
	var whole: int = int(score)
	if whole != _last_emitted_score:
		_last_emitted_score = whole
		_bus.score_changed.emit(whole)
	var metres: int = int(track.distance_travelled)
	if metres != _last_emitted_metres:
		_last_emitted_metres = metres
		_bus.distance_changed.emit(metres)
