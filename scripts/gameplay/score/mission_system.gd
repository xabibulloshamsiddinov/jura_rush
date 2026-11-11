## Missions (3 active at a time) and achievements, both driven by MissionDef resources and fed
## entirely by the event bus. Completing a full mission set raises the account multiplier.
## Registered as the &"missions" service so UI screens can list progress.
class_name MissionSystem
extends Node

const SET_SIZE: int = 3

## Stats of the current run: metric -> int.
var run_stats: Dictionary = {}

var _cfg: GameConfig = GameConfig.current()
var _missions: Array[MissionDef] = ContentDB.missions_of(MissionDef.Kind.MISSION)
var _achievements: Array[MissionDef] = ContentDB.missions_of(MissionDef.Kind.ACHIEVEMENT)


func _ready() -> void:
	Services.provide(&"missions", self)
	_ensure_active_set()
	GameEvents.run_started.connect(func() -> void: run_stats.clear())
	GameEvents.coin_collected.connect(func(value: int, _p: Vector3) -> void: bump(&"coins", value))
	GameEvents.player_jumped.connect(func() -> void: bump(&"jumps", 1))
	GameEvents.player_rolled.connect(func() -> void: bump(&"rolls", 1))
	GameEvents.near_miss.connect(func(_lane: int) -> void: bump(&"near_misses", 1))
	GameEvents.shield_hit.connect(func() -> void: bump(&"shield_used", 1))
	GameEvents.powerup_activated.connect(func(_id: StringName, _d: float) -> void: bump(&"powerups", 1))
	GameEvents.player_stumbled.connect(func(_k: StringName) -> void: bump(&"stumbles", 1))
	GameEvents.mystery_box_opened.connect(func(reward: StringName, amount: int) -> void:
		bump(&"boxes", 1)
		if reward == &"coins":
			bump(&"coins", amount))
	GameEvents.distance_changed.connect(_on_distance)
	GameEvents.score_changed.connect(func(value: int) -> void: _set_run_stat(&"score", value))
	GameEvents.run_ended.connect(func(_result: Dictionary) -> void: bump(&"runs", 1))


## Adds to a stat (run + lifetime) and re-checks missions and achievements.
func bump(metric: StringName, amount: int) -> void:
	var key: String = String(metric)
	run_stats[key] = int(run_stats.get(key, 0)) + amount
	var totals: Dictionary = SaveSystem.section("stats")
	totals[key] = int(totals.get(key, 0)) + amount
	_evaluate(metric)


## Current value of a definition's metric in its scope.
func value_of(def: MissionDef) -> int:
	var key: String = String(def.metric)
	if def.scope == MissionDef.Scope.RUN:
		return int(run_stats.get(key, 0))
	var total: int = int(SaveSystem.section("stats").get(key, 0))
	if def.kind == MissionDef.Kind.ACHIEVEMENT:
		return total
	var bases: Dictionary = _state().get("base", {})
	return total - int(bases.get(String(def.id), 0))


## The three active missions as rows: {def, value, target, done}.
func mission_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var done: Array = _state().get("done", [])
	for id: Variant in _active_ids():
		var def: MissionDef = ContentDB.mission(StringName(str(id)))
		if def == null:
			continue
		var is_done: bool = done.has(String(def.id))
		rows.append({"def": def, "value": def.target if is_done else mini(value_of(def), def.target),
				"target": def.target, "done": is_done})
	return rows


## Every achievement as rows: {def, value, target, done}.
func achievement_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var unlocked: Array = SaveSystem.data.get("achievements", [])
	for def in _achievements:
		var is_done: bool = unlocked.has(String(def.id))
		rows.append({"def": def, "value": def.target if is_done else mini(value_of(def), def.target),
				"target": def.target, "done": is_done})
	return rows


func _state() -> Dictionary:
	return SaveSystem.section("missions")


func _active_ids() -> Array:
	var active: Array = _state().get("active", [])
	return active


## Fills the active set from the mission list (cycling) when it is empty.
func _ensure_active_set() -> void:
	var state: Dictionary = _state()
	if not _active_ids().is_empty() or _missions.is_empty():
		return
	var set_index: int = int(state.get("set_index", 0))
	var active: Array = []
	var bases: Dictionary = {}
	var totals: Dictionary = SaveSystem.section("stats")
	for i in range(SET_SIZE):
		var def: MissionDef = _missions[(set_index * SET_SIZE + i) % _missions.size()]
		active.append(String(def.id))
		bases[String(def.id)] = int(totals.get(String(def.metric), 0))
	state["active"] = active
	state["base"] = bases
	state["done"] = []
	SaveSystem.mark_dirty()


func _set_run_stat(metric: StringName, value: int) -> void:
	if value > int(run_stats.get(String(metric), 0)):
		run_stats[String(metric)] = value
		_evaluate(metric)


func _on_distance(metres: int) -> void:
	var before: int = int(run_stats.get("distance", 0))
	if metres > before:
		bump(&"distance", metres - before)


func _evaluate(metric: StringName) -> void:
	var state: Dictionary = _state()
	var done: Array = state.get("done", [])
	for id: Variant in _active_ids():
		var def: MissionDef = ContentDB.mission(StringName(str(id)))
		if def == null or def.metric != metric or done.has(String(def.id)):
			continue
		var value: int = value_of(def)
		GameEvents.mission_progress.emit(def.id, mini(value, def.target), def.target)
		if value >= def.target:
			done.append(String(def.id))
			state["done"] = done
			SaveSystem.add_coins(def.reward_coins)
			GameEvents.mission_completed.emit(def.id)
	if not _active_ids().is_empty() and done.size() >= _active_ids().size():
		_complete_set(state)
	var unlocked: Array = SaveSystem.data.get("achievements", [])
	for def in _achievements:
		if def.metric != metric or unlocked.has(String(def.id)):
			continue
		if value_of(def) >= def.target:
			unlocked.append(String(def.id))
			SaveSystem.data["achievements"] = unlocked
			SaveSystem.add_coins(def.reward_coins)
			GameEvents.achievement_unlocked.emit(def.id)


## A full set is done: +1 account multiplier (capped) and the next three missions start.
func _complete_set(state: Dictionary) -> void:
	var multiplier: int = mini(int(state.get("multiplier", 1)) + 1, _cfg.account_multiplier_cap)
	state["multiplier"] = multiplier
	state["set_index"] = int(state.get("set_index", 0)) + 1
	state["active"] = []
	_ensure_active_set()
	GameEvents.mission_set_completed.emit(multiplier)
	SaveSystem.mark_dirty()
