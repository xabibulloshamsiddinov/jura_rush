## Maps game events to sounds and music changes. This is the only place that decides "what
## sound does this event make", which keeps gameplay code free of audio calls.
class_name AudioEventRouter
extends Node

var _audio: Node = null
var _speed_fraction: float = 0.0
var _flying: bool = false
var _running: bool = false
var _rumble_left: float = 0.0
var _cfg: GameConfig = GameConfig.current()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = get_parent()
	GameEvents.coin_collected.connect(func(_v: int, _p: Vector3) -> void: _audio.call(&"play_coin"))
	GameEvents.player_jumped.connect(func() -> void: _play(&"jump"))
	GameEvents.player_rolled.connect(func() -> void: _play(&"roll"))
	GameEvents.player_landed.connect(func(impact: float) -> void:
		if impact > 6.0:
			_play(&"land"))
	GameEvents.lane_changed.connect(func(_f: int, _t: int) -> void: _play(&"swipe", 0.1))
	GameEvents.player_stumbled.connect(func(_k: StringName) -> void: _play(&"stumble"))
	GameEvents.player_crashed.connect(_on_crash)
	GameEvents.near_miss.connect(func(_l: int) -> void: _play(&"near_miss", 0.08))
	GameEvents.combo_changed.connect(func(combo: int) -> void:
		if combo == 1:
			_play(&"combo_break"))
	GameEvents.powerup_activated.connect(_on_powerup_activated)
	GameEvents.powerup_expiring.connect(func(_id: StringName) -> void: _play(&"powerup_warning", 0.0))
	GameEvents.powerup_expired.connect(_on_powerup_expired)
	GameEvents.shield_hit.connect(func() -> void: _play(&"shield_hit"))
	GameEvents.shield_broken.connect(func() -> void: _play(&"shield_break"))
	GameEvents.obstacle_smashed.connect(func(_p: Vector3) -> void: _play(&"smash"))
	GameEvents.mystery_box_opened.connect(func(_r: StringName, _a: int) -> void: _play(&"box_open"))
	GameEvents.moving_train_warning.connect(_on_train_warning)
	GameEvents.biome_changed.connect(func(_id: StringName, _t: String) -> void: _play(&"biome", 0.0))
	GameEvents.mission_completed.connect(func(_id: StringName) -> void: _jingle(&"mission_complete"))
	GameEvents.mission_set_completed.connect(func(_m: int) -> void: _jingle(&"mission_complete"))
	GameEvents.achievement_unlocked.connect(func(_id: StringName) -> void: _jingle(&"mission_complete"))
	GameEvents.item_purchased.connect(func(_id: StringName) -> void: _play(&"purchase", 0.0))
	GameEvents.countdown_tick.connect(func(n: int) -> void:
		_play(&"count_go" if n <= 0 else &"count_beep", 0.0))
	GameEvents.ui_feedback.connect(_on_ui_feedback)
	GameEvents.speed_changed.connect(_on_speed_changed)
	GameEvents.state_changed.connect(_on_state_changed)
	set_process(false)


func _play(id: StringName, pitch_var: float = 0.05) -> void:
	_audio.call(&"play", id, pitch_var)


func _jingle(id: StringName) -> void:
	_audio.call(&"duck", -6.0)
	_audio.call(&"play", id, 0.0)


func _on_crash(_kind: StringName) -> void:
	_audio.call(&"duck", -9.0)
	_play(&"crash", 0.0)
	_flying = false
	_update_loops()


func _on_powerup_activated(id: StringName, _duration: float) -> void:
	_play(&"powerup_start", 0.0)
	if id == &"jetpack":
		_flying = true
		_update_loops()


func _on_powerup_expired(id: StringName) -> void:
	_play(&"powerup_end", 0.0)
	if id == &"jetpack":
		_flying = false
		_update_loops()


## Triceratops stampede telegraph: a bellow and the rumble of hooves from its lane ahead (3D).
func _on_train_warning(lane: int) -> void:
	var pos: Vector3 = Vector3(_cfg.lane_x(lane), 2.0, -30.0)
	_audio.call(&"play_3d", &"train_horn", pos)
	_rumble_left = 2.6
	_audio.call(&"set_loop", &"train_rumble", 0.9, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	_rumble_left -= delta
	if _rumble_left <= 0.0:
		_audio.call(&"set_loop", &"train_rumble", 0.0, 1.0)
		set_process(false)


func _on_ui_feedback(kind: StringName) -> void:
	match kind:
		&"click":
			_play(&"ui_click")
		&"hover":
			_play(&"ui_hover", 0.0)
		&"back":
			_play(&"ui_back")
		&"confirm":
			_play(&"ui_confirm", 0.0)
		&"error":
			_play(&"ui_error", 0.0)
		&"count":
			_play(&"count_up", 0.1)


func _on_speed_changed(speed: float) -> void:
	_speed_fraction = _cfg.speed_fraction(speed)
	_audio.call(&"set_intensity", _speed_fraction)
	_update_loops()


func _on_state_changed(_from: StringName, to: StringName) -> void:
	_running = to == &"running"
	_audio.call(&"set_paused_filter", to == &"paused")
	match to:
		&"menu", &"boot":
			_audio.call(&"set_music_mode", &"menu")
		&"game_over":
			_audio.call(&"set_music_mode", &"menu")
		&"loading", &"countdown", &"running":
			_audio.call(&"set_music_mode", &"game")
	_update_loops()


func _update_loops() -> void:
	var wind: float = (0.25 + 0.75 * _speed_fraction) if _running else 0.0
	_audio.call(&"set_loop", &"wind_loop", wind, 0.8 + 0.5 * _speed_fraction)
	_audio.call(&"set_loop", &"jetpack_loop", 1.0 if (_flying and _running) else 0.0, 1.0)
