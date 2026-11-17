## Automation helper (run with: godot --path . -- --shot=user://shot.png). Saves a screenshot of
## the menu, starts a bot-driven run, saves gameplay screenshots, then quits. Used to check the
## rendering without a human at the keyboard.
##
## Dev-only extras (after "--", next to --shot=...):
##   --shot-interval=S       seconds between the frames of every burst below. Without it each
##                           burst keeps its own default (shot 1.5 s, menu 0.9 s, start 0.25 s).
##   --shot-burst=N          N more gameplay frames after _run2 (_b00, _b01 ...)
##   --menu-burst=N          N more menu frames before PLAY (_menu00 ...: idle loop review)
##   --start-burst=N         N frames right after PLAY (_start00 ...: camera swing, T-Rex retreat)
##   --force-powerup=ID      activates power-up ID (jetpack, dash, magnet ...) 6 s after PLAY;
##                           _run2 then follows 0.8 s after _run1 so the power-up is still on
##   --action-shots          on the empty runway: lane change, jump and roll with frames mid-move
##   --shot-scenario=menu    menu idle / roar frames, then the run-start roar and retreat
##   --shot-scenario=chase   forces a stumble (T-Rex chase frames), then a crash (catch frames)
##   --shot-pattern=a,b,...  forces these chunk patterns (round robin) for the whole run
## --action-shots and --shot-scenario replace the default sequence; the other flags combine.
## All waits are real time, so crash slow motion and hit-stop do not stretch the schedule.
class_name ScreenshotRun
extends Node

var _world: GameWorld = null
var _path: String = ""
var _patterns: PackedStringArray = PackedStringArray()
var _pattern_chunks: int = -1
var _pattern_index: int = 0


func _init(world: GameWorld, path: String) -> void:
	_world = world
	_path = path
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var burst: int = 0
	var interval: float = -1.0
	var scenario: String = ""
	var action_shots: bool = false
	var menu_burst: int = 0
	var start_burst: int = 0
	var force_powerup: StringName = &""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-burst="):
			burst = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-interval="):
			interval = maxf(float(arg.get_slice("=", 1)), 0.02)
		elif arg.begins_with("--shot-scenario="):
			scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-pattern="):
			_patterns = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--menu-burst="):
			menu_burst = int(arg.get_slice("=", 1))
		elif arg.begins_with("--start-burst="):
			start_burst = int(arg.get_slice("=", 1))
		elif arg.begins_with("--force-powerup="):
			force_powerup = StringName(arg.get_slice("=", 1))
		elif arg == "--action-shots":
			action_shots = true
	if action_shots:
		await _action_shots()
		get_tree().quit()
		return
	if scenario == "menu":
		await _menu_scenario()
		get_tree().quit()
		return
	if scenario == "chase":
		await _chase_scenario()
		get_tree().quit()
		return
	var shot_step: float = interval if interval > 0.0 else 1.5
	var menu_step: float = interval if interval > 0.0 else 0.9
	var start_step: float = interval if interval > 0.0 else 0.25

	await _wait(1.5)
	await _save("_menu")
	for i in range(menu_burst):
		await _wait(menu_step)
		await _save("_menu%02d" % i)
	_world.bot.enabled = true
	GameEvents.request_play.emit(false)
	var elapsed: float = 0.0
	for i in range(start_burst):
		await _wait(start_step)
		elapsed += start_step
		await _save("_start%02d" % i)
	if force_powerup != &"":
		await _wait(maxf(6.0 - elapsed, 0.1))
		elapsed = maxf(elapsed, 6.0)
		_world.player.powerups.activate(force_powerup)
	await _wait(maxf(9.0 - elapsed, 0.1))
	await _save("_run1")
	await _wait(6.0 if force_powerup == &"" else 0.8)
	await _save("_run2")
	for i in range(burst):
		await _wait(shot_step)
		await _save("_b%02d" % i)
	GameEvents.request_pause.emit()
	await _wait(0.6)
	await _save("_pause")
	get_tree().quit()


func _process(_delta: float) -> void:
	# --shot-pattern: keep forcing the listed patterns, one per generated chunk.
	if _patterns.is_empty() or _world == null or _world.track == null:
		return
	var generator: ChunkGenerator = _world.track.generator
	if generator.chunks_generated != _pattern_chunks:
		_pattern_chunks = generator.chunks_generated
		generator.force_next(StringName(_patterns[_pattern_index % _patterns.size()]))
		_pattern_index += 1


func _menu_scenario() -> void:
	for i in range(6):
		await _wait(0.9)
		await _save("_menu%d" % i)
	GameEvents.request_play.emit(false)
	for i in range(8):
		await _wait(0.3)
		await _save("_start%d" % i)


func _chase_scenario() -> void:
	_world.bot.enabled = true
	GameEvents.request_play.emit(false)
	await _wait(8.0)
	await _save("_run")
	GameEvents.player_stumbled.emit(&"debug")
	for i in range(4):
		await _wait(0.45)
		await _save("_chase%d" % i)
	_world.bot.enabled = false
	_world.player.die(&"debug")
	for i in range(5):
		await _wait(0.45)
		await _save("_catch%d" % i)


## Scripted moves on the obstacle-free start of a run, saved mid-motion.
func _action_shots() -> void:
	await _wait(1.5)
	GameEvents.request_play.emit(false)
	while not GameState.is_running():
		await get_tree().process_frame
	var p: Player = _world.player
	await _wait(0.5)
	p.push_command(InputCommand.Lane.new(-1))
	await _wait(0.05)
	await _save("_lane_a")
	await _wait(0.05)
	await _save("_lane_b")
	await _wait(0.5)
	p.push_command(InputCommand.Jump.new())
	await _wait(0.06)
	await _save("_jump_takeoff")
	await _wait(0.2)
	await _save("_jump_apex")
	while not p.on_ground:
		await get_tree().process_frame
	await _wait(0.04)
	await _save("_land")
	await _wait(0.5)
	p.push_command(InputCommand.Roll.new())
	for i in range(4):
		await _wait(0.1)
		await _save("_roll%d" % i)


## Real-time wait (ignores the crash slow motion and hit-stop time scale).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _save(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_path.get_basename() + suffix + ".png")
