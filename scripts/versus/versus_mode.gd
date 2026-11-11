## Opens and closes the 2 Player versus mode next to the single-player game without touching
## its flow: the single-player world is taken out of the tree while a match runs (GameState
## stays in the menu state) and put back, with its look restored, when the players leave.
##
## UI talks to it only through GameEvents.request_versus_* and reads the match through
## Services.locate(&"versus").
##
## Command line (after "--"):  --versus             open the versus intro at boot
##                             --versus-ui-shot=p   open the intro, screenshot it, quit
##                             --menu-shot=p        screenshot the main menu, quit
##                             --versus-bots        start a bot vs bot match at boot
##                             --versus-shot=p.png  bot match, screenshot after a few seconds, quit
##                             --versus-shot-at=S   seconds before the screenshot (default 9)
##                             --versus-time=S      match length override (testing)
##                             --versus-soak=N      headless bot match for N seconds
class_name VersusMode
extends Node

const LANDSCAPE: Vector2i = Vector2i(1280, 720)

var game: VsGame = null
var presenter: VsPresenter = null

var _world: Node3D = null
var _saved_window: Vector2i = Vector2i.ZERO
var _bots: bool = false
var _shot_path: String = ""
var _soak_left: float = 0.0
var _shot_at: float = 9.0


func _init(single_player_world: Node3D) -> void:
	_world = single_player_world


func _ready() -> void:
	VsInput.ensure()
	GameEvents.request_versus_open.connect(open_intro)
	GameEvents.request_versus_start.connect(start)
	GameEvents.request_versus_exit.connect(stop)
	GameEvents.request_versus_rematch.connect(func() -> void:
		if game != null:
			game.start_match())
	GameEvents.request_versus_pause.connect(func(value: bool) -> void:
		if game != null:
			game.set_paused(value))
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--versus":
			_open_intro.call_deferred()
		elif arg.begins_with("--menu-shot="):
			_menu_shot.call_deferred(arg.get_slice("=", 1))
		elif arg.begins_with("--versus-ui-shot="):
			_shot_path = arg.get_slice("=", 1)
			_open_intro.call_deferred()
		elif arg == "--versus-bots":
			_bots = true
		elif arg.begins_with("--versus-shot="):
			_bots = true
			_shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--versus-shot-at="):
			_shot_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--versus-time="):
			VsGame.match_time_override = float(arg.get_slice("=", 1))
		elif arg.begins_with("--versus-soak="):
			_bots = true
			_soak_left = float(arg.get_slice("=", 1))
	if _bots:
		_auto_start.call_deferred()


func _exit_tree() -> void:
	# Quitting during a match: the detached single-player world is not in the tree, free it.
	if _world != null and is_instance_valid(_world) and not _world.is_inside_tree():
		_world.free()


## True while a versus match is open.
func active() -> bool:
	return game != null


## Shows the 2 Player intro (controls and rules) over the menu.
func open_intro() -> void:
	_landscape_window(true)
	SceneRouter.show_screen(&"versus_intro")


## Opens the match (from the intro screen).
func start() -> void:
	if game != null:
		game.start_match()
		return
	var parent: Node = _world.get_parent()
	if parent != null:
		parent.remove_child(_world)
	game = VsGame.new()
	game.name = "Versus"
	get_parent().add_child(game)
	get_parent().move_child(game, 0)
	if _bots:
		game.bots[0] = VsBot.new(11)
		game.bots[1] = VsBot.new(23)
	presenter = VsPresenter.new()
	presenter.game = game
	add_child(presenter)
	Services.provide(&"versus", game)
	_landscape_window(true)
	game.start_match()
	SceneRouter.show_screen(&"versus_hud")


## Closes the match and returns to the single-player main menu.
func stop() -> void:
	if game == null:
		_landscape_window(false)
		SceneRouter.show_screen(&"main_menu")
		return
	presenter.stop_loops()
	presenter.queue_free()
	presenter = null
	Services.remove(&"versus")
	game.queue_free()
	game = null
	get_parent().add_child(_world)
	get_parent().move_child(_world, 0)
	# Rebuild the menu backdrop: resets the track, biome colours, fog and bend globals the
	# versus palette replaced, and the menu camera.
	_world.call(&"_show_menu_world")
	var rig: Object = _world.get(&"camera_rig")
	if rig != null:
		(rig.get(&"camera") as Camera3D).make_current()
	AudioManager.set_music_mode(&"menu")
	AudioManager.set_paused_filter(false)
	_landscape_window(false)
	SceneRouter.show_screen(&"main_menu")


func _process(delta: float) -> void:
	if _soak_left > 0.0 and game != null:
		_soak_left -= delta
		if game.phase == &"over":
			game.start_match()
		if _soak_left <= 0.0:
			Log.info(&"versus", "soak finished, fans %d / %d" % [game.cars[0].fans, game.cars[1].fans])
			get_tree().quit(0)


## Desktop windows open in portrait for the runner; a shared-screen race needs landscape.
func _landscape_window(on: bool) -> void:
	if OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var size: Vector2i = DisplayServer.window_get_size()
	if on:
		if size.x >= size.y:
			return
		_saved_window = size
		DisplayServer.window_set_size(LANDSCAPE)
	elif _saved_window != Vector2i.ZERO:
		DisplayServer.window_set_size(_saved_window)
		_saved_window = Vector2i.ZERO
	var screen: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var now: Vector2i = DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen.position + (screen.size - now) / 2)


func _menu_shot(path: String) -> void:
	while GameState.current() != &"menu":
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit(0)


func _open_intro() -> void:
	while GameState.current() != &"menu":
		await get_tree().process_frame
	open_intro()
	if not _shot_path.is_empty() and not _bots:
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit(0)


func _auto_start() -> void:
	# Wait for the boot sequence (menu state) before opening the match.
	while GameState.current() != &"menu":
		await get_tree().process_frame
	start()
	if not _shot_path.is_empty():
		await get_tree().create_timer(_shot_at).timeout
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(_shot_path)
		Log.info(&"versus", "screenshot saved to %s" % _shot_path)
		get_tree().quit(0)
