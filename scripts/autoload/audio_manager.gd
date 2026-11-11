## Audio service: buses, pooled voices with per-sound limits and priorities, loops, the coin
## pitch chain and adaptive music layers. Gameplay never calls it: AudioEventRouter subscribes
## to the event bus and triggers sounds from there.
extends Node

const VOICES: int = 14
const VOICES_3D: int = 3
const BUSES: Array[StringName] = [&"Music", &"SFX", &"UI", &"Ambience"]
const SETTING_OF_BUS: Dictionary = {&"Music": "music", &"SFX": "sfx", &"UI": "sfx", &"Ambience": "ambience"}
## Mute toggle per bus (Settings: Music ON/OFF, Sound effects ON/OFF).
const TOGGLE_OF_BUS: Dictionary = {&"Music": "music_on", &"SFX": "sfx_on", &"UI": "sfx_on", &"Ambience": "sfx_on"}
## A single music file dropped at res://assets/audio/music.ogg (or .mp3 / .wav) replaces the
## synthesised layers and loops in the menu and in runs.
const MUSIC_TRACK_BASE: String = "res://assets/audio/music"
const COIN_CHAIN_RESET: float = 0.6
const COIN_CHAIN_MAX: int = 12

## True once all placeholder sounds have been generated.
var ready_to_play: bool = false
var config: AudioConfig = null

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _player_ids: Array[StringName] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _active: Dictionary = {}
var _loops: Dictionary = {}
var _music: Dictionary = {}
var _music_target: Dictionary = {}
var _music_mode: StringName = &"off"
var _intensity: float = 0.0
var _duck_db: float = 0.0
var _coin_chain: int = 0
var _coin_timer: float = 0.0
var _lowpass: AudioEffectLowPassFilter = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Services.provide(&"audio", self)
	_setup_buses()
	if ResourceLoader.exists("res://config/audio_config.tres"):
		config = ResourceLoader.load("res://config/audio_config.tres") as AudioConfig
	if config == null:
		config = AudioConfig.new()
	for i in range(VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		_player_ids.append(&"")
		p.finished.connect(_on_voice_finished.bind(i))
	for i in range(VOICES_3D):
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.unit_size = 12.0
		p3.max_distance = 120.0
		# Doppler: set through set() because the property is not present in every 4.x release.
		p3.set(&"doppler_tracking", 2)
		add_child(p3)
		_players_3d.append(p3)
	add_child(AudioEventRouter.new())
	GameEvents.settings_changed.connect(apply_volumes)
	apply_volumes()


func _process(delta: float) -> void:
	if _coin_timer > 0.0:
		_coin_timer -= delta
		if _coin_timer <= 0.0:
			_coin_chain = 0
	if _duck_db < 0.0:
		_duck_db = minf(_duck_db + delta * 6.0, 0.0)
		_apply_bus(&"Music")
	for layer: StringName in _music.keys():
		var player: AudioStreamPlayer = _music[layer]
		var target: float = float(_music_target.get(layer, 0.0))
		var current: float = db_to_linear(player.volume_db)
		var next: float = move_toward(current, target, delta * 0.8)
		player.volume_db = linear_to_db(maxf(next, 0.0001))


## Generates every placeholder sound. Awaitable; `progress` receives 0..1 for the loading bar.
func build_async(progress: Callable, with_music: bool = true) -> void:
	var ids: Array = SfxLibrary.DEFS.keys()
	for i in range(ids.size()):
		var id: StringName = ids[i]
		var override: AudioStream = config.find(id)
		_streams[id] = override if override != null else SfxLibrary.build(id)
		if i % 4 == 3:
			progress.call(float(i) / float(ids.size()) * 0.6)
			await get_tree().process_frame
	var track: AudioStream = _find_music_track() if with_music else null
	if track != null:
		_add_music_layer(&"track", track)
		(_music[&"track"] as AudioStreamPlayer).play()
	elif with_music:
		var seq: MusicSequencer = MusicSequencer.new(config.bpm)
		_add_music_layer(&"drums", config.music_drums if config.music_drums != null else seq.build_drums())
		progress.call(0.7)
		await get_tree().process_frame
		_add_music_layer(&"bass", config.music_bass if config.music_bass != null else seq.build_bass())
		progress.call(0.8)
		await get_tree().process_frame
		_add_music_layer(&"lead", config.music_lead if config.music_lead != null else seq.build_lead())
		progress.call(0.9)
		await get_tree().process_frame
		_add_music_layer(&"pad", config.music_menu if config.music_menu != null else seq.build_pad())
		for layer: StringName in _music.keys():
			(_music[layer] as AudioStreamPlayer).play()
	ready_to_play = true
	progress.call(1.0)


## Plays a one-shot. pitch_var = random pitch spread (0.05 = +/-5 %), pitch = base pitch.
func play(id: StringName, pitch_var: float = 0.05, volume_var: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(id):
		return
	var def: Array = SfxLibrary.DEFS[id]
	var max_voices: int = def[2]
	var priority: int = def[3]
	if int(_active.get(id, 0)) >= max_voices:
		return
	var slot: int = _find_voice(priority)
	if slot < 0:
		return
	var p: AudioStreamPlayer = _players[slot]
	_release_slot(slot)
	p.stream = _streams[id] as AudioStream
	p.bus = def[0]
	p.volume_db = float(def[1]) + randf_range(-volume_var, volume_var)
	p.pitch_scale = maxf(pitch * (1.0 + randf_range(-pitch_var, pitch_var)), 0.05)
	p.play()
	_player_ids[slot] = id
	_active[id] = int(_active.get(id, 0)) + 1


## Plays a positional one-shot (passing trains). Returns the player so callers can move it.
func play_3d(id: StringName, position: Vector3) -> AudioStreamPlayer3D:
	if not _streams.has(id):
		return null
	for p in _players_3d:
		if not p.playing:
			var def: Array = SfxLibrary.DEFS[id]
			p.stream = _streams[id] as AudioStream
			p.volume_db = float(def[1]) + 6.0
			p.position = position
			p.play()
			return p
	return null


## Coin pickup with a pitch that climbs one semitone per consecutive coin.
func play_coin() -> void:
	play(&"coin", 0.0, 0.0, MathUtils.semitones(float(_coin_chain)))
	_coin_chain = mini(_coin_chain + 1, COIN_CHAIN_MAX)
	_coin_timer = COIN_CHAIN_RESET


## Starts (or adjusts) a looping sound at a linear volume 0..1 and pitch.
func set_loop(id: StringName, volume: float, pitch: float = 1.0) -> void:
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _loops.get(id) as AudioStreamPlayer
	if volume <= 0.001:
		if p != null and p.playing:
			p.stop()
		return
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = _streams[id] as AudioStream
		p.bus = (SfxLibrary.DEFS[id] as Array)[0]
		add_child(p)
		_loops[id] = p
	p.volume_db = float((SfxLibrary.DEFS[id] as Array)[1]) + linear_to_db(clampf(volume, 0.001, 1.0))
	p.pitch_scale = pitch
	if not p.playing:
		p.play()


## Music mix: &"menu" (calm pad), &"game" (layers follow intensity) or &"off".
func set_music_mode(mode: StringName) -> void:
	_music_mode = mode
	_update_music_targets()


## Adaptive music: 0 = start of a run, 1 = top speed. Drums, bass and lead fade in with it.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	_update_music_targets()


## Briefly lowers the music (crash, jingles).
func duck(db: float = -6.0) -> void:
	_duck_db = db
	_apply_bus(&"Music")


## Muffles music while paused.
func set_paused_filter(enabled: bool) -> void:
	if _lowpass != null:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(&"Music"), 0, enabled)


## Re-reads the volume settings (dB = linear_to_db(slider)).
func apply_volumes() -> void:
	for bus in BUSES:
		_apply_bus(bus)


## Sound ids available (audio lab).
func sound_ids() -> Array:
	return _streams.keys()


func _setup_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 700.0
	var music_index: int = AudioServer.get_bus_index(&"Music")
	AudioServer.add_bus_effect(music_index, _lowpass, 0)
	AudioServer.set_bus_effect_enabled(music_index, 0, false)


func _apply_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var linear: float = SettingsManager.get_float(str(SETTING_OF_BUS[bus]))
	var enabled: bool = SettingsManager.get_bool(str(TOGGLE_OF_BUS[bus]))
	AudioServer.set_bus_mute(index, linear <= 0.001 or not enabled)
	var db: float = linear_to_db(maxf(linear, 0.001))
	if bus == &"Music":
		db += _duck_db
	AudioServer.set_bus_volume_db(index, db)


func _add_music_layer(layer: StringName, stream: AudioStream) -> void:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Music"
	p.volume_db = -80.0
	add_child(p)
	_music[layer] = p
	_update_music_targets()


func _update_music_targets() -> void:
	var i: float = _intensity
	if _music.has(&"track"):
		var level: float = {&"menu": 0.75, &"game": 0.85 + 0.15 * i}.get(_music_mode, 0.0)
		_music_target = {&"track": level}
		return
	match _music_mode:
		&"menu":
			_music_target = {&"pad": 0.9, &"bass": 0.35, &"lead": 0.22, &"drums": 0.0}
		&"game":
			_music_target = {&"pad": 0.3, &"bass": 0.5 + 0.4 * i, &"drums": 0.45 + 0.45 * i,
					&"lead": smoothstep(0.25, 0.75, i) * 0.8}
		_:
			_music_target = {&"pad": 0.0, &"bass": 0.0, &"lead": 0.0, &"drums": 0.0}


## The optional single music file (looping), or null when the synth layers should play.
func _find_music_track() -> AudioStream:
	for ext: String in [".ogg", ".mp3", ".wav"]:
		var path: String = MUSIC_TRACK_BASE + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = ResourceLoader.load(path) as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			elif stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			elif stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			return stream
	return null


## Finds a free voice, or steals the lowest-priority one if it is less important.
func _find_voice(priority: int) -> int:
	var weakest: int = -1
	var weakest_priority: int = priority
	for i in range(_players.size()):
		if not _players[i].playing:
			return i
		var other: StringName = _player_ids[i]
		var other_priority: int = (SfxLibrary.DEFS[other] as Array)[3] if SfxLibrary.DEFS.has(other) else 0
		if other_priority < weakest_priority:
			weakest_priority = other_priority
			weakest = i
	return weakest


func _release_slot(slot: int) -> void:
	var id: StringName = _player_ids[slot]
	if id != &"":
		_active[id] = maxi(int(_active.get(id, 0)) - 1, 0)
		_player_ids[slot] = &""


func _on_voice_finished(slot: int) -> void:
	_release_slot(slot)
