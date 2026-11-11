## Turns versus gameplay events into sound and effects (the versus counterpart of
## AudioEventRouter + VFXManager's bus listeners). Also drives the engine and siren loops,
## speed lines and the adaptive music intensity.
class_name VsPresenter
extends Node

var game: VsGame = null

var _audio: Node = null


func _ready() -> void:
	_audio = AudioManager
	game.fx.connect(_on_fx)
	GameEvents.versus_countdown.connect(func(n: int) -> void:
		_audio.call(&"play", &"count_go" if n <= 0 else &"count_beep", 0.0))
	_audio.call(&"set_music_mode", &"game")


func _exit_tree() -> void:
	stop_loops()


## Silences the looping sounds (pause, exit).
func stop_loops() -> void:
	_audio.call(&"set_loop", &"vs_engine", 0.0)
	_audio.call(&"set_loop", &"vs_siren", 0.0)
	_audio.call(&"set_loop", &"wind_loop", 0.0)
	VFXManager.screen.set_speed_lines(0.0)


func _process(_delta: float) -> void:
	if game == null:
		return
	if game.paused or game.phase == &"over":
		stop_loops()
		_audio.call(&"set_paused_filter", game.paused)
		return
	_audio.call(&"set_paused_filter", false)
	var f: float = game.speed_fraction()
	_audio.call(&"set_intensity", 0.35 + 0.65 * f if game.phase == &"race" else 0.2)
	var rel: float = 0.0
	var danger: float = 0.0
	var nitro: bool = false
	for i in range(2):
		var c: VsCar = game.cars[i]
		if not c.alive():
			continue
		rel = maxf(rel, c.rel_speed)
		nitro = nitro or c.nitro_t > 0.0
		danger = maxf(danger, 1.0 - clampf((game.police_z[i] - c.position.z - VsDefs.BUST_RANGE) / 9.0, 0.0, 1.0))
	var engine_pitch: float = 0.75 + 0.45 * f + clampf(rel / VsDefs.NITRO_REL, -0.3, 1.0) * 0.35
	_audio.call(&"set_loop", &"vs_engine", 0.75, engine_pitch)
	_audio.call(&"set_loop", &"vs_siren", 0.25 + 0.75 * danger, 1.0)
	_audio.call(&"set_loop", &"wind_loop", 0.3 + 0.5 * f, 0.8 + 0.5 * f)
	var lines: float = smoothstep(0.4, 1.0, f) * 0.45
	if nitro:
		lines = 1.0
	VFXManager.screen.set_speed_lines(lines * _strength())


func _strength() -> float:
	return 0.35 if SettingsManager.reduce_effects() else 1.0


func _play(id: StringName, pitch_var: float = 0.05) -> void:
	_audio.call(&"play", id, pitch_var)


