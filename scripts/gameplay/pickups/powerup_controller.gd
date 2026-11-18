## Player component that runs active power-ups: durations (from PowerupDef + shop upgrade
## level), stacking rules, expiry warnings and the strategy callbacks.
class_name PowerupController
extends Node

const WARNING_TIME: float = 2.0

var player: Player = null
## False in multiplayer: every player gets the base durations, whatever the save has upgraded.
var use_upgrades: bool = true

## id -> seconds remaining.
var _remaining: Dictionary = {}
## id -> total duration of the current activation (HUD radial).
var _total: Dictionary = {}
var _warned: Dictionary = {}
var _strategies: Dictionary = {}
var _expired: Array[StringName] = []


func _ready() -> void:
	for def: PowerupDef in ContentDB.POWERUPS:
		_strategies[def.id] = PowerupStrategy.create(def.id)


## Starts (or refreshes / extends, per the def's stacking rule) a power-up.
func activate(id: StringName) -> void:
	var def: PowerupDef = ContentDB.powerup(id)
	if def == null or player.is_dead:
		return
	var duration: float = def.duration_for_level(SaveSystem.upgrade_level(id) if use_upgrades else 0)
	var was_active: bool = _remaining.has(id)
	if was_active and def.stacking == PowerupDef.Stacking.IGNORE:
		return
	if was_active and def.stacking == PowerupDef.Stacking.EXTEND:
		duration = minf(float(_remaining[id]) + duration, duration * 2.0)
	_remaining[id] = duration
	_total[id] = duration
	_warned.erase(id)
	if not was_active:
		(_strategies[id] as PowerupStrategy).on_activate(player)
	player.events.powerup_activated.emit(id, duration)


## Starts a power-up for an explicit duration (head-start consumable).
func activate_for(id: StringName, duration: float) -> void:
	activate(id)
	if _remaining.has(id):
		_remaining[id] = duration
		_total[id] = duration
		player.events.powerup_activated.emit(id, duration)


## True while a power-up is running.
func is_active(id: StringName) -> bool:
	return _remaining.has(id)


## Seconds left (0 when inactive).
func remaining(id: StringName) -> float:
	return float(_remaining.get(id, 0.0))


## Ends a power-up now.
func cancel(id: StringName) -> void:
	if not _remaining.has(id):
		return
	_remaining.erase(id)
	_total.erase(id)
	(_strategies[id] as PowerupStrategy).on_expire(player)
	player.events.powerup_expired.emit(id)


## Ends everything (death, new run).
func clear_all() -> void:
	for id: StringName in _remaining.keys():
		cancel(id)


## Counts durations down and fires callbacks.
func tick(delta: float) -> void:
	if _remaining.is_empty():
		return
	_expired.clear()
	for id: StringName in _remaining.keys():
		var left: float = float(_remaining[id]) - delta
		_remaining[id] = left
		(_strategies[id] as PowerupStrategy).on_tick(player, delta, left)
		if left <= WARNING_TIME and not _warned.has(id):
			_warned[id] = true
			player.events.powerup_expiring.emit(id)
		if left <= 0.0:
			_expired.append(id)
	for id in _expired:
		cancel(id)
