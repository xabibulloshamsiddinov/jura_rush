## Debug overlay (F3) and cheats. Only created in debug builds.
##   F3 overlay + track debug lines   F4 bot on/off        F5 invincible 60 s
##   F6 +1000 coins, +5 keys          F7 next biome        F8 give next power-up
##   F9 slow motion                   F10 reload config    F11 +30 s of speed ramp
##   F12 force next pattern (cycles through the library)
class_name DebugOverlay
extends CanvasLayer

var _world: GameWorld = null
var _label: Label = null
var _refresh: float = 0.0
var _powerup_index: int = 0
var _pattern_index: int = 0
var _last_failed: StringName = &""


func _init(world: GameWorld) -> void:
	_world = world
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16.0, 220.0)
	_label.add_theme_font_size_override(&"font_size", 24)
	_label.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.7))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.visible = false
	add_child(_label)
	GameEvents.validator_failed.connect(func(id: StringName) -> void: _last_failed = id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		_label.visible = not _label.visible
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F4:
			_world.bot.enabled = not _world.bot.enabled
		KEY_F5:
			_world.player.grant_invulnerability(60.0)
		KEY_F6:
			SaveSystem.add_coins(1000)
			SaveSystem.add_keys(5)
		KEY_F7:
			_world.biomes.skip()
		KEY_F8:
			_world.player.powerups.activate(ContentDB.POWERUPS[_powerup_index].id)
			_powerup_index = (_powerup_index + 1) % ContentDB.POWERUPS.size()
		KEY_F9:
			GameState.toggle_slow_motion()
		KEY_F10:
			GameConfig.reload()
		KEY_F11:
			_world.director.run_time += 30.0
		KEY_F12:
			var library: PatternLibrary = _world.track.library
			_pattern_index = (_pattern_index + 1) % library.size()
			_world.track.generator.force_next(library.defs[_pattern_index].id)


func _process(delta: float) -> void:
	if not _label.visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	var track: TrackManager = _world.track
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS %d   %.1f ms" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("draw calls %d   objects %d   nodes %d" % [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	lines.append("state %s   seed %d   bot %s" % [GameState.current(), GameState.run_seed,
			"on" if _world.bot.enabled else "off"])
	lines.append("speed %.1f   dist %d m   chunks %d   recycled %d" % [track.world_speed,
			int(track.distance_travelled), track.chunks.size(), track.recycled_count])
	lines.append("difficulty %.1f   skill %.2f   tension %.0f   rest %d" % [
			_world.director.pattern_difficulty(), _world.director.skill(),
			track.generator.tension, track.generator.rest_queue])
	lines.append("pattern %s   here %s" % [track.generator.last_pattern_id,
			track.chunk_at(0.0).pattern_id if track.chunk_at(0.0) != null else &"-"])
	lines.append("validator rejects %d (last %s)   max gap %.4f" % [track.generator.failures,
			_last_failed, track.max_gap_seen])
	lines.append("pools in use %d / %d" % [PoolManager.total_in_use(), PoolManager.total_created()])
	lines.append(PoolManager.stats_text())
	_label.text = "\n".join(lines)
