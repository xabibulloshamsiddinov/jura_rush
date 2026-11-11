## Automation helper (run with: godot --path . -- --shot=user://shot.png). Saves a screenshot of
## the menu, starts a bot-driven run, saves gameplay screenshots, then quits. Used to check the
## rendering without a human at the keyboard.
class_name ScreenshotRun
extends Node

var _world: GameWorld = null
var _path: String = ""


func _init(world: GameWorld, path: String) -> void:
	_world = world
	_path = path
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	await _save("_menu")
	_world.bot.enabled = true
	GameEvents.request_play.emit(false)
	await get_tree().create_timer(9.0).timeout
	await _save("_run1")
	await get_tree().create_timer(6.0).timeout
	await _save("_run2")
	# --shot-burst=N: N more gameplay frames, 1.5 s apart (visual review of a whole stretch).
	var burst: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-burst="):
			burst = int(arg.get_slice("=", 1))
	for i in range(burst):
		await get_tree().create_timer(1.5).timeout
		await _save("_b%02d" % i)
	GameEvents.request_pause.emit()
	await get_tree().create_timer(0.6).timeout
	await _save("_pause")
	get_tree().quit()


func _save(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_path.get_basename() + suffix + ".png")
