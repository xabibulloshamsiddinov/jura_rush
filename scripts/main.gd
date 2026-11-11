## Boot scene. Shows the splash, pre-warms pools / effects / synthesised audio behind a loading
## bar, creates the 3D world, then hands over to the game-flow state machine.
##
## Command line (after "--"):  --bot            start with the test bot playing
##                             --bot-soak=600   headless bot soak test for N simulated seconds
##                             --shot=path.png  save a screenshot a few seconds in, then quit
extends Node

const WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")

var world: GameWorld = null


func _ready() -> void:
	InputMapSetup.ensure()
	Engine.max_fps = 60
	var headless: bool = DisplayServer.get_name() == "headless"
	var soak_seconds: float = 0.0
	var shot_path: String = ""
	var use_bot: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bot-soak="):
			soak_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			shot_path = arg.get_slice("=", 1)
		elif arg == "--bot":
			use_bot = true
	if soak_seconds > 0.0 or not shot_path.is_empty():
		# Automated runs must never touch the real profile.
		SaveSystem.path = "user://automation_save.json"
		SaveSystem.data = SaveCodec.defaults()
		SaveSystem.data["tutorial_done"] = true
	SceneRouter.show_screen(&"loading_overlay", {"mode": "boot"})
	var overlay: UIScreen = SceneRouter.get_screen(&"loading_overlay")
	await get_tree().process_frame
	overlay.call(&"set_progress", 0.1)
	VFXManager.prewarm()
	PoolManager.register_factory(&"floating_text", func() -> Node: return FloatingText.new(), 12, false)
	await get_tree().process_frame
	world = WORLD_SCENE.instantiate() as GameWorld
	add_child(world)
	move_child(world, 0)
	overlay.call(&"set_progress", 0.4)
	await get_tree().process_frame
	await AudioManager.build_async(func(p: float) -> void:
		overlay.call(&"set_progress", 0.4 + 0.6 * p), not headless)
	add_child(VersusMode.new(world))
	if OS.is_debug_build():
		add_child(DebugOverlay.new(world))
	await get_tree().create_timer(0.35).timeout
	GameState.boot_finished()
	if soak_seconds > 0.0:
		add_child(BotSoak.new(world, soak_seconds))
	elif not shot_path.is_empty():
		add_child(ScreenshotRun.new(world, shot_path))
	elif use_bot:
		world.bot.enabled = true