func _on_fx(kind: StringName, pos: Vector3, color: Color, _player: int) -> void:
	var bright: Color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	match kind:
		&"lane":
			_play(&"swipe", 0.1)
		&"cycle":
			_play(&"ui_click", 0.05)
		&"empty", &"full":
			_play(&"ui_error", 0.0)
		&"pickup":
			_play(&"vs_pickup", 0.06)
			VFXManager.play(&"burst", pos, bright)
			VFXManager.ring(Vector3(pos.x, 0.1, pos.z), color, 0.4, 2.6, 0.35)
		&"fire_seeker":
			_play(&"vs_seeker", 0.04)
		&"fire_bolt":
			_play(&"vs_bolt", 0.1)
		&"lock":
			_play(&"vs_lock", 0.0)
		&"pulse":
			_play(&"vs_pulse", 0.03)
			VFXManager.ring(Vector3(pos.x, 0.3, pos.z), color, 0.6, VsDefs.PULSE_RADIUS, 0.4)
			VFXManager.ring(Vector3(pos.x, 1.0, pos.z), color.lightened(0.3), 0.5, VsDefs.PULSE_RADIUS * 0.8, 0.3, false)
			VFXManager.play(&"burst", pos + Vector3(0.0, 0.8, 0.0), bright)
			VFXManager.screen.flash(color, 0.18 * _strength(), 0.3)
			game.camera.shake.add_trauma(0.35)
		&"emp":
			_play(&"vs_emp", 0.03)
		&"emp_hit":
			_play(&"vs_emp", 0.08)
			VFXManager.play(&"sparks", pos + Vector3(0.0, 0.8, 0.0), bright)
			if SettingsManager.quality() > 0 and not SettingsManager.reduce_effects():
				VFXManager.screen.chroma_pulse(0.35)
		&"mine_drop":
			_play(&"vs_mine", 0.0)
		&"nitro":
			_play(&"vs_nitro", 0.03)
			VFXManager.ring(Vector3(pos.x, 0.5, pos.z + 2.5), color, 0.4, 2.8, 0.35, false)
		&"brake_jump":
			_play(&"vs_brake", 0.05)
			VFXManager.play(&"sparks", pos + Vector3(0.0, 0.2, 0.0))
		&"shield":
			_play(&"vs_shield", 0.0)
			VFXManager.ring(Vector3(pos.x, 0.9, pos.z), color, 0.8, 3.2, 0.4, false)
		&"shield_block":
			_play(&"shield_hit", 0.05)
			VFXManager.ring(Vector3(pos.x, 0.9, pos.z), color, 1.0, 3.6, 0.3, false)
		&"repair":
			_play(&"vs_repair", 0.0)
			VFXManager.play(&"burst", pos + Vector3(0.0, 1.0, 0.0), bright)
			VFXManager.ring(Vector3(pos.x, 0.1, pos.z), color, 0.4, 3.0, 0.5)
		&"explode":
			_play(&"vs_explode", 0.08)
			VFXManager.play(&"crash", pos, bright)
			VFXManager.ring(Vector3(pos.x, 0.2, pos.z), color, 0.5, 4.5, 0.4)
		&"explode_small", &"zap":
			_play(&"vs_zap", 0.1)
			VFXManager.play(&"sparks", pos, bright)
		&"hit":
			_play(&"stumble", 0.08)
			VFXManager.play(&"sparks", pos)
			VFXManager.play(&"debris", pos)
		&"smash":
			_play(&"smash", 0.1)
			VFXManager.play(&"debris", pos)
		&"near":
			_play(&"near_miss", 0.08)
			VFXManager.streak(pos, Color(0.6, 0.9, 1.0), 7.0, 0.3)
		&"ram":
			_play(&"vs_zap", 0.15)
			VFXManager.play(&"sparks", pos)
		&"police_hit":
			_play(&"smash", 0.1)
			VFXManager.play(&"sparks", pos, Color(1.0, 1.5, 3.0))
		&"wreck":
			_audio.call(&"duck", -8.0)
			_play(&"crash", 0.0)
			_play(&"vs_explode", 0.0)
			VFXManager.play(&"crash", pos, bright)
			VFXManager.play(&"debris", pos)
			VFXManager.play(&"shards", pos, bright)
			VFXManager.ring(Vector3(pos.x, 0.2, pos.z), Color(1.0, 0.7, 0.3), 0.6, 7.0, 0.55)
			VFXManager.screen.flash(Color(1.0, 0.85, 0.7), 0.6 * _strength(), 0.25)
			if SettingsManager.quality() > 0 and not SettingsManager.reduce_effects():
				VFXManager.screen.chroma_pulse(0.6)
		&"busted":
			_audio.call(&"duck", -8.0)
			_play(&"vs_busted", 0.0)
			VFXManager.ring(Vector3(pos.x, 0.2, pos.z), Color(0.3, 0.45, 1.0), 0.6, 6.0, 0.5)
			VFXManager.screen.flash(Color(0.3, 0.4, 1.0), 0.45 * _strength(), 0.4)
		&"respawn":
			_play(&"vs_respawn", 0.0)
			VFXManager.ring(Vector3(pos.x, 0.1, pos.z), color, 0.5, 3.5, 0.5)
		&"finish":
			_audio.call(&"duck", -6.0)
			_audio.call(&"play", &"mission_complete", 0.0)
			_audio.call(&"set_music_mode", &"menu")
			stop_loops()
